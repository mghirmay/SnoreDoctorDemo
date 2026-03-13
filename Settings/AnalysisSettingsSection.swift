//
//  AnalysisSettingsSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI
import CoreData


struct AnalysisSettingsSection: View {
    @AppStorage("useCustomLLModel") var useCustomLLModel: Bool = AppSettings.defaultUseCustomLLModel
    @AppStorage("snoreConfidenceThreshold") var confidenceThreshold: Double = AppSettings.defaultSnoreConfidenceThreshold
    @AppStorage("analysisWindowDuration") var analysisWindowDuration: Double = AppSettings.defaultAnalysisWindowDuration
    @AppStorage("analysisOverlapFactor") var analysisOverlapFactor: Double = AppSettings.defaultAnalysisOverlapFactor

    var body: some View {
        Section(header: Text("Analysis Settings".translate())) {
            
            // Toggle for Model Selection
            Toggle("Use Custom LL Model".translate(), isOn: $useCustomLLModel)
                .tint(Color("AppColor"))
            
            // Detection Confidence Threshold
            VStack {
                HStack {
                    Text("Detection Confidence Threshold".translate())
                    Spacer()
                    Text("\(Int(confidenceThreshold * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05)
            }

            // Analysis Window Duration
            VStack {
                HStack {
                    Text("Analysis Window Duration".translate())
                    Spacer()
                    Text(String(format: "%.1f s", analysisWindowDuration))
                        .foregroundColor(.secondary)
                }
                Slider(value: $analysisWindowDuration, in: 0.1...5.0, step: 0.1)
            }

            // Analysis Overlap Factor
            VStack {
                HStack {
                    Text("Analysis Overlap Factor".translate())
                    Spacer()
                    Text("\(Int(analysisOverlapFactor * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $analysisOverlapFactor, in: 0.0...0.9, step: 0.1)
            }
        }
    }
}
