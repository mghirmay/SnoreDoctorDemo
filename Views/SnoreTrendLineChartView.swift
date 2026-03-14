//
//  SnoreTrendLineChartView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts

enum TrendMetric: String, CaseIterable {
    case averageConfidence = "Avg Confidence"
    case count             = "Event Count"
    case duration          = "Duration"

    var yLabel: String {
        switch self {
        case .averageConfidence: return "Avg Confidence"
        case .count:             return "Detections"
        case .duration:          return "Duration (s)"
        }
    }

    var section: String {
        switch self {
        case .averageConfidence : return "Confidence"
        case .count, .duration: return "Activity"
        }
    }

    var isConfidenceBased: Bool {
        switch self {
        case .averageConfidence: return true
        case .count, .duration: return false
        }
    }
}

struct TrendBucket: Identifiable {
    let id = UUID()
    let time: Date
    let averageConfidence: Double
    let count: Int
    let duration: Double

    func value(for metric: TrendMetric) -> Double {
        switch metric {
        case .averageConfidence: return averageConfidence
        case .count:             return Double(count)
        case .duration:          return duration
        }
    }
}

struct SnoreTrendLineChartView: View {
    @ObservedObject var session: RecordingSession
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>
    @State private var selectedMetric: TrendMetric = .averageConfidence
    @State private var selectedBucket: TrendBucket? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        let trendData = aggregateBuckets(events: snoreEvents)
        let maxValue = trendData.map { $0.value(for: selectedMetric) }.max() ?? 1

        VStack(alignment: .leading, spacing: 8) {
          
            HStack {
                Text("Nightly Snore Load")
                    .font(.headline)
                Spacer()
                Menu {
                    Section("Confidence") {
                        metricButton(.averageConfidence, icon: "waveform.path.ecg")
                    }
                    Section("Activity") {
                        metricButton(.count,    icon: "chart.bar")
                        metricButton(.duration, icon: "timer")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMetric.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                HelpPopoverButton(info: HelpDataFactory.definition(for: selectedMetric))
            }
            .padding(.horizontal)
            

            if trendData.isEmpty {
                ChartEmptyState()
            } else {

                // MARK: - Detail Callout
                if let bucket = selectedBucket {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(Self.timeFormatter.string(from: bucket.time))
                                .font(.caption).bold()
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedMetric.yLabel)
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(formattedValue(bucket.value(for: selectedMetric), metric: selectedMetric))
                                .font(.caption).bold()
                                .foregroundStyle(dotColor(bucket: bucket, maxValue: maxValue))
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg Confidence")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", bucket.averageConfidence * 100))
                                .font(.caption).bold()
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Events")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(bucket.count)")
                                .font(.caption).bold()
                        }
                        Spacer()
                        Button { selectedBucket = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: - Chart
                Chart {
                    // Area fill
                    ForEach(trendData) { bucket in
                        AreaMark(
                            x: .value("Time", bucket.time),
                            yStart: .value("Zero", 0),
                            yEnd:   .value(selectedMetric.yLabel, bucket.value(for: selectedMetric))
                        )
                        .interpolationMethod(.cardinal)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.25), .blue.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Line
                    ForEach(trendData) { bucket in
                        LineMark(
                            x: .value("Time", bucket.time),
                            y: .value(selectedMetric.yLabel, bucket.value(for: selectedMetric))
                        )
                        .interpolationMethod(.cardinal)
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Dots
                    ForEach(trendData) { bucket in
                        PointMark(
                            x: .value("Time", bucket.time),
                            y: .value(selectedMetric.yLabel, bucket.value(for: selectedMetric))
                        )
                        .symbolSize(bucket.id == selectedBucket?.id ? 120 : 40)
                        .foregroundStyle(dotColor(bucket: bucket, maxValue: maxValue))
                    }

                    // Reference line — only for confidence-based metrics
                    if selectedMetric.isConfidenceBased {
                        RuleMark(y: .value("Threshold", 0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(.red.opacity(0.4))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("70%")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                    }
                }
                .chartYScale(domain: 0...(selectedMetric.isConfidenceBased ? 1.0 : maxValue * 1.2))
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(); AxisTick()
                        AxisValueLabel {
                            if let d = value.as(Date.self) {
                                Text(Self.timeFormatter.string(from: d))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(); AxisTick()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(selectedMetric.isConfidenceBased
                                     ? String(format: "%.0f%%", v * 100)
                                     : String(format: "%.0f", v))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let date: Date = proxy.value(atX: location.x - geo.frame(in: .local).minX) else { return }
                                let closest = trendData.min(by: {
                                    abs($0.time.timeIntervalSince(date)) <
                                    abs($1.time.timeIntervalSince(date))
                                })
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedBucket = (selectedBucket?.id == closest?.id) ? nil : closest
                                }
                            }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .frame(minHeight: 300)
        .layoutPriority(1)
        .animation(.easeInOut(duration: 0.2), value: selectedBucket?.id)
        .animation(.easeInOut(duration: 0.3), value: selectedMetric)
    }

    @ViewBuilder
    private func metricButton(_ metric: TrendMetric, icon: String) -> some View {
        Button {
            withAnimation { selectedMetric = metric }
            selectedBucket = nil
        } label: {
            Label(metric.rawValue, systemImage: selectedMetric == metric ? "checkmark" : icon)
        }
    }
    
    
    // MARK: - Dot color
    // Confidence metrics: green/orange/red by threshold
    // Activity metrics: scale linearly against session max
    private func dotColor(bucket: TrendBucket, maxValue: Double) -> Color {
        switch selectedMetric {
        case .averageConfidence:
            let v = bucket.value(for: selectedMetric)
            return SleepQuality.confidenceColor(for: v)
            
        case .count, .duration:
            let ratio = maxValue > 0 ? bucket.value(for: selectedMetric) / maxValue : 0
            return SleepQuality.ratioColor(for: ratio)

        }
    }

    // MARK: - Value formatting
    private func formattedValue(_ value: Double, metric: TrendMetric) -> String {
        switch metric {
        case .averageConfidence:
            return String(format: "%.0f%%", value * 100)
        case .count:
            return String(format: "%.0f", value)
        case .duration:
            return String(format: "%.1fs", value)
        }
    }

    // MARK: - Aggregation
    private func aggregateBuckets(events: FetchedResults<SnoreEvent>,
                                  intervalMinutes: Int = 10) -> [TrendBucket] {
        guard let first = events.first?.startTime else { return [] }
        let interval = TimeInterval(intervalMinutes * 60)

        let grouped = Dictionary(grouping: events) { event -> Date in
            guard let t = event.startTime else { return first }
            let bucket = floor(t.timeIntervalSince(first) / interval) * interval
            return first.addingTimeInterval(bucket)
        }

        return grouped.map { bucketTime, eventsInBucket in
            let confidences = eventsInBucket.map { $0.averageConfidence }.sorted()
            let avg    = confidences.reduce(0, +) / Double(confidences.count)
            let total  = eventsInBucket.reduce(0) { $0 + Int($1.count) }
            let dur    = eventsInBucket.reduce(0.0) { $0 + $1.duration }

            return TrendBucket(
                time:              bucketTime,
                averageConfidence: avg,
                count:             total,
                duration:          dur
            )
        }.sorted { $0.time < $1.time }
    }
}
