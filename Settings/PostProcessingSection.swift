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
        Section(header: Text("Snore Event Post-Processing".translate())) {
            
            // Gap Threshold
            VStack {
                HStack {
                    Text("Gap Threshold".translate())
                    Spacer()
                    Text("\(String(format: "%.1f", gap)) s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $gap, in: 1.0...30.0, step: 0.5)
            }
            
            // Smoothing Window
            VStack {
                HStack {
                    Text("Smoothing Window Size".translate())
                    Spacer()
                    Text("\(windowSize) events")
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(windowSize) },
                    set: { windowSize = Int($0) }
                ), in: 1...10, step: 1)
            }
            
            // Short Interruption Threshold
            VStack {
                HStack {
                    Text("Short Interruption Threshold".translate())
                    Spacer()
                    Text("\(String(format: "%.1f", shortGap)) s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $shortGap, in: 0.1...3.0, step: 0.1)
            }
        }
    }
}
