import SwiftUI

struct TagSelectionView: View {
    let story: StoryData
    @State private var claudeResult: ClaudeTagResult?
    @State private var selectedTags = Set<String>()
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storyManager: StoryManager
    
    private let claudeService = ClaudeService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(story.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content area
            VStack {
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        
                        Text("Generating tags...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if let result = claudeResult, result.success {
                    VStack(alignment: .leading, spacing: 8) {
                        if let source = result.source {
                            Text("Generated via \(source)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        TagCloudView(
                            tags: result.tags,
                            selectedTags: $selectedTags
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                }
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Apply") {
                    applySelectedTags()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTags.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: 200)
        .onAppear {
            generateTags()
        }
    }
    
    private func generateTags() {
        Task {
            do {
                let result = try await claudeService.generateTags(title: story.title, url: story.url)
                
                await MainActor.run {
                    self.claudeResult = result
                    self.isLoading = false
                    
                    if !result.success {
                        self.errorMessage = result.error ?? "Failed to generate tags"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func applySelectedTags() {
        guard !selectedTags.isEmpty else { return }
        
        // Apply tags to the story via StoryManager
        Task {
            await storyManager.applyTagsToStory(story, tags: Array(selectedTags))
        }
        
        dismiss()
    }
}

struct TagCloudView: View {
    let tags: [String]
    @Binding var selectedTags: Set<String>
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 60), spacing: 4)
        ], spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                TagButton(
                    tag: tag,
                    isSelected: selectedTags.contains(tag)
                ) {
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

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TagSelectionView(story: StoryData(
        id: "1",
        title: "SwiftUI Best Practices for Performance",
        url: "https://example.com",
        commentsURL: "https://example.com/comments",
        source: .hackernews,
        points: 123,
        commentCount: 45,
        authorName: "swiftdev",
        createdAt: Date()
    ))
    .environmentObject(StoryManager())
}