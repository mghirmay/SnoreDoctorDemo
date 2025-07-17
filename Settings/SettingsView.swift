//
//  SettingsView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingClearDataAlert = false
    @State private var clearDataSuccess = false
    @State private var clearDataErrorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                AnalysisSettingsSection()
                PostProcessingSection()
                AudioRecordingSection()
                DataManagementSection(
                    clearDataAction: clearAllData,
                    success: clearDataSuccess,
                    errorMessage: clearDataErrorMessage
                )
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
            .onAppear(perform: initializeDefaults)
        }
    }

    private func clearAllData() {
        clearDataSuccess = false
        clearDataErrorMessage = nil

        do {
            let soundEventRequest = NSBatchDeleteRequest(fetchRequest: SoundEvent.fetchRequest())
            let sessionRequest = NSBatchDeleteRequest(fetchRequest: RecordingSession.fetchRequest())
            try viewContext.execute(soundEventRequest)
            try viewContext.execute(sessionRequest)
            try viewContext.save()
            viewContext.reset()
            clearAllAudioFiles()
            clearDataSuccess = true
        } catch {
            clearDataErrorMessage = error.localizedDescription
            viewContext.rollback()
        }
    }

    private func clearAllAudioFiles() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for file in fileURLs where ["m4a", "wav"].contains(file.pathExtension) {
                try fileManager.removeItem(at: file)
            }
        } catch {
            clearDataErrorMessage = (clearDataErrorMessage ?? "") + "\nError deleting audio files: \(error.localizedDescription)"
        }
    }

    private func initializeDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "snoreConfidenceThreshold") == nil {
            defaults.snoreConfidenceThreshold = AppSettings.defaultSnoreConfidenceThreshold
        }
        if defaults.string(forKey: "audioFormatPreference") == nil {
            defaults.audioFormatPreference = .aac
        }
        if defaults.double(forKey: "sampleRatePreference") == 0 {
            defaults.sampleRatePreference = 44100.0
        }
        if defaults.string(forKey: "audioQualityPreference") == nil {
            defaults.audioQualityPreference = .high
        }
        if defaults.object(forKey: "analysisWindowDuration") == nil {
            defaults.analysisWindowDuration = AppSettings.defaultAnalysisWindowDuration
        }
        if defaults.object(forKey: "analysisOverlapFactor") == nil {
            defaults.analysisOverlapFactor = AppSettings.defaultAnalysisOverlapFactor
        }
        if defaults.object(forKey: "postProcessGapThreshold") == nil {
            defaults.postProcessGapThreshold = AppSettings.defaultPostProcessGapThreshold
        }
        if defaults.object(forKey: "postProcessSmoothingWindowSize") == nil {
            defaults.postProcessSmoothingWindowSize = AppSettings.defaultPostProcessSmoothingWindowSize
        }
        if defaults.object(forKey: "postProcessShortInterruptionThreshold") == nil {
            defaults.postProcessShortInterruptionThreshold = AppSettings.defaultPostProcessShortInterruptionThreshold
        }
    }
}
