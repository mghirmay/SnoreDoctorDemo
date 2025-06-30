// MARK: - SoundDataManager.swift (or within your existing ViewModel)
//  SoundDataManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//


// SoundDataManager.swift
import Foundation
import CoreData

class SoundDataManager {
    let persistenceController = PersistenceController.shared

    /**
     Parses a sound analysis log string and saves it to Core Data.
     Example input: "Detected: whispering (Confidence: 81.34%)"

     - Parameter logString: The string containing the detected event and confidence.
     - Parameter session: The RecordingSession object this event belongs to.
     - Parameter duration: The duration of the detected event in seconds.
     */
    func saveSnoreDoctorResult(logString: String, session: RecordingSession, duration: Double? = nil) { // CHANGED: Now takes RecordingSession object
        let context = persistenceController.container.viewContext

        let pattern = #"Detected: ([a-zA-Z_ ]+)(?: \(Confidence: (\d+\.\d+)%\))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("Error: Invalid regex pattern.")
            return
        }

        let range = NSRange(logString.startIndex..<logString.endIndex, in: logString)
        if let match = regex.firstMatch(in: logString, options: [], range: range) {
            var eventName: String?
            var confidence: Double?

            if let nameRange = Range(match.range(at: 1), in: logString) {
                eventName = String(logString[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let confidenceRange = Range(match.range(at: 2), in: logString) {
                confidence = Double(logString[confidenceRange])
            }

            if let name = eventName, !name.isEmpty {
                let newSoundEvent = SoundEvent(context: context)
                newSoundEvent.id = UUID()
                newSoundEvent.name = name
                newSoundEvent.confidence = confidence ?? 0.0
                newSoundEvent.timestamp = Date() // Timestamp of the detection

                newSoundEvent.audioFileName = session.audioFileName // Use session's audioFileName
                newSoundEvent.duration = duration ?? 0.0

                newSoundEvent.session = session // NEW: Link to the session!

                // No need to call persistenceController.save() here for every event
                // It's better to save the context less frequently, e.g., when the session ends
                // Or let the ViewController handle the final save if it needs to ensure the session object is saved
                print("Prepared new sound event: '\(name)' for session '\(session.title ?? session.id?.uuidString ?? "N/A")' duration \(duration ?? 0.0)s")
            } else {
                print("Could not parse valid event name from log string: \(logString)")
            }
        } else {
            print("Log string did not match expected pattern: '\(logString)'")
        }
    }
}
