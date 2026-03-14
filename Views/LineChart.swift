//
//  LineChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//

import SwiftUI
import Charts

struct LineChart: View {
    let data: [(Date, Double)]
    let title: String
    let helpInfo: HelpDefinition
    let xLabel: String
    let yLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChartHeader(title: title, helpInfo: helpInfo)

            if data.isEmpty {
                ChartEmptyState()
            } else {
                Chart {
                    ForEach(data.sorted(by: { $0.0 < $1.0 }), id: \.0) { date, value in
                        LineMark(
                            x: .value(xLabel, date),
                            y: .value(yLabel, value)
                        )
                        .interpolationMethod(.catmullRom)
                        .symbol(.circle)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(formatDate(value.as(Date.self)))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(String(format: "%.1f", value.as(Double.self) ?? 0))
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
