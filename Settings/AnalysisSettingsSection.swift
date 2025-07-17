//
//  AnalysisSettingsSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI
import CoreData

struct AnalysisSettingsSection: View {
    @AppStorage("snoreConfidenceThreshold") var confidenceThreshold: Double = AppSettings.defaultSnoreConfidenceThreshold
    @AppStorage("analysisWindowDuration") var analysisWindowDuration: Double = AppSettings.defaultAnalysisWindowDuration
    @AppStorage("analysisOverlapFactor") var analysisOverlapFactor: Double = AppSettings.defaultAnalysisOverlapFactor

    var body: some View {
        Section("Analysis Settings".translate()) {
            SettingSliderDouble(
                title: "Detection Confidence Threshold".translate(),
                value: $confidenceThreshold,
                range: 0.1...0.9,
                step: 0.05,
                minLabel: "10%",
                maxLabel: "90%",
                valueFormatter: { value in // Updated to use the valueFormatter closure
                    "\(Int(value * 100))%"
                }
            )

            SettingSliderDouble(
                title: "Analysis Window Duration".translate(),
                value: $analysisWindowDuration,
                range: 0.1...5.0,
                step: 0.1,
                minLabel: "0.1s",
                maxLabel: "5.0s",
                valueFormatter: { value in // Updated to use the valueFormatter closure
                    String(format: "%.1f s", value)
                }
            )

            SettingSliderDouble(
                title: "Analysis Overlap Factor".translate(),
                value: $analysisOverlapFactor,
                range: 0.0...0.9,
                step: 0.1,
                minLabel: "0%",
                maxLabel: "90%",
                valueFormatter: { value in // Updated to use the valueFormatter closure
                    String(format: "%.0f%%", value * 100) // Format as percentage with no decimals
                }
            )
        }
    }
}
