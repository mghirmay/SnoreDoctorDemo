//
// SleepReportView.swift
// SnoreDoctorDemo
//
// Created by musie Ghirmay on 30.06.25.
//

import SwiftUI
import Charts // Requires iOS 16+
import CoreData

struct SleepReportView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var sleepDataManager: SleepDataManager

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date()) // Initialize to start of today

    // Initialize SleepDataManager with the viewContext from PersistenceController
    init() {
        // Use PersistenceController.shared.container.viewContext for the main app
        _sleepDataManager = StateObject(wrappedValue: SleepDataManager(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Calendar
                CalendarView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    sleepDataManager: sleepDataManager
                )
                .padding()

                Divider()
                    .padding(.vertical, 5)

                // MARK: - Daily Report for Selected Date
                DailySleepReportView(
                    selectedDate: selectedDate,
                    sleepDataManager: sleepDataManager
                )
                .padding()

                Spacer()
            }
            .navigationTitle("Sleep Report")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Optional: Load dummy data only if no sessions exist
                // Wrap in #if DEBUG to prevent this in production builds
                #if DEBUG
                let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
                do {
                    let count = try viewContext.count(for: fetchRequest)
                    if count == 0 {
                        print("No existing sessions found, loading dummy data for SleepReportView.")
                        sleepDataManager.loadDummyCoreData()
                    } else {
                        print("Existing sessions found (\(count)), skipping dummy data load in SleepReportView.")
                    }
                } catch {
                    print("Error checking for existing sessions: \(error)")
                }
                #endif
            }
        }
    }
}

// MARK: - Calendar View (Re-using the previous structure, adjusted for Core Data)

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @ObservedObject var sleepDataManager: SleepDataManager // Now an ObservedObject for dynamic updates

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy" // Corrected format to show year clearly
        return formatter
    }()

    var body: some View {
        VStack {
            // Month navigation
            HStack {
                Button(action: {
                    changeMonth(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .accessibilityLabel("Previous Month")
                }
                Spacer()
                Text(dateFormatter.string(from: currentMonth))
                    .font(.headline)
                Spacer()
                Button(action: {
                    changeMonth(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .accessibilityLabel("Next Month")
                }
            }
            .padding(.bottom, 5)

            // Weekday Headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Days Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if calendar.isDate(date, equalTo: currentMonth, toGranularity: .month) {
                        dayCell(date: date)
                    } else {
                        Text("") // Empty cell for days outside current month
                    }
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let sleepDuration = sleepDataManager.calculateDailySleepDuration(for: date)
        let color = colorForSleepDuration(sleepDuration)
        let hasData = sleepDuration > 0 // Determines if there's any sleep data for the day

        return ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
                .frame(width: 30, height: 30)

            Text("\(calendar.component(.day, from: date))")
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(hasData ? 1.0 : 0.5) // Dim days without data
            
            if hasData {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .offset(x: 10, y: 10) // Position the color dot
            }
        }
        .frame(width: 40, height: 40) // Ensure consistent cell size
        .contentShape(Rectangle()) // Make the whole cell tappable
        .onTapGesture {
            selectedDate = date
        }
    }

    private func daysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let startOfMonth = monthInterval.start
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1 for Sunday, 2 for Monday
        let daysToPrepend = (firstWeekday - calendar.firstWeekday + 7) % 7 // Days from previous month

        var days: [Date] = []
        if let startDate = calendar.date(byAdding: .day, value: -daysToPrepend, to: startOfMonth) {
            for i in 0..<42 { // Display 6 weeks for consistency (always show full 6 rows)
                if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                    days.append(date)
                }
            }
        }
        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func colorForSleepDuration(_ duration: TimeInterval) -> Color {
        // Assuming duration is in hours here, as per your formatting in DailySleepReportView
        if duration < 4 {
            return .red
        } else if duration < 6 {
            return .yellow
        } else {
            return .green
        }
    }
}


// MARK: - Daily Sleep Report View

struct DailySleepReportView: View {
    let selectedDate: Date
    @ObservedObject var sleepDataManager: SleepDataManager // Now an ObservedObject
    
    // Fetch RecordingSessions for the selected date using Core Data
    private var recordingSessionsForSelectedDay: [RecordingSession] {
        sleepDataManager.fetchRecordingSessions(for: selectedDate)
    }
    
    // Calculate daily sleep duration using the data manager
    private var dailySleepDuration: TimeInterval {
        sleepDataManager.calculateDailySleepDuration(for: selectedDate)
    }

    private var sleepDurationColor: Color {
        if dailySleepDuration < 4 {
            return .red
        } else if dailySleepDuration < 6 {
            return .yellow
        } else {
            return .green
        }
    }
    
    // Aggregate all SoundEvents for the selected day from all relevant sessions
    private var allSoundEventsForSelectedDay: [SoundEvent] {
        var events: [SoundEvent] = []
        for session in recordingSessionsForSelectedDay {
            events.append(contentsOf: sleepDataManager.fetchSoundEvents(for: session))
        }
        return events
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // FIX: Use modern Date.FormatStyle for cleaner date formatting
            Text("Report for \(selectedDate, format: .dateTime.day().month(.abbreviated).year(.defaultDigits))")
                .font(.title2)
                .bold()

            HStack {
                Text("Total Sleep:")
                Spacer()
                Text(String(format: "%.1f hours", dailySleepDuration))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(sleepDurationColor)
            }
            
            Text("Audio Events Throughout Sleep")
                .font(.headline)
            
            if allSoundEventsForSelectedDay.isEmpty {
                Text("No audio events recorded for this day.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                AudioEventHistogramView(
                    soundEvents: allSoundEventsForSelectedDay,
                    sleepSessions: recordingSessionsForSelectedDay // Pass the sessions for background highlight
                )
                .frame(height: 200) // Set a fixed height for the histogram
            }
        }
    }
}

// MARK: - Audio Event Histogram View
struct AudioEventHistogramView: View {
    let soundEvents: [SoundEvent]
    let sleepSessions: [RecordingSession]

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(soundEvents) { event in
                    if let timestamp = event.timestamp {
                        let eventType = SoundEventType.from(rawValue: event.name)

                        BarMark(
                            x: .value("Time", timestamp, unit: .hour),
                            y: .value("Count", 1)
                        )
                        .foregroundStyle(by: .value("Type", eventType.rawValue))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                }
            }
            .chartYAxis(.hidden)
            .chartBackground { proxy in
                GeometryReader { geometry in
                    let plotFrame = geometry[proxy.plotAreaFrame] // resolve anchor here

                    ZStack(alignment: .leading) {
                        ForEach(sleepSessions) { session in
                            if let start = session.startTime, let end = session.endTime {
                                let startX = proxy.position(forX: start) ?? 0
                                let endX = proxy.position(forX: end) ?? 0
                                let width = max(0, endX - startX)
                                let offsetX = startX - plotFrame.origin.x

                                Rectangle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: width, height: geometry.size.height)
                                    .offset(x: offsetX)
                            }
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: SoundEventType.allCases.map { $0.rawValue }
            )
            .chartLegend(position: .bottom, alignment: .center)
        } else {
            Text("Charts are only available on iOS 16 and above.")
                .foregroundColor(.red)
        }
    }
}
