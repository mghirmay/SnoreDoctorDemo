//
//  HelpDataFactory.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData

struct HelpDataFactory {

    static let SnoreTrendLineChartView = HelpDefinition(
        title: "Nightly Snore Load",
        definition: """
        Tracks the average snore confidence across your sleep in 10-minute buckets, giving you a clear picture of when your snoring was lightest and heaviest.

        • X axis: Time of night.
        • Y axis: Average detection confidence (0–100%) per interval.
        • Dot color: Green = low (<40%), Orange = moderate (40–70%), Red = heavy (>70%).
        • Dashed red line: 70% threshold — sustained peaks above this line indicate heavy snoring episodes.

        Tap any dot to see the exact time, average confidence, and number of snore events in that interval.

        A flat, low line means restful sleep. Clusters of red dots or sustained peaks above the threshold may be worth discussing with a doctor.
        """,
        sourceName: "Sleep Foundation",
        sourceURL: URL(string: "https://www.sleepfoundation.org/snoring")
    )

   
    static let snoreEventBarChartView = HelpDefinition(
        title: "Detailed Snore Events",
        definition: """
        Each bar represents a single aggregated snoring event detected during your sleep.

        • Position (X axis): When during the night the snore occurred.
        • Height (Y axis): How confident the detection was — from 0% (uncertain) to 100% (definite snore).
        • Color: Green = low confidence (<40%), Orange = moderate (40–70%), Red = high confidence (>70%).
        • Count label (N×): How many individual snore detections were merged into this event.

        Tap any bar to see the exact time, confidence, count, and duration of that event.

        Look for clusters of red bars to identify your heaviest snoring periods of the night.
        """,
        sourceName: "Snore Intensity Guide",
        sourceURL: URL(string: "https://www.sleepfoundation.org/snoring")
    )
    
    static let snoreHeatmapView = HelpDefinition(
        title: "Snore Density",
        definition: """
        A colour-coded strip showing when your snoring was lightest and heaviest across the night, in 10-minute buckets.

        • Each tile = one 10-minute interval.
        • Tile color: Green = light (<40% confidence), Orange = moderate (40–70%), Red = heavy (>70%).
        • Darker / more saturated tiles = stronger snoring activity in that window.

        Tap any tile to see the exact time, average confidence, and number of events in that interval.

        Clusters of red tiles indicate sustained heavy snoring periods. Isolated red tiles may just be a brief intense event. Use alongside the Trend chart for a fuller picture.
        """,
        sourceName: "Sleep Foundation",
        sourceURL: URL(string: "https://www.sleepfoundation.org/snoring")
    )
    
    static let boxPlotChart = HelpDefinition(
        title: "Snore Load Distribution",
        definition: """
        This chart summarizes the range of your snoring intensity throughout the session:
        
        • The Box: Represents the middle 50% of your snore intensity readings. 
        • The Line: Marks the median intensity; half your snores were quieter than this, and half were louder.
        • The Whiskers: Extend to the lowest and highest intensity levels detected.
        
        This view helps you understand if your snoring intensity is consistent or highly variable across the entire night.
        """,
        sourceName: "Statistical Sleep Analysis",
        sourceURL: URL(string: "https://en.wikipedia.org/wiki/Box_plot")
    )
    
    static let generalTrendChart = HelpDefinition(
        title: "Trend Over Time",
        definition: """
        This chart tracks how your measured data fluctuated throughout your sleep session.
        
        • The X-axis represents time, flowing from left to right.
        • The Y-axis represents the measured value.
        • The slope of the line shows the speed of changes: steeper segments indicate rapid shifts, while flatter segments show stability.
        
        Circles on the line mark specific data points recorded by the sensor.
        """,
        sourceName: "Data Visualization Best Practices",
        sourceURL: URL(string: "https://www.nngroup.com/articles/line-charts/")
    )
    
    
}

