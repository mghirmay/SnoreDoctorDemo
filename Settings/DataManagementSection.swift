//
//  DataManagementSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//



import SwiftUI
import CoreData

struct DataManagementSection: View {
    var clearDataAction: () -> Void
    var resetSettingsAction: () -> Void
    var repairDataAction: () -> Void // New logic to fix orphaned files
    
    var success: Bool
    var errorMessage: String?
    
    @State private var storageSize: String = "Calculating..."

    var body: some View {
        Section(header: Text("Data Management".translate())) {
            
            // 1. Storage Info (Read Only)
            HStack {
                Label("Total Recordings Size".translate(), systemImage: "internaldrive")
                Spacer()
                Text(storageSize)
                    .foregroundColor(.secondary)
            }
            .onAppear { calculateStorage() }

            // 2. Reset Settings (Non-Destructive to Data)
            Button {
                resetSettingsAction()
            } label: {
                Label("Reset App Settings".translate(), systemImage: "arrow.counterclockwise")
            }

            // 3. Repair Data (Fixing Logic)
            Button {
                repairDataAction()
                calculateStorage() // Refresh size after repair
            } label: {
                Label("Repair & Sync Database".translate(), systemImage: "wrench.and.screwdriver")
            }
            .help("Deletes database entries missing their audio files.")

            // 4. Clear All (Destructive)
            Button(role: .destructive) {
                clearDataAction()
            } label: {
                Label("Clear All Data".translate(), systemImage: "trash")
            }

            // Feedback Messages
            if success {
                Text("Action completed successfully.".translate())
                    .foregroundColor(.green)
                    .font(.caption)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }

    private func calculateStorage() {
        // Logic to sum up the size of the /Recordings folder
        if let url = try? FileManager.getRecordingsFolderURL() {
            storageSize = FileManager.default.sizeOfFolder(at: url)
        }
    }
}
