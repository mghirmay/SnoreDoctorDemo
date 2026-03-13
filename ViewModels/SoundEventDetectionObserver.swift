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
import CoreData // Essential for Core Data operations




// MARK: - SoundEventDetectionObserverDelegate Protocol Definition
protocol SoundEventDetectionObserverDelegate: AnyObject {
    func didDetectSoundEvent(logString: String)
    func analysisDidFail(error: Error)
    func analysisDidComplete()
}

class SoundEventDetectionObserver: NSObject, SNResultsObserving {
    weak var delegate: SoundEventDetectionObserverDelegate?
    
    // The observer now "owns" the active session
    private(set) var currentRecordingSession: RecordingSession?
    var activeRecordingSessionURL: URL? {
        guard let session = currentRecordingSession, let id = session.id else {
            return nil
        }
        // Use your standardized helper!
        return try? FileManager.getURL(forSessionID: id)
    }

    
    // NEW: Internal flag to control if processing of results should occur
    private var isProcessingActive: Bool = true
    
    private var snoreAggregator: SnoreEventRealtimeAggregator?
    
    private let soundDataManager: SoundDataManager


    // MARK: - Initialization

    /// Initializes the sound event detection observer.
    /// - Parameters:
    ///   - delegate: The object that will receive notifications about detected events and analysis status.
    ///   - context: The Core Data `NSManagedObjectContext` to be used for saving `SoundEvent`s and updating `RecordingSession` counts.
    init(delegate: SoundEventDetectionObserverDelegate, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext, soundDataManager: SoundDataManager) {
        self.delegate = delegate
        self.soundDataManager = soundDataManager
        super.init()
    }

    
    // Add a method to initialize the session internally
    func startNewSession(context: NSManagedObjectContext){
        
        let sessionID = UUID()
            
        do {
            // Reset event counters for the new session to start fresh
            self.isProcessingActive = true // Ensure active when a new session starts
            let recordingURL = try FileManager.getURL(forSessionID: sessionID)
            
            let newSession = RecordingSession(context: context)
            newSession.id = sessionID
            newSession.startTime = Date()
            //newSession.endTime = Date()
            // Update the session's integer properties
            newSession.totalSnoreEvents = 0
            newSession.totalSnoreRelated = 0
            newSession.totalNonSnoreEvents = 0
            
            newSession.notes = nil
            newSession.audioFileName = recordingURL.lastPathComponent
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMM d, h:mm a"
            newSession.title = dateFormatter.string(from: newSession.startTime ?? Date())
            
            //
            self.currentRecordingSession = newSession
            
            // Initialize your aggregator here
            self.snoreAggregator = SnoreEventRealtimeAggregator(context: context, for: newSession)
            print("SoundEventDetectionObserver: SnoreEventRealtimeAggregator and event counters initialized for new session.")
  
        }
        catch {
            // Handle the failure!
            // This is crucial: if this fails, you probably shouldn't start recording.
            print("Failed to create recording file: \(error.localizedDescription)")
            // Stop the session creation if we can't save the file
        }
    }
    
    
    
 
    
    func finalizeSession() {
        // Handle logic when recording stops
        // Update Core Data session end time and save
        updateSessionCountsAndSave(updateEndTime : true)
        self.currentRecordingSession = nil
        self.snoreAggregator = nil
    }

   



    // MARK: - Control Methods (Added for completeness, manage internal state)

    /// Pauses the internal processing of analysis results.
    /// The SNResultsObserving delegate methods will still be called,
    /// but the logic within `didProduce` will be skipped.
    public func pauseMonitoring() {
        print("SoundEventDetectionObserver: Pausing monitoring.")
        self.isProcessingActive = false
    }

    /// Resumes the internal processing of analysis results.
    public func resumeMonitoring() {
        print("SoundEventDetectionObserver: Resuming monitoring.")
        self.isProcessingActive = true
    }
    


    // MARK: - SNResultsObserving Protocol Methods

