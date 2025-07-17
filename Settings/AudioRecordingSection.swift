//
//  AudioRecordingSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI
import AVFoundation

struct AudioRecordingSection: View {
    @AppStorage("audioFormatPreference") private var audioFormatRaw: String = UserDefaults.AudioFormat.aac.rawValue
    @AppStorage("sampleRatePreference") private var sampleRate: Double = 44100.0
    @AppStorage("audioQualityPreference") private var audioQualityRaw: String = UserDefaults.AudioRecordingQuality.high.rawValue

    var body: some View {
        Section("Audio Recording Settings".translate()) {

            Picker("Format".translate(), selection: Binding<UserDefaults.AudioFormat>(
                get: { UserDefaults.AudioFormat(rawValue: audioFormatRaw) ?? .aac },
                set: { audioFormatRaw = $0.rawValue }
            )) {
                ForEach(UserDefaults.AudioFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }

            Picker("Sample Rate".translate(), selection: $sampleRate) {
                Text("44.1 kHz").tag(44100.0)
                Text("48 kHz").tag(48000.0)
            }

            Picker("Quality".translate(), selection: Binding<UserDefaults.AudioRecordingQuality>(
                get: { UserDefaults.AudioRecordingQuality(rawValue: audioQualityRaw) ?? .high },
                set: { audioQualityRaw = $0.rawValue }
            )) {
                ForEach(UserDefaults.AudioRecordingQuality.allCases) { quality in
                    Text(quality.rawValue.translate()).tag(quality)
                }
            }
        }
    }
}
