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
        This chart shows the intensity of your snoring throughout the night. 
        
        The peaks represent periods of more frequent or louder snoring, averaged in 10-minute intervals. A flatter line indicates quieter, more restful sleep, while high peaks may suggest periods of heavy snoring or sleep disruption.
        """,
        sourceName: "Sleep Science Reference",
        sourceURL: URL(string: "https://www.sleepfoundation.org/snoring")
    )

    static let snoreEventBarChartViewContent = HelpDefinition(
        title: "Detailed Snore Events",
        definition: """
        Each bar in this chart represents a specific snoring event detected during your sleep.
        
        • Height: Represents the confidence/intensity (0% to 100%).
        • Width: Shows how long that specific snore lasted.
        • Color: Indicates the intensity level—green bars are light snores, while yellow and red bars indicate much stronger snoring events.
        
        This view helps you identify if your snoring occurs in short bursts or long, sustained periods throughout the night.
        """,
        sourceName: "Snore Intensity Guide",
        sourceURL: URL(string: "https://www.sleepfoundation.org/snoring")
    )
    
    static let snoreHeatmapView = HelpDefinition(
        title: "Snore Density Heatmap",
        definition: """
        This view provides a quick, bird's-eye view of your snoring patterns throughout the night.
        
        • Light Red: Indicates periods of low-intensity snoring or quiet sleep.
        • Dark Red: Highlights periods of higher-intensity or more frequent snoring.
        
        The timeline flows from left to right, allowing you to quickly spot whether your snoring was consistent all night or concentrated in specific blocks of time.
        """,
        sourceName: "Sleep Quality Tracking",
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
            return HelpDefinition(title: "Confidence Distribution", definition: "Shows the range of snore intensity confidence. A narrow box means your snoring volume is consistent, while a tall box indicates high variability.", sourceName: "Sleep Foundation", sourceURL: URL(string: "https://www.sleepfoundation.org/snoring"))
            
        case .snoreDurationBoxPlot:
            return HelpDefinition(title: "Duration Distribution", definition: "Visualizes the typical length of your snoring events. Helps distinguish between short, sporadic snorts and long, sustained snoring periods.", sourceName: "Sleep Science", sourceURL: nil)
            
        case .snoreEventCountBoxPlot:
            return HelpDefinition(title: "Event Frequency", definition: "Statistical view of how many snore events occur per observation window. Helps identify if snoring density increases throughout the night.", sourceName: "Sleep Foundation", sourceURL: nil)
            
        case .snoreConfidenceOverTime:
            return HelpDefinition(title: "Intensity Trend", definition: "A chronological view of your snoring volume. Peaks represent louder, more intense snoring sessions, often linked to deeper sleep cycles.", sourceName: "Sleep Foundation", sourceURL: nil)
            
        case .snoreDurationOverTime:
            return HelpDefinition(title: "Event Duration Trend", definition: "Maps how long individual snoring events last over the course of your sleep, showing if snoring duration trends longer as the night progresses.", sourceName: "Sleep Science", sourceURL: nil)
            
        case .snoreEventCountOverTime:
            return HelpDefinition(title: "Snore Density Over Time", definition: "Tracks the number of detected snore events per interval, providing a clear map of when your snoring is most frequent.", sourceName: "Sleep Foundation", sourceURL: nil)
            
        case .snoreSoundEventComposition:
            return HelpDefinition(title: "Sound Profile", definition: "A breakdown of different sound types detected (e.g., rumbles vs. whistles). This helps identify specific breathing patterns associated with your snoring.", sourceName: "Sleep Foundation", sourceURL: nil)
            
        case .snoreConfidenceVsDuration:
            return HelpDefinition(title: "Intensity vs. Duration", definition: "Correlates the strength of your snore with its length. Clusters in the top-right indicate long, intense snoring events that may require attention.", sourceName: "Sleep Foundation", sourceURL: nil)
        }
    }
}
