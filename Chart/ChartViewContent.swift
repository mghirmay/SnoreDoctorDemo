//
//  ChartViewContent.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//


// ChartViewContent.swift
import SwiftUI
import Charts
import CoreData // Assuming you need this for SoundEvent

struct ChartViewContent: View {
    let soundEvents: FetchedResults<SoundEvent>
    // The markerColor closure's signature needs to match what you pass from SnoreDoctorChartView.
    // If SnoreDoctorChartView passes `chartMarkerColor(for:)`, its signature depends on which option above you chose.
    // Let's assume Option B for flexibility, where it still takes String?.
    let markerColor: (String?) -> Color // This signature remains the same as before if you use Option B for chartMarkerColor
    let formatTimeInterval: (TimeInterval) -> String

    // Helper to get all event type raw values for chart domains
    private var allSoundEventNames: [String] {
        SoundEventType.allCases.map { $0.rawValue }
    }

    var body: some View {
        if soundEvents.isEmpty {
            ContentUnavailableView("No Sound Events", systemImage: "waveform.badge.exclamationmark")
                .frame(height: 300)
        } else {
            let firstTimestamp = soundEvents.first?.timestamp ?? Date()

            Chart {
                ForEach(soundEvents) { event in
                    if event.confidence > AppSettings.defaultSnoreConfidenceThreshold  {
                        if let timestamp = event.timestamp,
                           let rawName = event.name, // Get the raw string
                           !rawName.isEmpty, // <-- Add this check!
                           
                            
                            let confidence = event.confidence as? Double {
                            
                            let name = SoundEventType.from(rawValue: rawName).rawValue
                            
                            if rawName == "snoring" {
                                
                                
                                let elapsedTime = timestamp.timeIntervalSince(firstTimestamp)
                                
                                
                                BarMark (
                                    x: .value("Time", elapsedTime),
                                    y: .value("Confidence", confidence)
                                )
                                .symbol(by: .value("Event Type", name))
                                .foregroundStyle(by: .value("Event Type", name))
                                
                                .annotation(position: .overlay, alignment: .bottom) {
                                    Text(name)
                                        .font(.caption2)
                                        .foregroundColor(markerColor(name)) // Still uses the closure
                                        .background(Color.white.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartSymbolScale(
                // Use the allSoundEventNames array
                domain: allSoundEventNames,
                range: [.square, .square, .square, .square,
                        .circle, .circle,
                        .triangle, .triangle,
                        .diamond,
                        .cross,
                        .plus]
            )
            .chartForegroundStyleScale(domain: allSoundEventNames) { value in
                markerColor(value) // Still uses the closure
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let interval = value.as(TimeInterval.self) {
                            Text(formatTimeInterval(interval))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(String(format: "%.0f%%", (value.as(Double.self) ?? 0) * 100))
                }
            }
            .padding()
            .frame(height: 300)
        }
    }
}



// You can now remove SoundEventPointMark struct, as its logic is inlined.
// Or, if you keep it, it should conform to ChartContent (more advanced)
/*
// If you *really* wanted a separate helper for the PointMark,
// it would need to return ChartContent. This is more complex
// and often not necessary for simple PointMarks like this.
//
// For example, if SoundEventPointMark was like this:
struct SoundEventPointMark: ChartContent {
    let event: SoundEvent
    let firstTimestamp: Date
    let markerColor: (String?) -> Color

    var body: some ChartContent { // Returns ChartContent
        if let timestamp = event.timestamp,
           let name = event.name,
           let confidence = event.confidence as? Double {

            let elapsedTime = timestamp.timeIntervalSince(firstTimestamp)

            PointMark(
                x: .value("Time", elapsedTime),
                y: .value("Confidence", confidence)
            )
            .symbol(by: .value("Event Type", name))
            .foregroundStyle(by: .value("Event Type", name))
            .annotation(position: .overlay, alignment: .bottom) {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(markerColor(name))
                    .background(Color.white.opacity(0.8))
                    .clipShape(Capsule())
            }
        } else {
            // You MUST return something even if the 'if let' fails
            // An EmptyChartContent or similar. For Chart, usually best
            // to keep the conditional directly in the Chart body.
             EmptyChartContent() // Not a standard type, illustrates the need
        }
    }
}
*/
