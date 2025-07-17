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
    var success: Bool
    var errorMessage: String?

    var body: some View {
        Section("Data Management".translate()) {
            Button(role: .destructive) {
                clearDataAction()
            } label: {
                Label("Clear All Data".translate(), systemImage: "trash")
            }

            if success {
                Text("Data cleared successfully.".translate())
                    .foregroundColor(.green)
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}
