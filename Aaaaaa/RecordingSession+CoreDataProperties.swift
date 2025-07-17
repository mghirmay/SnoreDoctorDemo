//
//  RecordingSession+CoreDataProperties.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 16.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//
//

import Foundation
import CoreData


extension RecordingSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingSession> {
        return NSFetchRequest<RecordingSession>(entityName: "RecordingSession")
    }

    @NSManaged public var audioFileName: String?
    @NSManaged public var endTime: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var title: String?
    @NSManaged public var totalSnoreEvents: Int32
    @NSManaged public var snoreEvents: NSSet?
    @NSManaged public var soundEvents: NSSet?

}

// MARK: Generated accessors for snoreEvents
extension RecordingSession {

    @objc(addSnoreEventsObject:)
    @NSManaged public func addToSnoreEvents(_ value: SnoreEvent)

    @objc(removeSnoreEventsObject:)
    @NSManaged public func removeFromSnoreEvents(_ value: SnoreEvent)

    @objc(addSnoreEvents:)
    @NSManaged public func addToSnoreEvents(_ values: NSSet)

    @objc(removeSnoreEvents:)
    @NSManaged public func removeFromSnoreEvents(_ values: NSSet)

}

// MARK: Generated accessors for soundEvents
extension RecordingSession {

    @objc(addSoundEventsObject:)
    @NSManaged public func addToSoundEvents(_ value: SoundEvent)

    @objc(removeSoundEventsObject:)
    @NSManaged public func removeFromSoundEvents(_ value: SoundEvent)

    @objc(addSoundEvents:)
    @NSManaged public func addToSoundEvents(_ values: NSSet)

    @objc(removeSoundEvents:)
    @NSManaged public func removeFromSoundEvents(_ values: NSSet)

}

extension RecordingSession : Identifiable {

}
