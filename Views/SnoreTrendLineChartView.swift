//
//  SnoreTrendLineChartView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts // Make sure Charts is imported here


struct SnoreTrendLineChartView: View {
    @ObservedObject var session: RecordingSession
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>
    @State private var showInfo = false // This manages the visibility
    
    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        let trendData = aggregateEvents(events: snoreEvents)
        HStack {
            Text("Nightly Snore Load")
                .font(.headline)
            HelpPopoverButton(info: HelpDataFactory.SnoreTrendLineChartView)
        }
        .padding(.horizontal)
    
        Chart(trendData) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Intensity", point.averageConfidence)
            )
            .interpolationMethod(.cardinal) // Makes the line nice and smooth
            .foregroundStyle(.blue)
            
            // Add area under the line to emphasize intensity
            AreaMark(
                x: .value("Time", point.time),
                yStart: .value("Zero", 0),
                yEnd: .value("Intensity", point.averageConfidence)
            )
            .interpolationMethod(.cardinal)
            .foregroundStyle(.blue.opacity(0.1))
        }
        .chartYScale(domain: 0...1.0)
        .padding()
    }
    
    
    
    private func aggregateEvents(events: FetchedResults<SnoreEvent>) -> [TrendPoint] {
        // 1. Group events into 10-minute buckets
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.startTime!)
                .minute! / 10 // Change to / 10 for 10-minute buckets
        }

        // 2. Map to TrendPoint objects
        return grouped.map { (key, eventsInBucket) in
            let avg = eventsInBucket.reduce(0.0) { $0 + $1.averageConfidence } / Double(eventsInBucket.count)
            return TrendPoint(time: eventsInBucket.first!.startTime!, averageConfidence: avg, snoreCount: 1)
        }.sorted { $0.time < $1.time }
    }
}
