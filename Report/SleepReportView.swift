//
// SleepReportView.swift
// SnoreDoctorDemo
//
// Created by musie Ghirmay on 30.06.25.
//
import Foundation
import SwiftUI
import Charts // Requires iOS 16+
import CoreData

struct SleepReportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // Add this line

    @StateObject private var sleepDataManager: SleepDataManager

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today

    // Initialize SleepDataManager with the viewContext from PersistenceController
    init() {
        // Use PersistenceController.shared.container.viewContext for the main app
        _sleepDataManager = StateObject(wrappedValue: SleepDataManager(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Calendar
                CalendarView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    sleepDataManager: sleepDataManager
                )
                .padding()

                Divider()
                    .padding(.vertical, 5)

                // MARK: - Daily Report for Selected Date
                DailySleepReportView(
                    selectedDate: selectedDate,
                    sleepDataManager: sleepDataManager
                )
                .padding()

                Spacer()
            }
            .navigationTitle("Sleep Report")
            .navigationBarTitleDisplayMode(.inline)
            // MARK: - Add Done Button Here
            .toolbar { // Use .toolbar to add items to the navigation bar
                ToolbarItem(placement: .navigationBarLeading) { // Place it on the leading (left) side
                    Button("Done") {
                        dismiss() // Call dismiss to close the view
                    }
                }
            }
            .onAppear {
                // Optional: Load dummy data only if no sessions exist
                // Wrap in #if DEBUG to prevent this in production builds
                #if DEBUG
                let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
                do {
                    let count = try viewContext.count(for: fetchRequest)
                    if count == 0 {
                        print("No existing sessions found, loading dummy data for SleepReportView.")
                        sleepDataManager.loadDummyCoreData()
                    } else {
                        print("Existing sessions found (\(count)), skipping dummy data load in SleepReportView.")
                    }
                } catch {
                    print("Error checking for existing sessions: \(error)")
                }
                #endif
            }
        }
    }
}



