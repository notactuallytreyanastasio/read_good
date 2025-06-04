import Foundation

class RedditAPI {
    private let baseURL = "https://oauth.reddit.com"
    private let authURL = "https://www.reddit.com/api/v1/access_token"
    private let session = URLSession.shared
    private let userAgent = "ReadGood/1.0"
    
    private var accessToken: String?
    private var tokenExpiresAt: Date?
    
    // Default subreddits matching the original app
    private let defaultSubreddits = [
        "news", "television", "elixir", "aitah", 
        "bestofredditorupdates", "explainlikeimfive"
    ]
    
    struct RedditResponse: Codable {
        let data: RedditData
    }
    
    struct RedditData: Codable {
        let children: [RedditChild]
    }
    
    struct RedditChild: Codable {
        let data: RedditPost
    }
    
    struct RedditPost: Codable {
        let id: String
        let title: String
        let url: String
        let permalink: String
        let score: Int
        let num_comments: Int
        let author: String
        let created_utc: Double
        let subreddit: String
        let is_self: Bool
        let selftext: String?
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let expires_in: Int
    }
    
    func fetchStories() async throws -> [StoryData] {
        try await authenticateIfNeeded()
        
        let stories = try await withThrowingTaskGroup(of: [StoryData].self) { group in
            for subreddit in defaultSubreddits {
                group.addTask {
                    return try await self.fetchSubredditPosts(subreddit: subreddit)
                }
            }
            
            var allStories: [StoryData] = []
            for try await subredditStories in group {
                allStories.append(contentsOf: subredditStories)
            }
            return allStories
        }
        
        // Shuffle and return top 15
        return Array(stories.shuffled().prefix(15))
    }
    
    private func authenticateIfNeeded() async throws {
        if let token = accessToken, 
           let expiresAt = tokenExpiresAt,
           expiresAt > Date() {
            return // Token still valid
        }
        
        guard let credentials = CredentialManager.shared.getRedditCredentials() else {
            throw APIError.missingCredentials("Reddit API credentials not configured. Please use 'ACTIVATE REDDIT' to set up credentials.")
        }
        
        let clientId = credentials.clientId
        let clientSecret = credentials.clientSecret
        
        print("Attempting Reddit authentication with Client ID: \(clientId.prefix(5))...")
        
        let credentialString = "\(clientId):\(clientSecret)"
        let credentialsData = credentialString.data(using: String.Encoding.utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        
        var request = URLRequest(url: URL(string: authURL)!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        print("Making Reddit auth request to: \(authURL)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.authenticationFailed("Invalid response from Reddit API")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = String(data: data, encoding: .utf8) {
                print("Reddit API Error Response: \(errorData)")
                throw APIError.authenticationFailed("Reddit authentication failed (HTTP \(httpResponse.statusCode)): \(errorData)")
            } else {
                throw APIError.authenticationFailed("Reddit authentication failed with HTTP status \(httpResponse.statusCode)")
            }
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        accessToken = tokenResponse.access_token
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in - 60)) // Refresh 1 minute early
        
        print("Reddit authentication successful")
    }
    
    private func fetchSubredditPosts(subreddit: String) async throws -> [StoryData] {
        guard let token = accessToken else {
            throw APIError.missingToken("No Reddit access token available")
        }
        
        let url = URL(string: "\(baseURL)/r/\(subreddit)/hot?limit=10")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed("Failed to fetch r/\(subreddit)")
        }
        
        let redditResponse = try JSONDecoder().decode(RedditResponse.self, from: data)
        
        return redditResponse.data.children.compactMap { child in
            let post = child.data
            let createdAt = Date(timeIntervalSince1970: post.created_utc)
            let redditURL = "https://old.reddit.com\(post.permalink)"
            
            return StoryData(
                id: post.id,
                title: post.title,
                url: redditURL,
                commentsURL: redditURL,
                source: .reddit,
                points: post.score,
                commentCount: post.num_comments,
                authorName: post.author,
                createdAt: createdAt,
                subreddit: post.subreddit,
                isSelf: post.is_self,
                actualURL: post.is_self ? redditURL : post.url
            )
        }
    }
}

enum APIError: Error, LocalizedError {
    case missingCredentials(String)
    case authenticationFailed(String)
    case missingToken(String)
    case requestFailed(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials(let message),
             .authenticationFailed(let message),
             .missingToken(let message),
             .requestFailed(let message),
             .invalidResponse(let message):
            return message
        }
    }
}