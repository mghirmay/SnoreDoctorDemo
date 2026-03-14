//
//  SnoreEventBarChartView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts

enum BarMetric: String, CaseIterable {
    case averageConfidence = "Avg Confidence"
    case duration          = "Duration"
    case count             = "Count"

    var yLabel: String {
        switch self {
        case .averageConfidence: return "Confidence"
        case .duration:          return "Duration (s)"
        case .count:             return "Detections"
        }
    }

    var isConfidenceBased: Bool { self == .averageConfidence }

    func value(for event: SnoreEvent) -> Double {
        switch self {
        case .averageConfidence: return event.averageConfidence
        case .duration:          return event.duration
        case .count:             return Double(event.count)
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .averageConfidence: return String(format: "%.0f%%", value * 100)
        case .duration:          return String(format: "%.1fs", value)
        case .count:             return String(format: "%.0f", value)
        }
    }
}

struct SnoreEventBarChartView: View {
    @ObservedObject var session: RecordingSession
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>
    @State private var selectedEvent: SnoreEvent? = nil
    @State private var selectedMetric: BarMetric = .averageConfidence

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let detailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    private var maxValue: Double {
        snoreEvents.map { selectedMetric.value(for: $0) }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Snore Events")
                    .font(.headline)
                Spacer()
                Menu {
                    Section("Confidence") {
                        metricButton(.averageConfidence, icon: "waveform.path.ecg")
                    }
                    Section("Activity") {
                        metricButton(.duration, icon: "timer")
                        metricButton(.count,    icon: "chart.bar")
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
                .onChange(of: selectedMetric) { _, _ in selectedEvent = nil }
                HelpPopoverButton(info: HelpDataFactory.definition(for: selectedMetric))
            }
            .padding(.horizontal)

            if snoreEvents.isEmpty {
                ChartEmptyState()
            } else {

                // MARK: - Detail Callout
                if let event = selectedEvent, let start = event.startTime {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(Self.detailFormatter.string(from: start))
                                .font(.caption).bold()
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedMetric.yLabel)
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(selectedMetric.formatted(selectedMetric.value(for: event)))
                                .font(.caption).bold()
                                .foregroundStyle(barColor(for: event))
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confidence")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", event.averageConfidence * 100))
                                .font(.caption).bold()
                                .foregroundStyle(SleepQuality.confidenceColor(for: event.averageConfidence))
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Count")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(event.count)×")
                                .font(.caption).bold()
                        }
                        if let end = event.endTime {
                            Divider().frame(height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Duration")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(String(format: "%.1fs", end.timeIntervalSince(start)))
                                    .font(.caption).bold()
                            }
                        }
                        Spacer()
                        Button { selectedEvent = nil } label: {
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
                    ForEach(snoreEvents) { event in
                        if let start = event.startTime {
                            BarMark(
                                x: .value("Time", start),
                                y: .value(selectedMetric.yLabel, selectedMetric.value(for: event))
                            )
                            .foregroundStyle(
                                event.id == selectedEvent?.id
                                    ? barColor(for: event)
                                    : barColor(for: event).opacity(0.55)
                            )
                            .annotation(position: .top) {
                                Text("\(event.count)×")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
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
                                let closest = snoreEvents.min(by: {
                                    abs($0.startTime?.timeIntervalSince(date) ?? .infinity) <
                                    abs($1.startTime?.timeIntervalSince(date) ?? .infinity)
                                })
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedEvent = (selectedEvent?.id == closest?.id) ? nil : closest
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
        .animation(.easeInOut(duration: 0.2), value: selectedEvent?.id)
        .animation(.easeInOut(duration: 0.3), value: selectedMetric)
    }

    // MARK: - Helpers


    /// Activity metrics: relative to session max.
    private func barColor(for event: SnoreEvent) -> Color {
        switch selectedMetric {
        case .averageConfidence:
            return SleepQuality.confidenceColor(for: event.averageConfidence)
        case .duration, .count:
            let ratio = maxValue > 0 ? selectedMetric.value(for: event) / maxValue : 0
            return SleepQuality.ratioColor(for: ratio)
        }
    }

 
    
    @ViewBuilder
    private func metricButton(_ metric: BarMetric, icon: String) -> some View {
        Button {
            withAnimation { selectedMetric = metric }
            selectedEvent = nil
        } label: {
            Label(metric.rawValue, systemImage: selectedMetric == metric ? "checkmark" : icon)
        }
    }
}
