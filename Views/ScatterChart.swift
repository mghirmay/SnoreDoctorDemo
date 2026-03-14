//
//  ScatterChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


import SwiftUI
import Charts

struct ScatterChart: View {
    let data: [(x: Double, y: Double, label: String)]
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
                    ForEach(data.indices, id: \.self) { i in
                        let point = data[i]
                        PointMark(
                            x: .value(xLabel, point.x),
                            y: .value(yLabel, point.y)
                        )
                        .foregroundStyle(by: .value("Label", point.label))
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(String(format: "%.1f", value.as(Double.self) ?? 0))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(String(format: "%.1f", value.as(Double.self) ?? 0))
                    }
                }
                .chartLegend(.hidden)
            }
        }
    }
}
