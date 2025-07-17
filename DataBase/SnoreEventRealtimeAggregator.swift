import Foundation
import CoreData

class SnoreEventRealtimeAggregator {

    let managedObjectContext: NSManagedObjectContext
    //let snoreIdentifiers: Set<String> = ["snoring", "gasp", "breathing", "sigh", "whispering"]
    let recordingSession: RecordingSession // The session this aggregator is operating on


    // State variables for the current in-progress SnoreEvent
    private var currentSnoreEventsBatch: [SoundEvent] = []
    private var batchStartTimestamp: Date?
    private var batchEndTimestamp: Date? // This will now store the timestamp of the last *sound event*
    private var batchConfidences: [Double] = []
    private var batchNamesHistogram: [String: Int] = [:]
    private var lastSoundEventProcessedTimestamp: Date? // To track gaps, this will be the timestamp of the last soundEvent

    // Timer to finalize a SnoreEvent if no new relevant SoundEvents arrive within the gapThreshold
    private var finalizationTimer: Timer?
    

    init(context: NSManagedObjectContext, for session: RecordingSession) {
        self.managedObjectContext = context
        self.recordingSession = session
    }

    /// Call this method every time a new SoundEvent is detected and ready for processing.
    /// It's assumed the SoundEvent has its timestamp and name set.
    func processNewSoundEvent(_ soundEvent: SoundEvent) {
        guard let currentEventTimestamp = soundEvent.timestamp else {
            print("Warning: SoundEvent timestamp is nil. Skipping processing.")
            return
        }

    
        // Initialize gapThreshold directly from UserDefaults
        let gapThreshold: Double = UserDefaults.standard.postProcessGapThreshold
        // Use the global AppSettings.snoreEventIdentifiers
        let snoreIdentifiers: Set<String> = AppSettings.snoreEventIdentifiers;
            
        let isSnoreRelated = snoreIdentifiers.contains(soundEvent.name?.lowercased() ?? "")

        // Invalidate any pending finalization timer, as a new event has arrived
        finalizationTimer?.invalidate()
        finalizationTimer = nil

        // Check for a significant gap if we have an active batch
        if let lastEventTime = lastSoundEventProcessedTimestamp {
            let timeSinceLastEvent = currentEventTimestamp.timeIntervalSince(lastEventTime)

            if timeSinceLastEvent > gapThreshold {
                // Gap detected: finalize the current batch
                finalizeCurrentSnoreEventBatch()
            }
        }

        if isSnoreRelated {
            // Add to current batch
            if currentSnoreEventsBatch.isEmpty {
                batchStartTimestamp = currentEventTimestamp
            }
            currentSnoreEventsBatch.append(soundEvent)
            batchEndTimestamp = currentEventTimestamp // batchEndTimestamp is now the timestamp of the last event
            batchConfidences.append(soundEvent.confidence)
            if let name = soundEvent.name {
                batchNamesHistogram[name, default: 0] += 1
            }

            // Set up a timer to finalize if no more snore-related events come in within the threshold
            scheduleFinalizationTimer(gapThreshold : gapThreshold)

        } else {
            // Non-snore event: finalize any existing batch
            finalizeCurrentSnoreEventBatch()
        }

        // Update the timestamp of the last processed event, regardless of type
        lastSoundEventProcessedTimestamp = currentEventTimestamp
    }

    /// Call this method when the recording session officially ends to ensure any pending SnoreEvent is saved.
    func finalizeRecordingSession() {
        finalizeCurrentSnoreEventBatch()
    }
    
    private func scheduleFinalizationTimer(gapThreshold : Double) {
        finalizationTimer?.invalidate() // Invalidate any existing timer
        finalizationTimer = Timer.scheduledTimer(withTimeInterval: gapThreshold, repeats: false) { [weak self] _ in
            // If this fires, it means no new snore-related events came in within the gap threshold
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
            let snoreEvent = SnoreEvent(context: managedObjectContext)
            snoreEvent.id = UUID()
            snoreEvent.session = recordingSession

            snoreEvent.startTime = batchStartTimestamp
            snoreEvent.endTime = batchEndTimestamp // Set endTime to the timestamp of the last grouped SoundEvent

            // Calculate duration based on the difference between start and end timestamps
            if let start = snoreEvent.startTime, let end = snoreEvent.endTime {
                snoreEvent.duration = end.timeIntervalSince(start)
            } else {
                snoreEvent.duration = 0.0 // Should not happen if batchStart/End are valid
            }

            snoreEvent.count = Int32(currentSnoreEventsBatch.count)

            if !batchConfidences.isEmpty {
                snoreEvent.averageConfidence = batchConfidences.reduce(0.0, +) / Double(batchConfidences.count)
                snoreEvent.minConfidence = batchConfidences.min() ?? 0.0
                snoreEvent.maxConfidence = batchConfidences.max() ?? 0.0
                snoreEvent.peakConfidence = batchConfidences.max() ?? 0.0

                let sortedConfidences = batchConfidences.sorted()
                if sortedConfidences.count % 2 == 0 {
                    let middleIndex = sortedConfidences.count / 2
                    snoreEvent.medianConfidence = (sortedConfidences[middleIndex - 1] + sortedConfidences[middleIndex]) / 2.0
                } else {
                    snoreEvent.medianConfidence = sortedConfidences[sortedConfidences.count / 2]
                }
            } else {
                snoreEvent.averageConfidence = 0
                snoreEvent.minConfidence = 0
                snoreEvent.maxConfidence = 0
                snoreEvent.medianConfidence = 0
            }

            snoreEvent.soundEventNamesHistogram = batchNamesHistogram as NSDictionary
            snoreEvent.name = "Snore Episode (Events: \(currentSnoreEventsBatch.count))"

            try managedObjectContext.save()
            print("Saved new SnoreEvent: \(snoreEvent.id?.uuidString ?? "N/A"), Start: \(snoreEvent.startTime ?? Date()), End: \(snoreEvent.endTime ?? Date()), Duration: \(snoreEvent.duration)s")

        } catch {
            print("Error creating or saving SnoreEvent: \(error.localizedDescription)")
        }

        resetBatchState()
    }

    private func resetBatchState() {
        currentSnoreEventsBatch = []
        batchStartTimestamp = nil
        batchEndTimestamp = nil
        batchConfidences = []
        batchNamesHistogram = [:]
        // lastSoundEventProcessedTimestamp is NOT reset here, as it tracks overall stream progress
        // finalizationTimer is already invalidated in finalizeCurrentSnoreEventBatch
    }

    deinit {
        // Invalidate timer if the aggregator is deallocated
        finalizationTimer?.invalidate()
    }
    
}
