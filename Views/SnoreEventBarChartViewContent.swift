//
//  SnoreEventBarChartViewContent.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts // Make sure Charts is imported here


struct SnoreEventBarChartViewContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var session: RecordingSession

    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // e.g., 22:30, 01:45
        return formatter
    }()

    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        VStack {
            if snoreEvents.isEmpty {
                ContentUnavailableView {
                    Label("No Snore Events", systemImage: "sparkles.square.dashed")
                } description: {
                    Text("This session has no recorded snore events.")
                }
            } else {
                HStack {
                    Text("Snore events")
                        .font(.headline)
                    HelpPopoverButton(info: HelpDataFactory.snoreEventBarChartViewContent)
                }
                .padding(.horizontal)
            
                Chart {
                 
                    // 1. BarMark (The event duration)
                    ForEach(snoreEvents) { event in
                        if let start = event.startTime, let end = event.endTime {
                            //debug print
                            let _ = print("Event: \(event.startTime?.description ?? "N/A") to \(event.endTime?.description ?? "N/A"), Confidence: \(event.averageConfidence)")
                            
                            let duration = end.timeIntervalSince(start)
                            let minDuration: TimeInterval = 60 // Force every bar to be at least 60 seconds wide
                            let displayEnd = duration < minDuration ? start.addingTimeInterval(minDuration) : end

                            
                            BarMark(
                                xStart: .value("Start Time", start),
                                xEnd: .value("End Time", displayEnd), // Use the adjusted end time
                                y: .value("Average Confidence", event.averageConfidence)
                            )
                            // MARK: - COLORING CHANGE HERE
                            .annotation(position: .overlay, alignment: .bottom) {
                                if event.averageConfidence > 0.3 {
                                    Text(String(format: "%.0f%%", event.averageConfidence * 100))
                                        .font(.caption2)
                                        .foregroundStyle(.black) // Keep text white for readability
                                }
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .yellow, .green],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel() {
                            if let date = value.as(Date.self) {
                                Text(SnoreEventBarChartViewContent.timeFormatter.string(from: date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let confidence = value.as(Double.self) {
                                Text(String(format: "%.0f%%", confidence * 100))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...1.0)
                .padding()
                .background(Color.gray.opacity(0.1))
                
            }
        }
        .frame(minHeight: 300) // Give it some breathing room
        .layoutPriority(1)
    }


}
