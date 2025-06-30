//
//  SoundEventType.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//


//
// SoundEventType.swift
// SnoreDoctorDemo
//
// Created by YourName on Date.
//

import Foundation // Or import SwiftUI if you want to add color/symbol directly here

enum SoundEventType: String, CaseIterable, Identifiable {
    case snoring = "Snoring"
    case snoringSpeechLike = "Snoring (Speech-like)"
    case snoringNoise = "Snoring (Noise)"
    case snoringNoiseBreathing = "Snoring (Noise/Breathing)"
    case quiet = "Quiet"
    case silence = "Silence"
    case speech = "Speech"
    case talking = "Talking"
    case cough = "Cough"
    case noise = "Noise"
    case otherUnknown = "Other/Unknown"

    // Conformance to Identifiable (useful for ForEach in SwiftUI)
    var id: String { self.rawValue }

    // Optional: A helper to get a SoundEventType from a raw string, with a fallback
    static func from(rawValue: String?) -> SoundEventType {
        guard let rawValue = rawValue,
              let type = SoundEventType(rawValue: rawValue) else {
            return .snoringSpeechLike // Default for nil or unrecognized string
        }
        return type
    }
}
