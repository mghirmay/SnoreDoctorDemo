// ChartViewContent.swift

import SwiftUI
import Charts
import CoreData // Make sure to import CoreData for SnoreEvent

struct ChartViewContent: View {
    // This property needs to be a direct 'let' or 'var' to receive FetchedResults
    // Do NOT use @Binding or @State here for 'snoreEvents'
    let snoreEvents: FetchedResults<SnoreEvent>
    let sessionStartTime: Date?
    let markerColor: (Double) -> Color
    let formatTimeInterval: (TimeInterval) -> String

    var body: some View {
        if snoreEvents.isEmpty {
            ContentUnavailableView("No Snore Events", systemImage: "waveform.badge.exclamationmark")
                .frame(height: 300)
        } else {
            let referenceStartTime = sessionStartTime ?? snoreEvents.first?.startTime ?? Date()

            Chart {
                ForEach(snoreEvents, id: \.self) { event in
                    if let eventStartTime = event.startTime {
                        let elapsedTime = eventStartTime.timeIntervalSince(referenceStartTime)

                        BarMark(
                            x: .value("Time", elapsedTime),
                            y: .value("Snore Score", event.snoreScore)
                        )
                        .foregroundStyle(markerColor(event.snoreScore))
                        .annotation(position: .overlay, alignment: .bottom) {
                            Text(String(format: "%.1f", event.snoreScore))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .background(markerColor(event.snoreScore).opacity(0.8))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
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
