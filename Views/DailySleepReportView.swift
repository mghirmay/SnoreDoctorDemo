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
    @EnvironmentObject var soundDataManager: SoundDataManager
    let selectedDate: Date
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
                    HStack {
                        Text("title")
                            .font(.headline)
                        HelpPopoverButton(info: HelpDataFactory.DailySleepReportView1)
                    }
                    .padding(.horizontal)
                    Chart {
                        ForEach(sessions) { session in
                            if let start = session.startTime, let end = session.endTime {
                                BarMark(
                                    xStart: .value("Start", start),
                                    xEnd: .value("End", end),
                                    y: .value("Type", "Sleep")
                                )
                                .cornerRadius(6)
                                // Automatically colors bars based on a property
                                .foregroundStyle(by: .value("Quality", session.qualityScore))
                                
                            }
                        }
                        interactionRuleMark
                    }
                    .frame(height: 100)
                    .chartXScale(domain: chartRange)
                    .chartXSelection(value: $selectedTime)

                    Text("Activity Density")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack {
                        Text("title")
                            .font(.headline)
                        HelpPopoverButton(info: HelpDataFactory.DailySleepReportView2)
                    }
                    // SOUND EVENTS CHART (The Density/Heatmap View)
                    Chart {
                        let dailyTrend = aggregateDailyEvents(events: Array(events))
                        
                        ForEach(dailyTrend) { point in
                            RectangleMark(
                                x: .value("Time", point.time),
                                y: .value("Row", "Snore Density"),
                                width: .ratio(1)
                            )
                            .foregroundStyle(by: .value("Load", point.snoreLoad))
                        }
                        
                        interactionRuleMark
                    }
                    .chartForegroundStyleScale(range: Gradient(colors: [.blue.opacity(0.1), .yellow, .orange, .red]))
                    .chartXScale(domain: chartRange)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 80)
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
    
    
    
    private func aggregateDailyEvents(events: [SoundEvent], interval: Int = 15) -> [TrendPoint] {
        let calendar = Calendar.current
        
        // 1. Group the events
        let grouped = Dictionary(grouping: events) { event -> Date in
            let date = event.timestamp ?? Date()
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let minuteBucket = (components.minute! / interval) * interval
            return calendar.date(bySettingHour: components.hour!, minute: minuteBucket, second: 0, of: date)!
        }

        // 2. Map with explicit, step-by-step calculations
        let trendPoints: [TrendPoint] = grouped.map { (time, eventsInBucket) in
            let count = eventsInBucket.count
            
            // Break the reduction out of the initialization
            let totalConfidence = eventsInBucket.reduce(0.0, { sum, event in
                sum + event.confidence
            })
            
            let avg = count > 0 ? totalConfidence / Double(count) : 0.0
            
            return TrendPoint(
                time: time,
                averageConfidence: avg,
                snoreCount: count
            )
        }

        // 3. Final sort
        return trendPoints.sorted { $0.time < $1.time }
    }
}
