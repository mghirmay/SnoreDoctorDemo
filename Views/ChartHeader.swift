//
//  ChartHeader.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import SwiftUI

/// Unified header used by all chart types.
/// Title on the left, help button on the right.
// Unified header used by all chart types.
/// Title on the left, help button on the right.
struct ChartHeader: View {
    let title: String
    let helpInfo: HelpDefinition

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            HelpPopoverButton(info: helpInfo)
        }
    }
}

/// Unified empty-state used by all chart types.
struct ChartEmptyState: View {
    var body: some View {
        HStack {
            Spacer()
            Text("No data available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 40)
    }
}
