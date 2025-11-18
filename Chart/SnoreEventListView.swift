//
//  SnoreEventListView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 17.10.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//


import SwiftUI
import CoreData
import Foundation

// Assuming SoundEventPlaybackDelegate and RecordingSession are defined elsewhere
// and SnoreEvent is the Core Data entity you provided.

struct SnoreEventListView: View {
    // Fetches SnoreEvent instead of SoundEvent
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>

    @State private var activePlaybackSession: RecordingSession?

    // Use a non-optional ObservedObject for the delegate if possible, but keeping the original structure for compatibility
    private var playbackDelegate: SoundEventPlaybackDelegate?

    private static let timeFormatter = DateComponentsFormatter.positionalFormatter

    // MARK: - Initializer
    init(session: RecordingSession?, playbackDelegate: SoundEventPlaybackDelegate?) {
        _activePlaybackSession = State(initialValue: session)
        self.playbackDelegate = playbackDelegate

        let predicate: NSPredicate
        if let session = session {
            // Predicate now filters for SnoreEvent entities linked to the session
            predicate = NSPredicate(format: "session == %@", session)
        } else {
            // Default: Show all events (if not session is passed)
            predicate = NSPredicate(value: true)
        }

        // FetchRequest for SnoreEvent
        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    // MARK: - View Body
    var body: some View {
        List {
            Section("Aggregated Snore Events") {
                if snoreEvents.isEmpty {
                    Text("No aggregated snore events found for this session.")
                        .foregroundColor(.gray)
                } else {
                    // Iterate through SnoreEvent
                    ForEach(snoreEvents, id: \.self) { event in
                        SnoreEventRowView(
                            event: event,
                            playbackDelegate: playbackDelegate,
                            formatter: Self.timeFormatter,
                            onTap: {
                                handleEventPlayback(event: event)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Playback Handler
    private func handleEventPlayback(event: SnoreEvent) {
        guard let playbackDelegate = playbackDelegate else {
            print("Playback: No playback delegate available.")
            return
        }

        guard let eventSession = event.session else {
            print("Playback: SnoreEvent is not associated with a RecordingSession.")
            return
        }
        
        guard let startTime = event.startTime else {
            print("Playback: SnoreEvent is missing a start time.")
            return
        }

        // 1. Call loadAudio with completion
        playbackDelegate.loadAudio(for: eventSession) { success in
            guard success else {
                print("Playback: Failed to load audio file for session.")
                return
            }

            // 2. ONLY if audio is loaded, proceed to seek and play
            // We use the delegate method to handle the seek and play action
            // This method might implement a short rewind before playing for context.
            playbackDelegate.seekAndPlaySnoreEvent(
                session: eventSession,
                startTime: startTime, 
                duration: event.duration
            )
        }
        
        activePlaybackSession = eventSession
    }
}

// ---

fileprivate struct SnoreEventRowView: View {
    let event: SnoreEvent
    let playbackDelegate: SoundEventPlaybackDelegate?
    let formatter: DateComponentsFormatter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    
                    Text("Snore Cluster")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Avg. Confidence: \(event.averageConfidence * 100, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Dur: \(event.duration, specifier: "%.1f")s")
                        Divider()
                        Text("Count: \(event.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if let startTime = event.startTime {
                        Text("Start Time: \(startTime.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Time: N/A")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if playbackDelegate != nil {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "speaker.slash.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel("Play snore event starting at \(event.startTime?.formatted(date: .omitted, time: .shortened) ?? "N/A")")
    }
}