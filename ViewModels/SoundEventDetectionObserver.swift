//
//  SoundEventDetectionObserver.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
import Foundation
import SoundAnalysis
import CoreML
import AVFoundation
import CoreData // Essential for Core Data operations

// MARK: - SoundEventDetectionObserverDelegate Protocol Definition
// (As provided by you, no changes made to this protocol)
protocol SoundEventDetectionObserverDelegate: AnyObject {
    func didDetectSoundEvent(logString: String)
    func analysisDidFail(error: Error)
    func analysisDidComplete()
}

class SoundEventDetectionObserver: NSObject, SNResultsObserving {
    weak var delegate: SoundEventDetectionObserverDelegate?
    
    // The SoundDataManager and NSManagedObjectContext for Core Data operations
    private let soundDataManager =  SoundDataManager()
   
    // MARK: - Event Counters
    private var totalSnoreEventsDetected: Int = 0
    private var totalSnoreRelatedEventsDetected: Int = 0 // Includes 'snoring'
    private var totalNonSnoreEventsDetected: Int = 0

    // MARK: - Recording Session and Aggregator
    weak var currentRecordingSession: RecordingSession? {
        didSet {
            // When a new recording session is assigned (e.g., recording starts)
            if let session = currentRecordingSession {
               // Ensure context is available. Assuming PersistenceController is globally accessible.
                let context = PersistenceController.shared.container.viewContext
                self.snoreAggregator = SnoreEventRealtimeAggregator(context: context, for: session)
     
                // Reset event counters for the new session to start fresh
                self.totalSnoreEventsDetected = 0
                self.totalSnoreRelatedEventsDetected = 0
                self.totalNonSnoreEventsDetected = 0
                
                print("SoundEventDetectionObserver: SnoreEventRealtimeAggregator and event counters initialized for new session.")
            } else {
                // If the session becomes nil (e.g., recording stopped)
                snoreAggregator?.finalizeRecordingSession() // Ensure any pending snore events are saved
                snoreAggregator = nil // Clear the aggregator
                print("SoundEventDetectionObserver: SnoreEventRealtimeAggregator finalized and cleared.")
            }
        }
    }

    private var snoreAggregator: SnoreEventRealtimeAggregator?

    // MARK: - Initialization

    /// Initializes the sound event detection observer.
    /// - Parameters:
    ///   - delegate: The object that will receive notifications about detected events and analysis status.
    ///   - context: The Core Data `NSManagedObjectContext` to be used for saving `SoundEvent`s and updating `RecordingSession` counts.
    init(delegate: SoundEventDetectionObserverDelegate, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.delegate = delegate
        super.init()
    }

    // MARK: - SNResultsObserving Protocol Methods

