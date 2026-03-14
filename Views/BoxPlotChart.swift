//
//  BoxPlotChart.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.07.25.
//


import SwiftUI
import Charts

struct BoxPlotChart: View {
    let data: [Double]
    let title: String
    let xLabel: String?
    let yLabel: String?

    init(data: [Double], title: String, helpInfo: HelpDefinition, xLabel: String? = nil, yLabel: String? = nil) {
        self.data = data
        self.title = title
        self.xLabel = xLabel
        self.yLabel = yLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChartHeader(title: title, helpInfo: HelpDataFactory.boxPlotChart)

            if data.isEmpty {
                ChartEmptyState()
            } else {
                let stats = boxPlotStats(for: data)
                Chart {
                    RuleMark(
                        x: .value("Category", "Distribution"),
                        yStart: .value("Min", stats.min),
                        yEnd: .value("Max", stats.max)
                    )
                    .foregroundStyle(.blue.opacity(0.6))

                    RectangleMark(
                        x: .value("Category", "Distribution"),
                        yStart: .value("Q1", stats.q1),
                        yEnd: .value("Q3", stats.q3)
                    )
                    .foregroundStyle(.blue.opacity(0.3))

                    RuleMark(y: .value("Median", stats.median))
                        .annotation(position: .trailing) {
                            Text(String(format: "%.2f", stats.median))
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.blue)
                }
                .chartYAxisLabel(yLabel ?? "")
                .chartXAxisLabel(xLabel ?? "")
                .chartPlotStyle { plot in
                    plot.frame(minHeight: 200)
                }
            }
        }
    }

    func boxPlotStats(for values: [Double]) -> (min: Double, q1: Double, median: Double, q3: Double, max: Double) {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return (0, 0, 0, 0, 0) }
        let count = sorted.count

        func quantile(_ q: Double) -> Double {
            let pos = q * Double(count - 1)
            let lower = Int(floor(pos))
            let upper = Int(ceil(pos))
            if lower == upper { return sorted[lower] }
            return sorted[lower] + (pos - Double(lower)) * (sorted[upper] - sorted[lower])
        }

        return (
            min: sorted.first ?? 0,
            q1: quantile(0.25),
            median: quantile(0.5),
            q3: quantile(0.75),
            max: sorted.last ?? 0
        )
    }
}
