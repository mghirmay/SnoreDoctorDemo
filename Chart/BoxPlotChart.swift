//
//  BoxPlotChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


// BoxPlotChart.swift
import SwiftUI
import Charts

struct BoxPlotChart: View {
    let data: [Double]
    let title: String
    var yLabel: String? // Optional y-axis label

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)

            if data.isEmpty {
                Text("No data for this box plot.")
                    .foregroundColor(.gray)
            } else {
                Chart {
                    // For a true box plot, you'd typically calculate quartiles (Q1, Q2/median, Q3), min, max.
                    // The Charts framework doesn't have a direct "BoxPlotMark".
                    // You would typically simulate it with RuleMark for whiskers, RectangleMark for the box,
                    // and PointMark for median/outliers.
                    // For simplicity, let's just show a distribution or a simple bar for now.
                    // A proper box plot requires statistical calculation.

                    // For a simple histogram-like distribution if a true box plot is complex:
                    // Using a histogram for distribution, not a true box plot in Charts directly.
                    // For a real box plot, you'd calculate statistics (min, max, quartiles) and use RuleMarks and RectangleMarks.
                    // For demonstration, let's just show individual points or a simplified representation.

                    // A more appropriate approach for "Box Plot" is to calculate statistics
                    // (min, Q1, median, Q3, max) and use RuleMarks and RectangleMarks.
                    // For now, let's just visualize the data points if a true box plot isn't feasible with direct marks.

                    // If you want to show individual data points on a pseudo-boxplot
                    ForEach(data.indices, id: \.self) { index in
                        PointMark(
                            x: .value("Index", Double(index)), // Or some category
                            y: .value("Value", data[index])
                        )
                    }
                    // A proper box plot would involve more complex statistical calculations
                    // and combining RuleMark and RectangleMark.
                    // e.g., RuleMark(y: .value("Q1", q1)...)
                }
                .chartYAxis {
                    if let yLabel = yLabel {
                        AxisMarks {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(yLabel)
                        }
                    }
                }
                .chartXAxis(.hidden) // Box plots often don't have a meaningful X-axis from individual data points
            }
        }
    }
}