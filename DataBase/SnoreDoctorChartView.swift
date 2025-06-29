//
//  SnoreDoctorChartView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 24.06.25.
//



import SwiftUI
import Charts // Import the Charts framework for Swift Charts

struct SnoreDoctorChartView: View {
    
    // Environment value to dismiss the view
    @Environment(\.dismiss) var dismiss // ADD THIS LINE
    
    // Fetches all SoundEvent objects from Core Data
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
        animation: .default)
    private var soundEvents: FetchedResults<SoundEvent>

    // MARK: - Data Aggregation for Chart 
    // This computed property transforms the raw Core Data results into chart-friendly data
    var aggregatedChartData: [SoundEventCount] {
        let counts = soundEvents.reduce(into: [String: Int]()) { result, event in
            result[event.name ?? "Unknown", default: 0] += 1
        }
        return counts.map { SoundEventCount(name: $0.key, count: $0.value) }
                     .sorted { $0.count > $1.count } // Sort by count for better visualization
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Sound Event Occurrences")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)

                if aggregatedChartData.isEmpty {
                    ContentUnavailableView("No Sound Data Yet", systemImage: "chart.bar.fill", description: Text("Start analyzing sounds to see your chart here."))
                } else {
                    // Use ResponsiveContainer concept for flexible sizing if this were HTML/React.
                    // In SwiftUI, Chart naturally adapts to its parent frame.
                    Chart(aggregatedChartData, id: \.name) { dataPoint in
                        BarMark(
                            x: .value("Event", dataPoint.name),
                            y: .value("Count", dataPoint.count)
                        )
                        .foregroundStyle(by: .value("Event", dataPoint.name)) // Color bars by event name
                        .annotation(position: .top) { // Display count on top of bars
                            Text("\(dataPoint.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(preset: .automatic) { value in
                            AxisValueLabel()
                            AxisGridLine()
                        }
                    }
                    .padding()
                    .frame(height: 300) // Set a fixed height for the chart
                }

                Spacer() // Pushes content to the top

                // Optional: A list of all raw events for debugging/review
                List {
                    Section("Raw Sound Events") {
                        ForEach(soundEvents) { event in
                            VStack(alignment: .leading) {
                                Text("Event: \(event.name ?? "N/A")")
                                    .font(.headline)
                                Text("Confidence: \(event.confidence, specifier: "%.2f")%")
                                    .font(.subheadline)
                                Text("Timestamp: \(event.timestamp ?? Date(), formatter: Self.dateFormatter)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                        }
                        .onDelete(perform: deleteSoundEvents) // Allow deleting events
                    }
                }
                .frame(maxHeight: .infinity) // Allow list to expand
            }
            .navigationTitle("Sound Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Helper struct for chart data aggregation
    struct SoundEventCount: Identifiable {
        let id = UUID() // Required for Identifiable
        let name: String
        let count: Int
    }

    // Date formatter for display
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    // MARK: - Core Data Deletion
    private func deleteSoundEvents(offsets: IndexSet) {
        withAnimation {
            offsets.map { soundEvents[$0] }.forEach(PersistenceController.shared.container.viewContext.delete)
            PersistenceController.shared.save()
        }
    }
}

