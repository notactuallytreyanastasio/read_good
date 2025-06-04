import Foundation
import Combine

import AppKit

@MainActor
class StoryManager: ObservableObject {
    nonisolated static let shared = StoryManager()
    
    @Published var stories: [StoryData] = []
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    
    private let dataController = DataController()
    private let hackernewsAPI = HackerNewsAPI()
    private let redditAPI = RedditAPI()
    private let pinboardAPI = PinboardAPI()
    private let archiveService = ArchiveService()
    private let claudeService = ClaudeService()
    
    private var cancellables = Set<AnyCancellable>()
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    nonisolated init() {
        // setupPeriodicRefresh() will be called after @MainActor properties are set
    }
    
    nonisolated func startPeriodicRefresh() {
        Task { @MainActor in
            setupPeriodicRefresh()
            // Also load any existing tags on startup
            loadTopTags()
        }
    }
    
    func refreshAllStories() {
        guard !isLoading else { 
            print("⚠️ Refresh already in progress, skipping")
            return 
        }
        
        print("🔄 Starting story refresh...")
        isLoading = true
        
        Task {
            do {
                print("📡 Fetching stories with caching logic...")
                
                // Check cache status for each source
                let hnShouldRefresh = await dataController.shouldRefreshSource("hackernews", cacheMinutes: 30)
                let pinboardShouldRefresh = await dataController.shouldRefreshSource("pinboard", cacheMinutes: 30)
                // Reddit always refreshes (no caching)
                
                print("📊 Cache status - HN: \(hnShouldRefresh ? "refresh" : "cached"), Pinboard: \(pinboardShouldRefresh ? "refresh" : "cached"), Reddit: always refresh")
                
                // Fetch or load cached stories
                let hnStories: [StoryData]
                if hnShouldRefresh {
                    hnStories = try await hackernewsAPI.fetchTopStories()
                    print("✅ Fetched \(hnStories.count) fresh HN stories")
                    dataController.recordSourceFetch("hackernews")
                } else {
                    hnStories = await dataController.getCachedStories(for: .hackernews)
                    print("📚 Loaded \(hnStories.count) cached HN stories")
                }
                
                let pinboardStories: [StoryData]
                do {
                    if pinboardShouldRefresh {
                        pinboardStories = try await pinboardAPI.fetchPopularStories()
                        print("✅ Fetched \(pinboardStories.count) fresh Pinboard stories")
                        dataController.recordSourceFetch("pinboard")
                    } else {
                        pinboardStories = await dataController.getCachedStories(for: .pinboard)
                        print("📚 Loaded \(pinboardStories.count) cached Pinboard stories")
                    }
                } catch {
                    print("⚠️ Pinboard fetch failed, using cached: \(error)")
                    pinboardStories = await dataController.getCachedStories(for: .pinboard)
                }
                
                // Reddit always fetches fresh (no caching)
                var redditStories: [StoryData] = []
                do {
                    redditStories = try await redditAPI.fetchStories()
                    print("✅ Fetched \(redditStories.count) fresh Reddit stories")
                    dataController.recordSourceFetch("reddit")
                } catch {
                    if case APIError.missingCredentials = error {
                        print("⚠️ Reddit fetch skipped: No credentials configured. Use 'ACTIVATE REDDIT' to set up.")
                    } else {
                        print("⚠️ Reddit fetch failed: \(error)")
                    }
                }
                
                let allStories = hnStories + redditStories + pinboardStories
                
                // Update UI on main thread
                await MainActor.run {
                    self.stories = allStories
                    self.lastRefresh = Date()
                    print("🎉 Updated UI with \(allStories.count) total stories")
                }
                
                // Save to Core Data in background (only if we fetched fresh data)
                if hnShouldRefresh || pinboardShouldRefresh || !redditStories.isEmpty {
                    dataController.batchSaveStories(allStories)
                }
                
                // Load top tags after saving stories
                self.loadTopTags()
                
            } catch {
                print("❌ Failed to refresh stories: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    @Published var showingTagSelection = false
    @Published var tagSelectionStory: StoryData?
    
    func handleStoryClick(_ story: StoryData, clickType: ClickType) {
        Task {
            // Track click in database
            await trackClick(story: story, type: clickType)
            
            // Generate archive URLs
            let archiveURL = archiveService.generateArchiveURL(for: story.url ?? "")
            
            // Open URLs based on click type and story source
            switch clickType {
            case .article:
                await openStoryURLs(story: story, archiveURL: archiveURL)
                
                // Generate and apply tags automatically for now
                if let url = story.url {
                    await generateAndApplyTagsDirectly(story: story, url: url)
                }
                
            case .comments:
                if let commentsURL = story.commentsURL {
                    await openURL(commentsURL)
                }
                
            case .archive:
                await openURL(archiveURL)
            }
        }
    }
    
    func applyTagsToStory(_ story: StoryData, tags: [String]) async {
        dataController.performBackgroundTask { context in
            let managedStory = Story.findOrCreate(from: story, in: context)
            
            tags.forEach { tagName in
                _ = Tag.findOrCreate(name: tagName, for: managedStory, in: context)
            }
            
            do {
                try context.save()
                print("✅ Applied \(tags.count) tags to story: \(story.title)")
            } catch {
                print("❌ Failed to save tags: \(error)")
            }
        }
    }
    
    private func openStoryURLs(story: StoryData, archiveURL: String) async {
        switch story.source {
        case .hackernews:
            // HN: Archive + Discussion + Article
            await openURL(archiveURL)
            
            if let commentsURL = story.commentsURL {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s delay
                await openURL(commentsURL)
            }
            
            if let articleURL = story.url {
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s delay
                await openURL(articleURL)
            }
            
        case .reddit:
            // Reddit: Archive + Reddit Discussion + Actual Article
            await openURL(archiveURL)
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            await openURL(story.commentsURL ?? story.url ?? "")
            
            if let actualURL = story.actualURL, actualURL != story.url {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await openURL(actualURL)
            }
            
        case .pinboard:
            // Pinboard: Archive + Article
            await openURL(archiveURL)
            
            if let articleURL = story.url {
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s delay
                await openURL(articleURL)
            }
        }
    }
    
    private func openURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        await MainActor.run {
            _ = NSWorkspace.shared.open(url)
        }
    }
    
    private func trackClick(story: StoryData, type: ClickType) async {
        dataController.performBackgroundTask { context in
            let managedStory = Story.findOrCreate(from: story, in: context)
            managedStory.isViewed = true
            managedStory.viewedAt = Date()
            managedStory.engagementCount += 1
            
            _ = Click.create(type: type, for: managedStory, in: context)
            
            do {
                try context.save()
            } catch {
                print("Failed to track click: \(error)")
            }
        }
    }
    
    private func generateAndApplyTagsDirectly(story: StoryData, url: String) async {
        do {
            let result = try await claudeService.generateTags(title: story.title, url: url)
            
            if result.success && !result.tags.isEmpty {
                dataController.performBackgroundTask { context in
                    let managedStory = Story.findOrCreate(from: story, in: context)
                    
                    result.tags.forEach { tagName in
                        _ = Tag.findOrCreate(name: tagName, for: managedStory, in: context)
                    }
                    
                    do {
                        try context.save()
                        print("✅ Applied \(result.tags.count) AI tags via \(result.source ?? "unknown") to story: \(story.title)")
                    } catch {
                        print("❌ Failed to save tags: \(error)")
                    }
                }
            } else {
                print("⚠️ Claude tag generation failed: \(result.error ?? "Unknown error")")
            }
        } catch {
            print("❌ Failed to generate tags: \(error)")
        }
    }
    
    private func setupPeriodicRefresh() {
        Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshAllStories()
            }
            .store(in: &cancellables)
    }
    
    // Search functions - now async to avoid blocking UI
    func searchStories(query: String) async -> [Story] {
        return await dataController.searchStories(query: query)
    }
    
    func searchStoriesByTags(_ tags: [String]) async -> [Story] {
        return await dataController.searchStoriesByTags(tags)
    }
    
    @Published var searchResults: [StoryData] = []
    @Published var isSearching = false
    
    // Tag browser state
    @Published var topTags: [(String, Int)] = []
    @Published var selectedTag: String?
    
    func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            // Check if query contains tags (comma-separated)
            if query.contains(",") {
                let tags = query.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let coreDataStories = await searchStoriesByTags(tags)
                let storyData = coreDataStories.compactMap { story in
                    StoryData(
                        id: story.id,
                        title: story.title,
                        url: story.url,
                        commentsURL: story.commentsURL,
                        source: StorySource(rawValue: story.source) ?? .hackernews,
                        points: Int(story.points),
                        commentCount: Int(story.commentCount),
                        authorName: nil, // Not stored in Core Data
                        createdAt: story.firstSeenAt // Use firstSeenAt as proxy
                    )
                }
                
                await MainActor.run {
                    self.searchResults = storyData
                    self.isSearching = false
                    print("🔍 Tag search for \(tags) found \(storyData.count) results")
                }
            } else {
                // Regular title search
                let coreDataStories = await searchStories(query: query)
                let storyData = coreDataStories.compactMap { story in
                    StoryData(
                        id: story.id,
                        title: story.title,
                        url: story.url,
                        commentsURL: story.commentsURL,
                        source: StorySource(rawValue: story.source) ?? .hackernews,
                        points: Int(story.points),
                        commentCount: Int(story.commentCount),
                        authorName: nil, // Not stored in Core Data
                        createdAt: story.firstSeenAt // Use firstSeenAt as proxy
                    )
                }
                
                await MainActor.run {
                    self.searchResults = storyData
                    self.isSearching = false
                    print("🔍 Title search for '\(query)' found \(storyData.count) results")
                }
            }
        }
    }
    
