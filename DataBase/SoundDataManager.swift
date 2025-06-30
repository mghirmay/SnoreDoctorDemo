// MARK: - SoundDataManager.swift (or within your existing ViewModel)
//  SoundDataManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//


// SoundDataManager.swift
import Foundation
import CoreData

class SoundDataManager {
    let persistenceController = PersistenceController.shared

    /**
     Saves a sound analysis result directly to Core Data.

     - Parameter identifier: The name of the detected sound event (e.g., "snoring", "speech").
     - Parameter confidence: The confidence score of the detection (0.0 to 1.0).
     - Parameter session: The RecordingSession object this event belongs to.
     - Parameter duration: The duration of the detected event in seconds (optional).
     */
    // MODIFIED: Signature changed to accept identifier and confidence directly
    func saveSnoreDoctorResult(identifier: String, confidence: Double, session: RecordingSession, duration: Double? = nil) {
        let context = persistenceController.container.viewContext

        context.perform { // Perform Core Data operations on the context's queue for thread safety
            let newSoundEvent = SoundEvent(context: context)
            newSoundEvent.id = UUID()
            newSoundEvent.name = identifier // Use the direct identifier as the event name
            newSoundEvent.confidence = confidence // Use the direct confidence (Double)
            newSoundEvent.timestamp = Date() // Timestamp of the detection

            newSoundEvent.audioFileName = session.audioFileName // Use session's audioFileName
            newSoundEvent.duration = duration ?? 0.0

            newSoundEvent.session = session // Link to the session!

            // No need to call persistenceController.save() here for every event.
            // Let the ViewController handle the final save when the session ends
            // or when it deems appropriate to commit changes.
            print("Prepared new sound event: '\(identifier)' (Conf: \(confidence)) for session '\(session.title ?? session.id?.uuidString ?? "N/A")' duration \(duration ?? 0.0)s")
        }
    }

    // You might want to add a method to fetch all SoundEvents for the HistogramView if needed here
    // Although the HistogramView uses @FetchRequest, sometimes a manager method is useful for other parts.
    func fetchAllSoundEvents() -> [SoundEvent] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SoundEvent> = SoundEvent.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all sound events: \(error.localizedDescription)")
            return []
        }
    }
}
