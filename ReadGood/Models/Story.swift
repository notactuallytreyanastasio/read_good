import Foundation
import CoreData

// Story entity for Core Data
@objc(Story)
public class Story: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var url: String?
    @NSManaged public var commentsURL: String?
    @NSManaged public var source: String // "hn", "reddit", "pinboard"
    @NSManaged public var points: Int32
    @NSManaged public var commentCount: Int32
    @NSManaged public var firstSeenAt: Date
    @NSManaged public var lastSeenAt: Date
    @NSManaged public var timesAppeared: Int32
    @NSManaged public var isViewed: Bool
    @NSManaged public var viewCount: Int32
    @NSManaged public var viewedAt: Date?
    @NSManaged public var isEngaged: Bool
    @NSManaged public var engagedAt: Date?
    @NSManaged public var engagementCount: Int32
    @NSManaged public var archiveURL: String?
    @NSManaged public var tags: Set<Tag>
    @NSManaged public var clicks: Set<Click>
}

// Swift model for API responses
struct StoryData: Codable, Identifiable {
    let id: String
    let title: String
    let url: String?
    let commentsURL: String?
    let source: StorySource
    let points: Int
    let commentCount: Int
    let authorName: String?
    let createdAt: Date?
    
    // Specific to Reddit
    let subreddit: String?
    let isSelf: Bool?
    let actualURL: String? // For Reddit - the actual link vs Reddit discussion
    
    init(id: String, title: String, url: String? = nil, commentsURL: String? = nil, 
         source: StorySource, points: Int = 0, commentCount: Int = 0, 
         authorName: String? = nil, createdAt: Date? = nil,
         subreddit: String? = nil, isSelf: Bool? = nil, actualURL: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.commentsURL = commentsURL
        self.source = source
        self.points = points
        self.commentCount = commentCount
        self.authorName = authorName
        self.createdAt = createdAt
        self.subreddit = subreddit
        self.isSelf = isSelf
        self.actualURL = actualURL
    }
}

enum StorySource: String, CaseIterable, Codable {
    case hackernews = "hn"
    case reddit = "reddit"
    case pinboard = "pinboard"
    
    var displayName: String {
        switch self {
        case .hackernews: return "Hacker News"
        case .reddit: return "Reddit"
        case .pinboard: return "Pinboard"
        }
    }
    
    var emoji: String {
        switch self {
        case .hackernews: return "🟠"
        case .reddit: return "👽"
        case .pinboard: return "📌"
        }
    }
}

// Core Data extensions
extension Story {
    static func findOrCreate(from storyData: StoryData, in context: NSManagedObjectContext) -> Story {
        let request: NSFetchRequest<Story> = Story.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND source == %@", 
                                       storyData.id, storyData.source.rawValue)
        
        if let existingStory = try? context.fetch(request).first {
            // Update existing story
            existingStory.title = storyData.title
            existingStory.url = storyData.url
            existingStory.commentsURL = storyData.commentsURL
            existingStory.points = Int32(storyData.points)
            existingStory.commentCount = Int32(storyData.commentCount)
            existingStory.lastSeenAt = Date()
            existingStory.timesAppeared += 1
            return existingStory
        } else {
            // Create new story
            let story = Story(context: context)
            story.id = storyData.id
            story.title = storyData.title
            story.url = storyData.url
            story.commentsURL = storyData.commentsURL
            story.source = storyData.source.rawValue
            story.points = Int32(storyData.points)
            story.commentCount = Int32(storyData.commentCount)
            story.firstSeenAt = Date()
            story.lastSeenAt = Date()
            story.timesAppeared = 1
            story.isViewed = false
            story.viewCount = 0
            story.isEngaged = false
            story.engagementCount = 0
            return story
        }
    }
}

// Fetch requests
extension Story {
    static func fetchRequest() -> NSFetchRequest<Story> {
        NSFetchRequest<Story>(entityName: "Story")
    }
    
    static func unreadStoriesRequest() -> NSFetchRequest<Story> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isViewed == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.lastSeenAt, ascending: false)]
        return request
    }
    
    static func recentStoriesRequest() -> NSFetchRequest<Story> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isViewed == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.viewedAt, ascending: false)]
        request.fetchLimit = 50
        return request
    }
    
    static func gemStoriesRequest() -> NSFetchRequest<Story> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "timesAppeared <= 2 AND isViewed == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.firstSeenAt, ascending: false)]
        return request
    }
}

struct StoryStats {
    let id: String
    let title: String
    let url: String?
    let source: String
    let points: Int32
    let viewCount: Int32
    let clickCount: Int
    let tags: [String]
    let firstSeenAt: Date
    let lastSeenAt: Date
}