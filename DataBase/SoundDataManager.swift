//
//  SoundDataManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 09.07.25.
//


// MARK: - DataManager.swift
import Foundation
import CoreData

class SoundDataManager: ObservableObject {
    // Make it ObservableObject if you need it in SwiftUI views
    let persistenceController = PersistenceController.shared
    let managedObjectContext: NSManagedObjectContext // Make it public or internal

    // Inject SnoreEventPostProcessor
    private let snoreEventPostProcessor: SnoreEventPostProcessor

    // Initializer to inject the Core Data context
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.managedObjectContext = context
        self.snoreEventPostProcessor = SnoreEventPostProcessor(context: context) // Initialize here

        // For development: uncomment to load dummy data initially if your Core Data is empty
        // Ensure you only call this once or have logic to prevent duplicate data.
        // For example, check if there's any data first.
        // if UserDefaults.standard.bool(forKey: "hasLoadedDummyData") == false {
        //    loadDummyCoreData()
        //    UserDefaults.standard.set(true, forKey: "hasLoadedDummyData")
        // }
    }
    
    
       // ... your saveSoundEvent method and other Core Data methods ...
       func saveContext() {
           // You can have this method if you want DataManager to wrap saving
           PersistenceController.shared.save() // Or this. If DataManager has its own context,
                                             // you might call self.managedObjectContext.save()
                                             // and handle errors
       }

    // MARK: - Sound Event Management

    /**
     Saves a sound analysis result directly to Core Data.

     - Parameter identifier: The name of the detected sound event (e.g., "snoring", "speech").
     - Parameter confidence: The confidence score of the detection (0.0 to 1.0).
     - Parameter session: The RecordingSession object this event belongs to.
     - Parameter duration: The duration of the detected event in seconds (optional).
     - Parameter operations: The timeStape of the detected event in seconds (optional).
     */
    func saveSoundEvent(identifier: String, confidence: Double, session: RecordingSession, duration: Double? = nil, timeStamp : Date) -> SoundEvent {
        // Perform Core Data operations on the context's queue for thread safety
        // This function will block until the `perform` block is executed and the new SoundEvent is created.
        // If you need truly asynchronous behavior and don't want to block, you'd need a completion handler.
        var newSoundEvent: SoundEvent!

        managedObjectContext.performAndWait { // Use performAndWait to get the result synchronously
            let event = SoundEvent(context: self.managedObjectContext)
            event.id = UUID()
            event.name = identifier
            event.confidence = confidence
            event.timestamp = timeStamp
            event.session = session // Link to the session!
            event.audioFileName = session.audioFileName // Use session's audioFileName
            newSoundEvent = event // Assign the created event to the outer variable

            print("Prepared new sound event: '\(identifier)' (Conf: \(confidence)) for session '\(session.title ?? session.id?.uuidString ?? "N/A")' duration \(duration ?? 0.0)s")
        }

        return newSoundEvent
    }

    // You might want to add a method to fetch all SoundEvents for a session (though FetchRequest in SwiftUI handles this)
    func fetchSoundEvents(for recordingSession: RecordingSession) -> [SoundEvent] {
        // Core Data relationships are implicitly fetched.
        // Convert NSSet to [SoundEvent] and sort by timestamp.
        guard let eventsSet = recordingSession.soundEvents as? Set<SoundEvent> else {
            return []
        }
        return eventsSet.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    // NEW: Fetches ALL SoundEvents for a specific calendar date (midnight to midnight)
    func fetchSoundEvents(for date: Date) -> [SoundEvent] {
        let fetchRequest: NSFetchRequest<SoundEvent> = SoundEvent.fetchRequest()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
                                             startOfDay as NSDate,
                                             endOfDay as NSDate)

        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)]

        do {
            return try managedObjectContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch sound events for \(date): \(error)")
            return []
        }
    }


    // MARK: - Sleep Session Management

    func fetchRecordingSessions(for displayDate: Date) -> [RecordingSession] {
        let calendar = Calendar.current
        let startOfDisplayDay = calendar.startOfDay(for: displayDate)
        
        // We want to find sessions that ENDED on the displayDate.
        // Usually, if you wake up on Tuesday, that is your "Tuesday Sleep Report,"
        // even if you went to bed on Monday.
        guard let endOfDisplayDay = calendar.date(byAdding: .day, value: 1, to: startOfDisplayDay) else {
            return []
        }

        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        
        // Filter: Sessions that end between 00:00 and 23:59 of the selected date
        // This naturally captures the "Night Sleep" and any "Day Naps" on that specific day.
        fetchRequest.predicate = NSPredicate(
            format: "endTime >= %@ AND endTime < %@",
            startOfDisplayDay as NSDate,
            endOfDisplayDay as NSDate
        )
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: true)]

        do {
            return try managedObjectContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }

    // Calculates total sleep duration for a given day (in seconds)
    func calculateDailySleepDuration(for date: Date) -> TimeInterval {
        let sessionsForDay = fetchRecordingSessions(for: date)

        guard !sessionsForDay.isEmpty else {
            return 0
        }

        var totalSleepTime: TimeInterval = 0

        for session in sessionsForDay {
            guard let startTime = session.startTime,
                  let endTime = session.endTime else {
                print("Warning: Malformed session found with missing start or end time for session: \(session.title ?? "N/A").")
                continue
            }

            if endTime > startTime {
                totalSleepTime += endTime.timeIntervalSince(startTime)
            } else {
                print("Warning: Session found with endTime <= startTime for session: \(session.title ?? "N/A"). Skipping duration calculation.")
            }
        }
        return totalSleepTime
    }
    
    // MARK: - Snore Event Aggregation (Crucial for Charts!)
    // This is the logic you'd run periodically or at the end of a session
    // to aggregate SoundEvents into SnoreEvents.
    
    func aggregateSnoreEvents(for session: RecordingSession) {
           do {
               // The post-processor handles fetching, deleting old events, and saving new ones.
               try snoreEventPostProcessor.processSessionForSnoreEvents(session: session)
               print("Successfully re-aggregated SnoreEvents for session: \(session.title ?? "N/A") using SnoreEventPostProcessor.")
           } catch {
               print("Error aggregating SnoreEvents for session \(session.title ?? "N/A"): \(error.localizedDescription)")
               // You might want to display an alert to the user here in a real app
           }
       }
  


}


