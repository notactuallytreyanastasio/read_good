import Foundation

class HackerNewsAPI {
    private let baseURL = "https://hacker-news.firebaseio.com/v0"
    private let session = URLSession.shared
    
    struct HNItem: Codable {
        let id: Int
        let title: String?
        let url: String?
        let score: Int?
        let descendants: Int?
        let by: String?
        let time: Int?
        let type: String?
    }
    
    func fetchTopStories() async throws -> [StoryData] {
        // Get top story IDs
        let topStoriesURL = URL(string: "\(baseURL)/topstories.json")!
        let (data, _) = try await session.data(from: topStoriesURL)
        let storyIDs = try JSONDecoder().decode([Int].self, from: data)
        
        // Fetch details for first 15 stories
        let limitedIDs = Array(storyIDs.prefix(15))
        
        let stories = try await withThrowingTaskGroup(of: StoryData?.self) { group in
            for id in limitedIDs {
                group.addTask {
                    return try await self.fetchStoryDetails(id: id)
                }
            }
            
            var results: [StoryData] = []
            for try await story in group {
                if let story = story {
                    results.append(story)
                }
            }
            return results
        }
        
        return stories.sorted { $0.points > $1.points }
    }
    
    private func fetchStoryDetails(id: Int) async throws -> StoryData? {
        let itemURL = URL(string: "\(baseURL)/item/\(id).json")!
        let (data, _) = try await session.data(from: itemURL)
        let item = try JSONDecoder().decode(HNItem.self, from: data)
        
        guard let title = item.title, !title.isEmpty else { return nil }
        
        // Convert timestamp to Date
        let createdAt = item.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        
        // Generate comments URL
        let commentsURL = "https://news.ycombinator.com/item?id=\(id)"
        
        return StoryData(
            id: String(id),
            title: title,
            url: item.url,
            commentsURL: commentsURL,
            source: .hackernews,
            points: item.score ?? 0,
            commentCount: item.descendants ?? 0,
            authorName: item.by,
            createdAt: createdAt
        )
    }
}