//
//  SettingsView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//

// SettingsView.swift
import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingClearDataAlert = false
    @State private var clearDataSuccess = false
    @State private var clearDataErrorMessage: String?

    // NEW: @AppStorage for the confidence threshold
    // This links directly to UserDefaults.
    @AppStorage("snoreConfidenceThreshold") var confidenceThreshold: Double = AppSettings.defaultSnoreConfidenceThreshold

    var body: some View {
        NavigationView {
            Form {
                Section("Analysis Settings") { // New section for settings
                    VStack(alignment: .leading) {
                        Text("Detection Confidence Threshold")
                            .font(.headline)
                        Text(String(format: "Requires > %.1f%% Confidence", confidenceThreshold * 100))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Slider(value: $confidenceThreshold, in: 0.0...1.0, step: 0.05) { // Slider from 0.0 to 1.0
                            Text("Threshold")
                        } minimumValueLabel: {
                            Text("0%")
                        } maximumValueLabel: {
                            Text("100%")
                        }
                    }
                    .padding(.vertical, 5) // Add some padding around the slider
                }

                Section("Data Management") {
                    Button("Clear All Recorded Data") {
                        showingClearDataAlert = true
                    }
                    .foregroundColor(.red)
                }

                if clearDataSuccess {
                    Text("All data cleared successfully!")
                        .foregroundColor(.green)
                } else if let errorMessage = clearDataErrorMessage {
                    Text("Error clearing data: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone. All recorded sound events and session data will be permanently deleted.")
            }
            .onAppear {
                // Ensure the @AppStorage variable is initialized from UserDefaults on appear
                // This is generally handled automatically by @AppStorage, but a small check never hurts.
                if UserDefaults.standard.object(forKey: "snoreConfidenceThreshold") == nil {
                    UserDefaults.standard.set(AppSettings.defaultSnoreConfidenceThreshold, forKey: "snoreConfidenceThreshold")
                }
            }
        }
    }

    private func clearAllData() {
        // ... (your existing clearAllData and clearAllAudioFiles functions) ...
        clearDataSuccess = false // Reset status
        clearDataErrorMessage = nil

        let fetchRequestSoundEvents: NSFetchRequest<NSFetchRequestResult> = SoundEvent.fetchRequest()
        let batchDeleteRequestSoundEvents = NSBatchDeleteRequest(fetchRequest: fetchRequestSoundEvents)

        // Assuming you have RecordingSession entity
        let fetchRequestRecordingSessions: NSFetchRequest<NSFetchRequestResult> = RecordingSession.fetchRequest()
        let batchDeleteRequestRecordingSessions = NSBatchDeleteRequest(fetchRequest: fetchRequestRecordingSessions)

        do {
            try viewContext.execute(batchDeleteRequestSoundEvents)
            try viewContext.execute(batchDeleteRequestRecordingSessions)

            try viewContext.save()
            viewContext.reset() // Reset context to clear in-memory objects

            clearDataSuccess = true
            print("Successfully cleared all data from Core Data.")

            clearAllAudioFiles()

        } catch {
            print("Error clearing Core Data: \(error.localizedDescription)")
            clearDataErrorMessage = error.localizedDescription
            viewContext.rollback()
        }
    }

    private func clearAllAudioFiles() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "m4a" {
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
