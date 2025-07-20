//
//  SnoreEventCreator.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 19.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//

import CoreData
import Foundation

// --- Assuming these are defined elsewhere ---
// extension UserDefaults { var postProcessGapThreshold: Double { 0.5 } }
// class AppSettings { static let snoreEventRelatedIdentifiers: Set<String> = ["snoring", "gasp", "breathing", "sigh", "whispering"] }
// class RecordingSession: NSManagedObject { @NSManaged public var id: UUID? }
// class SnoreEvent: NSManagedObject {
//    @NSManaged public var id: UUID?
//    @NSManaged public var session: RecordingSession?
//    @NSManaged public var startTime: Date?
//    @NSManaged public var endTime: Date?
//    @NSManaged public var duration: Double
//    @NSManaged public var count: Int32
//    @NSManaged public var averageConfidence: Double
//    @NSManaged public var minConfidence: Double
//    @NSManaged public var maxConfidence: Double
//    @NSManaged public var peakConfidence: Double
//    @NSManaged public var medianConfidence: Double
//    @NSManaged public var soundEventNamesHistogram: NSDictionary?
//    @NSManaged public var name: String?
// }


// MARK: - Protocol Definition

/// Protocol for types that can create and save SnoreEvent objects from a batch of SoundEvents.
protocol SnoreEventCreator {
    var managedObjectContext: NSManagedObjectContext { get }

    /// Creates a new SnoreEvent from a batch of SoundEvents and persists it.
    /// - Parameters:
    ///   - soundEvents: An array of SoundEvent objects representing the batch.
    ///   - session: The RecordingSession this SnoreEvent belongs to.
    /// - Throws: An error if the SnoreEvent cannot be created or saved.
    func createAndSaveSnoreEvent(from soundEvents: [SoundEvent], for session: RecordingSession) throws
}

// MARK: - Protocol Extension (Default Implementation)

extension SnoreEventCreator {
    func createAndSaveSnoreEvent(from soundEvents: [SoundEvent], for session: RecordingSession) throws {
        guard !soundEvents.isEmpty else { return }

        let snoreEvent = SnoreEvent(context: managedObjectContext) // Use the context from the conforming type
        snoreEvent.id = UUID()
        snoreEvent.session = session

        // Ensure the soundEvents array is sorted by timestamp for correct startTime and duration
        let sortedSoundEvents = soundEvents.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }

        snoreEvent.startTime = sortedSoundEvents.first?.timestamp
        snoreEvent.endTime = sortedSoundEvents.last?.timestamp

        if let start = snoreEvent.startTime, let end = snoreEvent.endTime {
            snoreEvent.duration = end.timeIntervalSince(start)
        } else {
            snoreEvent.duration = 0.0
        }

        snoreEvent.count = Int32(soundEvents.count)
        snoreEvent.countSnores = Int32(soundEvents.filter { $0.name == "snoring" }.count)

        let confidences = soundEvents.map { $0.confidence }
        if !confidences.isEmpty {
            snoreEvent.averageConfidence = confidences.reduce(0.0, +) / Double(confidences.count)
            snoreEvent.minConfidence = confidences.min() ?? 0.0
            snoreEvent.maxConfidence = confidences.max() ?? 0.0
            snoreEvent.peakConfidence = confidences.max() ?? 0.0

            let sortedConfidences = confidences.sorted()
            if sortedConfidences.count % 2 == 0 {
                let middleIndex = sortedConfidences.count / 2
                snoreEvent.medianConfidence = (sortedConfidences[middleIndex - 1] + sortedConfidences[middleIndex]) / 2.0
            } else {
                snoreEvent.medianConfidence = sortedConfidences[sortedConfidences.count / 2]
            }
        } else {
            snoreEvent.averageConfidence = 0.0
            snoreEvent.minConfidence = 0.0
            snoreEvent.maxConfidence = 0.0
            snoreEvent.medianConfidence = 0.0
            snoreEvent.peakConfidence = 0.0
        }

        var namesHistogram: [String: Int] = [:]
        for event in soundEvents {
            if let name = event.name {
                namesHistogram[name, default: 0] += 1
            }
        }
        snoreEvent.soundEventNamesHistogram = namesHistogram as NSDictionary
        snoreEvent.name = "Snore Episode (Events: \(soundEvents.count))"

        // The responsibility of saving the context will depend on the caller.
        // For the PostProcessor, it saves once at the end. For RealtimeAggregator, it saves per event.
        // We will explicitly call `managedObjectContext.save()` in the conforming classes.
        print("Created SnoreEvent from \(soundEvents.count) SoundEvents. Start: \(snoreEvent.startTime ?? Date()), End: \(snoreEvent.endTime ?? Date()), Duration: \(snoreEvent.duration)s")
    }
}
