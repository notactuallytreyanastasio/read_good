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
                print("📡 Fetching stories from all sources...")
                
                // Start with just Hacker News for testing
                let hnStories = try await hackernewsAPI.fetchTopStories()
                print("✅ Fetched \(hnStories.count) HN stories")
                
                // Try other sources but don't fail if they error
                var redditStories: [StoryData] = []
                var pinboardStories: [StoryData] = []
                
                do {
                    redditStories = try await redditAPI.fetchStories()
                    print("✅ Fetched \(redditStories.count) Reddit stories")
                } catch {
                    print("⚠️ Reddit fetch failed (expected if no credentials): \(error)")
                }
                
                do {
                    pinboardStories = try await pinboardAPI.fetchPopularStories()
                    print("✅ Fetched \(pinboardStories.count) Pinboard stories")
                } catch {
                    print("⚠️ Pinboard fetch failed: \(error)")
                }
                
                let allStories = hnStories + redditStories + pinboardStories
                
                // Update UI on main thread
                await MainActor.run {
                    self.stories = allStories
                    self.lastRefresh = Date()
                    print("🎉 Updated UI with \(allStories.count) total stories")
                }
                
                // Save to Core Data in background
                dataController.batchSaveStories(allStories)
                
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
                
                // Auto-generate tags
                if let url = story.url {
                    await generateAndApplyTags(story: story, url: url)
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
    
    private func generateAndApplyTags(story: StoryData, url: String) async {
        do {
            let tags = try await claudeService.generateTags(title: story.title, url: url)
            
            dataController.performBackgroundTask { context in
                let managedStory = Story.findOrCreate(from: story, in: context)
                
                tags.forEach { tagName in
                    _ = Tag.findOrCreate(name: tagName, for: managedStory, in: context)
                }
                
                do {
                    try context.save()
                    print("Applied \(tags.count) AI tags to story: \(story.title)")
                } catch {
                    print("Failed to save tags: \(error)")
                }
            }
        } catch {
            print("Failed to generate tags: \(error)")
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
    
    // Search functions
    func searchStories(query: String) -> [Story] {
        return dataController.searchStories(query: query)
    }
    
    func searchStoriesByTags(_ tags: [String]) -> [Story] {
        return dataController.searchStoriesByTags(tags)
    }
}