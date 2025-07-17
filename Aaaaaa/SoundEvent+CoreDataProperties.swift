//
//  SoundEvent+CoreDataProperties.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 16.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//
//

import Foundation
import CoreData


extension SoundEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SoundEvent> {
        return NSFetchRequest<SoundEvent>(entityName: "SoundEvent")
    }

    @NSManaged public var audioFileName: String?
    @NSManaged public var confidence: Double
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var session: RecordingSession?

}

extension SoundEvent : Identifiable {

}
