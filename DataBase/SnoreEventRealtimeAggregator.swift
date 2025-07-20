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
        
        let gapThreshold: Double = UserDefaults.standard.postProcessGapThreshold
        let snoreIdentifiers: Set<String> = AppSettings.snoreEventRelatedIdentifiers
        
        let isSnoreRelated = snoreIdentifiers.contains(soundEvent.name?.lowercased() ?? "")

        finalizationTimer?.invalidate()
        finalizationTimer = nil

        if let lastProcessedTime = lastSoundEventProcessedTimestamp {
            let timeSinceLastEvent = currentEventTimestamp.timeIntervalSince(lastProcessedTime)
            if timeSinceLastEvent > gapThreshold {
                finalizeCurrentSnoreEventBatch()
            }
        }

        if isSnoreRelated {
            currentSnoreEventsBatch.append(soundEvent)
            scheduleFinalizationTimer(gapThreshold: gapThreshold)
        } else {
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
