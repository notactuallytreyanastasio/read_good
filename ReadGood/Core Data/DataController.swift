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
    
    // Search functionality
    func searchStories(query: String) -> [Story] {
        let request: NSFetchRequest<Story> = Story.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Story.lastSeenAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // Tag search
    func searchStoriesByTags(_ tagNames: [String]) -> [Story] {
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
            return try container.viewContext.fetch(request)
        } catch {
            print("Tag search failed: \(error.localizedDescription)")
            return []
        }
    }
}