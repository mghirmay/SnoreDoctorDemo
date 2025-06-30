//
//  SnoreDoctorObserver.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// SnoreDoctorObserver.swift
import Foundation
import SoundAnalysis
import CoreML
import AVFoundation
import CoreData // Make sure CoreData is imported for RecordingSession type

class SnoreDoctorObserver: NSObject, SNResultsObserving {
    weak var delegate: SnoreDoctorObserverDelegate?
    private let soundDataManager = SoundDataManager()

    // CHANGED: Now holds a reference to the current RecordingSession
    var currentRecordingSession: RecordingSession?

    init(delegate: SnoreDoctorObserverDelegate?) {
        self.delegate = delegate
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        print("SnoreDoctorObserver - Received a result")

        guard let classificationResult = result as? SNClassificationResult else { return }

        var detectedSnoreEvent: (identifier: String, confidence: Double)? = nil

        let eventDuration: Double
        if let classifyRequest = request as? SNClassifySoundRequest {
            eventDuration = classifyRequest.windowDuration.seconds
        } else {
            eventDuration = 1.0
            print("Warning: Request is not an SNClassifySoundRequest or windowDuration not available. Using default duration.")
        }

        let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold

        if let topClassification = classificationResult.classifications.first {
            if topClassification.confidence > requiredConfidence {
                detectedSnoreEvent = (topClassification.identifier, topClassification.confidence)
            }
        } else {
            detectedSnoreEvent = ("Silence", 1.0)
        }

        if let (identifier, confidenceValue) = detectedSnoreEvent {
            let confidence = String(format: "%.2f", confidenceValue * 100)
            let outputString = "Detected: \(identifier) (Confidence: \(confidence)%)\n"

            DispatchQueue.main.async {
                self.delegate?.didDetectSoundEvent(logString: outputString)

                // CHANGED: Pass the currentRecordingSession to SoundDataManager
                if let session = self.currentRecordingSession {
                    self.soundDataManager.saveSnoreDoctorResult(
                        logString: outputString.trimmingCharacters(in: .whitespacesAndNewlines),
                        session: session, // Pass the session object
                        duration: eventDuration
                    )
                } else {
                    print("Error: currentRecordingSession is nil. SoundEvent not saved with session.")
                    // Handle this critical error: maybe log to a temporary file or alert user
                }
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed with error: \(error)")
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed.")
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
    }
}
