//
//  PersistentCloudKitContainer.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//

import CoreData

struct PersistentCloudKitContainer {
    static let shared = PersistentCloudKitContainer()

    let container: NSPersistentCloudKitContainer  // ← swapped from NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SnoreDoctorDataModel")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Required for CloudKit sync to work correctly
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description.")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Same handling as your original — swap for graceful error in production
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Your existing additions — kept as-is
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil

        // Added: local data wins on merge conflict (correct for backup/restore use case)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Saving Data
    func save() {
        let context = container.viewContext

        context.performAndWait {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    print("Unresolved error saving main context: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}
