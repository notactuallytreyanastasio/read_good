import SwiftUI

struct StoryMenuView: View {
    @EnvironmentObject var storyManager: StoryManager
    @ObservedObject private var credentialManager = CredentialManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var showingSearch = false
    @State private var showingRedditCredentials = false
    
    enum FilterType: String, CaseIterable {
        case all = "All Stories"
        case unread = "Unread"
        case gems = "Hidden Gems"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .unread: return "circle"
            case .gems: return "diamond"
            case .recent: return "clock"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tag browser at the top
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("Tags:")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if storyManager.topTags.isEmpty {
                        Text("Loading...")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(storyManager.topTags, id: \.0) { tag in
                            Button(action: {
                                if storyManager.selectedTag == tag.0 {
                                    // Deselect if already selected
                                    storyManager.selectTag(nil)
                                } else {
                                    storyManager.selectTag(tag.0)
                                }
                            }) {
                                HStack(spacing: 2) {
                                    Text(tag.0)
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                    
                                    Text("(\(tag.1))")
                                        .font(.system(size: 7))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    storyManager.selectedTag == tag.0 ? 
                                    Color(NSColor.selectedControlColor) : 
                                    Color(NSColor.controlBackgroundColor)
                                )
                                .cornerRadius(3)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(
                                storyManager.selectedTag == tag.0 ? 
                                .primary : 
                                .secondary
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Debug button
                    Button("Debug") {
                        storyManager.debugQueryTags()
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    // All tags button
                    Button("All Tags") {
                        storyManager.openTagWindow()
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    if storyManager.selectedTag != nil {
                        Button("Clear") {
                            storyManager.selectTag(nil)
                        }
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.windowBackgroundColor))
                
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 0.5)
            }
            
            // Compact header
            HStack(spacing: 8) {
                Text("ReadGood")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if storyManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button(action: { storyManager.refreshAllStories() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: { showingSearch.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reddit activation button
                Button(action: { showingRedditCredentials = true }) {
                    HStack(spacing: 2) {
                        Image(systemName: credentialManager.hasRedditCredentials ? "checkmark.circle.fill" : "globe")
                            .font(.system(size: 9))
                            .foregroundColor(credentialManager.hasRedditCredentials ? .green : .orange)
                        
                        Text(credentialManager.hasRedditCredentials ? "Reddit" : "ACTIVATE REDDIT")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(credentialManager.hasRedditCredentials ? .primary : .orange)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { storyManager.debugQueryTags() }) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Compact search (if shown)
            if showingSearch {
                VStack(spacing: 2) {
                    TextField("Search stories or tags...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(3)
                        .onSubmit {
                            storyManager.performSearch(query: searchText)
                        }
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                storyManager.searchResults = []
                            }
                        }
                    
                    Text("Comma-separated tags: swift, ios")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Compact filter tabs
            HStack(spacing: 0) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.rawValue)
                            .font(.system(size: 9))
                            .foregroundColor(selectedFilter == filter ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedFilter == filter ? Color(NSColor.selectedControlColor) : Color.clear)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(NSColor.windowBackgroundColor))
            
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
            
            // Compact stories list
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredStories.isEmpty && !storyManager.isLoading {
                        Text("No stories")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(filteredStories) { story in
                            CompactStoryRowView(story: story)
                                .onAppear {
                                    storyManager.trackStoryView(story)
                                }
                                .onTapGesture {
                                    storyManager.handleStoryClick(story, clickType: .article)
                                }
                        }
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // Minimal footer
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
            
            HStack {
                if let lastRefresh = storyManager.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $storyManager.showingTagWindow) {
            AllTagsView(tags: storyManager.allTagsData)
        }
        .sheet(isPresented: $showingRedditCredentials) {
            RedditCredentialsView()
        }
        // TODO: Add TagSelectionView to Xcode project
        /* 
        .sheet(isPresented: $storyManager.showingTagSelection) {
            if let story = storyManager.tagSelectionStory {
                TagSelectionView(story: story)
                    .environmentObject(storyManager)
            }
        }
        */
    }
    
    private var filteredStories: [StoryData] {
        // Use search results if available (includes tag filtering)
        let baseStories: [StoryData]
        if storyManager.selectedTag != nil && !storyManager.searchResults.isEmpty {
            baseStories = storyManager.searchResults
            print("📱 UI: Using tag filtered results: \(baseStories.count)")
        } else if !searchText.isEmpty && !storyManager.searchResults.isEmpty {
            baseStories = storyManager.searchResults
            print("📱 UI: Using search results: \(baseStories.count)")
        } else if !searchText.isEmpty {
            // Fall back to live title filtering if no search results
            baseStories = storyManager.stories.filter { story in
                story.title.localizedCaseInsensitiveContains(searchText)
            }
            print("📱 UI: Using live title filter: \(baseStories.count)")
        } else {
            baseStories = storyManager.stories
            print("📱 UI: Using all stories: \(baseStories.count)")
        }
        
        // Apply type filter
        let result: [StoryData]
        switch selectedFilter {
        case .all:
            result = baseStories
        case .unread:
            // Would filter by unread stories from Core Data
            result = baseStories
        case .gems:
            // Filter by low-appearance stories (hidden gems)
            result = baseStories.filter { $0.points < 50 }
        case .recent:
            // Would filter by recently clicked stories from Core Data
            result = baseStories
        }
        
        print("📱 UI: Final filtered stories: \(result.count)")
        return result
    }
}

struct CompactStoryRowView: View {
    let story: StoryData
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Source indicator
            Text(story.source.emoji)
                .font(.system(size: 10))
            
            // Title and metadata in single line when possible
            VStack(alignment: .leading, spacing: 1) {
                Text(story.title)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("\(story.points)↑")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    Text("\(story.commentCount)💬")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    if let author = story.authorName {
                        Text(author)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isHovering ? Color(NSColor.selectedControlColor).opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// Keep the old one for now but rename it
struct StoryRowView: View {
    let story: StoryData
    
    var body: some View {
        CompactStoryRowView(story: story)
    }
}

struct LoadingView: View {
    var body: some View {
        HStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.5)
            Text("Loading...")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AllTagsView: View {
    let tags: [(String, Int)]
    
    var body: some View {
        NavigationView {
            VStack {
                if tags.isEmpty {
                    Text("No tags found in database")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("\(tags.count) unique tags found")
                        .font(.headline)
                        .padding()
                    
                    List {
                        ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Text(tag.0)
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Text("\(tag.1)")
                                    .foregroundColor(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("All Tags")
            .frame(minWidth: 400, minHeight: 500)
        }
    }
}

#Preview {
    StoryMenuView()
        .environmentObject(StoryManager())
}