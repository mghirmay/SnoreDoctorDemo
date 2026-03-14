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
     */
    func saveSoundEvent(identifier: String, confidence: Double, session: RecordingSession, isSnoreRelated: Bool) -> SoundEvent {
        var newSoundEvent: SoundEvent!
  

        managedObjectContext.performAndWait {
            let event = SoundEvent(context: self.managedObjectContext)
            event.id = UUID()
            event.name = identifier
            event.confidence = confidence
            event.timestamp = Date()
            
            // --- THE FILTER ---
             if isSnoreRelated {
                // Only link to the session if it's a snore or related sound
                event.session = session
                event.audioFileName = session.audioFileName
                print("💾 Saving Snore-Related: \(identifier)")
            } else {
                // If it's NOT a snore, we don't link it.
                // It stays in RAM (temporary) so the aggregator can see it,
                // but it won't be saved to the database.
                print("☁️ Processing Temporary Sound: \(identifier)")
            }
            
            newSoundEvent = event
        }

        return newSoundEvent
    }
    
    /// Fetches all SnoreEvents for a single RecordingSession.
    /// Mirrors the pattern of fetchSoundEvents(for recordingSession:) —
    /// casts the Core Data NSSet relationship and sorts by startTime.
    func fetchSnoreEvents(for recordingSession: RecordingSession) -> [SnoreEvent] {
        guard let set = recordingSession.snoreEvents as? Set<SnoreEvent> else {
            return []
        }
        return set.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
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
 
    
    /// Fetches ALL SnoreEvents across every RecordingSession for a given calendar date.
    /// Useful when you need a flat list for charting across the full night.
    func fetchSnoreEvents(for date: Date) -> [SnoreEvent] {
        let sessions = fetchRecordingSessions(for: date)
        return sessions.flatMap { session -> [SnoreEvent] in
            guard let set = session.snoreEvents as? Set<SnoreEvent> else { return [] }
            return set.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
        }
    }

 
    // NEW: Fetches ALL SoundEvents for a specific calendar date (midnight to midnight)
    func fetchSoundEvents(for date: Date) -> [SoundEvent] {
        let sessions = fetchRecordingSessions(for: date)
        return sessions.flatMap { session -> [SoundEvent] in
            guard let set = session.soundEvents as? Set<SoundEvent> else { return [] }
            return set.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        }
    }


    // MARK: - Sleep Session Management
    /// Fetches all RecordingSessions sorted by startTime descending (most recent first).
    func fetchRecordingSessions() -> [RecordingSession] {
        let request: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: false)]

        do {
            return try managedObjectContext.fetch(request)
        } catch {
            print("Failed to fetch all sessions: \(error)")
            return []
        }
    }
    
    /// Fetches a single RecordingSession by its UUID.
    func fetchRecordingSession(id: UUID) -> RecordingSession? {
        let request: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try managedObjectContext.fetch(request).first
        } catch {
            print("Failed to fetch session by id \(id): \(error)")
            return nil
        }
    }

    
    
    func fetchRecordingSessions(for displayDate: Date) -> [RecordingSession] {
        let calendar = Calendar.current
        let startOfDisplayDay = calendar.startOfDay(for: displayDate)
        
        // Get the start of the NEXT day
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDisplayDay) else {
            return []
        }

        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        
        // NEW Predicate: Find all sessions that started ON the selected date
        // regardless of when they ended.
        fetchRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDisplayDay as NSDate,
            startOfNextDay as NSDate
        )
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: true)]

        do {
            return try managedObjectContext.fetch(fetchRequest)
        } catch {
            print("Fetch error: \(error)")
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
  
    
    
    func reconcileIncompleteSessions(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        request.predicate = NSPredicate(format: "endTime == nil")

        do {
            let sessions = try context.fetch(request)
            for session in sessions {
                let eventRequest: NSFetchRequest<SnoreEvent> = SnoreEvent.fetchRequest()
                eventRequest.predicate = NSPredicate(format: "session == %@", session)
                eventRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: false)]
                eventRequest.fetchLimit = 1

                if let latestEvent = try context.fetch(eventRequest).first,
                   let lastTime = latestEvent.startTime {
                    session.endTime = lastTime
                    session.lastUpdate = lastTime
                } else {
                    session.endTime = session.startTime?.addingTimeInterval(60)
                    print("Patched empty session \(session.objectID) with default duration.")
                }

                // Recalculate quality score now that endTime is set
                let start = session.startTime ?? Date()
                let end   = session.endTime   ?? Date()
                let durationHours = end.timeIntervalSince(start) / 3600.0

                session.qualityScore = SleepQuality.calculateQualityScore(
                    snoreCount:      Int(session.totalSnoreEvents),
                    relatedCount:    Int(session.totalSnoreRelated),
                    nonSnoreCount:   Int(session.totalNonSnoreEvents),
                    durationInHours: durationHours
                )

                print("Recalculated quality for session \(session.id?.uuidString ?? "N/A"): \(session.qualityScore)")
            }
            try context.save()
        } catch {
            print("Reconciliation failed: \(error)")
        }
    }
    
    
    /// Runs a full data repair pass on all sessions.
    /// Step 1: Patches any sessions with a nil endTime (reconcileIncompleteSessions).
    /// Step 2: Rebuilds SnoreEvents from SoundEvents for every session.
    ///
    /// Call this once at app startup, after the Core Data stack is ready.
    func reconcileAndRebuildAllSessions() {
        print("🔧 Starting full session reconciliation and SnoreEvent rebuild...")

        // Step 1: Patch incomplete sessions first so endTime is valid before aggregation
        reconcileIncompleteSessions(in: managedObjectContext)

        // Step 2: Rebuild SnoreEvents for every session
        let allSessions = fetchRecordingSessions()

        guard !allSessions.isEmpty else {
            print("ℹ️ No sessions found. Nothing to rebuild.")
            return
        }

        var successCount = 0
        var failCount = 0

        for session in allSessions {
            do {
                try snoreEventPostProcessor.processSessionForSnoreEvents(session: session)
                successCount += 1
            } catch {
                failCount += 1
                print("❌ Failed to rebuild SnoreEvents for session \(session.id?.uuidString ?? "N/A"): \(error.localizedDescription)")
            }
        }

        print("✅ Rebuild complete — \(successCount) succeeded, \(failCount) failed out of \(allSessions.count) session(s).")
    }


}


