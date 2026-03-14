//
//  SnoreEventPostProcessor.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 09.07.25.
//

import Foundation
import CoreData

// MARK: - SnoreEventPostProcessor

class SnoreEventPostProcessor: SnoreEventCreator {
    let managedObjectContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    // MARK: - Main Entry Point

    /// Processes a single session, rebuilding all SnoreEvents from its SoundEvents.
    /// Call this AFTER reconcileIncompleteSessions so session.endTime is guaranteed to exist.
    func processSessionForSnoreEvents(session: RecordingSession) throws {
        let sessionID = session.id?.uuidString ?? "N/A"
        print("▶️ Starting SnoreEvent aggregation for session: \(sessionID)")

        // Guard: endTime must exist (reconcileIncompleteSessions should have patched this already)
        guard session.endTime != nil else {
            print("⚠️ Skipping session \(sessionID) — endTime is nil. Run reconcileIncompleteSessions first.")
            return
        }

        // 1. Wipe existing SnoreEvents for a clean rebuild
        try deleteExistingSnoreEvents(for: session)

        // 2. Fetch all snore-related SoundEvents for this session, sorted by timestamp
        let fetchRequest: NSFetchRequest<SoundEvent> = SoundEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        let allSoundEvents = try managedObjectContext.fetch(fetchRequest)

        guard !allSoundEvents.isEmpty else {
            print("ℹ️ No SoundEvents found for session \(sessionID). Nothing to aggregate.")
            return
        }

        // 3. Aggregate into batches and create SnoreEvents
        let createdCount = try aggregateIntoBatches(allSoundEvents, for: session)

        // 4. Single save at the end — not per-batch
        if managedObjectContext.hasChanges {
            try managedObjectContext.save()
            print("✅ Saved \(createdCount) SnoreEvent(s) for session: \(sessionID)")
        } else {
            print("ℹ️ No changes to save for session: \(sessionID)")
        }
    }

    // MARK: - Batch Aggregation

    /// Walks through sorted SoundEvents, groups them by gap threshold, and flushes each batch.
    /// Returns the number of SnoreEvents created.
    @discardableResult
    private func aggregateIntoBatches(_ sortedEvents: [SoundEvent], for session: RecordingSession) throws -> Int {
        let gapThreshold: Double = UserDefaults.standard.postProcessGapThreshold
        var currentBatch: [SoundEvent] = []
        var lastSnoreTimestamp: Date? = nil
        var createdCount = 0

        for soundEvent in sortedEvents {
            guard let timestamp = soundEvent.timestamp else {
                print("⚠️ Skipping SoundEvent '\(soundEvent.name ?? "N/A")' — nil timestamp.")
                continue
            }

            let isSnoreRelated = SoundIdentifiers.snoreRelated.contains(soundEvent.name?.lowercased() ?? "")

            if isSnoreRelated {
                // Check if this event is too far from the last one — if so, flush current batch first
                if let lastTimestamp = lastSnoreTimestamp,
                   timestamp.timeIntervalSince(lastTimestamp) > gapThreshold {
                    if !currentBatch.isEmpty {
                        try createAndSaveSnoreEvent(from: currentBatch, for: session)
                        createdCount += 1
                        currentBatch = []
                    }
                }
                currentBatch.append(soundEvent)
                lastSnoreTimestamp = timestamp

            } else {
                // Non-snore event: flush whatever we have
                if !currentBatch.isEmpty {
                    try createAndSaveSnoreEvent(from: currentBatch, for: session)
                    createdCount += 1
                    currentBatch = []
                }
                lastSnoreTimestamp = nil
            }
        }

        // ✅ FIX: Flush the final batch AFTER the loop, not inside it
        // The original code checked `index == count - 1` inside the loop,
        // which silently dropped the last batch if the final event had a nil timestamp.
        if !currentBatch.isEmpty {
            try createAndSaveSnoreEvent(from: currentBatch, for: session)
            createdCount += 1
        }

        return createdCount
    }

    // MARK: - Delete Existing SnoreEvents

    private func deleteExistingSnoreEvents(for session: RecordingSession) throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SnoreEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)

        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDelete.resultType = .resultTypeObjectIDs

        do {
            let result = try managedObjectContext.execute(batchDelete) as? NSBatchDeleteResult
            if let deletedIDs = result?.result as? [NSManagedObjectID] {
                // Merge deletions into the in-memory context so live objects are invalidated
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
                    into: [managedObjectContext]
                )
                print("🗑️ Deleted \(deletedIDs.count) existing SnoreEvent(s) for session: \(session.id?.uuidString ?? "N/A")")
            }
        } catch {
            print("❌ Failed to delete SnoreEvents: \(error.localizedDescription)")
            throw error
        }
    }
}
