import Foundation
import SwiftUI
import Charts
import CoreData

// Helper struct for data that's ready to be charted
struct ChartableSleepSession: Identifiable {
    let id = UUID() // Use UUID or session.id if unique and stable
    let session: RecordingSession
    let chartStart: Date
    let chartEnd: Date
    let actualDuration: TimeInterval // The full duration for annotation
}

struct DailySleepReportView: View {
    let selectedDate: Date
    @ObservedObject var soundDataManager: SoundDataManager
    @State private var selectedTime: Date?

    // This range MUST match the predicate logic in SoundDataManager
    private var chartRange: ClosedRange<Date> {
        let sessions = soundDataManager.fetchRecordingSessions(for: selectedDate)
        
        // Fallback: If no sessions, show a default 12-hour window around selectedDate
        guard let firstStart = sessions.compactMap({ $0.startTime }).min(),
              let lastEnd = sessions.compactMap({ $0.endTime }).max() else {
            let start = Calendar.current.startOfDay(for: selectedDate)
            return start...start.addingTimeInterval(3600 * 12)
        }
        
        // Add 30 minutes of "padding" to the start and end so bars aren't touching the edges
        return firstStart.addingTimeInterval(-1800)...lastEnd.addingTimeInterval(1800)
    }

    var body: some View {
        let sessions = soundDataManager.fetchRecordingSessions(for: selectedDate)
        let events = soundDataManager.fetchSoundEvents(for: selectedDate)
        
        Group {
            if sessions.isEmpty && events.isEmpty {
                // Friendly empty state
                VStack {
                    Image(systemName: "zzz")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No data for this night")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    // SESSION CHART
                    Chart {
                        ForEach(sessions) { session in
                            if let start = session.startTime, let end = session.endTime {
                                BarMark(
                                    xStart: .value("Start", start),
                                    xEnd: .value("End", end),
                                    y: .value("Type", "Sleep")
                                )
                                .foregroundStyle(Color.blue.gradient)
                                .cornerRadius(6)
                            }
                        }
                        interactionRuleMark
                    }
                    .frame(height: 100)
                    .chartXScale(domain: chartRange)
                    .chartXSelection(value: $selectedTime)

                    // SOUND EVENTS CHART
                    Chart {
                        ForEach(events) { event in
                            if let time = event.timestamp {
                                BarMark(
                                    x: .value("Time", time),
                                    y: .value("Events", 1)
                                )
                                .foregroundStyle(by: .value("Category", event.name ?? "Snore"))
                            }
                        }
                        interactionRuleMark
                    }
                    .frame(maxHeight: .infinity) // Fills the bottom space
                    .chartXScale(domain: chartRange)
                    .chartXSelection(value: $selectedTime)
                }
            }
        }
        .onAppear {
            print("Chart appearing for \(selectedDate). Sessions found: \(sessions.count)")
        }
    }
    
 
    @ChartContentBuilder
    private var interactionRuleMark: some ChartContent {
        if let selectedTime = selectedTime {
            RuleMark(x: .value("Selected", selectedTime))
                .foregroundStyle(.primary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top) {
                    Text(selectedTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.bold())
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
        }
    }
}