    func request(_ request: SNRequest, didProduce result: SNResult) {
        // Only process results if monitoring is active
        guard isProcessingActive else {
            print("SoundEventDetectionObserver - Received result, but processing is paused.")
            return
        }

        print("SnoreDoctorObserver - Received a sound analysis result.")

        guard let classificationResult = result as? SNClassificationResult else { return }

        // Determine the duration of the analyzed sound event
        let windowDuration: Double
        if let classifyRequest = request as? SNClassifySoundRequest {
            windowDuration = classifyRequest.windowDuration.seconds
        } else {
            windowDuration = 1.0 // Fallback duration if request type is unexpected
            print("Warning: Request is not an SNClassifySoundRequest or windowDuration not available. Using default duration of \(windowDuration)s.")
        }

        let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold // Get confidence threshold from UserDefaults
        
   
        if let topClassification = classificationResult.classifications.first {
            let identifierToSave = topClassification.identifier
            let confidenceToSave = topClassification.confidence

            // --- Update Event Counters ---
            // Categorize and increment counts based on AppSettings definitions
            let isSnore = SoundIdentifiers.snore.contains(identifierToSave.lowercased())
            let isSnoreRelated = SoundIdentifiers.snoreRelated.contains(identifierToSave.lowercased())
            let isNonSnoreEvent = SoundIdentifiers.nonSnore.contains(identifierToSave.lowercased())

           
            
        
            // Check if the event meets the UI display confidence threshold
            if topClassification.confidence > requiredConfidence {
                let confidenceDisplay = String(format: "%.2f", confidenceToSave * 100)
                let outputStringForUI = "Detected: \(identifierToSave) (Confidence: \(confidenceDisplay)%)\n"
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.delegate?.didDetectSoundEvent(logString: outputStringForUI)
                }
                
        
                
                // Regardless of UI display confidence, save the raw SoundEvent to Core Data
                // and pass it to the real-time aggregator for SnoreEvent grouping.
                if let session = self.currentRecordingSession {
                    
                    // Update the session's "Last Seen" timestamp
                    session.lastUpdate = Date()
                    // Update the session's integer properties
                    if isSnore {
                        session.totalSnoreEvents += 1
                        // Only play if not already playing to avoid overlapping sounds
                        // Play the random sound snippet
                        AudioPlaybackManager.shared.notifySnoreDetected()
                            
                    } else if isSnoreRelated {
                            session.totalSnoreRelated += 1
                    }
                    else if isNonSnoreEvent {
                        session.totalNonSnoreEvents += 1
                    }
             
                    let createdSoundEvent = self.soundDataManager.saveSoundEvent(
                        identifier: identifierToSave,
                        confidence: confidenceToSave,
                        session: session,
                        isSnoreRelated: isSnoreRelated
                    )
                    // Pass the newly created (and saved) SoundEvent to the real-time aggregator
                    self.snoreAggregator?.processNewSoundEvent(createdSoundEvent)
                    
                    
              
                 
                } else {
                    print("Error: currentRecordingSession is nil. SoundEvent '\(identifierToSave)' not saved with session.")
                }
                
            } else {
                print("Event '\(identifierToSave)' with confidence \(confidenceToSave) below display threshold (\(requiredConfidence)).")
            }
            
         
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed with error: \(error.localizedDescription)")
        
        // Finalize any pending SnoreEvent aggregation
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear the aggregator instance
        
        // Save the accumulated counts to the RecordingSession Core Data object
        updateSessionCountsAndSave(updateEndTime: true)
        
        currentRecordingSession = nil // Clear the session reference
        
        // Notify delegate about the failure and provide final counts
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
        self.isProcessingActive = false // Mark as inactive on failure
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed.")
        
        // Finalize any pending SnoreEvent aggregation
        snoreAggregator?.finalizeRecordingSession()
        snoreAggregator = nil // Clear the aggregator instance
        
        // Save the accumulated counts to the RecordingSession Core Data object
        updateSessionCountsAndSave(updateEndTime: true)
        
        currentRecordingSession = nil // Clear the session reference
        
        // Notify delegate about completion and provide final counts
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
        self.isProcessingActive = false // Mark as inactive on completion
    }

    // MARK: - Private Helper Methods

    /// Updates the `RecordingSession`'s count properties in Core Data with the current accumulated totals
    /// and saves the `managedObjectContext`. This is typically called when a recording session concludes.
    private func updateSessionCountsAndSave(updateEndTime : Bool) {
        // Inside updateSessionCountsAndSave()
        guard let session = currentRecordingSession else {
            print("Cannot update session counts: currentRecordingSession is nil during save attempt.")
            return
        }

        print("Pre-update session counts: Snore=\(session.totalSnoreEvents), Related=\(session.totalSnoreRelated), Non-Snore=\(session.totalNonSnoreEvents)")

        session.endTime = Date() // Set the end time for the session
        
        // Perform the calculation sleep quality
        let start = session.startTime ?? Date()
        let end = session.endTime ?? Date()
        let durationHours = end.timeIntervalSince(start) / 3600.0
        let totalSnoreEventsDetected = Int(session.totalSnoreEvents);
        let totalSnoreRelatedEventsDetected = Int(session.totalSnoreRelated);
        let totalNonSnoreEventsDetected = Int(session.totalNonSnoreEvents);
     
        session.qualityScore = calculateQualityScore(
            snoreCount: totalSnoreEventsDetected,
                relatedCount: totalSnoreRelatedEventsDetected,
                nonSnoreCount: totalNonSnoreEventsDetected,
                durationInHours: durationHours
            )
        
   
        print("Post-update session counts (in memory): Snore=\(session.totalSnoreEvents), Related=\(session.totalSnoreRelated), Non-Snore=\(session.totalNonSnoreEvents)")

        // Crucial check: Does the context actually have changes?
        print("Managed object context has changes BEFORE save: \(soundDataManager.managedObjectContext.hasChanges)")

        do {
            soundDataManager.saveContext()
            print("Session counts saved to Core Data for session \(session.id?.uuidString ?? "N/A"): Snore=\(totalSnoreEventsDetected), Related=\(totalSnoreRelatedEventsDetected), Non-Snore=\(totalNonSnoreEventsDetected)")
        }
    }
    
    
    
    /// Calculates the sleep quality score based on detected audio events.
    /// Returns a Double between 0.0 (Poor) and 1.0 (Excellent).
    private func calculateQualityScore(
        snoreCount: Int,
        relatedCount: Int,
        nonSnoreCount: Int,
        durationInHours: Double
    ) -> Double {
        let totalEvents = Double(snoreCount + relatedCount + nonSnoreCount)
        
        // If no events detected, consider it a perfect, quiet night
        guard totalEvents > 0 else { return 1.0 }
        
        // Calculate ratio of "problem" events vs total activity
        let problemEvents = Double(snoreCount + relatedCount)
        let cleanlinessRatio = 1.0 - (problemEvents / totalEvents)
        
        // Penalize short sessions (e.g., sessions under 4 hours are marked down)
        let durationMultiplier = min(durationInHours / 4.0, 1.0)
        
        return cleanlinessRatio * durationMultiplier
    }
}