extension HelpDataFactory {
    static let DailySleepReportView1 = HelpDefinition(
        title: "Sleep Session Timeline",
        definition: """
        This bar chart displays your recorded sleep sessions.
        
        • Horizontal Axis: Shows the timeline of your night.
        • Colors: Represent your sleep quality score; warmer or cooler tones help you identify the most restful vs. restless periods.
        """,
        sourceName: "Sleep Quality Tracking",
        sourceURL: nil
    )
    
    static let DailySleepReportView2 = HelpDefinition(
        title: "Activity Density Heatmap",
        definition: """
        This heatmap visualizes the concentration of sound events detected throughout the night.
        
        • Color Intensity: Moves from blue (low activity) to red (high activity).
        • Interpretation: Use this to see if your snoring or noise events are clustered in specific parts of the night or spread evenly.
        """,
        sourceName: "Snore Intensity Guide",
        sourceURL: nil
    )
}

extension HelpDataFactory {
    static func definition(for type: ChartType) -> HelpDefinition {
        switch type {
        case .snoreConfidenceBoxPlot:
            return HelpDefinition(
                title: "Confidence Distribution",
                definition: """
                Shows the statistical spread of detection confidence across all snore events in this session.

                • Median line: Your typical snore confidence level.
                • Box (Q1–Q3): The middle 50% of events — a narrow box means consistent detection, a tall box means high variability.
                • Whiskers: The full range from weakest to strongest detection.

                High median confidence (>70%) suggests clear, strong snoring. Low confidence may indicate light or intermittent sounds.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))

        case .snoreDurationBoxPlot:
            return HelpDefinition(
                title: "Duration Distribution",
                definition: """
                Visualizes the statistical spread of individual snore event lengths across your session.

                • Median line: Your typical snore duration.
                • Box (Q1–Q3): Where most event durations fall.
                • Whiskers: Shortest to longest recorded event.

                A high median with a wide box suggests prolonged, variable snoring. A low, tight distribution indicates short, consistent bursts.
                """,
                sourceName: "Sleep Science",
                sourceURL: nil)

        case .snoreEventCountBoxPlot:
            return HelpDefinition(
                title: "Event Frequency Distribution",
                definition: """
                A statistical view of how many raw detections were merged into each aggregated snore event.

                • Median line: The typical number of detections per event.
                • Box (Q1–Q3): The typical detection density range.
                • Whiskers: Minimum and maximum detections in a single event.

                High counts per event indicate sustained snoring bursts rather than isolated sounds.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: nil)

        case .snoreConfidenceOverTime:
            return HelpDefinition(
                title: "Confidence Over Time",
                definition: """
                A chronological line chart of detection confidence for each snore event across the night.

                • X axis: Time of night.
                • Y axis: Confidence (0–100%).

                Rising confidence later in the night may indicate deeper sleep cycles. Sustained high confidence periods suggest prolonged heavy snoring.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: nil)

        case .snoreDurationOverTime:
            return HelpDefinition(
                title: "Duration Over Time",
                definition: """
                Tracks how long individual snore events last as the night progresses.

                • X axis: Time of night.
                • Y axis: Event duration in seconds.

                An upward trend over the course of the night may suggest increasing airway relaxation during deeper sleep. Short, flat values indicate brief, consistent snoring throughout.
                """,
                sourceName: "Sleep Science",
                sourceURL: nil)

        case .snoreEventCountOverTime:
            return HelpDefinition(
                title: "Snore Frequency Over Time",
                definition: """
                Tracks the number of raw detections merged into each event across the night.

                • X axis: Time of night.
                • Y axis: Detection count per event.

                Peaks indicate periods of dense, sustained snoring activity. Use this alongside the Confidence chart to distinguish frequent light snoring from intense episodes.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: nil)

        case .snoreSoundEventComposition:
            return HelpDefinition(
                title: "Sound Profile",
                definition: """
                A donut chart breaking down the types of sounds detected across the session — for example, rumbles, whistles, or other breath sounds.

                • Each segment represents a sound category and its share of total detections.

                A dominant single category suggests a consistent snoring pattern. A mixed profile may indicate varied breathing obstructions worth discussing with a doctor.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: nil)

        case .snoreConfidenceVsDuration:
            return HelpDefinition(
                title: "Confidence vs. Duration",
                definition: """
                A scatter plot correlating how confident each detection was with how long that event lasted.

                • X axis: Event duration (seconds).
                • Y axis: Detection confidence (0–100%).
                • Each dot = one aggregated snore event.

                Events in the top-right (long + high confidence) are the most significant. Events bottom-left (short + low confidence) may be borderline detections. Clusters in the top-right warrant attention.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: nil)
        }
    }
}

