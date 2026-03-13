//
//  SessionDetailView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 16.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData
import Charts // Make sure Charts is imported here


enum ChartMode: String, CaseIterable, Identifiable {
    case events = "Events"
    case trend = "Trend"
    case heatmap = "Density"
    
    var id: String { self.rawValue }
}

struct SessionDetailReport: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var session: RecordingSession
    @State private var selectedMode: ChartMode = .events
    
    var body: some View {
        NavigationView {
            // Use a VStack instead of ScrollView to allow "filling" the screen
            VStack(spacing: 0) {
                
                // 1. Top Section: Session Details & Notes
                // We keep this at its natural height
                EditNotesContentView(session: session)
                    .padding(.bottom)
                
                Divider()

                // 2. Bottom Section: The Chart
                VStack(alignment: .leading, spacing: 10) {
                    Text("Snore Events Chart")
                        .font(.headline)
                        .padding([.horizontal, .top])

                    Picker("Chart View", selection: $selectedMode) {
                                    ForEach(ChartMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding()
                    
                    // Conditional rendering based on mode
                        switch selectedMode {
                            case .events:
                                SnoreEventBarChartViewContent(session: session)
                                // This allows the chart to grow and fill all available space
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.1), radius: 4)
                                .padding([.horizontal, .bottom])
                            case .trend:
                                SnoreTrendLineChartView(session: session)
                            case .heatmap:
                                SnoreHeatmapView(session: session)
                        }
                   
                        
                }
                // layoutPriority ensures the Chart is the one to expand
                // if there is a conflict for space
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

// Small helper view for the stats
struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.headline).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}


struct EditNotesContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var session: RecordingSession
    @State private var notesText: String = ""

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // --- SESSION INFO SECTION ---
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? "Untitled Session")
                    .font(.title3)
                    .bold()
                
                if let startTime = session.startTime {
                    Label("\(startTime, formatter: Self.dateFormatter)", systemImage: "play.circle")
                }
                
                if let endTime = session.endTime {
                    Label("\(endTime, formatter: Self.dateFormatter)", systemImage: "stop.circle")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Divider()

            // --- STATS GRID ---
            HStack(spacing: 15) {
                StatItem(label: "Snores", value: "\(session.totalSnoreEvents)", color: .orange)
                StatItem(label: "Related", value: "\(session.totalSnoreRelated)", color: .blue)
                StatItem(label: "Other", value: "\(session.totalNonSnoreEvents)", color: .gray)
            }

            Divider()

            // --- NOTES SECTION ---
            Text("Notes")
                .font(.caption)
                .bold()
                .textCase(.uppercase)
                .foregroundColor(.secondary)

            TextEditor(text: $notesText)
                .frame(minHeight: 150) // Ensures it doesn't collapse to 0
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .padding()
        .onAppear {
            notesText = session.notes ?? ""
        }
        .onDisappear {
            if notesText != session.notes {
                session.notes = notesText
                PersistenceController.shared.save()
            }
        }
    }
}