    func request(_ request: SNRequest, didProduce result: SNResult) {
        print("SnoreDoctorObserver - Received a sound analysis result.")

        guard let classificationResult = result as? SNClassificationResult else { return }

        // Determine the duration of the analyzed sound event
        let eventDuration: Double
        if let classifyRequest = request as? SNClassifySoundRequest {
            eventDuration = classifyRequest.windowDuration.seconds
        } else {
            eventDuration = 1.0 // Fallback duration if request type is unexpected
            print("Warning: Request is not an SNClassifySoundRequest or windowDuration not available. Using default duration of \(eventDuration)s.")
        }

        let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold // Get confidence threshold from UserDefaults
        
        // Use current time as the timestamp for the detected event.
        // You might adjust this to be relative to the recording session's start time if precise synchronization is needed.
        let timestamp = Date()

        if let topClassification = classificationResult.classifications.first {
            let identifierToSave = topClassification.identifier
            let confidenceToSave = topClassification.confidence

            // --- Update Event Counters ---
            // Categorize and increment counts based on AppSettings definitions
            let isSnore = AppSettings.snoreEventIdentifier.contains(identifierToSave.lowercased())
            let isSnoreRelated = AppSettings.snoreEventRelatedIdentifiers.contains(identifierToSave.lowercased())

            if isSnore {
                totalSnoreEventsDetected += 1
            }
            if isSnoreRelated {
                totalSnoreRelatedEventsDetected += 1
            } else {
                // This event is neither "snoring" nor "snore-related" (like gasp, breathing, etc.)
                totalNonSnoreEventsDetected += 1
            }
            // --- End Update Event Counters ---

            // Check if the event meets the UI display confidence threshold
            if topClassification.confidence > requiredConfidence {
                let confidenceDisplay = String(format: "%.2f", confidenceToSave * 100)
                let outputStringForUI = "Detected: \(identifierToSave) (Confidence: \(confidenceDisplay)%)\n"
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.delegate?.didDetectSoundEvent(logString: outputStringForUI)
                }
            } else {
                print("Event '\(identifierToSave)' with confidence \(confidenceToSave) below display threshold (\(requiredConfidence)).")
            }
            
            // Regardless of UI display confidence, save the raw SoundEvent to Core Data
            // and pass it to the real-time aggregator for SnoreEvent grouping.
            if let session = self.currentRecordingSession {
                let createdSoundEvent = self.soundDataManager.saveSoundEvent(
                    identifier: identifierToSave,
                    confidence: confidenceToSave,
                    session: session,
                    duration: eventDuration,
                    timeStamp: timestamp
                )
                // Pass the newly created (and saved) SoundEvent to the real-time aggregator
                self.snoreAggregator?.processNewSoundEvent(createdSoundEvent)
            } else {
                print("Error: currentRecordingSession is nil. SoundEvent '\(identifierToSave)' not saved with session.")
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed with error: \(error.localizedDescription)")
        
        // Finalize any pending SnoreEvent aggregation
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear the aggregator instance
        
        // Save the accumulated counts to the RecordingSession Core Data object
        updateSessionCountsAndSave()
        
        currentRecordingSession = nil // Clear the session reference
        
        // Notify delegate about the failure and provide final counts
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed.")
        
        // Finalize any pending SnoreEvent aggregation
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear the aggregator instance
        
        // Save the accumulated counts to the RecordingSession Core Data object
        updateSessionCountsAndSave()
        
        currentRecordingSession = nil // Clear the session reference
        
        // Notify delegate about completion and provide final counts
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
    }

    // MARK: - Private Helper Methods

    /// Updates the `RecordingSession`'s count properties in Core Data with the current accumulated totals
    /// and saves the `managedObjectContext`. This is typically called when a recording session concludes.
    public func updateSessionCountsAndSave() {
        // Inside updateSessionCountsAndSave()
        guard let session = currentRecordingSession else {
            print("Cannot update session counts: currentRecordingSession is nil during save attempt.")
            return
        }

        print("Pre-update session counts: Snore=\(session.totalSnoreEvents), Related=\(session.totalSnoreRelated), Non-Snore=\(session.totalNonSnoreEvents)")

        
        // Assign the aggregated counts to the RecordingSession Core Data object
        session.totalSnoreEvents = Int32(totalSnoreEventsDetected)
        session.totalSnoreRelated = Int32(totalSnoreRelatedEventsDetected)
        session.totalNonSnoreEvents = Int32(totalNonSnoreEventsDetected)

        // Set the end time for the session
        session.endTime = Date()

        print("Post-update session counts (in memory): Snore=\(session.totalSnoreEvents), Related=\(session.totalSnoreRelated), Non-Snore=\(session.totalNonSnoreEvents)")

        // Crucial check: Does the context actually have changes?
        print("Managed object context has changes BEFORE save: \(soundDataManager.managedObjectContext.hasChanges)")

        do {
            soundDataManager.saveContext()
            print("Session counts saved to Core Data for session \(session.id?.uuidString ?? "N/A"): Snore=\(totalSnoreEventsDetected), Related=\(totalSnoreRelatedEventsDetected), Non-Snore=\(totalNonSnoreEventsDetected)")
        }
    }
}
