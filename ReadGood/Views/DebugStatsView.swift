import SwiftUI

struct DebugStatsView: View {
    @EnvironmentObject var storyManager: StoryManager
    @State private var stories: [StoryStats] = []
    @State private var isLoading = true
    @State private var sortOrder: SortOrder = .byViews
    
    enum SortOrder: String, CaseIterable {
        case byViews = "Views"
        case byClicks = "Clicks"
        case byTitle = "Title"
        case bySource = "Source"
        case byPoints = "Points"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Stats")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Sort picker
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: sortOrder) { _ in
                    sortStories()
                }
                
                Button("Refresh") {
                    loadStats()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading stats...")
                        .font(.headline)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if stories.isEmpty {
                VStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No stories found")
                        .font(.headline)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Stats table
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header row
                        HStack {
                            Group {
                                Text("Title")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Source")
                                    .frame(width: 80)
                                Text("Views")
                                    .frame(width: 60)
                                Text("Clicks")
                                    .frame(width: 60)
                                Text("Points")
                                    .frame(width: 60)
                                Text("Tags")
                                    .frame(width: 120)
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        ForEach(stories, id: \.id) { story in
                            DebugStoryRowView(story: story)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadStats()
        }
    }
    
    private func loadStats() {
        isLoading = true
        
        Task {
            let allStories = await storyManager.dataController.getAllStoriesWithStats()
            
            await MainActor.run {
                self.stories = allStories
                self.isLoading = false
                sortStories()
            }
        }
    }
    
    private func sortStories() {
        switch sortOrder {
        case .byViews:
            stories.sort { $0.viewCount > $1.viewCount }
        case .byClicks:
            stories.sort { $0.clickCount > $1.clickCount }
        case .byTitle:
            stories.sort { $0.title.lowercased() < $1.title.lowercased() }
        case .bySource:
            stories.sort { $0.source < $1.source }
        case .byPoints:
            stories.sort { $0.points > $1.points }
        }
    }
}

struct DebugStoryRowView: View {
    let story: StoryStats
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Group {
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.title)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let url = story.url {
                        Text(url)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(story.source.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(sourceColor(for: story.source))
                    .frame(width: 80)
                
                Text("\(story.viewCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(story.viewCount > 0 ? .blue : .secondary)
                    .frame(width: 60)
                
                Text("\(story.clickCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(story.clickCount > 0 ? .green : .secondary)
                    .frame(width: 60)
                
                Text("\(story.points)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(story.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                    if story.tags.count > 3 {
                        Text("+\(story.tags.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = story.url {
                NSWorkspace.shared.open(URL(string: url)!)
            }
        }
    }
    
    private func sourceColor(for source: String) -> Color {
        switch source.lowercased() {
        case "hn": return .orange
        case "reddit": return .red
        case "pinboard": return .purple
        default: return .secondary
        }
    }
}

#Preview {
    DebugStatsView()
        .environmentObject(StoryManager())
        .frame(width: 800, height: 600)
}