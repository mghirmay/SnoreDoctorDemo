//
//  SnoreEventChartContent.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


//
//  SnoreEventChartContent.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 09.07.25.
//

import SwiftUI
import Charts
import CoreData

struct SnoreEventChartContent: View {
    let snoreEvents: FetchedResults<SnoreEvent>
    @State private var selectedChartType: ChartType = .snoreConfidenceOverTime

    var body: some View {
        VStack {
            Picker("Chart Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases) { chartType in
                    Text(chartType.rawValue).tag(chartType)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 5)

            if snoreEvents.isEmpty {
                ContentUnavailableView(
                    "No Snore Events",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("No aggregated snore events available for this session. Run the aggregation process after recording.")
                )
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                chartView(for: selectedChartType)
                    .frame(height: 250)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding([.horizontal, .bottom])
            }
        }
    }

    @ViewBuilder
    private func chartView(for type: ChartType) -> some View {
        switch type {
        case .snoreConfidenceBoxPlot:
            BoxPlotChart(
                data: snoreEvents.map { $0.averageConfidence },
                title: "Average Confidence Distribution"
            )

        case .snoreDurationBoxPlot:
            BoxPlotChart(
                data: snoreEvents.map { $0.duration },
                title: "Duration Distribution (Seconds)"
            )

        case .snoreEventCountBoxPlot:
            BoxPlotChart(
                data: snoreEvents.map { Double($0.count) },
                title: "Sound Event Count Distribution"
            )

        case .snoreConfidenceOverTime:
            LineChart(
                data: snoreEvents.compactMap { event in
                    guard let start = event.startTime else { return nil }
                    return (start, event.averageConfidence)
                },
                title: "Average Confidence Over Time",
                xLabel: "Time",
                yLabel: "Confidence"
            )

        case .snoreDurationOverTime:
            LineChart(
                data: snoreEvents.compactMap { event in
                    guard let start = event.startTime else { return nil }
                    return (start, event.duration)
                },
                title: "Duration Over Time",
                xLabel: "Time",
                yLabel: "Duration (s)"
            )

        case .snoreEventCountOverTime:
            LineChart(
                data: snoreEvents.compactMap { event in
                    guard let start = event.startTime else { return nil }
                    return (start, Double(event.count))
                },
                title: "Sound Event Count Over Time",
                xLabel: "Time",
                yLabel: "Count"
            )

        case .snoreSoundEventComposition:
            let aggregatedHistogram = snoreEvents.reduce(into: [String: Int]()) { result, event in
                if let histogram = event.soundEventNamesHistogram as? [String: Int] {
                    for (key, value) in histogram {
                        result[key, default: 0] += value
                    }
                }
            }
            BarChart(data: aggregatedHistogram, title: "Aggregated Sound Event Composition")

        case .snoreConfidenceVsDuration:
            ScatterChart(
                data: snoreEvents.compactMap { event in
                    guard let start = event.startTime else { return nil }
                    return (
                        x: event.duration,
                        y: event.averageConfidence,
                        label: "Snore at \(start.formatted(date: .omitted, time: .shortened))"
                    )
                },
                title: "Confidence vs Duration",
                xLabel: "Duration (s)",
                yLabel: "Confidence"
            )
        }
    }

}

