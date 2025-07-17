//
//  SettingSliderDouble.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.07.25.
//

import SwiftUI


struct SettingSliderDouble: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minLabel: String
    let maxLabel: String
    let valueFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(valueFormatter(value))
                .font(.subheadline)
                .foregroundColor(.gray)

            Slider(
                value: $value,
                in: range,
                step: step
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
