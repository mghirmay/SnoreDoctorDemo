//
//  ChartType.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//
enum ChartType: String, CaseIterable, Identifiable {
    // Titles updated to match BoxPlotChart/LineChart titles

    case snoreConfidenceBoxPlot = "Average Confidence Distribution"
    case snoreDurationBoxPlot = "Duration Distribution (Seconds)"
    case snoreEventCountBoxPlot = "Sound Event Count Distribution"

    case snoreConfidenceOverTime = "Average Confidence Over Time"
    case snoreDurationOverTime = "Duration Over Time"
    case snoreEventCountOverTime = "Sound Event Count Over Time"

    case snoreSoundEventComposition = "Aggregated Sound Event Composition"
    case snoreConfidenceVsDuration = "Confidence vs Duration"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .snoreConfidenceBoxPlot, .snoreDurationBoxPlot, .snoreEventCountBoxPlot:
            // Using a widely compatible icon for older iOS versions
            return "chart.bar.xaxis"

        case .snoreConfidenceOverTime, .snoreDurationOverTime, .snoreEventCountOverTime:
            return "chart.line.uptrend.xyaxis"

        case .snoreSoundEventComposition:
            return "chart.bar.fill"

        case .snoreConfidenceVsDuration:
            return "chart.dots.scatter"
        }
    }
}
