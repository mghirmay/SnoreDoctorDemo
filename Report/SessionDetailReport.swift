//
//  SessionDetailView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 16.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts

enum ChartMode: String, CaseIterable, Identifiable {
    case events  = "Events"
    case trend   = "Trend"
    case heatmap = "Density"
    var id: String { rawValue }
}

struct SessionDetailReport: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var session: RecordingSession
    @State private var selectedMode: ChartMode = .events

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: - Session info + notes
                EditNotesContentView(session: session)
                    .padding(.bottom)

                Divider()

                // MARK: - Chart area
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Chart View", selection: $selectedMode) {
                        ForEach(ChartMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    Group {
                        switch selectedMode {
                        case .events:  SnoreEventBarChartView(session: session)
                        case .trend:   SnoreTrendLineChartView(session: session)
                        case .heatmap: SnoreHeatmapView(session: session)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .layoutPriority(1)
            }
            .navigationTitle(session.title ?? "Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}


