//
//  ChartType.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


enum ChartType: String, CaseIterable, Identifiable {
    case snoreConfidenceBoxPlot = "Snore Confidence Box Plot"
    case snoreDurationBoxPlot = "Snore Duration Box Plot"
    case snoreEventCountBoxPlot = "Snore Event Count Box Plot"
    case snoreConfidenceOverTime = "Snore Confidence Over Time"
    case snoreDurationOverTime = "Snore Duration Over Time"
    case snoreEventCountOverTime = "Snore Event Count Over Time"
    case snoreSoundEventComposition = "Snore Sound Event Composition"
    case snoreConfidenceVsDuration = "Snore Confidence vs Duration"

    var id: String { rawValue }
}