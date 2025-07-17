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
import CoreData // Make sure this is imported for Core Data classes

// MARK: - SnoreDoctorObserverDelegate Protocol Definition
protocol SoundEventDetectionObserverDelegate: AnyObject { // Use 'AnyObject' for weak references
    // REVERTED: didDetectSoundEvent now takes only the logString again
    func didDetectSoundEvent(logString: String)
    func analysisDidFail(error: Error)
    func analysisDidComplete()
}

class SoundEventDetectionObserver: NSObject, SNResultsObserving {
    weak var delegate: SoundEventDetectionObserverDelegate? // Make sure this is 'weak' to prevent retain cycles
    private let soundDataManager = SoundDataManager()

    // CHANGED: currentRecordingSession is now weak, and initialized via init or a dedicated setup method.
    // This allows the observer to be initialized without a session, and then the session can be set when recording starts.
    weak var currentRecordingSession: RecordingSession? {
        didSet {
            // When a new session is set, (re)initialize the aggregator
            if let session = currentRecordingSession {
                // Ensure context is available. Assuming PersistenceController is globally accessible.
                let context = PersistenceController.shared.container.viewContext
                self.snoreAggregator = SnoreEventRealtimeAggregator(context: context, for: session)
                print("SoundEventDetectionObserver: SnoreEventRealtimeAggregator initialized for new session.")
            } else {
                // If session becomes nil (e.g., recording stopped), finalize and clear aggregator
                snoreAggregator?.finalizeRecordingSession()
                snoreAggregator = nil
                print("SoundEventDetectionObserver: SnoreEventRealtimeAggregator finalized and cleared.")
            }
        }
    }

    // This property needs to exist to be initialized in didSet of currentRecordingSession
    private var snoreAggregator: SnoreEventRealtimeAggregator?


    // CHANGED: Initializer simplified, as currentRecordingSession will be set separately
    init(delegate: SoundEventDetectionObserverDelegate) { // Delegate is now non-optional in init
        self.delegate = delegate
        super.init()
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        print("SnoreDoctorObserver - Received a result")

        guard let classificationResult = result as? SNClassificationResult else { return }

        let eventDuration: Double
        if let classifyRequest = request as? SNClassifySoundRequest {
            eventDuration = classifyRequest.windowDuration.seconds
        } else {
            eventDuration = 1.0
            print("Warning: Request is not an SNClassifySoundRequest or windowDuration not available. Using default duration.")
        }

        let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold // Assuming this exists

        // Get top classification and its timestamp
        
        let identifierToSave: String
        let confidenceToSave: Double
        let timestamp = Date(timeIntervalSinceNow: classificationResult.timeRange.start.seconds) // Accurate timestamp for the analyzed segment

        var outputStringForUI: String?

        if let topClassification = classificationResult.classifications.first {
            identifierToSave = topClassification.identifier
            confidenceToSave = topClassification.confidence

            // Determine if this event should be shown in the UI based on confidence
            if topClassification.confidence > requiredConfidence {
                let confidenceDisplay = String(format: "%.2f", topClassification.confidence * 100)
                    outputStringForUI = "Detected: \(topClassification.identifier) (Confidence: \(confidenceDisplay)%)\n"
                
                
                // 1. UPDATE UI ONLY IF A RELEVANT EVENT WAS DETECTED (based on outputStringForUI)
                if let logString = outputStringForUI {
                    DispatchQueue.main.async {
                        self.delegate?.didDetectSoundEvent(logString: logString) // Pass only the logString
                    }
                }
                
                // 2. SAVE THE EVENT TO CORE DATA VIA SOUNDDATAMANAGER
                // The SoundDataManager will create/save the SoundEvent Core Data object
                if let session = self.currentRecordingSession {
                    
                    let createdSoundEvent = self.soundDataManager.saveSoundEvent(identifier:identifierToSave,
                                                            confidence: confidenceToSave,
                                                            session: session,
                                                            duration: eventDuration,
                                                            timeStamp: Date())

                    // Now you can directly use the 'createdSoundEvent' which is the SoundEvent object returned.
                    if createdSoundEvent != nil { // Check if it's not nil, though with `performAndWait` it usually won't be unless there's a serious Core Data issue.
                        print("SoundEvent successfully created and returned: \(createdSoundEvent.name ?? "N/A")")
                        // 2. PASS THE DETECTED EVENT DATA TO THE SNORE AGGREGATOR
                        self.snoreAggregator?.processNewSoundEvent(createdSoundEvent)
                    } else {
                        print("Failed to create SoundEvent (unlikely with synchronous return).")
                    }

                } else {
                    print("Error: currentRecordingSession is nil. SoundEvent not saved with session.")
                }

            }
       
        }


       

    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed with error: \(error)")
        // Finalize aggregation on error
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear aggregator
        currentRecordingSession = nil // Clear session reference
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed.")
        // Finalize aggregation when analysis completes
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear aggregator
        currentRecordingSession = nil // Clear session reference
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
    }
}
