//
//  PersistenceController.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
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
                fatalError("Failed to load Core Data stack: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Saving Data
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this with more robust error handling in a production app
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
