//
//  SoundEventDetectionObserver.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//

import Foundation
import SoundAnalysis
import CoreML
import AVFoundation
import CoreData

// MARK: - Delegate Protocol

protocol SoundEventDetectionObserverDelegate: AnyObject {
    func didDetectSoundEvent(logString: String)
    func analysisDidFail(error: Error)
    func analysisDidComplete()
}

// MARK: - SoundEventDetectionObserver

class SoundEventDetectionObserver: NSObject, SNResultsObserving {

    // MARK: - Public Properties

    weak var delegate: SoundEventDetectionObserverDelegate?

    /// The active Core Data session owned by this observer.
    private(set) var currentRecordingSession: RecordingSession?

    /// Derives the recording URL from the active session's ID.
    var activeRecordingSessionURL: URL? {
        guard let id = currentRecordingSession?.id else { return nil }
        return try? FileManager.getURL(forSessionID: id)
    }

    // MARK: - Private Properties

    /// Guards against processing results after `pauseMonitoring()` is called.
    private var isProcessingActive = true

    private var snoreAggregator: SnoreEventRealtimeAggregator?
    private let soundDataManager: SoundDataManager

    // MARK: - Init

    /// - Parameters:
    ///   - delegate: Receives lifecycle and detection callbacks on the main thread.
    ///   - soundDataManager: Handles all Core Data persistence.
    init(
        delegate: SoundEventDetectionObserverDelegate,
        soundDataManager: SoundDataManager
    ) {
        self.delegate = delegate
        self.soundDataManager = soundDataManager
        super.init()
    }

    // MARK: - Session Lifecycle

    /// Creates a new `RecordingSession` in Core Data and prepares internal state.
    ///
    /// - Parameter context: The `NSManagedObjectContext` to use for this session.
    ///   All subsequent Core Data operations (aggregator, save) will use the same context.
    func startNewSession(context: NSManagedObjectContext) {
        // Ensure we start fresh — finalize any lingering session.
        if currentRecordingSession != nil {
            finalizeSession()
        }

        let sessionID = UUID()

        // Guard on the file URL: if we can't create it, don't start the session.
        guard let recordingURL = try? FileManager.getURL(forSessionID: sessionID) else {
            print("SoundEventDetectionObserver: Failed to create recording URL for session \(sessionID). Session not started.")
            return
        }

        context.performAndWait {
            let newSession = RecordingSession(context: context)
            newSession.id = sessionID
            newSession.startTime = Date()
            newSession.totalSnoreEvents = 0
            newSession.totalSnoreRelated = 0
            newSession.totalNonSnoreEvents = 0
            newSession.notes = nil
            newSession.audioFileName = recordingURL.lastPathComponent

            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE, MMM d, h:mm a"
            newSession.title = fmt.string(from: newSession.startTime ?? Date())

            self.currentRecordingSession = newSession
            self.snoreAggregator = SnoreEventRealtimeAggregator(context: context, for: newSession)
            self.isProcessingActive = true

            print("SoundEventDetectionObserver: Session started — \(newSession.title ?? sessionID.uuidString)")
        }
    }

    /// Saves the session's final counts and quality score, then clears all references.
    /// Called by `SoundRecognitionManager.stopRecognition()` on a manual stop,
    /// and also internally when the analysis request completes or fails.
    func finalizeSession() {
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil
        updateSessionCountsAndSave()
        currentRecordingSession = nil
        isProcessingActive = false
    }

    // MARK: - Monitoring Control

    /// Pauses result processing without stopping the audio pipeline.
    func pauseMonitoring() {
        print("SoundEventDetectionObserver: Monitoring paused.")
        isProcessingActive = false
    }

    /// Resumes result processing.
    func resumeMonitoring() {
        print("SoundEventDetectionObserver: Monitoring resumed.")
        isProcessingActive = true
    }

    // MARK: - SNResultsObserving

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard isProcessingActive else { return }
        guard let classificationResult = result as? SNClassificationResult else { return }
        guard let top = classificationResult.classifications.first else { return }

        let identifier = top.identifier
        let confidence = top.confidence
        let threshold = UserDefaults.standard.snoreConfidenceThreshold

        guard confidence > threshold else {
            print("SoundEventDetectionObserver: '\(identifier)' below threshold (\(confidence) ≤ \(threshold)).")
            return
        }

        let isSnore        = SoundIdentifiers.snore.contains(identifier.lowercased())
        let isSnoreRelated = SoundIdentifiers.snoreRelated.contains(identifier.lowercased())
        let isNonSnore     = SoundIdentifiers.nonSnore.contains(identifier.lowercased())

        let logString = String(format: "Detected: %@ (%.2f%%)\n", identifier, confidence * 100)
        DispatchQueue.main.async {
            self.delegate?.didDetectSoundEvent(logString: logString)
        }

        guard let session = currentRecordingSession else {
            print("SoundEventDetectionObserver: No active session — '\(identifier)' not saved.")
            return
        }

        soundDataManager.managedObjectContext.perform {
            session.lastUpdate = Date()

            if isSnore {
                session.totalSnoreEvents += 1
                // Notify the playback layer on the main thread.
                DispatchQueue.main.async {
                    AudioPlaybackManager.shared.notifySnoreDetected()
                }
            } else if isSnoreRelated {
                session.totalSnoreRelated += 1
            } else if isNonSnore {
                session.totalNonSnoreEvents += 1
            }

            let savedEvent = self.soundDataManager.saveSoundEvent(
                identifier: identifier,
                confidence: confidence,
                session: session,
                isSnoreRelated: isSnoreRelated
            )
            self.snoreAggregator?.processNewSoundEvent(savedEvent)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundEventDetectionObserver: Analysis failed — \(error.localizedDescription)")
        finalizeSession()
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        print("SoundEventDetectionObserver: Analysis completed.")
        finalizeSession()
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
    }

    // MARK: - Private Helpers

    /// Computes the final quality score and persists the session to Core Data.
    private func updateSessionCountsAndSave() {
        guard let session = currentRecordingSession else {
            print("SoundEventDetectionObserver: updateSessionCountsAndSave — no active session.")
            return
        }

        soundDataManager.managedObjectContext.perform {
            let start = session.startTime ?? Date()
            let end   = Date()
            session.endTime = end

            let durationHours = end.timeIntervalSince(start) / 3600.0

            session.qualityScore = SleepQuality.calculateQualityScore(
                snoreCount:    Int(session.totalSnoreEvents),
                relatedCount:  Int(session.totalSnoreRelated),
                nonSnoreCount: Int(session.totalNonSnoreEvents),
                durationInHours: durationHours
            )

            self.soundDataManager.saveContext()

            print("""
            SoundEventDetectionObserver: Session saved — \
            Snore=\(session.totalSnoreEvents) \
            Related=\(session.totalSnoreRelated) \
            NonSnore=\(session.totalNonSnoreEvents) \
            Quality=\(session.qualityScore)
            """)
        }
    }
}
