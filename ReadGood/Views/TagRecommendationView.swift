import SwiftUI

struct TagRecommendationView: View {
    let story: StoryData
    @EnvironmentObject var storyManager: StoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var recommendedTags: [String] = []
    @State private var selectedTags: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var debugLog: [String] = []
    @State private var debugText: String = ""
    
    private let claudeService = ClaudeService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Test text to verify view is loading
            Text("DEBUG: TagRecommendationView is loading...")
                .font(.title)
                .foregroundColor(.red)
                .background(Color.yellow)
                .padding()
            
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Tag Recommendations")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(story.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Divider()
            
            // Debug info section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Debug Information (Copyable):")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Copy Debug Info") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(debugText, forType: .string)
                    }
                    .font(.caption)
                }
                
                TextEditor(text: $debugText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 300)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Content
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Getting recommendations from Claude...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text("Unable to get recommendations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if recommendedTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    
                    Text("No recommendations available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select tags to apply:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120))
                    ], spacing: 8) {
                        ForEach(recommendedTags, id: \.self) { tag in
                            RecommendedTagButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                addDebugLog("User toggled tag: \(tag)")
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                if !recommendedTags.isEmpty {
                    Button("Apply Selected") {
                        applySelectedTags()
                    }
                    .disabled(selectedTags.isEmpty)
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 800, minHeight: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            addDebugLog("View appeared for story: \(story.title)")
            updateDebugText() // Initialize debug text
            loadRecommendations()
        }
    }
    
    private func addDebugLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        debugLog.append(logEntry)
        updateDebugText()
        print("🏷️ DEBUG: \(message)")
    }
    
    private func updateDebugText() {
        var text = """
        === DEBUG INFORMATION ===
        Story: \(story.title)
        URL: \(story.url ?? "nil")
        Source: \(story.source.rawValue)
        Loading: \(isLoading ? "YES" : "NO")
        Error: \(errorMessage ?? "none")
        Recommended tags count: \(recommendedTags.count)
        Recommended tags: \(recommendedTags.joined(separator: ", "))
        
        === DEBUG LOG ===
        """
        
        for (index, log) in debugLog.enumerated() {
            text += "\n\(index + 1). \(log)"
        }
        
        debugText = text
    }
    
    private func loadRecommendations() {
        addDebugLog("Starting loadRecommendations()")
        isLoading = true
        errorMessage = nil
        addDebugLog("Set isLoading = true, cleared errorMessage")
        updateDebugText() // Update after state change
        
        Task {
            addDebugLog("Task started for Claude service call")
            do {
                addDebugLog("Calling claudeService.generateTags with title: '\(story.title)' and url: '\(story.url ?? "nil")'")
                let result = try await claudeService.generateTags(title: story.title, url: story.url)
                addDebugLog("Claude service returned result: success=\(result.success), tags=\(result.tags), source=\(result.source ?? "nil"), error=\(result.error ?? "nil")")
                
                await MainActor.run {
                    addDebugLog("Back on MainActor, processing result")
                    if result.success {
                        recommendedTags = Array(result.tags.prefix(5)) // Limit to 5 tags
                        addDebugLog("Set recommendedTags to \(recommendedTags.count) items: \(recommendedTags)")
                        print("🏷️ Got \(recommendedTags.count) tag recommendations: \(recommendedTags)")
                    } else {
                        errorMessage = result.error ?? "Unknown error"
                        addDebugLog("Set errorMessage: \(errorMessage ?? "nil")")
                        print("❌ Tag recommendation failed: \(result.error ?? "Unknown error")")
                    }
                    isLoading = false
                    addDebugLog("Set isLoading = false")
                    updateDebugText() // Update after all state changes
                }
            } catch {
                addDebugLog("Caught exception: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    addDebugLog("Set errorMessage from exception: \(errorMessage ?? "nil")")
                    updateDebugText() // Update after error state changes
                    print("❌ Tag recommendation error: \(error)")
                }
            }
        }
    }
    
    private func applySelectedTags() {
        let tagsToApply = Array(selectedTags)
        
        Task {
            await storyManager.applyTagsToStory(story, tags: tagsToApply)
            
            await MainActor.run {
                print("✅ Applied \(tagsToApply.count) tags to story: \(story.title)")
                // Refresh top tags after applying new ones
                storyManager.loadTopTags()
                dismiss()
            }
        }
    }
}

struct RecommendedTagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 12))
                
                Text(tag)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TagRecommendationView(story: StoryData(
        id: "preview",
        title: "SwiftUI Performance Best Practices for iOS Development",
        url: "https://example.com",
        source: .hackernews,
        points: 100,
        commentCount: 25
    ))
    .environmentObject(StoryManager())
}
