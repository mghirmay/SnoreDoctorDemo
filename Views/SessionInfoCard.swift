//
//  SessionInfoCard.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData


// MARK: - Session Info Card
struct SessionInfoCard: View {
    @ObservedObject var session: RecordingSession
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Title + dates
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title ?? "Untitled Session")
                    .font(.subheadline)
                    .bold()

                if let startTime = session.startTime {
                    Label("\(startTime, formatter: dateFormatter)", systemImage: "play.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let endTime = session.endTime {
                    Label("\(endTime, formatter: dateFormatter)", systemImage: "stop.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Stats row
            HStack(spacing: 20) {
                StatItem(label: "Snores",  value: "\(session.totalSnoreEvents)",    color: .orange)
                StatItem(label: "Related", value: "\(session.totalSnoreRelated)",   color: .blue)
                StatItem(label: "Other",   value: "\(session.totalNonSnoreEvents)", color: .gray)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
