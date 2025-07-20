//
//  SnoreEventPostProcessor.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 09.07.25.
//


import Foundation
import CoreData

// MARK: - SnoreEventPostProcessor (Conforming to SnoreEventCreator)

class SnoreEventPostProcessor: SnoreEventCreator {
    let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    func processSessionForSnoreEvents(session: RecordingSession) throws {
        print("Starting snore event aggregation for session: \(session.id?.uuidString ?? "N/A")")

        try deleteExistingSnoreEvents(for: session)

        let fetchRequest: NSFetchRequest<SoundEvent> = SoundEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let sortedSoundEvents = try managedObjectContext.fetch(fetchRequest)

        guard !sortedSoundEvents.isEmpty else {
            print("No sound events found for session \(session.id?.uuidString ?? "N/A"). No SnoreEvents created.")
            return
        }

        var currentSnoreEventsBatch: [SoundEvent] = []
        var lastSnoreRelatedEventTimestamp: Date?

        for (index, soundEvent) in sortedSoundEvents.enumerated() {
            guard let currentEventTimestamp = soundEvent.timestamp else {
                print("Skipping SoundEvent with nil timestamp: \(soundEvent.name ?? "N/A")")
                continue
            }

            let gapThreshold: Double = UserDefaults.standard.postProcessGapThreshold
            let snoreIdentifiers: Set<String> = AppSettings.snoreEventRelatedIdentifiers
            
            let isSnoreRelated = snoreIdentifiers.contains(soundEvent.name?.lowercased() ?? "")

            if isSnoreRelated {
                if let lastTimestamp = lastSnoreRelatedEventTimestamp,
                   currentEventTimestamp.timeIntervalSince(lastTimestamp) > gapThreshold {
                    if !currentSnoreEventsBatch.isEmpty {
                        // Use the protocol's default implementation
                        try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
                        currentSnoreEventsBatch = []
                    }
                }
                currentSnoreEventsBatch.append(soundEvent)
                lastSnoreRelatedEventTimestamp = currentEventTimestamp
            } else {
                if !currentSnoreEventsBatch.isEmpty {
                    // Use the protocol's default implementation
                    try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
                    currentSnoreEventsBatch = []
                }
                lastSnoreRelatedEventTimestamp = nil
            }

            if index == sortedSoundEvents.count - 1 && !currentSnoreEventsBatch.isEmpty {
                // Use the protocol's default implementation for the very last batch
                try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
            }
        }

        if managedObjectContext.hasChanges {
            try managedObjectContext.save() // Final save for the post-processor
            print("Context saved after SnoreEvent aggregation for session: \(session.id?.uuidString ?? "N/A")")
        } else {
            print("No changes to save for session: \(session.id?.uuidString ?? "N/A")")
        }

        print("Finished snore event aggregation for session: \(session.id?.uuidString ?? "N/A")")
    }

    private func deleteExistingSnoreEvents(for session: RecordingSession) throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SnoreEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)

        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try managedObjectContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [managedObjectContext])
            }
            print("Deleted existing SnoreEvents for session: \(session.id?.uuidString ?? "N/A")")
        } catch {
            print("Error deleting existing SnoreEvents: \(error.localizedDescription)")
            throw error
        }
    }
}

