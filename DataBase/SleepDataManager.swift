//
//  SleepDataManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//


import CoreData
import Foundation


// MARK: - SleepDataManager (Core Data Integration)

class SleepDataManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    // Initializer to inject the Core Data context
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // For development: uncomment to load dummy data initially if your Core Data is empty
        // Ensure you only call this once or have logic to prevent duplicate data.
        // For example, check if there's any data first.
        // Note: For real data, you wouldn't load dummies here.
        // if UserDefaults.standard.bool(forKey: "hasLoadedDummyData") == false {
        //    loadDummyCoreData()
        //    UserDefaults.standard.set(true, forKey: "hasLoadedDummyData")
        // }
    }
    
    // Fetches RecordingSessions for a specific date
    func fetchRecordingSessions(for date: Date) -> [RecordingSession] {
        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        // Predicate to filter sessions that either start or end on the given day
        // Or sessions that span across the day (start before and end after)
        // Ensure properties are non-nil for comparison in predicate
        let predicate = NSPredicate(format: "(startTime >= %@ AND startTime < %@) OR (endTime >= %@ AND endTime < %@) OR (startTime < %@ AND endTime > %@)",
                                    startOfDay as NSDate,
                                    endOfDay as NSDate,
                                    startOfDay as NSDate,
                                    endOfDay as NSDate,
                                    startOfDay as NSDate,
                                    endOfDay as NSDate)
        
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch recording sessions for date \(date): \(error)")
            return []
        }
    }
    
    // Fetches SoundEvents for a specific RecordingSession
    func fetchSoundEvents(for recordingSession: RecordingSession) -> [SoundEvent] {
        // Core Data relationships are implicitly fetched.
        // Convert NSSet to [SoundEvent] and sort by timestamp.
        guard let eventsSet = recordingSession.events as? Set<SoundEvent> else {
            return []
        }
        return eventsSet.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    // Calculates total sleep duration for a given day (in hours)
    // This now fetches sessions via Core Data
    func calculateDailySleepDuration(for date: Date) -> TimeInterval {
        let sessionsForDay = fetchRecordingSessions(for: date)
        
        guard let firstSessionStartTime = sessionsForDay.first?.startTime,
              let lastSessionEndTime = sessionsForDay.last?.endTime else {
            return 0 // No sleep data for this day
        }
        
        // Simple calculation: time from start of first session to end of last session.
        // This still assumes contiguous sleep for calculation.
        // For more advanced calculation:
        // You might sum up the actual duration of each session (endTime - startTime)
        // and add logic to subtract detected awake periods if you have that data.
        let totalDuration = lastSessionEndTime.timeIntervalSince(firstSessionStartTime)
        return totalDuration / 3600.0 // Convert to hours
    }
    
    // MARK: - Dummy Core Data Loader (for testing)
    func loadDummyCoreData() {
        let calendar = Calendar.current
        
        // Clear existing data (optional, for clean testing)
        // try? viewContext.fetch(RecordingSession.fetchRequest()).forEach(viewContext.delete)
        // try? viewContext.fetch(SoundEvent.fetchRequest()).forEach(viewContext.delete)
        // try? viewContext.save()
        
        // Current date for dummy data generation
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        // Session 1: Good sleep (today)
        let session1 = RecordingSession(context: viewContext)
        session1.id = UUID()
        session1.startTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)!
        session1.endTime = calendar.date(byAdding: .hour, value: 8, to: session1.startTime!)!
        session1.title = "Good Sleep"
        session1.audioFileName = "session1_audio.m4a"
        
        addSoundEvent(session: session1, timestamp: calendar.date(byAdding: .minute, value: 30, to: session1.startTime!)!, name: SoundEventType.snoring.rawValue)
        addSoundEvent(session: session1, timestamp: calendar.date(byAdding: .hour, value: 1, to: session1.startTime!)!, name: SoundEventType.cough.rawValue)
        addSoundEvent(session: session1, timestamp: calendar.date(byAdding: .hour, value: 3, to: session1.startTime!)!, name: SoundEventType.snoring.rawValue)
        addSoundEvent(session: session1, timestamp: calendar.date(byAdding: .hour, value: 6, to: session1.startTime!)!, name: SoundEventType.cough.rawValue)

        // Session 2: Short sleep (yesterday - yellow)
        let session2 = RecordingSession(context: viewContext)
        session2.id = UUID()
        session2.startTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: yesterday)!
        session2.endTime = calendar.date(byAdding: .hour, value: 5, to: session2.startTime!)! // 7 hours
        session2.title = "Short Night"
        session2.audioFileName = "session2_audio.m4a"

        addSoundEvent(session: session2, timestamp: calendar.date(byAdding: .hour, value: 1, to: session2.startTime!)!, name: SoundEventType.talking.rawValue)
        addSoundEvent(session: session2, timestamp: calendar.date(byAdding: .hour, value: 4, to: session2.startTime!)!, name: SoundEventType.snoring.rawValue)
        addSoundEvent(session: session2, timestamp: calendar.date(byAdding: .hour, value: 4, to: session2.startTime!)!
                                       .addingTimeInterval(30 * 60), name: SoundEventType.snoring.rawValue)


        // Session 3: Very short sleep (two days ago - red)
        let session3 = RecordingSession(context: viewContext)
        session3.id = UUID()
        session3.startTime = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: twoDaysAgo)!
        session3.endTime = calendar.date(byAdding: .hour, value: 3, to: session3.startTime!)! // 2 hours
        session3.title = "Rough Night"
        session3.audioFileName = "session3_audio.m4a"

        addSoundEvent(session: session3, timestamp: calendar.date(byAdding: .minute, value: 45, to: session3.startTime!)!, name: SoundEventType.cough.rawValue)
        
        // Session 4: No sleep data for three days ago (for calendar check)
        // No session added for threeDaysAgo, so calculateDailySleepDuration should return 0.
        
        // Save all changes
        do {
            try viewContext.save()
            print("Dummy Core Data loaded successfully.")
        } catch {
            print("Failed to save dummy data: \(error)")
        }
    }
    
    private func addSoundEvent(session: RecordingSession, timestamp: Date, name: String, confidence: Double = 1.0, duration: Double = 0.5) {
        let soundEvent = SoundEvent(context: viewContext)
        soundEvent.id = UUID()
        soundEvent.timestamp = timestamp
        soundEvent.name = name
        soundEvent.confidence = confidence
        soundEvent.duration = duration
        soundEvent.session = session // Establish the relationship
        soundEvent.audioFileName = session.audioFileName // Link to session's audio file
    }
}
