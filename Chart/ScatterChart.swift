//
//  ScatterChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


// ScatterChart.swift
import SwiftUI
import Charts

struct ScatterChart: View {
    // Data is a tuple of (x: Double, y: Double, label: String) for scatter plots
    let data: [(x: Double, y: Double, label: String)]
    let title: String
    let xLabel: String
    let yLabel: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)

            if data.isEmpty {
                Text("No data for this scatter chart.")
                    .foregroundColor(.gray)
            } else {
                Chart {
                    ForEach(data.indices, id: \.self) { index in
                        let point = data[index]
                        PointMark(
                            x: .value(xLabel, point.x),
                            y: .value(yLabel, point.y)
                        )
                        .foregroundStyle(by: .value("Label", point.label)) // Optional: color by label
                        .annotation(position: .overlay, alignment: .bottom) {
                            // You might want to show labels on tap rather than all at once if many points
                            // Text(point.label).font(.caption2)
                        }
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
                .chartLegend(.hidden) // Or .visible depending on if you style by label
            }
        }
    }
}