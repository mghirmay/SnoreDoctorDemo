//
//  SettingsView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI
import CoreData

extension Notification.Name {
    static let dataDidClear = Notification.Name("dataDidClear")
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var dataManager: SoundDataManager

    @State private var showingClearDataAlert = false
    @State private var clearDataSuccess = false
    @State private var clearDataErrorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                AnalysisSettingsSection()
                PostProcessingSection()
                AudioRecordingSection()
                PlaybackSettingsSection()
                ExportImportSection()        
                DataManagementSection(
                    clearDataAction: clearAllData,
                    resetSettingsAction: resetSettingsToDefaults,
                    repairDataAction: repairDatabase,
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
        }.navigationViewStyle(.stack)
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
            
            //Post the notification
            NotificationCenter.default.post(name: .dataDidClear, object: nil)
        } catch {
            clearDataErrorMessage = error.localizedDescription
            viewContext.rollback()
        }
    }

    private func clearAllAudioFiles() {
        do {
            // Use your existing helper to get the specific Recordings folder
            let recordingsFolder = try FileManager.getRecordingsFolderURL()
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: recordingsFolder.path) {
                let fileURLs = try fileManager.contentsOfDirectory(at: recordingsFolder, includingPropertiesForKeys: nil)
                
                for file in fileURLs {
                    // Now we target the actual extensions you've been using
                    if ["caf", "m4a", "wav"].contains(file.pathExtension.lowercased()) {
                        try fileManager.removeItem(at: file)
                    }
                }
                print("Successfully cleared all recordings from subfolder.")
            }
        } catch {
            clearDataErrorMessage = (clearDataErrorMessage ?? "") + "\nError deleting audio files: \(error.localizedDescription)"
        }
    }
    
    
    private func repairDatabase() {
        clearDataSuccess = false
        clearDataErrorMessage = nil
        
        do {
            // 1. RECONCILE INCOMPLETE SESSIONS (Logic you provided)
            // Fixes "Zombie" sessions that didn't save an end time
            // Use the existing logic from your manager!
            dataManager.reconcileIncompleteSessions(in: viewContext)
            
            // 2. REMOVE ORPHANED SESSIONS
            // Fixes entries where the audio file is actually missing from disk
            let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
            let sessions = try viewContext.fetch(fetchRequest)
            let folder = try FileManager.getRecordingsFolderURL()
            var repairCount = 0
            
            for session in sessions {
                if let fileName = session.audioFileName {
                    let fileURL = folder.appendingPathComponent(fileName)
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        viewContext.delete(session)
                        repairCount += 1
                    }
                } else if session.startTime == nil {
                    // If the session doesn't even have a start time, it's garbage
                    viewContext.delete(session)
                    repairCount += 1
                }
            }
            
            if viewContext.hasChanges {
                try viewContext.save()
            }
            
            clearDataSuccess = true
            print("Database Repair & Reconciliation complete.")
            
        } catch {
            clearDataErrorMessage = "Repair failed: \(error.localizedDescription)"
            viewContext.rollback()
        }
    }
    
    private func resetSettingsToDefaults() {
        clearDataSuccess = false
        clearDataErrorMessage = nil
        
        let standard = UserDefaults.standard
        
        // Analysis
        standard.useCustomLLModel = AppSettings.defaultUseCustomLLModel
        standard.snoreConfidenceThreshold = AppSettings.defaultSnoreConfidenceThreshold
        standard.analysisWindowDuration = AppSettings.defaultAnalysisWindowDuration
        standard.analysisOverlapFactor = AppSettings.defaultAnalysisOverlapFactor
        
        // Post-Processing
        standard.postProcessGapThreshold = AppSettings.defaultPostProcessGapThreshold
        standard.postProcessSmoothingWindowSize = AppSettings.defaultPostProcessSmoothingWindowSize
        standard.postProcessShortInterruptionThreshold = AppSettings.defaultPostProcessShortInterruptionThreshold
        
        // Playback
        standard.initialVolume = AppSettings.defaultInitialVolume
        standard.volumeStep = AppSettings.defaultVolumeStep
        standard.silenceTimeout = AppSettings.defaultSilenceTimeout
        
        clearDataSuccess = true
        print("Settings reset to defaults.")
    }

}
