//
//  SnoreEventPostProcessor.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 09.07.25.
//


import Foundation
import CoreData

class SnoreEventPostProcessor {

    let managedObjectContext: NSManagedObjectContext
   
    /// Initializes the post-processor.
    /// - Parameters:
    ///   - context: The NSManagedObjectContext to perform operations on.
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    /// Fetches all SoundEvents for a given RecordingSession and aggregates them into SnoreEvents.
    /// Any existing SnoreEvents for this session will be deleted before aggregation.
    /// - Parameter session: The RecordingSession to process.
    /// - Throws: An error if Core Data operations fail.
    func processSessionForSnoreEvents(session: RecordingSession) throws {
        print("Starting snore event aggregation for session: \(session.id?.uuidString ?? "N/A")")

        // 1. Delete any existing SnoreEvents for this session to ensure a clean re-aggregation
        try deleteExistingSnoreEvents(for: session)

        // 2. Fetch all SoundEvents for the session, sorted by timestamp
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
        var lastSnoreRelatedEventTimestamp: Date? // Tracks the timestamp of the last *snore-related* event added to a batch. This is crucial for gap detection.

        for (index, soundEvent) in sortedSoundEvents.enumerated() {
            guard let currentEventTimestamp = soundEvent.timestamp else {
                print("Skipping SoundEvent with nil timestamp: \(soundEvent.name ?? "N/A")")
                continue
            }

            // Initialize gapThreshold directly from UserDefaults
            let gapThreshold: Double = UserDefaults.standard.postProcessGapThreshold
            // Use the global AppSettings.snoreEventIdentifiers
            let snoreIdentifiers: Set<String> = AppSettings.snoreEventIdentifiers;
            
            let isSnoreRelated = snoreIdentifiers.contains(soundEvent.name?.lowercased() ?? "")

            if isSnoreRelated {
                // If it's a snore-related event
                if let lastTimestamp = lastSnoreRelatedEventTimestamp, // Check against the timestamp of the last *snore-related* event
                   
                        
                    currentEventTimestamp.timeIntervalSince(lastTimestamp) > gapThreshold {
                    // Significant gap detected, finalize the previous batch if it's not empty.
                    if !currentSnoreEventsBatch.isEmpty {
                        try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
                        currentSnoreEventsBatch = [] // Start a new batch
                    }
                }
                currentSnoreEventsBatch.append(soundEvent)
                lastSnoreRelatedEventTimestamp = currentEventTimestamp // Update for next iteration
            } else {
                // If it's a non-snore event, finalize the current batch (if any)
                if !currentSnoreEventsBatch.isEmpty {
                    try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
                    currentSnoreEventsBatch = []
                }
                lastSnoreRelatedEventTimestamp = nil // Reset as a non-snore event breaks the "snore sequence"
            }

            // After processing all sound events, finalize any remaining batch
            // This is outside the loop to ensure the very last batch is processed
            if index == sortedSoundEvents.count - 1 && !currentSnoreEventsBatch.isEmpty {
                try createAndSaveSnoreEvent(from: currentSnoreEventsBatch, for: session)
            }
        }

        // Final save for the context to persist all changes (SnoreEvents creation and potential deletions)
        if managedObjectContext.hasChanges {
            try managedObjectContext.save()
            print("Context saved after SnoreEvent aggregation for session: \(session.id?.uuidString ?? "N/A")")
        } else {
            print("No changes to save for session: \(session.id?.uuidString ?? "N/A")")
        }

        print("Finished snore event aggregation for session: \(session.id?.uuidString ?? "N/A")")
    }

    /// Deletes all existing SnoreEvents associated with a given RecordingSession.
    /// - Parameter session: The RecordingSession whose SnoreEvents should be deleted.
    /// - Throws: An error if the deletion fails.
    private func deleteExistingSnoreEvents(for session: RecordingSession) throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SnoreEvent.fetchRequest()
        // THIS PREDICATE IS KEY: It filters to only SnoreEvents associated with the given 'session'
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)

        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try managedObjectContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                // Merge changes back to the main context if necessary (e.g., if you're viewing data)
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [managedObjectContext])
            }
            print("Deleted existing SnoreEvents for session: \(session.id?.uuidString ?? "N/A")")
        } catch {
            print("Error deleting existing SnoreEvents: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    /// Creates a new SnoreEvent from a batch of SoundEvents and saves it.
    /// - Parameters:
    ///   - soundEvents: An array of SoundEvent objects to be grouped.
    ///   - session: The RecordingSession this SnoreEvent belongs to.
    /// - Throws: An error if the SnoreEvent cannot be created or saved.
    private func createAndSaveSnoreEvent(from soundEvents: [SoundEvent], for session: RecordingSession) throws {
        guard !soundEvents.isEmpty else { return }

        let snoreEvent = SnoreEvent(context: managedObjectContext)
        snoreEvent.id = UUID()
        snoreEvent.session = session

        // Ensure the soundEvents array is sorted by timestamp for correct startTime and duration
        // This sorting is crucial, especially if the `soundEvents` array passed here isn't strictly ordered,
        // although `processSessionForSnoreEvents` fetches them sorted. Defensive programming.
        let sortedSoundEvents = soundEvents.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }

        snoreEvent.startTime = sortedSoundEvents.first?.timestamp
        snoreEvent.endTime = sortedSoundEvents.last?.timestamp // endTime is timestamp of the last SoundEvent

        // Calculate duration based on the difference between start and end timestamps
        if let start = snoreEvent.startTime, let end = snoreEvent.endTime {
            snoreEvent.duration = end.timeIntervalSince(start)
        } else {
            // Fallback if timestamps are somehow missing, though they shouldn't be for valid SoundEvents
            snoreEvent.duration = 0.0
        }

        snoreEvent.count = Int32(soundEvents.count)

        let confidences = soundEvents.map { $0.confidence }
        if !confidences.isEmpty {
            snoreEvent.averageConfidence = confidences.reduce(0.0, +) / Double(confidences.count)
            snoreEvent.minConfidence = confidences.min() ?? 0.0
            snoreEvent.maxConfidence = confidences.max() ?? 0.0
            snoreEvent.peakConfidence = confidences.max() ?? 0.0

            let sortedConfidences = confidences.sorted()
            if sortedConfidences.count % 2 == 0 {
                let middleIndex = sortedConfidences.count / 2
                snoreEvent.medianConfidence = (sortedConfidences[middleIndex - 1] + sortedConfidences[middleIndex]) / 2.0
            } else {
                snoreEvent.medianConfidence = sortedConfidences[sortedConfidences.count / 2]
            }
        } else {
            snoreEvent.averageConfidence = 0.0
            snoreEvent.minConfidence = 0.0
            snoreEvent.maxConfidence = 0.0
            snoreEvent.medianConfidence = 0.0
            snoreEvent.peakConfidence = 0.0
        }

        var namesHistogram: [String: Int] = [:]
        for event in soundEvents {
            if let name = event.name {
                namesHistogram[name, default: 0] += 1
            }
        }
        snoreEvent.soundEventNamesHistogram = namesHistogram as NSDictionary

        snoreEvent.name = "Snore Episode (\(soundEvents.count) events)"

        // No need to save here, processSessionForSnoreEvents does a single save at the end.
        print("Created SnoreEvent from \(soundEvents.count) SoundEvents. Start: \(snoreEvent.startTime ?? Date()), End: \(snoreEvent.endTime ?? Date()), Duration: \(snoreEvent.duration)s")
    }
}
