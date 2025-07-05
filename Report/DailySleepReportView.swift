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
    @ObservedObject var sleepDataManager: SleepDataManager

    @State private var dailySessions: [RecordingSession] = []
    @State private var dailySoundEvents: [SoundEvent] = []

    // MARK: - Computed property to prepare sleep session data for the chart
    private var chartableSleepSessions: [ChartableSleepSession] {
        let calendar = Calendar.current
        let displayStartOfDay = calendar.startOfDay(for: selectedDate)
        // This guard is outside the ChartContentBuilder, so it's fine here
        guard let displayEndOfDay = calendar.date(byAdding: .day, value: 1, to: displayStartOfDay) else {
            return [] // Return an empty array if date calculation fails
        }

        return dailySessions.compactMap { session in
            guard let sessionStartTime = session.startTime,
                  let sessionEndTime = session.endTime else {
                return nil // Skip sessions with missing times
            }

            let chartSegmentStart = max(sessionStartTime, displayStartOfDay)
            let chartSegmentEnd = min(sessionEndTime, displayEndOfDay)

            // Only include if there's a valid segment within the display day
            if chartSegmentEnd > chartSegmentStart {
                return ChartableSleepSession(
                    session: session,
                    chartStart: chartSegmentStart,
                    chartEnd: chartSegmentEnd,
                    actualDuration: sessionEndTime.timeIntervalSince(sessionStartTime)
                )
            }
            return nil // Exclude sessions that don't overlap with the display day
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sleep Sessions for \(selectedDate, formatter: dateFormatter)")
                .font(.headline)
                .padding(.bottom, 5)

            // MARK: - Sleep Sessions Chart
            // Now, we use chartableSleepSessions, which is already filtered and prepared
            if chartableSleepSessions.isEmpty {
                Text("No sleep sessions recorded for this day.")
                    .foregroundColor(.gray)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(chartableSleepSessions) { chartSession in // Chart now uses the prepared data
                    RectangleMark(
                        xStart: .value("Start Time", chartSession.chartStart),
                        xEnd: .value("End Time", chartSession.chartEnd),
                        y: .value("Session", "\(chartSession.session.startTime?.formatted(date: .omitted, time: .shortened) ?? "") - \(chartSession.session.endTime?.formatted(date: .omitted, time: .shortened) ?? "")")
                    )
                    .foregroundStyle(by: .value("Title", chartSession.session.title ?? "Unknown Session"))
                    .annotation(position: .overlay) {
                        if chartSession.actualDuration > 0 { // Check duration from the prepared struct
                            Text(formatDuration(chartSession.actualDuration))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
                .padding(.vertical)

                Text("Total Sleep for this sleep day: \(formatDuration(sleepDataManager.calculateDailySleepDuration(for: selectedDate)))")
                    .font(.subheadline)
                    .padding(.top, 5)
            }

            Divider()
                .padding(.vertical, 5)

            // MARK: - Sound Events Histogram Chart
            Text("Sound Events Overview")
                .font(.headline)
                .padding(.bottom, 5)

            // Similar logic for Sound Events: filter and prepare outside the Chart if needed
            if dailySoundEvents.isEmpty {
                Text("No sound events recorded for this day.")
                    .foregroundColor(.gray)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(dailySoundEvents) { event in
                    // For sound events, ensure timestamp is not nil.
                    // If it could be nil often, you'd apply a similar compactMap.
                    // For now, assuming timestamp is mostly present, or we can filter here:
                    if let timestamp = event.timestamp {
                        BarMark(
                            x: .value("Time", timestamp),
                            y: .value("Count", 1)
                        )
                        .foregroundStyle(by: .value("Event Type", event.name ?? "Unknown"))
                        .position(by: .value("Event Type", event.name ?? "Unknown"))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartXScale(domain: selectedDate.startOfDay...Calendar.current.date(byAdding: .day, value: 1, to: selectedDate.startOfDay)!)
                .frame(height: 150)
                .padding(.vertical)
            }
        }
        .onChange(of: selectedDate) {
            fetchDailySessions()
            fetchDailySoundEvents()
        }
        .onAppear {
            fetchDailySessions()
            fetchDailySoundEvents()
        }
    }

    private func fetchDailySessions() {
        dailySessions = sleepDataManager.fetchRecordingSessions(for: selectedDate)
    }

    private func fetchDailySoundEvents() {
        dailySoundEvents = sleepDataManager.fetchSoundEvents(for: selectedDate)
    }

    private func calculateTotalSleepDurationForDisplay() -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0
        }

        var totalDuration: TimeInterval = 0

        for session in dailySessions {
            guard let sessionStart = session.startTime,
                  let sessionEnd = session.endTime else {
                continue
            }

            let segmentStart = max(sessionStart, startOfDay)
            let segmentEnd = min(sessionEnd, endOfDay)

            if segmentEnd > segmentStart {
                totalDuration += segmentEnd.timeIntervalSince(segmentStart)
            }
        }
        return totalDuration
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dhr %02dmin", hours, minutes)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
}
