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


struct CalenderSleepReport: View {
    @EnvironmentObject var soundDataManager: SoundDataManager
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @Environment(\.dismiss) var dismiss
    

    init() {
        //TODO::
    }

    var body: some View {
        NavigationView {
            // Using a VStack instead of ScrollView as the primary container
            // to allow internal components to expand to the bottom.
            VStack(spacing: 0) {
                
                // --- TOP SECTION (Fixed Height) ---
                HStack(alignment: .top, spacing: 20) {
                    
                    // Top-Left: Calendar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wake-Up Date").font(.caption).bold().foregroundColor(.secondary)
                        CalendarView(
                            selectedDate: $selectedDate,
                            currentMonth: $currentMonth
                        )
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    .frame(width: 380)
                    
                    // Top-Right: Metrics & Sessions
                    VStack(spacing: 16) {
                        let dailyEvents = soundDataManager.fetchSoundEvents(for: selectedDate)
                        let totalSleep = soundDataManager.calculateDailySleepDuration(for: selectedDate)
                        
                        HStack(spacing: 12) {
                            SummaryCard(title: "Total Sleep", value: formatDuration(totalSleep), icon: "moon.fill", color: .blue)
                            SummaryCard(title: "Events", value: "\(dailyEvents.count)", icon: "waveform", color: .orange)
                            SummaryCard(title: "Efficiency", value: calculateEfficiency(events: dailyEvents.count, duration: totalSleep), icon: "gauge.medium", color: .green)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("RECORDINGS").font(.caption2).bold().foregroundColor(.secondary).padding([.leading, .top], 12)
                            SessionSidebarListView(selectedDate: selectedDate)
                                .environmentObject(soundDataManager)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fills height to match calendar
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
                .frame(height: 380) // Set a unified height for the top "Control Deck"
                .padding([.horizontal, .top], 24)
                
                // --- BOTTOM SECTION (The Expansion Area) ---
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sleep Timeline Analysis").font(.headline)
                        Spacer()
                        Label("Live Inspection", systemImage: "hand.tap").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    
                    // This now expands to fill every remaining pixel of the screen
                    DailySleepReportView(selectedDate: selectedDate)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.03), radius: 10)
                .padding(24) // Margin from screen edges
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sleep Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // Helpers
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func calculateEfficiency(events: Int, duration: TimeInterval) -> String {
        guard duration > 0 else { return "0%" }
        let eventsPerHour = Double(events) / (duration / 3600)
        let score = max(0, 100 - (eventsPerHour * 4))
        return "\(Int(score))%"
    }
}
