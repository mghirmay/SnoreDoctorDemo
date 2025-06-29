// MARK: - SoundDataManager.swift (or within your existing ViewModel)
//  SoundDataManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//



import Foundation
import CoreData // Don't forget to import CoreData

class SoundDataManager {
    let persistenceController = PersistenceController.shared

    /**
       Parses a sound analysis log string and saves it to Core Data.
       Example input: "Detected: whispering (Confidence: 81.34%)"

       - Parameter logString: The string containing the detected event and confidence.
       - Parameter audioFileName: The name of the audio file associated with this event.
       - Parameter duration: The duration of the detected event in seconds.
       */
      func saveSnoreDoctorResult(logString: String, audioFileName: String, duration: Double? = nil) {
          let context = persistenceController.container.viewContext

          let pattern = #"Detected: ([a-zA-Z_ ]+)(?: \(Confidence: (\d+\.\d+)%\))?"# // Added space to match 'Snoring (Speech-like)'
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

              if let name = eventName, !name.isEmpty { // Ensure name is not empty
                  let newSoundEvent = SoundEvent(context: context)
                  newSoundEvent.id = UUID()
                  newSoundEvent.name = name
                  newSoundEvent.confidence = confidence ?? 0.0
                  newSoundEvent.timestamp = Date() // This is the time the event was detected

                  newSoundEvent.audioFileName = audioFileName // NEW: Set the audio file name
                  newSoundEvent.duration = duration ?? 0.0 // NEW: Set the duration (default to 0 if nil)

                  persistenceController.save()
                  print("Saved new sound event: '\(name)' with confidence \(confidence ?? 0.0)% for file '\(audioFileName)' duration \(duration ?? 0.0)s")
              } else {
                  print("Could not parse valid event name from log string: \(logString)")
              }
          } else {
              print("Log string did not match expected pattern: '\(logString)'")
          }
      }
}

// How you might call it from your SnoreDoctorObserver (conceptual)
/*
// Inside your SnoreDoctorObserver or ViewModel:
func SnoreDoctorObserver(_ observer: SNAudioStreamAnalyzer, didProduce results: SNResults) {
    for result in results.results {
        // Assuming you have logic to convert SNClassificationResult to your log string format
        if let classificationResult = result as? SNClassificationResult {
            for classification in classificationResult.classifications {
                let confidence = classification.confidence * 100 // Convert to percentage
                let logString = "Detected: \(classification.identifier) (Confidence: \(String(format: "%.2f", confidence))%)"
                SoundDataManager().saveSnoreDoctorResult(logString: logString)
            }
        }
    }
}
*/
