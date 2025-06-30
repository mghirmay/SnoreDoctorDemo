//
//  SnoreDoctorObserver.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// SnoreDoctorObserver.swift
import Foundation
import SoundAnalysis
import CoreML
import AVFoundation
import CoreData

class SnoreDoctorObserver: NSObject, SNResultsObserving {
    weak var delegate: SnoreDoctorObserverDelegate?
    private let soundDataManager = SoundDataManager()

    var currentRecordingSession: RecordingSession?

    init(delegate: SnoreDoctorObserverDelegate?) {
        self.delegate = delegate
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

        let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold

        // Always get the top classification for saving, even if it doesn't meet the display threshold
        let identifierToSave: String
        let confidenceToSave: Double
        var outputStringForUI: String? // Optional: Only set if an event for UI is detected

        if let topClassification = classificationResult.classifications.first {
            identifierToSave = topClassification.identifier
            confidenceToSave = topClassification.confidence

            // Logic for UI display based on threshold
            if topClassification.confidence > requiredConfidence {
                let confidenceDisplay = String(format: "%.2f", topClassification.confidence * 100)
                outputStringForUI = "Detected: \(topClassification.identifier) (Confidence: \(confidenceDisplay)%)\n"
            }
            // Optionally, handle "low confidence" UI logging here if desired
            // else { outputStringForUI = "Detected: Other noise (Confidence: \(confidenceDisplay)%)\n" }
        } else {
            // Handle cases with no classifications (e.g., truly silence or classifier couldn't identify)
            identifierToSave = "Silence" // Or "Unknown"
            confidenceToSave = 1.0 // Or 0.0, depending on what "Silence" means for confidence
            outputStringForUI = "Detected: Silence\n" // Still log silence to UI
        }

        // 1. ALWAYS SAVE THE EVENT TO CORE DATA
        if let session = self.currentRecordingSession {
            // Use DispatchQueue.main.async for UI updates, but Core Data operations
            // should ideally be on the context's private queue if performance is critical,
            // or here if the context merges changes automatically (which yours does).
            DispatchQueue.main.async { // This block is fine as it wraps the saving
                self.soundDataManager.saveSnoreDoctorResult(
                    identifier: identifierToSave, // Pass the direct identifier
                    confidence: confidenceToSave,   // Pass the raw confidence
                    session: session,
                    duration: eventDuration
                )
            }
        } else {
            print("Error: currentRecordingSession is nil. SoundEvent not saved with session.")
        }

        // 2. ONLY UPDATE UI IF A RELEVANT EVENT WAS DETECTED (based on your threshold/logic)
        if let logString = outputStringForUI {
            DispatchQueue.main.async {
                self.delegate?.didDetectSoundEvent(logString: logString)
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
