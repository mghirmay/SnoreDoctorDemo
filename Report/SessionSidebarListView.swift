//
//  SessionSidebarList.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 22.02.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//
import Foundation
import SwiftUI
import Charts // Requires iOS 16+
import CoreData

struct SessionSidebarListView: View {
    @EnvironmentObject var soundDataManager: SoundDataManager
    let selectedDate: Date
    
    var body: some View {
        // We fetch the sessions specific to the date selected in the calendar
        let sessions = soundDataManager.fetchRecordingSessions(for: selectedDate)
        
        if sessions.isEmpty {
            // This fills the space with a helpful message if no data exists
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "moon.zzz")
                    .font(.largeTitle)
                    .foregroundColor(.gray.opacity(0.4))
                Text("No recordings for this day")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // A clean, simple list that stays inside the sidebar
            List(sessions, id: \.self) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title ?? "Sleep Session")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("\(session.startTime?.formatted(date: .omitted, time: .shortened) ?? "") - \(session.endTime?.formatted(date: .omitted, time: .shortened) ?? "")")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear) // Keeps the sidebar's background consistent
            }
            .listStyle(.plain) // Removes the heavy default iOS list styling
        }
    }
}
