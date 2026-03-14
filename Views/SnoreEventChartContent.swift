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
                    .frame(height: 300)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding([.horizontal, .bottom])
            }
        }
    }
    
    
    @ViewBuilder
   private func chartView(for type: ChartType) -> some View {
       renderContent(for: type)
   }


    @ViewBuilder
    private func renderContent(for type: ChartType) -> some View {
        let help = HelpDataFactory.definition(for: type)

        switch type {
        case .snoreConfidenceBoxPlot, .snoreDurationBoxPlot, .snoreEventCountBoxPlot:
            let data: [Double] = {
                switch type {
                case .snoreConfidenceBoxPlot: return snoreEvents.map { $0.averageConfidence }
                case .snoreDurationBoxPlot:   return snoreEvents.map { $0.duration }
                default:                      return snoreEvents.map { Double($0.count) }
                }
            }()
            BoxPlotChart(data: data, title: type.rawValue, helpInfo: help)

        case .snoreConfidenceOverTime, .snoreEventCountOverTime, .snoreDurationOverTime:
            LineChart(
                data: snoreEvents.compactMap { e in
                    guard let start = e.startTime else { return nil }
                    let y: Double
                    switch type {
                    case .snoreConfidenceOverTime: y = e.averageConfidence
                    case .snoreEventCountOverTime: y = Double(e.count)
                    case .snoreDurationOverTime:   y = e.duration
                    default:                       return nil
                    }
                    return (start, y)
                },
                title: type.rawValue,
                helpInfo: help,
                xLabel: "Time",
                yLabel: type == .snoreDurationOverTime ? "Duration (s)" : "Value"
            )

        case .snoreSoundEventComposition:
            let histogram = aggregateHistogram()
            Chart(histogram.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                SectorMark(
                    angle: .value("Count", value),
                    innerRadius: .ratio(0.6),
                    outerRadius: .inset(10)
                )
                .foregroundStyle(by: .value("Type", key))
            }
            .chartLegend(position: .bottom)

        case .snoreConfidenceVsDuration:
            ScatterChart(
                data: snoreEvents.compactMap { e in
                    guard let start = e.startTime else { return nil }
                    return (x: e.duration, y: e.averageConfidence,
                            label: "Snore at \(start.formatted(date: .omitted, time: .shortened))")
                },
                title: type.rawValue,
                helpInfo: help,
                xLabel: "Duration (s)",
                yLabel: "Confidence"
            )
        }
    }
    
    
    private func aggregateHistogram() -> [String: Int] {
        return snoreEvents.reduce(into: [String: Int]()) { result, event in
            if let dict = event.soundEventNamesHistogram as? [String: Int] {
                for (key, value) in dict { result[key, default: 0] += value }
            }
        }
    }
}