extension HelpDataFactory {
    static func definition(for metric: TrendMetric) -> HelpDefinition {
        switch metric {
        case .averageConfidence:
            return HelpDefinition(
                title: "Average Snore Confidence Over Time",
                definition: """
                Tracks the average detection confidence per 10-minute bucket across your sleep.

                • X axis: Time of night.
                • Y axis: Average confidence (0–100%) per interval.
                • Dot color: Green = low (<40%), Orange = moderate (40–70%), Red = heavy (>70%).
                • Dashed red line: 70% threshold — sustained peaks above this suggest heavy snoring.

                Tap any dot to see the exact time, confidence, and event count for that interval.

                A flat, low line means restful sleep. Sustained red peaks may be worth discussing with a doctor.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))

        case .count:
            return HelpDefinition(
                title: "Snore Detection Count Over Time",
                definition: """
                Tracks how many individual snore detections occurred per 10-minute bucket.

                • X axis: Time of night.
                • Y axis: Number of detections per interval.
                • Dot color: Scaled relative to your session's busiest interval — green = quiet, red = most active.

                Tap any dot to see the exact time, detection count, and average confidence for that interval.

                High peaks late in the night may indicate snoring worsens as you enter deeper sleep cycles.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))

        case .duration:
            return HelpDefinition(
                title: "Snore Duration Over Time",
                definition: """
                Tracks the total duration of snoring per 10-minute bucket across your sleep.

                • X axis: Time of night.
                • Y axis: Cumulative snore duration in seconds per interval.
                • Dot color: Scaled relative to your session's longest interval — green = brief, red = prolonged.

                Tap any dot to see the exact time, total duration, and average confidence for that interval.

                Rising duration later in the night may indicate increasing airway relaxation during deeper sleep.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))
        }
    }
}

extension HelpDataFactory {
    static func definition(for metric: BarMetric) -> HelpDefinition {
        switch metric {
        case .averageConfidence:
            return HelpDefinition(
                title: "Snore Events – Confidence",
                definition: """
                Each bar represents one aggregated snore event, showing how confident the detection was.

                • X axis: When during the night the event occurred.
                • Y axis: Average detection confidence (0–100%).
                • Bar color: Green = low (<40%), Orange = moderate (40–70%), Red = high (>70%).
                • Count label (N×): How many raw detections were merged into this event.

                Tap any bar to see full details. Tall red bars indicate strong, clear snoring events.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))

        case .duration:
            return HelpDefinition(
                title: "Snore Events – Duration",
                definition: """
                Each bar represents one aggregated snore event, showing how long it lasted.

                • X axis: When during the night the event occurred.
                • Y axis: Event duration in seconds.
                • Bar color: Scaled relative to the longest event in this session — green = brief, red = prolonged.
                • Count label (N×): How many raw detections were merged into this event.

                Tap any bar to see full details. Long events late in the night may indicate worsening obstruction.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))

        case .count:
            return HelpDefinition(
                title: "Snore Events – Detection Count",
                definition: """
                Each bar represents one aggregated snore event, showing how many raw detections it contains.

                • X axis: When during the night the event occurred.
                • Y axis: Number of raw detections merged into this event.
                • Bar color: Scaled relative to the densest event in this session — green = sparse, red = dense.
                • Count label (N×): Same value as the bar height — shown for quick comparison.

                Tap any bar to see full details. Dense events suggest sustained, repeated snoring in a short window.
                """,
                sourceName: "Sleep Foundation",
                sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))
        }
    }
}
