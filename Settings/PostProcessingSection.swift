//
//  PostProcessingSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//
// PostProcessingSection.swift
import SwiftUI
import CoreData

struct PostProcessingSection: View {
    @AppStorage("postProcessGapThreshold") var gap: Double = AppSettings.defaultPostProcessGapThreshold
    @AppStorage("postProcessSmoothingWindowSize") var windowSize: Int = AppSettings.defaultPostProcessSmoothingWindowSize
    @AppStorage("postProcessShortInterruptionThreshold") var shortGap: Double = AppSettings.defaultPostProcessShortInterruptionThreshold

    var body: some View {
        Section("Snore Event Post-Processing".translate()) {
            SettingSliderDouble(
                title: "Gap Threshold".translate(),
                value: $gap,
                range: 1.0...10.0,
                step: 0.5,
                minLabel: "1s",
                maxLabel: "10s",
                valueFormatter: { value in // Pass the formatter closure here
                    "\(String(format: "%.1f", value)) s"
                }
            )

            SettingSliderInt(
                title: "Smoothing Window Size".translate(),
                value: $windowSize,
                range: 1...7,
                step: 1,
                minLabel: "1",
                maxLabel: "7",
                valueFormatter: { value in // Pass the formatter closure here
                    "\(value) events"
                }
            )

            SettingSliderDouble(
                title: "Short Interruption Threshold".translate(),
                value: $shortGap,
                range: 0.1...2.0,
                step: 0.1,
                minLabel: "0.1s",
                maxLabel: "2.0s",
                valueFormatter: { value in String(format: "%.1f s", value) }
            )
        }
    }
}
