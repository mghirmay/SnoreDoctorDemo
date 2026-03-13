//
//  SnoreHeatmapView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import SwiftUI
import CoreData
import Charts // Make sure Charts is imported here

struct SnoreHeatmapView: View {
    @ObservedObject var session: RecordingSession
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>

    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        // We reuse the aggregation logic, but we treat it as discrete blocks
        let heatmapData = aggregateEvents(events: snoreEvents)
        HStack {
            Text("Heat map - Snore Density")
                .font(.headline)
            HelpPopoverButton(info: HelpDataFactory.snoreHeatmapView)
        }
        .padding(.horizontal)
        Chart(heatmapData) { point in
            RectangleMark(
                x: .value("Time", point.time),
                y: .value("Intensity", "Snore Density"), // All in one row
                width: .fixed(20), // Adjust width to make them look like tiles
                height: .fixed(50)
            )
            .foregroundStyle(colorForConfidence(point.averageConfidence))
        }
        .chartYAxis(.hidden) // We don't need a Y-axis for a 1D density strip
        .padding()
    }
    
    // Helper to map confidence to our red-to-green gradient
    private func colorForConfidence(_ confidence: Double) -> Color {
        let clamped = max(0.0, min(1.0, confidence))
        // Map: Low confidence = light red, High confidence = dark red
        return Color.red.opacity(0.2 + (clamped * 0.8))
    }
    
    
    private func aggregateEvents(events: FetchedResults<SnoreEvent>, intervalInMinutes: Int = 10) -> [TrendPoint] {
        let calendar = Calendar.current
        
        // 1. Group events into buckets
        let grouped = Dictionary(grouping: events) { event -> Date in
            guard let date = event.startTime else { return Date() }
            
            // This math floors the date to the nearest interval (e.g., 10:07 -> 10:00)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let minute = components.minute!
            let minuteBucket = (minute / intervalInMinutes) * intervalInMinutes
            
            return calendar.date(bySettingHour: components.hour!, minute: minuteBucket, second: 0, of: date)!
        }

        // 2. Map to TrendPoints and calculate averages
        return grouped.map { (bucketTime, eventsInBucket) in
            let avgConfidence = eventsInBucket.reduce(0.0) { $0 + $1.averageConfidence } / Double(eventsInBucket.count)
            return TrendPoint(time: bucketTime, averageConfidence: avgConfidence,  snoreCount: eventsInBucket.count)
        }.sorted { $0.time < $1.time }
    }
}
