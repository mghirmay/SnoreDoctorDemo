//
//  SoundEvent+Extensions.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//

// In SoundEvent+ChartHelpers.swift

import Foundation // Essential for String operations like trimming, lowercased
import CoreData   // Needed because SoundEvent is an NSManagedObject

extension SoundEvent {

    var normalizedChartName: String {
           // Use your SoundEventType enum to convert the raw name
           // The SoundEventType.from(rawValue:) static method already handles:
           // 1. nil 'self.name' (defaults to .otherUnknown)
           // 2. Unrecognized strings (defaults to .otherUnknown)
           // 3. Returns the correct rawValue for known types.
           return SoundEventType.from(rawValue: self.name).rawValue
       }
}
