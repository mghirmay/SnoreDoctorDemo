import Foundation
import SwiftUI
import Charts
import CoreData

struct DailySleepReportView: View {
    @EnvironmentObject var soundDataManager: SoundDataManager
    let selectedDate: Date
    @State private var selectedTime: Date?

    // MARK: - Data

    private var sessions: [RecordingSession] {
        soundDataManager.fetchRecordingSessions(for: selectedDate)
    }

    private var allSnoreEvents: [SnoreEvent] {
        soundDataManager.fetchSnoreEvents(for: selectedDate)
    }

    private var chartRange: ClosedRange<Date> {
        guard
            let firstStart = sessions.compactMap({ $0.startTime }).min(),
            let lastEnd    = sessions.compactMap({ $0.endTime }).max()
        else {
            let start = Calendar.current.startOfDay(for: selectedDate)
            return start...start.addingTimeInterval(3600 * 12)
        }
        return firstStart.addingTimeInterval(-1800)...lastEnd.addingTimeInterval(1800)
    }

    // MARK: - Aggregates

    private var totalSnoreCount: Int {
        allSnoreEvents.reduce(0) { $0 + Int($1.countSnores) }
    }

    private var totalNonSnoreCount: Int {
        sessions.reduce(0) { $0 + Int($1.totalNonSnoreEvents) }
    }

    private var totalSnoreRelatedCount: Int {
        sessions.reduce(0) { $0 + Int($1.totalSnoreRelated) }
    }

    private var avgQuality: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0.0) { $0 + $1.qualityScore } / Double(sessions.count)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        statCards
                        sessionChart
                        densityChart
                    }
                    .padding()
                }
            }
        }
    }


    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Snores",
                value: "\(totalSnoreCount)",
                icon: "waveform.path",
                color: .orange
            )
            StatCard(
                title: "Snore related",
                value: "\(totalSnoreRelatedCount)",
                icon: "waveform.path.ecg",
                color: .yellow
            )
            StatCard(
                title: "Other events",
                value: "\(totalNonSnoreCount)",
                icon: "ear",
                color: .purple
            )
            StatCard(
                title: "Sleep quality",
                value: "\(Int(avgQuality * 100))%",
                icon: "gauge.medium",
                color: SleepQuality.qualityColor(for: avgQuality)
            )
        }
    }

    // MARK: - Session Timeline Chart

    private var sessionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep sessions")
                    .font(.headline)
                HelpPopoverButton(info: HelpDataFactory.DailySleepReportView1)
            }

            Text("Each bar is one recording session. Colour shows sleep quality — green is good, amber is moderate, red is poor. Dots mark snore events detected during the session.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                // Session bars
                ForEach(sessions) { session in
                    if let start = session.startTime, let end = session.endTime {
                        BarMark(
                            xStart: .value("Start", start),
                            xEnd:   .value("End",   end),
                            y:      .value("Row",   "Sessions")
                        )
                        .cornerRadius(6)
                        .foregroundStyle(SleepQuality.qualityColor(for: session.qualityScore))
                    }
                }

                // SnoreEvent dots overlaid on the session bars
                ForEach(allSnoreEvents) { event in
                    if let ts = event.startTime {
                        PointMark(
                            x: .value("Time", ts),
                            y: .value("Row",  "Sessions")
                        )
                        .symbolSize(28)
                        .foregroundStyle(
                            event.countSnores > 0 ? Color.yellow : Color.red.opacity(0.8)
                        )
                    }
                }

                interactionRuleMark
            }
            .frame(height: 80)
            .chartXScale(domain: chartRange)
            .chartXAxis { sessionXAxis }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedTime)

            HStack(spacing: 16) {
                LegendDot(color: Color(red: 0.06, green: 0.43, blue: 0.34), label: "Good (≥80%)")
                LegendDot(color: Color(red: 0.52, green: 0.31, blue: 0.04), label: "Moderate (60–79%)")
                LegendDot(color: Color(red: 0.60, green: 0.24, blue: 0.11), label: "Poor (<60%)")
                LegendDot(color: .yellow,              label: "Snore",  shape: .circle)
                LegendDot(color: .red.opacity(0.8),    label: "Other",  shape: .circle)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Snore Density Chart

    private var densityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Snore density")
                    .font(.headline)
                HelpPopoverButton(info: HelpDataFactory.DailySleepReportView2)
            }

            Text("Snoring intensity bucketed into 15-minute windows across the night. Darker red means more snoring in that period. Blue means quiet. Use this to spot the worst patches of your night at a glance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(aggregatedBuckets) { point in
                    RectangleMark(
                        x: .value("Time",  point.time),
                        y: .value("Row",   "Snore density"),
                        width: .ratio(1)
                    )
                    .foregroundStyle(by: .value("Load", point.snoreLoad))
                }
                interactionRuleMark
            }
            .chartForegroundStyleScale(
                range: Gradient(colors: [.blue.opacity(0.1), .yellow, .orange, .red])
            )
            .chartXScale(domain: chartRange)
            .chartXAxis { sessionXAxis }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 60)
            .chartXSelection(value: $selectedTime)

            HStack(spacing: 0) {
                Text("Quiet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                LinearGradient(
                    colors: [.blue.opacity(0.3), .yellow, .orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 6)
                .cornerRadius(3)
                .padding(.horizontal, 8)
                Text("Loud")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Shared Interaction Rule

    @ChartContentBuilder
    private var interactionRuleMark: some ChartContent {
        if let t = selectedTime {
            RuleMark(x: .value("Selected", t))
                .foregroundStyle(Color.primary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                    Text(t.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
        }
    }

    // MARK: - Shared X Axis

    private var sessionXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour)) { _ in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "zzz")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.3))
            Text("No recordings for this night")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Start a recording session before bed to see your sleep timeline here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

   

    /// Buckets SnoreEvents into 15-minute windows using averageConfidence as intensity.
    private var aggregatedBuckets: [TrendPoint] {
        let calendar = Calendar.current
        let interval = 15

        let grouped = Dictionary(grouping: allSnoreEvents) { event -> Date in
            let date = event.startTime ?? Date()
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let bucket = (comps.minute! / interval) * interval
            return calendar.date(
                bySettingHour: comps.hour!, minute: bucket, second: 0, of: date
            )!
        }

        return grouped.map { time, bucket in
            let count = bucket.count
            let totalConf = bucket.reduce(0.0) { $0 + $1.averageConfidence }
            let avg = count > 0 ? totalConf / Double(count) : 0.0
            return TrendPoint(time: time, averageConfidence: avg, snoreCount: count)
        }
        .sorted { $0.time < $1.time }
    }
}

// MARK: - LegendDot

private struct LegendDot: View {
    enum Shape { case square, circle }
    let color: Color
    let label: String
    var shape: Shape = .square

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if shape == .circle {
                    Circle().frame(width: 8, height: 8)
                } else {
                    RoundedRectangle(cornerRadius: 2).frame(width: 10, height: 10)
                }
            }
            .foregroundColor(color)
            Text(label)
        }
    }
}
