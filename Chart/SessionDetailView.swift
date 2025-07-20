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

struct SessionDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // For dismissing the sheet

    @ObservedObject var session: RecordingSession

    var body: some View {
        NavigationView { // Embed in a NavigationView to get the toolbar and title
            ScrollView { // Use ScrollView for overall scrolling
                VStack(spacing: 20) { // Arrange content vertically
                    // Section for Notes and Session Details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Session Notes & Details")
                            .font(.headline)
                            .padding(.horizontal) // Match List's default padding

                        EditNotesContentView(session: session)
                            .frame(minHeight: 250) // Give notes content a good minimum height
                                                  // This is crucial for TextEditor
                            .background(Color(.systemBackground)) // Match overall background
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                    }

                    // Section for Snore Events Chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Snore Events Chart")
                            .font(.headline)
                            .padding(.horizontal) // Match List's default padding

                        SnoreEventBarChartViewContent(session: session)
                            .frame(height: 350) // Chart needs a fixed height
                            .background(Color(.systemBackground)) // Match overall background
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                    }

                    Spacer() // Pushes content to the top
                }
                .padding(.vertical) // Add some vertical padding around the whole content
            }
            .navigationTitle(session.title ?? "Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // The onDisappear in EditNotesContentView handles saving.
                        // Just dismiss the view here.
                        dismiss()
                    }
                }
            }
        } // End of NavigationView
    }
}

// MARK: - Extracted Content Views

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
        VStack(alignment: .leading, spacing: 8) { // Reduced spacing for a more compact look
            Group {
                Text("Title: \(session.title ?? "Untitled Session")")
                if let startTime = session.startTime {
                    Text("Started: \(startTime, formatter: Self.dateFormatter)")
                }
                if let endTime = session.endTime {
                    Text("Ended: \(endTime, formatter: Self.dateFormatter)")
                }
                Text("Snore Events: \(session.totalSnoreEvents)")
                Text("Snore Related: \(session.totalSnoreRelated)")
                Text("Other Events: \(session.totalNonSnoreEvents)")
            }
            .font(.subheadline)
            // No horizontal padding here, parent will handle it.

            Divider()

            TextEditor(text: $notesText)
                .scrollContentBackground(.hidden) // Hide default background for better control
                .background(Color.clear) // Ensure the TextEditor's own background is clear
                .padding(5) // Inner padding for text within the editor's frame
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Add a border
                )
                .fixedSize(horizontal: false, vertical: true) // Allow TextEditor to determine its ideal height based on content
                .frame(minHeight: 150) // Fallback min height if content is short
                .autocapitalization(.sentences)
                .disableAutocorrection(false)

        }
        // No top/bottom padding here, parent will handle it to allow it to grow
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


struct SnoreEventBarChartViewContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var session: RecordingSession

    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // e.g., 22:30, 01:45
        return formatter
    }()

    init(session: RecordingSession) {
        self.session = session
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        VStack {
            if snoreEvents.isEmpty {
                ContentUnavailableView {
                    Label("No Snore Events", systemImage: "sparkles.square.dashed")
                } description: {
                    Text("This session has no recorded snore events.")
                }
            } else {
                Chart {
                    ForEach(snoreEvents) { event in
                        if let start = event.startTime, let end = event.endTime {
                            BarMark(
                                xStart: .value("Start Time", start),
                                xEnd: .value("End Time", end),
                                y: .value("Average Confidence", event.averageConfidence)
                            )
                            // MARK: - COLORING CHANGE HERE
                            .foregroundStyle(colorForConfidence(event.averageConfidence))
                            .annotation(position: .overlay, alignment: .bottom) {
                                if event.averageConfidence > 0.3 {
                                    Text(String(format: "%.0f%%", event.averageConfidence * 100))
                                        .font(.caption2)
                                        .foregroundStyle(.white) // Keep text white for readability
                                }
                            }
                            .interpolationMethod(.stepStart)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel() {
                            if let date = value.as(Date.self) {
                                Text(SnoreEventBarChartViewContent.timeFormatter.string(from: date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let confidence = value.as(Double.self) {
                                Text(String(format: "%.0f%%", confidence * 100))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...1.0)
                .padding()
            }
        }
    }

    // MARK: - New Color Function
    private func colorForConfidence(_ confidence: Double) -> Color {
        // Map confidence (0.0 to 1.0) to a hue value (e.g., 0.0 to 0.33 for red to green in HSB)
        // A common approach is to interpolate between colors.
        // Let's create a red-yellow-green gradient.

        let clampedConfidence = max(0.0, min(1.0, confidence)) // Ensure value is between 0 and 1

        // Interpolate between Red (0,1,1) -> Yellow (1,1,0) -> Green (0,1,0) for Hue
        // HSB: Hue, Saturation, Brightness.
        // Red is around 0.0 hue, Green is 0.33 hue, Blue is 0.66 hue.
        // We want to go from Red (0.0 hue) towards Green (0.33 hue).

        let hue: Double
        if clampedConfidence <= 0.5 {
            // From Red (hue 0) to Yellow (hue 0.166)
            hue = 0.166 * clampedConfidence * 2 // Scale 0-0.5 to 0-1 for interpolation, then map to 0-0.166
        } else {
            // From Yellow (hue 0.166) to Green (hue 0.333)
            hue = 0.166 + (0.167 * (clampedConfidence - 0.5) * 2) // Scale 0.5-1.0 to 0-1 for interpolation, then map to 0.166-0.333
        }

        // Simpler approach: interpolate directly using RGB components.
        // (R, G, B)
        // Red: (1.0, 0.0, 0.0) -> Low Confidence
        // Yellow: (1.0, 1.0, 0.0) -> Mid Confidence
        // Green: (0.0, 1.0, 0.0) -> High Confidence

        var red: Double = 0.0
        var green: Double = 0.0
        var blue: Double = 0.0

        if clampedConfidence < 0.5 {
            // From Red to Yellow
            red = 1.0
            green = clampedConfidence * 2.0 // Green goes from 0.0 to 1.0 as confidence goes from 0.0 to 0.5
            blue = 0.0
        } else {
            // From Yellow to Green
            red = 1.0 - ((clampedConfidence - 0.5) * 2.0) // Red goes from 1.0 to 0.0 as confidence goes from 0.5 to 1.0
            green = 1.0
            blue = 0.0
        }

        return Color(red: red, green: green, blue: blue)
    }

    // Removed the old confidenceLevel function as it's no longer used for coloring
    /*
    private func confidenceLevel(for confidence: Double) -> String {
        if confidence >= 0.8 {
            return "Very High"
        } else if confidence >= 0.5 {
            return "High"
        } else if confidence >= 0.2 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    */
}
