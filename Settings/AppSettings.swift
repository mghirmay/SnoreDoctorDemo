//
//  AppSettings.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// Extensions/Constants.swift (or similar file)
// You might already have a file for constants, if not, create one.

import Foundation

extension UserDefaults {
    @objc dynamic var snoreConfidenceThreshold: Double {
        get { return double(forKey: "snoreConfidenceThreshold") }
        set { set(newValue, forKey: "snoreConfidenceThreshold") }
    }
}

// Define a constant for the default value
struct AppSettings {
    static let defaultSnoreConfidenceThreshold: Double = 0.6
}
