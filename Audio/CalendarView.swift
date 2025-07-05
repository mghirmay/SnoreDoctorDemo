//
//  CalendarView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 01.07.25.
//

import Foundation
import SwiftUI
import Charts // Requires iOS 16+
import CoreData

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
        let sleepDurationInHours = Int(duration) / 3600
        // Assuming duration is in hours here, as per your formatting in DailySleepReportView
        if sleepDurationInHours < 4 {
            return .red
        } else if sleepDurationInHours < 6 {
            return .yellow
        } else {
            return .green
        }
    }
}
