//
//  PersistenceController.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController() // Singleton instance

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "SnoreDoctorDataModel") // Match your .xcdatamodeld file name
        container.loadPersistentStores { description, error in
            if let error = error {
                // Handle the error appropriately in a production app
                // For development, fatalError is fine, but consider more robust logging/UI for users.
                fatalError("Failed to load Core Data stack: \(error.localizedDescription)")
            }
        }
        
        // --- ADDITIONS START HERE ---

        // 1. Crucial for automatically merging changes from background contexts to the main view context.
        container.viewContext.automaticallyMergesChangesFromParent = true

        // 2. Optional: Improves performance by disabling undo/redo tracking
        // if you don't explicitly use it for the main context.
        container.viewContext.undoManager = nil
        
        // --- ADDITIONS END HERE ---
    }

    // MARK: - Saving Data
    func save() {
        let context = container.viewContext
        
        // Use performAndWait to ensure the save operation runs on the context's
        // private queue, providing thread safety and avoiding potential deadlocks.
        // This is important even for the main context.
        context.performAndWait {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    // Replace this with more robust error handling in a production app.
                    // For example, log the error and present a user-friendly alert.
                    let nsError = error as NSError
                    print("Unresolved error saving main context: \(nsError), \(nsError.userInfo)")
                    // fatalError("Unresolved error \(nsError), \(nsError.userInfo)") // Avoid in production
                }
            }
        }
    }
}
