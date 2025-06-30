//
//  SoundEventListView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//
//
// SoundEventListView.swift
// SnoreDoctorDemo
//
// Created by [Your Name] on 2025/06/30.
//

import SwiftUI
import CoreData
import AVFoundation // Required if using playbackDelegate methods here directly, though protocol abstracts it.

struct SoundEventListView: View {
    @FetchRequest var soundEvents: FetchedResults<SoundEvent>
    let selectedRecordingSession: RecordingSession? // Needed to calculate event time
    weak var playbackDelegate: (any SoundEventPlaybackDelegate)? // Delegate for playback actions

    // DateFormatter for event times - make it static for efficiency
    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional // e.g., "01:23:45"
        formatter.zeroFormattingBehavior = .pad // pads with zeros (e.g., 0:05 -> 00:05)
        return formatter
    }()

    // MARK: - Initializer for FetchRequest
    // This initializer allows you to pass a predicate when creating the view.
    init(session: RecordingSession?, playbackDelegate: (any SoundEventPlaybackDelegate)?) {
        self.selectedRecordingSession = session
        self.playbackDelegate = playbackDelegate

        // Create the FetchRequest predicate based on the session ID
        // Note: Using NSNull() for nil session ensures the predicate is valid.
        // It effectively fetches no events if session is nil, which is desired.
        let predicate = NSPredicate(format: "session == %@", session ?? NSNull())

        _soundEvents = FetchRequest<SoundEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        List {
            Section("Detected Events") {
                if soundEvents.isEmpty {
                    Text("No detected events for this recording.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(soundEvents) { event in
                        Button(action: {
                            // Ensure valid data before attempting playback
                            if let eventTimestamp = event.timestamp,
                               let actualRecordingStartTime = selectedRecordingSession?.startTime {
                                let seekTime = eventTimestamp.timeIntervalSince(actualRecordingStartTime)
                                // Only seek if delegate is present
                                playbackDelegate?.seek(to: max(0, seekTime))
                                playbackDelegate?.play()
                            } else {
                                print("Warning: Cannot play event. Missing timestamp or session start time for event: \(event.name ?? "N/A")")
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    // Display event name, defaulting to "Unknown Event"
                                    Text(event.name ?? "Unknown Event")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    // Display confidence, handling potential non-Double types
                                    if let confidence = event.confidence as? Double {
                                        Text("Confidence: \(confidence, specifier: "%.2f")%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Confidence: N/A")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    // Display elapsed time since session start
                                    if let eventTimestamp = event.timestamp,
                                       let actualRecordingStartTime = selectedRecordingSession?.startTime {
                                        Text("Time: \(Self.timeFormatter.string(from: eventTimestamp.timeIntervalSince(actualRecordingStartTime)) ?? "N/A")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("Time: N/A")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer() // Pushes play button to the right
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }
}
