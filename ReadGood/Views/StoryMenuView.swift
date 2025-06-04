import SwiftUI

struct StoryMenuView: View {
    @EnvironmentObject var storyManager: StoryManager
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var showingSearch = false
    
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
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("ReadGood")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: { storyManager.refreshAllStories() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(storyManager.isLoading)
                    
                    Button(action: { showingSearch.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if showingSearch {
                    TextField("Search stories or tags...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                }
                
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.icon)
                            .tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .font(.system(size: 10))
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Stories list
            ScrollView {
                LazyVStack(spacing: 0) {
                    if storyManager.isLoading {
                        LoadingView()
                    } else {
                        ForEach(filteredStories) { story in
                            StoryRowView(story: story)
                                .onTapGesture {
                                    storyManager.handleStoryClick(story, clickType: .article)
                                }
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                if let lastRefresh = storyManager.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .font(.caption)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: 600)
    }
    
    private var filteredStories: [StoryData] {
        let stories = storyManager.stories
        
        // Apply search filter
        let searchFiltered = searchText.isEmpty ? stories : stories.filter { story in
            story.title.localizedCaseInsensitiveContains(searchText)
        }
        
        // Apply type filter (would need Core Data integration for unread/gems/recent)
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .unread:
            // Would filter by unread stories from Core Data
            return searchFiltered
        case .gems:
            // Would filter by low-appearance stories from Core Data
            return searchFiltered.filter { $0.points < 50 }
        case .recent:
            // Would filter by recently clicked stories from Core Data
            return searchFiltered
        }
    }
}

struct StoryRowView: View {
    let story: StoryData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(story.source.emoji)
                    .font(.system(size: 14))
                
                Text(story.title)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                    Text("\(story.points)")
                        .font(.system(size: 9))
                }
                .foregroundColor(.orange)
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 8))
                    Text("\(story.commentCount)")
                        .font(.system(size: 9))
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                if let author = story.authorName {
                    Text("by \(author)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            
            Text("Loading stories...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    StoryMenuView()
        .environmentObject(StoryManager.shared)
}