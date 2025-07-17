//
//  SnoreEvent+CoreDataProperties.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 16.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//
//

import Foundation
import CoreData


extension SnoreEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SnoreEvent> {
        return NSFetchRequest<SnoreEvent>(entityName: "SnoreEvent")
    }

    @NSManaged public var averageConfidence: Double
    @NSManaged public var count: Int32
    @NSManaged public var countNone: Int32
    @NSManaged public var countSnores: Int32
    @NSManaged public var duration: Double
    @NSManaged public var endTime: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var maxConfidence: Double
    @NSManaged public var medianConfidence: Double
    @NSManaged public var minConfidence: Double
    @NSManaged public var name: String?
    @NSManaged public var peakConfidence: Double
    @NSManaged public var soundEventNamesHistogram: NSObject?
    @NSManaged public var startTime: Date?
    @NSManaged public var session: RecordingSession?

}

extension SnoreEvent : Identifiable {

}
