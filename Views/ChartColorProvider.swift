//
//  ChartColorProvider.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//
// ChartColorProvider.swift
import SwiftUI

/// Provides consistent colors for different sound event types.
func chartMarkerColor(for eventName: String?) -> Color {
    let eventType = SoundEventType.from(rawValue: eventName) // Convert string to enum

    switch eventType {
    case .snoring: return .red
    case .snoringSpeechLike: return .orange
    case .snoringNoise: return .brown
    case .snoringNoiseBreathing: return .purple
    case .quiet: return .green
    case .silence: return .teal
    case .speech: return .blue
    case .talking: return .indigo
    case .cough: return .cyan
    case .noise: return .yellow
    case .otherUnknown: return .pink
    }
}
