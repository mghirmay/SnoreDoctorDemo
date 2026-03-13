import Foundation
import CoreData
// MARK: - SnoreEventRealtimeAggregator (Conforming to SnoreEventCreator)

class SnoreEventRealtimeAggregator: SnoreEventCreator {

    let managedObjectContext: NSManagedObjectContext
    let recordingSession: RecordingSession

    private var currentSnoreEventsBatch: [SoundEvent] = []
    private var lastSoundEventProcessedTimestamp: Date?
    private var finalizationTimer: Timer?
    
    init(context: NSManagedObjectContext, for session: RecordingSession) {
        self.managedObjectContext = context
        self.recordingSession = session
    }
    
    
    
    func processNewSoundEvent(_ soundEvent: SoundEvent) {
        guard let currentEventTimestamp = soundEvent.timestamp else {
            print("Warning: SoundEvent timestamp is nil. Skipping processing.")
            return
        }
        
        let eventName = soundEvent.name?.lowercased() ?? ""
        let isSnoreRelated = SoundIdentifiers.snoreRelated.contains(eventName)
        let isNonSnore = SoundIdentifiers.nonSnore.contains(eventName)
        let gapThreshold = UserDefaults.standard.postProcessGapThreshold
        let interruptionThreshold = UserDefaults.standard.postProcessShortInterruptionThreshold
       
        // 1. Check for gap-based finalization
        if let lastProcessed = lastSoundEventProcessedTimestamp {
            if currentEventTimestamp.timeIntervalSince(lastProcessed) > gapThreshold {
                finalizeCurrentSnoreEventBatch()
            }
        }

        // 2. Handle Timer: Reset it every time we process a new event
        finalizationTimer?.invalidate()
        finalizationTimer = nil

        // 3. Aggregation Logic
        if isSnoreRelated {
            currentSnoreEventsBatch.append(soundEvent)
            // Only schedule a new timer if we have active data
            scheduleFinalizationTimer(gapThreshold: gapThreshold)
        } else if isNonSnore {
            // "Real-life" approach: We ignore the sound,
            // but we do NOT reset the batch.
            // We allow the timer to keep running from its previous start.
            if !currentSnoreEventsBatch.isEmpty {
                scheduleFinalizationTimer(gapThreshold: gapThreshold)
            }
            
            // Use the Short Interruption Threshold:
            // Only ignore the event if the gap is very small (e.g., < 1s).
            // If the gap is longer, treat it as a significant interruption.
            let timeSinceLast = currentEventTimestamp.timeIntervalSince(lastSoundEventProcessedTimestamp ?? Date.distantPast)
            
            if timeSinceLast <= interruptionThreshold {
                print("Ignoring minor interruption: \(timeSinceLast) seconds")
                // Do nothing, keep the batch open
            } else {
                finalizeCurrentSnoreEventBatch()
            }
            
        } else {
            // Unknown sound: Close the batch
            finalizeCurrentSnoreEventBatch()
        }

        lastSoundEventProcessedTimestamp = currentEventTimestamp
    }

    

    func finalizeRecordingSession() {
        finalizeCurrentSnoreEventBatch()
    }
    
    private func scheduleFinalizationTimer(gapThreshold : Double) {
        finalizationTimer?.invalidate()
        finalizationTimer = Timer.scheduledTimer(withTimeInterval: gapThreshold, repeats: false) { [weak self] _ in
            self?.finalizeCurrentSnoreEventBatch()
        }
    }

    private func finalizeCurrentSnoreEventBatch() {
        guard !currentSnoreEventsBatch.isEmpty else {
            resetBatchState()
            return
        }

        finalizationTimer?.invalidate()
        finalizationTimer = nil

        do {
            // Sort the batch defensively before passing to the creator
            let sortedBatch = currentSnoreEventsBatch.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

            // Use the protocol's default implementation
            try createAndSaveSnoreEvent(from: sortedBatch, for: recordingSession)
            
            // Explicitly save the context for each finalized SnoreEvent in real-time
            try managedObjectContext.save()
            print("Saved new SnoreEvent via Realtime Aggregator.")

        } catch {
            print("Error creating or saving SnoreEvent from batch in Realtime Aggregator: \(error.localizedDescription)")
        }

        resetBatchState()
    }

    private func resetBatchState() {
        currentSnoreEventsBatch = []
        // lastSoundEventProcessedTimestamp is NOT reset here
    }

    deinit {
        finalizationTimer?.invalidate()
    }
}
