//
// SleepReportView.swift
// SnoreDoctorDemo
//
// Created by musie Ghirmay on 30.06.25.
//
import Foundation
import SwiftUI
import Charts
import CoreData

struct CalenderSleepReport: View {
    @EnvironmentObject var soundDataManager: SoundDataManager
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @Environment(\.dismiss) var dismiss

    init() {
        //TODO::
    }

    // MARK: - Derived data for the selected date

    private var dailyEvents: [SoundEvent] {
        let sessions = soundDataManager.fetchRecordingSessions(for: selectedDate)
        return sessions.flatMap { soundDataManager.fetchSoundEvents(for: $0) }
    }

    private var dailySnoreEvents: [SnoreEvent] {
        soundDataManager.fetchSnoreEvents(for: selectedDate)
    }

    private var totalSleep: TimeInterval {
        soundDataManager.calculateDailySleepDuration(for: selectedDate)
    }

    /// Average quality score across all sessions for the selected date (0–100).
    private var avgQuality: Double {
        let sessions = soundDataManager.fetchRecordingSessions(for: selectedDate)
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0.0) { $0 + $1.qualityScore } / Double(sessions.count)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // --- TOP SECTION (Fixed Height) ---
                HStack(alignment: .top, spacing: 20) {

                    // Top-Left: Calendar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wake-Up Date")
                            .font(.caption).bold().foregroundColor(.secondary)
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
                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "Total Sleep",
                                value: formatDuration(totalSleep),
                                icon: "moon.fill",
                                color: .blue
                            )
                            SummaryCard(
                                title: "Events",
                                value: "\(dailyEvents.count)",
                                icon: "waveform",
                                color: .orange
                            )
                            SummaryCard(
                                title: "Sleep Quality",
                                value: "\(Int(avgQuality * 100))%",
                                icon: "gauge.medium",
                                color: SleepQuality.qualityColor(for: avgQuality)
                            )
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("RECORDINGS")
                                .font(.caption2).bold().foregroundColor(.secondary)
                                .padding([.leading, .top], 12)
                            SessionSidebarListView(selectedDate: selectedDate)
                                .environmentObject(soundDataManager)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
                .frame(height: 380)
                .padding([.horizontal, .top], 24)

                // --- BOTTOM SECTION ---
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sleep Timeline Analysis").font(.headline)
                        Spacer()
                        Label("Live Inspection", systemImage: "hand.tap")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)

                    DailySleepReportView(selectedDate: selectedDate)
                        .environmentObject(soundDataManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.03), radius: 10)
                .padding(24)
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

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

  
}
