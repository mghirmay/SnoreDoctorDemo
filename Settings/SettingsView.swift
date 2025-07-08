//
//  SettingsView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
// SettingsView.swift
import SwiftUI
import CoreData
import AVFoundation
import SoundAnalysis   // Import SoundAnalysis for CMTime if needed for constants, though not strictly required here.

// Your existing AppSettings struct
struct AppSettings {
    static let defaultSnoreConfidenceThreshold: Double = 0.6
    static let defaultAnalysisWindowDuration: Double = 1.0
    static let defaultAnalysisOverlapFactor: Double = 0.5
}


struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingClearDataAlert = false
    @State private var clearDataSuccess = false
    @State private var clearDataErrorMessage: String?

    // Existing: @AppStorage for the confidence threshold
    @AppStorage("snoreConfidenceThreshold") var confidenceThreshold: Double = AppSettings.defaultSnoreConfidenceThreshold

    // --- NEW: @AppStorage for Sound Analysis Settings ---
    @AppStorage("analysisWindowDuration") var analysisWindowDuration: Double = AppSettings.defaultAnalysisWindowDuration
    @AppStorage("analysisOverlapFactor") var analysisOverlapFactor: Double = AppSettings.defaultAnalysisOverlapFactor
    // ----------------------------------------------------

    // Existing: @AppStorage for Audio Recording Settings
    @AppStorage("audioFormatPreference") var selectedAudioFormat: UserDefaults.AudioFormat = .aac
    @AppStorage("sampleRatePreference") var selectedSampleRate: Double = 44100.0
    @AppStorage("audioQualityPreference") var selectedAudioQuality: UserDefaults.AudioRecordingQuality = .high


    var body: some View {
        NavigationView {
            Form {
                Section("Analysis Settings".translate()) {
                    VStack(alignment: .leading) {
                        Text("Detection Confidence Threshold".translate())
                            .font(.headline)
                        Text("Requires Confidence".transtateWithValue(value: String(Int(confidenceThreshold * 100 ))))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05) {
                            Text("Threshold".translate())
                        } minimumValueLabel: {
                            Text("10%")
                        } maximumValueLabel: {
                            Text("90%")
                        }
                    }
                    .padding(.vertical, 5)
                    .tint(Color("AppColor"))

                    // --- NEW UI for Window Duration ---
                    VStack(alignment: .leading) {
                        Text("Analysis Window Duration".translate())
                            .font(.headline)
                        Text("Duration_Info".transtateWithValue(value: String(format: "%.1f", analysisWindowDuration))) // e.g., "Window duration: 1.0 sec"
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Slider(value: $analysisWindowDuration, in: 0.1...5.0, step: 0.1) { // Example range: 0.1 to 5.0 seconds
                            Text("Window Duration".translate())
                        } minimumValueLabel: {
                            Text("0.1s")
                        } maximumValueLabel: {
                            Text("5.0s")
                        }
                    }
                    .padding(.vertical, 5)
                    .tint(Color("AppColor"))

                    // --- NEW UI for Overlap Factor ---
                    VStack(alignment: .leading) {
                        Text("Analysis Overlap Factor".translate())
                            .font(.headline)
                        Text("Overlap_Info".transtateWithValue(value: String(format: "%.1f", analysisOverlapFactor))) // e.g., "Overlap: 0.5 (50%)"
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Slider(value: $analysisOverlapFactor, in: 0.0...0.9, step: 0.1) { // Range for overlap factor (0.0 to <1.0)
                            Text("Overlap Factor".translate())
                        } minimumValueLabel: {
                            Text("0%")
                        } maximumValueLabel: {
                            Text("90%")
                        }
                    }
                    .padding(.vertical, 5)
                    .tint(Color("AppColor"))
                }

                // --- Existing Section: Audio Recording Quality ---
                Section("Audio Recording Quality".translate()) {
                    Picker("Format".translate(), selection: $selectedAudioFormat) {
                        ForEach(UserDefaults.AudioFormat.allCases) { format in
                            Text(format.rawValue.translate()).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color("AppColor"))

                    VStack(alignment: .leading) {
                        Text("Sample Rate".translate() + ": \(Int(selectedSampleRate / 1000)) kHz")
                        Slider(value: $selectedSampleRate, in: 16000.0...48000.0, step: 8000.0) {
                            Text("Sample Rate".translate())
                        } minimumValueLabel: {
                            Text("16 kHz")
                        } maximumValueLabel: {
                            Text("48 kHz")
                        }
                        .tint(Color("AppColor"))
                    }

                    Picker("Quality".translate(), selection: $selectedAudioQuality) {
                        ForEach(UserDefaults.AudioRecordingQuality.allCases) { quality in
                            Text(quality.rawValue.translate()).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color("AppColor"))
                    Text("Info_Quality".translate())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                // ---------------------------------------------

                Section("Data Management".translate()) {
                    Button("Clear All Recorded Data".translate()) {
                        showingClearDataAlert = true
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
                }

                if clearDataSuccess {
                    Text("All data cleared successfully!".translate())
                        .foregroundColor(.green)
                } else if let errorMessage = clearDataErrorMessage {
                    Text("Error clearing data".translate() + " :\(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings".translate())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done".translate()) {
                        dismiss()
                    }
                    .tint(Color("AppColor"))
                }
            }
            .alert("Clear All Data?".translate(), isPresented: $showingClearDataAlert) {
                Button("Clear".translate(), role: .destructive) {
                    clearAllData()
                }
                Button("Cancel".translate(), role: .cancel) { }
            } message: {
                Text("Clear_Info".translate())
            }
            .onAppear {
                // Ensure @AppStorage variables are initialized with default values if not already set.
                // @AppStorage handles this mostly automatically, but this ensures a fallback.
                if UserDefaults.standard.object(forKey: "snoreConfidenceThreshold") == nil {
                    UserDefaults.standard.set(AppSettings.defaultSnoreConfidenceThreshold, forKey: "snoreConfidenceThreshold")
                }
                // Initialize audio settings if they are not set (first launch)
                if UserDefaults.standard.string(forKey: "audioFormatPreference") == nil {
                    UserDefaults.standard.audioFormatPreference = .aac // Default
                }
                if UserDefaults.standard.double(forKey: "sampleRatePreference") == 0 { // Default for double is 0 if not set
                    UserDefaults.standard.sampleRatePreference = 44100.0 // Default
                }
                if UserDefaults.standard.string(forKey: "audioQualityPreference") == nil {
                    UserDefaults.standard.audioQualityPreference = .high // Default
                }

                // --- NEW: Initialize analysis settings if not set ---
                if UserDefaults.standard.object(forKey: "analysisWindowDuration") == nil {
                    UserDefaults.standard.analysisWindowDuration = AppSettings.defaultAnalysisWindowDuration
                }
                if UserDefaults.standard.object(forKey: "analysisOverlapFactor") == nil {
                    UserDefaults.standard.analysisOverlapFactor = AppSettings.defaultAnalysisOverlapFactor
                }
                // ----------------------------------------------------
            }
        }
    }

    private func clearAllData() {
        clearDataSuccess = false
        clearDataErrorMessage = nil

        // Clear Core Data
        let fetchRequestSoundEvents: NSFetchRequest<NSFetchRequestResult> = SoundEvent.fetchRequest()
        let batchDeleteRequestSoundEvents = NSBatchDeleteRequest(fetchRequest: fetchRequestSoundEvents)

        let fetchRequestRecordingSessions: NSFetchRequest<NSFetchRequestResult> = RecordingSession.fetchRequest()
        let batchDeleteRequestRecordingSessions = NSBatchDeleteRequest(fetchRequest: fetchRequestRecordingSessions)

        do {
            try viewContext.execute(batchDeleteRequestSoundEvents)
            try viewContext.execute(batchDeleteRequestRecordingSessions)

            try viewContext.save()
            viewContext.reset() // Reset context to clear in-memory objects and ensure UI refresh

            clearDataSuccess = true
            print("Successfully cleared all data from Core Data.")

            // Clear associated audio files
            clearAllAudioFiles()

        } catch {
            print("Error clearing Core Data: \(error.localizedDescription)")
            clearDataErrorMessage = error.localizedDescription
            viewContext.rollback() // Rollback changes on error
        }
    }

    private func clearAllAudioFiles() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "m4a" || fileURL.pathExtension == "wav" {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted audio file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error deleting audio files: \(error.localizedDescription)")
            clearDataErrorMessage = (clearDataErrorMessage ?? "") + "\nError deleting audio files: \(error.localizedDescription)"
        }
    }
}

