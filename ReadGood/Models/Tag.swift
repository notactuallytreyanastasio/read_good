import Foundation
import CoreData

@objc(Tag)
public class Tag: NSManagedObject, Identifiable {
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var story: Story
}

extension Tag {
    static func fetchRequest() -> NSFetchRequest<Tag> {
        NSFetchRequest<Tag>(entityName: "Tag")
    }
    
    static func findOrCreate(name: String, for story: Story, in context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND story == %@", name.lowercased(), story)
        
        if let existingTag = try? context.fetch(request).first {
            return existingTag
        } else {
            let tag = Tag(context: context)
            tag.name = name.lowercased()
            tag.createdAt = Date()
            tag.story = story
            return tag
        }
    }
    
    static func allUniqueTagsRequest() -> NSFetchRequest<Tag> {
        let request = fetchRequest()
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["name"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }
}

@objc(Click)
public class Click: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var clickType: String // "article", "comments", "archive"
    @NSManaged public var clickedAt: Date
    @NSManaged public var story: Story
}

extension Click {
    static func fetchRequest() -> NSFetchRequest<Click> {
        NSFetchRequest<Click>(entityName: "Click")
    }
    
    static func create(type: ClickType, for story: Story, in context: NSManagedObjectContext) -> Click {
        let click = Click(context: context)
        click.id = UUID()
        click.clickType = type.rawValue
        click.clickedAt = Date()
        click.story = story
        return click
    }
}

enum ClickType: String, CaseIterable {
    case article = "article"
    case comments = "comments"
    case archive = "archive"
}

@objc(LinkWrite)
public class LinkWrite: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var source: String
    @NSManaged public var time: Date
}

extension LinkWrite {
    static func fetchRequest() -> NSFetchRequest<LinkWrite> {
        NSFetchRequest<LinkWrite>(entityName: "LinkWrite")
    }
    
    static func create(source: String, in context: NSManagedObjectContext) -> LinkWrite {
        let linkWrite = LinkWrite(context: context)
        linkWrite.id = UUID()
        linkWrite.source = source
        linkWrite.time = Date()
        return linkWrite
    }
    
    static func getLastFetchTime(for source: String, in context: NSManagedObjectContext) -> Date? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LinkWrite.time, ascending: false)]
        request.fetchLimit = 1
        
        return try? context.fetch(request).first?.time
    }
    
    static func shouldRefresh(source: String, cacheMinutes: Int, in context: NSManagedObjectContext) -> Bool {
        guard let lastFetch = getLastFetchTime(for: source, in: context) else {
            return true // No previous fetch, should refresh
        }
        
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
        let cacheSeconds = TimeInterval(cacheMinutes * 60)
        
        return timeSinceLastFetch > cacheSeconds
    }
}