//
//  EditNotesContentView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData

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
