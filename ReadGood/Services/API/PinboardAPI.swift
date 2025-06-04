import Foundation

class PinboardAPI {
    private let baseURL = "https://pinboard.in/popular/"
    private let session = URLSession.shared
    private let userAgent = "ReadGood/1.0"
    
    func fetchPopularStories() async throws -> [StoryData] {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed("Failed to fetch Pinboard popular")
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw APIError.invalidResponse("Could not decode Pinboard HTML")
        }
        
        return parseHTML(html)
    }
    
    private func parseHTML(_ html: String) -> [StoryData] {
        var stories: [StoryData] = []
        
        // Updated regex pattern for Pinboard HTML structure
        // Format: <a class="bookmark_title" href="URL">TITLE</a> ... <a class="bookmark_count">COUNT</a>
        let pattern = #"<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>.*?>(\d+)</a>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for (index, match) in matches.enumerated() {
                guard index < 12 else { break } // Limit to 12 stories
                
                let urlRange = Range(match.range(at: 1), in: html)!
                let titleRange = Range(match.range(at: 2), in: html)!
                let countRange = Range(match.range(at: 3), in: html)!
                
                let url = String(html[urlRange])
                let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let countString = String(html[countRange])
                let points = Int(countString) ?? 0
                
                let story = StoryData(
                    id: "pinboard_\(index)",
                    title: title,
                    url: url,
                    commentsURL: nil,
                    source: .pinboard,
                    points: points,
                    commentCount: 0,
                    authorName: nil,
                    createdAt: Date()
                )
                
                stories.append(story)
            }
        } catch {
            print("Regex parsing failed for Pinboard: \(error)")
            
            // Fallback: try simpler parsing
            stories = fallbackParseHTML(html)
        }
        
        return stories
    }
    
    private func fallbackParseHTML(_ html: String) -> [StoryData] {
        // Simple fallback parsing if regex fails
        let lines = html.components(separatedBy: .newlines)
        var stories: [StoryData] = []
        
        for (index, line) in lines.enumerated() {
            if line.contains("bookmark_title") && line.contains("href=") {
                // Extract URL and title using simple string operations
                if let urlStart = line.range(of: "href=\""),
                   let urlEnd = line.range(of: "\"", range: urlStart.upperBound..<line.endIndex),
                   let titleStart = line.range(of: ">", range: urlEnd.upperBound..<line.endIndex),
                   let titleEnd = line.range(of: "<", range: titleStart.upperBound..<line.endIndex) {
                    
                    let url = String(line[urlStart.upperBound..<urlEnd.lowerBound])
                    let title = String(line[titleStart.upperBound..<titleEnd.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !title.isEmpty && !url.isEmpty {
                        let story = StoryData(
                            id: "pinboard_fallback_\(stories.count)",
                            title: title,
                            url: url,
                            commentsURL: nil,
                            source: .pinboard,
                            points: 0,
                            commentCount: 0,
                            authorName: nil,
                            createdAt: Date()
                        )
                        
                        stories.append(story)
                        
                        if stories.count >= 12 { break }
                    }
                }
            }
        }
        
        return stories
    }
}