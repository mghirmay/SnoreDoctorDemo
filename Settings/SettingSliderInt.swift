
//
//  SettingSliderInt.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI

struct SettingSliderInt: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let minLabel: String
    let maxLabel: String
    let valueFormatter: (Int) -> String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(valueFormatter(value))
                .font(.subheadline)
                .foregroundColor(.gray)

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        let steppedValue = Int((newValue / Double(step)).rounded()) * step
                        value = min(max(steppedValue, range.lowerBound), range.upperBound)
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            ) {
                // Change this from Text(title) to EmptyView()
                EmptyView()
            } minimumValueLabel: {
                Text(minLabel)
            } maximumValueLabel: {
                Text(maxLabel)
            }
        }
        .padding(.vertical, 5)
        .tint(Color("AppColor"))
    }
}
