//
//  PlaybackSettingsSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 05.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import SwiftUI

struct PlaybackSettingsSection: View {
    @AppStorage("initialVolume") private var initialVolume: Double = Double(AppSettings.defaultInitialVolume)
    @AppStorage("volumeStep") private var volumeStep: Double = Double(AppSettings.defaultVolumeStep)
    @AppStorage("silenceTimeout") private var silenceTimeout: Double = AppSettings.defaultSilenceTimeout

    var body: some View {
        Section(header: Text("Playback Settings".translate())) {
            // Initial Volume
            VStack {
                HStack {
                    Text("Initial Volume".translate())
                    Spacer()
                    Text("\(Int(initialVolume * 100)) %")
                        .foregroundColor(.secondary)
                }
                Slider(value: $initialVolume, in: 0.1...1.0)
            }
            
            // Volume Step
            VStack {
                HStack {
                    Text("Volume Step".translate())
                    Spacer()
                    Text("\(Int(volumeStep * 100)) %")
                        .foregroundColor(.secondary)
                }
                Slider(value: $volumeStep, in: 0.05...0.5)
            }
            
            // Silence Timeout (Using HSlider instead of Stepper to avoid +/- buttons)
            VStack {
                HStack {
                    Text("Silence Timeout".translate())
                    Spacer()
                    Text("\(Int(silenceTimeout))s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $silenceTimeout, in: 5...60, step: 1)
            }
        }
    }
}
