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

    @StateObject private var soundDataManager: SoundDataManager

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today

    // Initialize SleepDataManager with the viewContext from PersistenceController
    init() {
        // Use PersistenceController.shared.container.viewContext for the main app
        _soundDataManager = StateObject(wrappedValue: SoundDataManager(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Top Section (Calendar and Info side-by-side)
                HStack(alignment: .top, spacing: 20) {
                    
                    // Calendar on the Top-Left
                    CalendarView(
                        selectedDate: $selectedDate,
                        currentMonth: $currentMonth,
                        soundDataManager: soundDataManager
                    )
                    .frame(maxWidth: 400) // 👈 Limits calendar width on iPad
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // The "Info View" / Report Content next to it
                    DailySleepReportView(
                        selectedDate: selectedDate,
                        soundDataManager: soundDataManager
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding()
                
                // If DailySleepReportView contains your chart, it will fill the remaining space.
                // If you have a separate Chart View, place it here:
                // SnoreDoctorChartView(...)
                
                Spacer()
            }
            .navigationTitle("Sleep Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
    }
}



