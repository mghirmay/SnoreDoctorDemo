//
//  LineChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


// LineChart.swift
import SwiftUI
import Charts

struct LineChart: View {
    // Data is a tuple of (Date, Double) for time-series data
    let data: [(Date, Double)]
    let title: String
    let xLabel: String
    let yLabel: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)

            if data.isEmpty {
                Text("No data for this line chart.")
                    .foregroundColor(.gray)
            } else {
                Chart {
                    ForEach(data.sorted(by: { $0.0 < $1.0 }), id: \.0) { date, value in // Sort by date
                        LineMark(
                            x: .value(xLabel, date),
                            y: .value(yLabel, value)
                        )
                        .interpolationMethod(.catmullRom) // Smooth line
                        .symbol(.circle) // Add markers for each point
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
                        AxisValueLabel(String(format: "%.1f", value.as(Double.self) ?? 0)) // Format Y-axis values
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Example: "14:30"
        return formatter.string(from: date)
    }
}