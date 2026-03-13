//
//  AppFormatters.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import Foundation

struct AppFormatters {
    // Reusable DateFormatter for display
    static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy, h:mm a"
        return formatter
    }()
    
    // Reusable DateComponentsFormatter for duration (e.g., "1h 30m")
    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}