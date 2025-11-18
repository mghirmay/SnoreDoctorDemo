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
            // MARK: - Chart Type Selector (Menu for better layout)
            HStack {
                Text("Chart Type:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Menu {
                    // Grouping Box Plots
                    Section("Distribution Charts (Box Plot)") {
                        ForEach([ChartType.snoreConfidenceBoxPlot, .snoreDurationBoxPlot, .snoreEventCountBoxPlot], id: \.self) { chartType in
                            Button {
                                selectedChartType = chartType
                            } label: {
                                Label(chartType.rawValue, systemImage: chartType.iconName)
                            }
                        }
                    }

                    // Grouping Time-Series Charts
                    Section("Over Time Charts (Line)") {
                        ForEach([ChartType.snoreConfidenceOverTime, .snoreDurationOverTime, .snoreEventCountOverTime], id: \.self) { chartType in
                            Button {
                                selectedChartType = chartType
                            } label: {
                                Label(chartType.rawValue, systemImage: chartType.iconName)
                            }
                        }
                    }

                    // Grouping Other Charts
                    Section("Other Analyses") {
                        Button {
                            selectedChartType = .snoreSoundEventComposition
                        } label: {
                            Label(ChartType.snoreSoundEventComposition.rawValue, systemImage: ChartType.snoreSoundEventComposition.iconName)
                        }
                        
                        Button {
                            selectedChartType = .snoreConfidenceVsDuration
                        } label: {
                            Label(ChartType.snoreConfidenceVsDuration.rawValue, systemImage: ChartType.snoreConfidenceVsDuration.iconName)
                        }
                    }
                } label: {
                    Label(selectedChartType.rawValue, systemImage: selectedChartType.iconName)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 5)

            // MARK: - Chart Display Area
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
                title: type.rawValue
          
            )

        case .snoreDurationBoxPlot:
            BoxPlotChart(
                data: snoreEvents.map { $0.duration },
                title: type.rawValue
            )

        case .snoreEventCountBoxPlot:
            BoxPlotChart(
                data: snoreEvents.map { Double($0.count) },
                title: type.rawValue
            )

        case .snoreDurationOverTime:
            Chart {
                ForEach(snoreEvents, id: \.self) { event in
                    if let start = event.startTime {
                        LineMark(
                            x: .value("Time", start),
                            y: .value("Duration (s)", event.duration)
                        )
                        PointMark(
                            x: .value("Time", start),
                            y: .value("Duration (s)", event.duration)
                        )
                        .annotation(position: .overlay, alignment: .top) {
                            Text(event.duration, format: .number.precision(.fractionLength(1)))
                                .font(.caption2)
                                .opacity(0.8)
                        }
                    }
                }
            }
            .chartXAxisLabel("Time")
            .chartYAxisLabel("Duration (s)")
            .chartPlotStyle { plot in
                plot.background(Color.clear)
            }
            .overlay(
                Text(type.rawValue)
                    .font(.headline)
                    .padding(.top, 4),
                alignment: .top
            )

        case .snoreConfidenceOverTime, .snoreEventCountOverTime:
            // Custom LineChart implementation
             LineChart(
                 data: snoreEvents.compactMap { event in
                     guard let start = event.startTime else { return nil }
                     return (
                         start,
                         type == .snoreConfidenceOverTime ? event.averageConfidence : Double(event.count)
                     )
                 },
                 title: type.rawValue,
                 xLabel: "Time",
                 yLabel: type == .snoreConfidenceOverTime ? "Confidence (0-1)" : "Count (Events)"
             )

        case .snoreSoundEventComposition:
            let aggregatedHistogram = snoreEvents.reduce(into: [String: Int]()) { result, event in
                if let histogram = event.soundEventNamesHistogram as? [String: Int] {
                    for (key, value) in histogram {
                        result[key, default: 0] += value
                    }
                }
            }
            BarChart(
                data: aggregatedHistogram,
                title: type.rawValue
            )

        case .snoreConfidenceVsDuration:
            // ScatterChart already has good labels, just ensuring they use rawValue
            ScatterChart(
                data: snoreEvents.compactMap { event in
                    guard let start = event.startTime else { return nil }
                    return (
                        x: event.duration,
                        y: event.averageConfidence,
                        label: "Snore at \(start.formatted(date: .omitted, time: .shortened))"
                    )
                },
                title: type.rawValue,
                xLabel: "Duration (s)",
                yLabel: "Confidence (0-1)"
            )
        }
    }
}
