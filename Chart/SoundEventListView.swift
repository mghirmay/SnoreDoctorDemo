import SwiftUI
import CoreData
import AVFoundation



struct SoundEventListView: View {
    @FetchRequest var soundEvents: FetchedResults<SoundEvent>

    @State private var activePlaybackSession: RecordingSession?

    // Remove 'weak' — SwiftUI views are value types
    private var playbackDelegate: SoundEventPlaybackDelegate?

    // Static formatter moved to an extension (optional improvement)
    private static let timeFormatter = DateComponentsFormatter.positionalFormatter

    // MARK: - Initializer
    init(session: RecordingSession?, playbackDelegate: SoundEventPlaybackDelegate?) {
        _activePlaybackSession = State(initialValue: session)
        self.playbackDelegate = playbackDelegate

        let predicate: NSPredicate
        if let session = session {
            predicate = NSPredicate(format: "session == %@", session)
        } else {
            predicate = NSPredicate(value: true)
        }

        _soundEvents = FetchRequest<SoundEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    // MARK: - View Body
    var body: some View {
        List {
          Section("Detected Events") {
            if soundEvents.isEmpty {
                Text("No detected events.")
                    .foregroundColor(.gray)
            } else {
                ForEach(soundEvents, id: \.self) { event in
                    if event.confidence >= UserDefaults.standard.snoreConfidenceThreshold {
                        if event.name == "snoring" {
                            SoundEventRowView(
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
        }
    }

    // MARK: - Playback Handler
    // MARK: - Playback Handler
    private func handleEventPlayback(event: SoundEvent) {
        guard let playbackDelegate = playbackDelegate else {
            print("Playback: No playback delegate available.")
            return
        }

        guard let eventSession = event.session else {
            print("Playback: Event '\(event.name ?? "N/A")' is not associated with a RecordingSession.")
            return
        }
        
        // Capture the desired seek time before the load operation
        let seekTime: TimeInterval?
        if let eventTimestamp = event.timestamp,
           let actualRecordingStartTime = eventSession.startTime {
            seekTime = eventTimestamp.timeIntervalSince(actualRecordingStartTime)
        } else {
            seekTime = nil
            print("Playback Warning: Missing timestamp or session start time for event '\(event.name ?? "N/A")'. Cannot calculate seek time.")
        }

        // ⭐️ Load audio with a completion handler
        playbackDelegate.loadAudio(for: eventSession) { success in
            guard success, let seekTime = seekTime else {
                print("Playback: Failed to load audio or seek time is invalid.")
                return
            }
            
            // ⭐️ Execute seek and play ONLY after successful audio loading
            playbackDelegate.seek(to: max(0, seekTime))
            playbackDelegate.play()
        }
        
        activePlaybackSession = eventSession // State update can happen immediately
    }
}

// MARK: - Formatter Extension (Optional but Clean)
extension DateComponentsFormatter {
    static let positionalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

fileprivate struct SoundEventRowView: View {
    let event: SoundEvent
    let playbackDelegate: SoundEventPlaybackDelegate?
    let formatter: DateComponentsFormatter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    
                    Text(event.name ?? "Unknown Event")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Confidence: \(event.confidence * 100, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                   
                    if let eventTimestamp = event.timestamp,
                       let eventSession = event.session,
                       let actualRecordingStartTime = eventSession.startTime {
                        Text("Time: \(eventTimestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Time: N/A (Requires event session)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if playbackDelegate != nil {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "speaker.slash.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel("Play event \(event.name ?? "Unknown")")
    }
}
