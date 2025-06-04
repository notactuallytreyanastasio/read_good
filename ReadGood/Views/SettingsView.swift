import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 300.0
    @AppStorage("maxStoriesPerSource") private var maxStoriesPerSource = 15
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("redditClientId") private var redditClientId = ""
    @AppStorage("redditClientSecret") private var redditClientSecret = ""
    @AppStorage("selectedSubreddits") private var selectedSubredditsData = Data()
    
    @State private var selectedSubreddits: Set<String> = []
    
    private let availableSubreddits = [
        "news", "worldnews", "technology", "programming", "science",
        "MachineLearning", "artificial", "datascience", "cybersecurity",
        "startups", "entrepreneur", "business", "Economics",
        "television", "movies", "books", "music",
        "elixir", "swift", "python", "javascript", "rust",
        "aitah", "bestofredditorupdates", "explainlikeimfive",
        "todayilearned", "internetisbeautiful", "futurology"
    ]
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                refreshInterval: $refreshInterval,
                maxStoriesPerSource: $maxStoriesPerSource,
                enableNotifications: $enableNotifications
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            RedditSettingsView(
                clientId: $redditClientId,
                clientSecret: $redditClientSecret,
                selectedSubreddits: $selectedSubreddits,
                availableSubreddits: availableSubreddits
            )
            .tabItem {
                Label("Reddit", systemImage: "r.circle")
            }
            
            DatabaseSettingsView()
                .tabItem {
                    Label("Database", systemImage: "internaldrive")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadSelectedSubreddits()
        }
        .onChange(of: selectedSubreddits) { _ in
            saveSelectedSubreddits()
        }
    }
    
    private func loadSelectedSubreddits() {
        if let subreddits = try? JSONDecoder().decode(Set<String>.self, from: selectedSubredditsData) {
            selectedSubreddits = subreddits
        } else {
            // Default subreddits
            selectedSubreddits = Set(["news", "technology", "programming", "science", "worldnews"])
        }
    }
    
    private func saveSelectedSubreddits() {
        if let data = try? JSONEncoder().encode(selectedSubreddits) {
            selectedSubredditsData = data
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var refreshInterval: Double
    @Binding var maxStoriesPerSource: Int
    @Binding var enableNotifications: Bool
    
    var body: some View {
        Form {
            Section("Refresh Settings") {
                VStack(alignment: .leading) {
                    Text("Refresh Interval: \(Int(refreshInterval/60)) minutes")
                    Slider(value: $refreshInterval, in: 60...3600, step: 60)
                }
                
                VStack(alignment: .leading) {
                    Text("Stories per source: \(maxStoriesPerSource)")
                    Slider(value: Binding(
                        get: { Double(maxStoriesPerSource) },
                        set: { maxStoriesPerSource = Int($0) }
                    ), in: 5...30, step: 1)
                }
            }
            
            Section("Notifications") {
                Toggle("Enable notifications", isOn: $enableNotifications)
            }
            
            Section("Claude Integration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude CLI Integration")
                        .font(.headline)
                    
                    Text("ReadGood uses Claude CLI for AI-powered tagging. Make sure you have Claude installed:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("Download Claude Desktop", destination: URL(string: "https://claude.ai/download")!)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

struct RedditSettingsView: View {
    @Binding var clientId: String
    @Binding var clientSecret: String
    @Binding var selectedSubreddits: Set<String>
    let availableSubreddits: [String]
    
    var body: some View {
        Form {
            Section("Reddit API Credentials") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To access Reddit stories, you need API credentials:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("Create Reddit App", destination: URL(string: "https://www.reddit.com/prefs/apps")!)
                        .font(.caption)
                }
                
                TextField("Client ID", text: $clientId)
                SecureField("Client Secret", text: $clientSecret)
            }
            
            Section("Subreddits") {
                Text("Select subreddits to follow:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(availableSubreddits, id: \.self) { subreddit in
                        Toggle(subreddit, isOn: Binding(
                            get: { selectedSubreddits.contains(subreddit) },
                            set: { isSelected in
                                if isSelected {
                                    selectedSubreddits.insert(subreddit)
                                } else {
                                    selectedSubreddits.remove(subreddit)
                                }
                            }
                        ))
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}

struct DatabaseSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        Form {
            Section("Database Management") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Database Statistics")
                        .font(.headline)
                    
                    // Would show actual stats from Core Data
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stories tracked: ~")
                        Text("Tags created: ~")
                        Text("Clicks recorded: ~")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Button("Clear All Data") {
                        // Would clear Core Data
                    }
                    .foregroundColor(.red)
                    
                    Button("Export Data") {
                        // Would export to JSON/CSV
                    }
                }
            }
            
            Section("Cache") {
                Button("Clear Image Cache") {
                    // Would clear any cached images
                }
                
                Button("Reset Settings") {
                    // Would reset all UserDefaults
                }
            }
        }
        .padding()
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}