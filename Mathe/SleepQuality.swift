//
//  Mathematics.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import SwiftUI
import Foundation

public struct SleepQuality {
    
    ///You might want to add a private init() {} to prevent anyone accidentally
    ///writing SleepQuality() — since it's a pure utility type with no instance state,
    ///blocking instantiation makes the intent clear
    private init() {}

    /// Calculates the sleep quality score (0–100) based on detected audio events.
    static func calculateQualityScore(
        snoreCount: Int,
        relatedCount: Int,
        nonSnoreCount: Int,
        durationInHours: Double
    ) -> Double {
        guard durationInHours > 0 else { return 0.0 }

        // Weight events by severity — snores are worst, related less so, other least
        let weightedEvents = Double(snoreCount)    * 1.0
                           + Double(relatedCount)  * 0.5
                           + Double(nonSnoreCount) * 0.2

        // Normalise to events per hour
        let eventsPerHour = weightedEvents / durationInHours

        // Map to 0–100: a rate of 0 = 100, a rate of 30+ = 0
        // Adjust the 30.0 threshold to taste based on your real data
        return max(0.0, 100.0 - (eventsPerHour / 30.0) * 100.0)
    }


    /// Maps a quality score (0–100) to a semantic colour — mirrors DailySleepReportView.
    static func qualityColor(for score: Double) -> Color {
          switch score {
          case 80...:   return Color(red: 0.06, green: 0.43, blue: 0.34) // teal  — good
          case 60..<80: return Color(red: 0.52, green: 0.31, blue: 0.04) // amber — moderate
          default:      return Color(red: 0.60, green: 0.24, blue: 0.11) // coral — poor
          }
      }
    
    static func confidenceColor(for  confidence: Double) -> Color {
        switch confidence {
        case ..<0.4:    return .green
        case 0.4..<0.7: return .orange
        default:        return .red
        }
    }
    

    static func confidenceColorOpacity(for confidence: Double) -> Color {
        switch confidence {
        case ..<0.4:    return .green.opacity(0.7)
        case 0.4..<0.7: return .orange.opacity(0.85)
        default:        return .red.opacity(0.9)
        }
    }
    
    
    static func ratioColor(for  ratio: Double) -> Color {
        switch ratio {
        case ..<0.33:     return .green
        case 0.33..<0.66: return .orange
        default:          return .red
        }
    }
    
    static func ratioColorOpacity(for  ratio: Double) -> Color {
        switch ratio {
        case ..<0.33: return .green.opacity(0.4 + ratio * 0.9)
        case 0.33..<0.66: return .orange.opacity(0.5 + ratio * 0.6)
        default: return .red.opacity(0.5 + ratio * 0.5)
        }
    }
}