    // Tag browser methods
    func loadTopTags() {
        Task {
            let tags = await dataController.getTopTags(limit: 5)
            await MainActor.run {
                self.topTags = tags
                print("🏷️ Loaded \(tags.count) top tags: \(tags.map { $0.0 })")
            }
        }
    }
    
    func selectTag(_ tagName: String?) {
        selectedTag = tagName
        if let tagName = tagName {
            // Search for stories with this tag
            performSearch(query: tagName)
        } else {
            // Clear tag filter
            searchResults = []
        }
    }
    
    func trackStoryView(_ story: StoryData) {
        Task {
            dataController.performBackgroundTask { context in
                let managedStory = Story.findOrCreate(from: story, in: context)
                managedStory.viewCount += 1
                
                do {
                    try context.save()
                } catch {
                    print("Failed to track story view: \(error)")
                }
            }
        }
    }
    
    // Debug methods
    func debugQueryTags() {
        Task {
            print("🏷️ DEBUG: Starting comprehensive database query...")
            let storyCount = await dataController.getStoryCount()
            let clickCount = await dataController.getClickCount()
            let allTags = await dataController.getAllTagsWithCounts()
            
            await MainActor.run {
                print("🏷️ DEBUG: Database Summary:")
                print("🏷️ DEBUG: - Stories: \(storyCount)")
                print("🏷️ DEBUG: - Clicks: \(clickCount)")
                print("🏷️ DEBUG: - Unique tags: \(allTags.count)")
                print("🏷️ DEBUG: All tags: \(allTags)")
            }
        }
    }
    
    @Published var showingTagWindow = false
    @Published var allTagsData: [(String, Int)] = []
    
    func openTagWindow() {
        Task {
            let allTags = await dataController.getAllTagsWithCounts()
            await MainActor.run {
                self.allTagsData = allTags
                self.showingTagWindow = true
            }
        }
    }
}