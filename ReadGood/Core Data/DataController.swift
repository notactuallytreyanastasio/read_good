import CoreData
import Foundation

class DataController: ObservableObject {
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "ReadGoodModel")
        
        // Configure for better performance
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data error: \(error.localizedDescription)")
            }
            
            // Enable automatic merging
            self.container.viewContext.automaticallyMergesChangesFromParent = true
        }
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save failed: \(error.localizedDescription)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
    
    func deleteAll<T: NSManagedObject>(_ type: T.Type) {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        
        do {
            let objects = try container.viewContext.fetch(request)
            objects.forEach { container.viewContext.delete($0) }
            save()
        } catch {
            print("Failed to delete all \(type): \(error.localizedDescription)")
        }
    }
    
    // Background context for heavy operations
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    // Batch operations
    func batchSaveStories(_ stories: [StoryData]) {
        performBackgroundTask { context in
            stories.forEach { storyData in
                _ = Story.findOrCreate(from: storyData, in: context)
            }
            
            do {
                try context.save()
                print("Batch saved \(stories.count) stories")
            } catch {
                print("Batch save failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Search functionality - async to avoid blocking main thread
    func searchStories(query: String) async -> [Story] {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Story> = Story.fetchRequest()
                request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.lastSeenAt, ascending: false)]
                
                do {
                    let results = try context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    print("Search failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // Tag search - async to avoid blocking main thread
    func searchStoriesByTags(_ tagNames: [String]) async -> [Story] {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Story> = Story.fetchRequest()
                
                // Create predicates for each tag
                let tagPredicates = tagNames.map { tagName in
                    NSPredicate(format: "ANY tags.name == %@", tagName.lowercased())
                }
                
                // Combine with OR logic
                let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: tagPredicates)
                request.predicate = compoundPredicate
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.lastSeenAt, ascending: false)]
                
                do {
                    let results = try context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    print("Tag search failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // Get most common tags - async to avoid blocking main thread
    func getTopTags(limit: Int = 5) async -> [(String, Int)] {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                
                do {
                    let allTags = try context.fetch(request)
                    
                    // Count occurrences of each tag name
                    var tagCounts: [String: Int] = [:]
                    for tag in allTags {
                        tagCounts[tag.name, default: 0] += 1
                    }
                    
                    // Sort by count and take top results
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                        .prefix(limit)
                        .map { ($0.key, $0.value) }
                    
                    continuation.resume(returning: Array(sortedTags))
                } catch {
                    print("Failed to fetch top tags: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // Debug method to get all tags with their counts
    func getAllTagsWithCounts() async -> [(String, Int)] {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                
                do {
                    let allTags = try context.fetch(request)
                    print("🏷️ DEBUG: Found \(allTags.count) total tag records in database")
                    
                    // Count occurrences of each tag name
                    var tagCounts: [String: Int] = [:]
                    for tag in allTags {
                        tagCounts[tag.name, default: 0] += 1
                        print("🏷️ DEBUG: Tag '\(tag.name)' for story: \(tag.story.title)")
                    }
                    
                    print("🏷️ DEBUG: Unique tag counts: \(tagCounts)")
                    
                    // Sort by count
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                        .map { ($0.key, $0.value) }
                    
                    continuation.resume(returning: Array(sortedTags))
                } catch {
                    print("Failed to fetch all tags: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // Get total story count for debugging
    func getStoryCount() async -> Int {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Story> = Story.fetchRequest()
                
                do {
                    let count = try context.count(for: request)
                    print("🏷️ DEBUG: Found \(count) stories in database")
                    continuation.resume(returning: count)
                } catch {
                    print("Failed to count stories: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // Get total click count for debugging
    func getClickCount() async -> Int {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Click> = Click.fetchRequest()
                
                do {
                    let count = try context.count(for: request)
                    print("🏷️ DEBUG: Found \(count) clicks in database")
                    continuation.resume(returning: count)
                } catch {
                    print("Failed to count clicks: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // Get all stories with their stats for debug view
    func getAllStoriesWithStats() async -> [StoryStats] {
        return await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                let request: NSFetchRequest<Story> = Story.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.lastSeenAt, ascending: false)]
                
                do {
                    let stories = try context.fetch(request)
                    
                    let storyStats = stories.map { story in
                        // Get tags for this story
                        let tags = Array(story.tags).map { $0.name }
                        
                        // Count clicks for this story
                        let clickCount = story.clicks.count
                        
                        return StoryStats(
                            id: story.id,
                            title: story.title,
                            url: story.url,
                            source: story.source,
                            points: story.points,
                            viewCount: story.viewCount,
                            clickCount: clickCount,
                            tags: tags,
                            firstSeenAt: story.firstSeenAt,
                            lastSeenAt: story.lastSeenAt
                        )
                    }
                    
                    continuation.resume(returning: storyStats)
                } catch {
                    print("Failed to fetch stories with stats: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
}