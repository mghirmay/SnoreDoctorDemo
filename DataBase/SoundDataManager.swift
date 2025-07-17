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


    // Define the hour at which a "sleep day" starts (e.g., 6 PM)
    private let sleepDayStartHour = 16 // 16:00 (4 PM)

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

    // Fetches RecordingSessions for a specific "sleep day" defined by the given date
    // The "sleep day" spans from sleepDayStartHour on `date` to sleepDayStartHour on the next
    // calendar day.
    func fetchRecordingSessions(for date: Date) -> [RecordingSession] {
        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()

        let calendar = Calendar.current

        // Calculate the start of the "sleep day" (e.g., 6 PM on selectedDate)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = sleepDayStartHour
        // Ensure date from components is not nil (e.g., if date is invalid)
        guard let sleepDayStart = calendar.date(from: components) else {
            print("Error: Could not create sleepDayStart date from components for \(date)")
            return []
        }

        // Calculate the end of the "sleep day" (e.g., 6 PM on the next calendar day)
        guard let sleepDayEnd = calendar.date(byAdding: .day, value: 1, to: sleepDayStart) else {
            print("Error: Could not calculate sleepDayEnd date from sleepDayStart \(sleepDayStart)")
            return []
        }

        // Predicate to filter sessions that either start or end within this custom "sleep day" window,
        // or span across it. This predicate covers all cases for sessions relevant to this custom day.
        let predicate = NSPredicate(format: "(startTime >= %@ AND startTime < %@) OR (endTime > %@ AND endTime <= %@) OR (startTime < %@ AND endTime > %@)",
                                     sleepDayStart as NSDate,
                                     sleepDayEnd as NSDate,
                                     sleepDayStart as NSDate,
                                     sleepDayEnd as NSDate,
                                     sleepDayStart as NSDate,
                                     sleepDayEnd as NSDate)

        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: true)]

        do {
            return try managedObjectContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch recording sessions for sleep day starting \(sleepDayStart): \(error)")
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


