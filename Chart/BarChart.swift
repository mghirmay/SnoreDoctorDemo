//
//  BarChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


// BarChart.swift
import SwiftUI
import Charts

struct BarChart: View {
    let data: [String: Int] // Dictionary for category-value pairs
    let title: String
    var xLabel: String?
    var yLabel: String?

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)

            if data.isEmpty {
                Text("No data for this bar chart.")
                    .foregroundColor(.gray)
            } else {
                Chart {
                    ForEach(data.sorted(by: { $0.key < $1.key }), id: \.key) { category, count in
                        BarMark(
                            x: .value(xLabel ?? "Category", category),
                            y: .value(yLabel ?? "Count", count)
                        )
                        .annotation(position: .top) {
                            Text("\(count)").font(.caption2)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(xLabel ?? "Category")
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(yLabel ?? "Count")
                    }
                }
            }
        }
    }
}