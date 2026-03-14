//
//  SnoreHeatmapView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import SwiftUI
import CoreData
import Charts

enum HeatmapMetric: String, CaseIterable {
    case snoreCount = "Event Count"
    case confidence  = "Confidence"
}

struct SnoreHeatmapView: View {
    @ObservedObject var session: RecordingSession
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>
    @State private var selectedPoint: TrendPoint? = nil
    @State private var metric: HeatmapMetric = .snoreCount

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
        let heatmapData = aggregateEvents(events: snoreEvents)
        let maxCount = heatmapData.map(\.snoreCount).max() ?? 1

        VStack(alignment: .leading, spacing: 8) {
            ChartHeader(title: "Snore Density", helpInfo: HelpDataFactory.snoreHeatmapView)
                .padding(.horizontal)

            if heatmapData.isEmpty {
                ChartEmptyState()
            } else {

                // MARK: - Metric Toggle
                Picker("Metric", selection: $metric.animation()) {
                    ForEach(HeatmapMetric.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: metric) { _, _ in selectedPoint = nil }

                // MARK: - Detail Callout
                if let point = selectedPoint {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(Self.timeFormatter.string(from: point.time))
                                .font(.caption).bold()
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg Confidence")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", point.averageConfidence * 100))
                                .font(.caption).bold()
                                .foregroundStyle(SleepQuality.confidenceColor(for: point.averageConfidence))
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Events")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(point.snoreCount)")
                                .font(.caption).bold()
                        }
                        Spacer()
                        Button { selectedPoint = nil } label: {
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

                // MARK: - Legend
                HStack(spacing: 12) {
                    ForEach([("Light", Color.green.opacity(0.7)),
                             ("Moderate", Color.orange.opacity(0.85)),
                             ("Heavy", Color.red.opacity(0.9))], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color)
                                .frame(width: 12, height: 12)
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(metric == .snoreCount ? "by number of events" : "by detection confidence")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)

                // MARK: - Chart
                Chart(heatmapData) { point in
                    RectangleMark(
                        x: .value("Time", point.time),
                        y: .value("Density", "Snore Density"),
                        width:  .fixed(tileWidth(totalPoints: heatmapData.count)),
                        height: .fixed(60)
                    )
                    .foregroundStyle(
                        tileColor(point: point, maxCount: maxCount)
                            .opacity(point.time == selectedPoint?.time ? 1.0 : 0.75)
                    )
                    .cornerRadius(4)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let d = value.as(Date.self) {
                                Text(Self.timeFormatter.string(from: d))
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
                                let closest = heatmapData.min(by: {
                                    abs($0.time.timeIntervalSince(date)) <
                                    abs($1.time.timeIntervalSince(date))
                                })
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPoint = (selectedPoint?.time == closest?.time) ? nil : closest
                                }
                            }
                    }
                }
                .frame(height: 100)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .frame(minHeight: 200)
        .layoutPriority(1)
        .animation(.easeInOut(duration: 0.2), value: selectedPoint?.time)
        .animation(.easeInOut(duration: 0.2), value: metric)
    }

    // MARK: - Tile color

    /// Confidence mode: green / orange / red by threshold.
    /// Count mode: opacity scales linearly from the session's max count.
    private func tileColor(point: TrendPoint, maxCount: Int) -> Color {
        switch metric {
        case .confidence:
            return SleepQuality.confidenceColorOpacity(for: point.averageConfidence)
        case .snoreCount:
            let ratio = maxCount > 0 ? Double(point.snoreCount) / Double(maxCount) : 0
            return SleepQuality.ratioColorOpacity(for: ratio)
        }
    }

   

    // MARK: - Helpers

    private func tileWidth(totalPoints: Int) -> CGFloat {
        guard totalPoints > 1 else { return 40 }
        return max(8, min(40, 320 / CGFloat(totalPoints)))
    }

    // MARK: - Aggregation (absolute time buckets)
    private func aggregateEvents(events: FetchedResults<SnoreEvent>,
                                 intervalInMinutes: Int = 10) -> [TrendPoint] {
        guard let first = events.first?.startTime else { return [] }
        let interval = TimeInterval(intervalInMinutes * 60)

        let grouped = Dictionary(grouping: events) { event -> Date in
            guard let t = event.startTime else { return first }
            let bucket = floor(t.timeIntervalSince(first) / interval) * interval
            return first.addingTimeInterval(bucket)
        }

        return grouped.map { bucketTime, eventsInBucket in
            let avg = eventsInBucket.reduce(0.0) { $0 + $1.averageConfidence } / Double(eventsInBucket.count)
            return TrendPoint(time: bucketTime,
                              averageConfidence: avg,
                              snoreCount: eventsInBucket.count)
        }.sorted { $0.time < $1.time }
    }
}
