//
//  AudioEventHistogramView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 01.07.25.
//
import Foundation
import SwiftUI
import Charts // Requires iOS 16+
import CoreData

// MARK: - Audio Event Histogram View
struct AudioEventHistogramView: View {
    let soundEvents: [SoundEvent]
    let sleepSessions: [RecordingSession]

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(soundEvents) { event in
                    if let timestamp = event.timestamp {
                        let eventType = SoundEventType.from(rawValue: event.name)

                        BarMark(
                            x: .value("Time", timestamp, unit: .hour),
                            y: .value("Count", 1)
                        )
                        .foregroundStyle(by: .value("Type", eventType.rawValue))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                }
            }
            .chartYAxis(.hidden)
            .chartBackground { proxy in
                GeometryReader { geometry in
                    let plotFrame = geometry[proxy.plotAreaFrame] // resolve anchor here

                    ZStack(alignment: .leading) {
                        ForEach(sleepSessions) { session in
                            if let start = session.startTime, let end = session.endTime {
                                let startX = proxy.position(forX: start) ?? 0
                                let endX = proxy.position(forX: end) ?? 0
                                let width = max(0, endX - startX)
                                let offsetX = startX - plotFrame.origin.x

                                Rectangle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: width, height: geometry.size.height)
                                    .offset(x: offsetX)
                            }
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: SoundEventType.allCases.map { $0.rawValue }
            )
            .chartLegend(position: .bottom, alignment: .center)
        } else {
            Text("Charts are only available on iOS 16 and above.")
                .foregroundColor(.red)
        }
    }
}
