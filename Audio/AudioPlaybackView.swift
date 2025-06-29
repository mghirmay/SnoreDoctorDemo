//
//  AudioPlaybackView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// AudioPlaybackView.swift
import SwiftUI
import AVFoundation // For TimeInterval

struct AudioPlaybackView: View {
    @Environment(\.dismiss) var dismiss // To dismiss the sheet
    @ObservedObject var viewModel: AudioPlaybackViewModel
    @FetchRequest var soundEvents: FetchedResults<SoundEvent> // Fetched for markers

    // We pass the name of the audio file to load
    let audioFileName: String?

    // Initialize the FetchRequest dynamically
    init(viewModel: AudioPlaybackViewModel, audioFileName: String?) {
        self.viewModel = viewModel
        self.audioFileName = audioFileName

        // Fetch SoundEvents associated with this specific audio file, sorted by timestamp
        _soundEvents = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: NSPredicate(format: "audioFileName == %@", audioFileName ?? "NONE"), // Filter by audio file name
            animation: .default
        )
    }

    // Date formatter for display purposes
    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(audioFileName != nil ? "Playing: \(audioFileName!)" : "No Audio File Selected")
                    .font(.headline)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.callout)
                }

                // MARK: - Playback Controls
                HStack {
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                    }
                    .disabled(viewModel.duration == 0) // Disable if no audio loaded

                    Slider(value: $viewModel.currentTime, in: 0...viewModel.duration) { editing in
                        if !editing {
                            viewModel.seek(to: viewModel.currentTime)
                        }
                    }
                    .disabled(viewModel.duration == 0)

                    Text(Self.timeFormatter.string(from: viewModel.currentTime) ?? "00:00")
                        .font(.caption)
                    Text("/")
                    Text(Self.timeFormatter.string(from: viewModel.duration) ?? "00:00")
                        .font(.caption)
                }
                .padding(.horizontal)

                // MARK: - Visual Timeline / Waveform (Conceptual)
                // This is a simplified visual representation.
                // A real waveform would involve parsing PCM data.
                VStack(alignment: .leading, spacing: 5) {
                    Text("Timeline with Events")
                        .font(.subheadline)
                        .padding(.leading)

                    ZStack(alignment: .leading) {
                        // Background line representing the full duration
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 10)

                        // Progress indicator
                        GeometryReader { geometry in
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: max(0, CGFloat(viewModel.currentTime / viewModel.duration) * geometry.size.width), height: 10)
                        }

                        // Markers for sound events
                        GeometryReader { geometry in
                            ForEach(soundEvents) { event in
                                if let timestamp = event.timestamp {
                                    // Calculate position based on timestamp relative to recording start
                                    // This assumes `timestamp` is relative to the start of the audio file.
                                    // If `timestamp` is absolute (e.g., Date()), you need the audio file's
                                    // actual start time to calculate relative position.
                                    let relativeTime = timestamp.timeIntervalSinceReferenceDate - (soundEvents.first?.timestamp?.timeIntervalSinceReferenceDate ?? timestamp.timeIntervalSinceReferenceDate) // Adjust if events don't start at 0
                                    let position = CGFloat(relativeTime / viewModel.duration) * geometry.size.width

                                    if position >= 0 && position <= geometry.size.width {
                                        VStack {
                                            Circle()
                                                .fill(markerColor(for: event.name))
                                                .frame(width: 15, height: 15)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                            Text(event.name ?? "Event")
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                        .offset(x: position - 7.5) // Center the circle
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 50) // Adjust height for timeline area
                    .padding(.horizontal)
                }

                // MARK: - Event List for detailed view and selection
                List {
                    Section("Detected Events") {
                        if soundEvents.isEmpty {
                            Text("No detected events for this recording.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(soundEvents) { event in
                                Button(action: {
                                    // Calculate time to seek to (relative to start of recording)
                                    if let firstTimestamp = soundEvents.first?.timestamp,
                                       let eventTimestamp = event.timestamp {
                                        let seekTime = eventTimestamp.timeIntervalSince(firstTimestamp)
                                        viewModel.seek(to: max(0, seekTime)) // Ensure not negative
                                        viewModel.togglePlayback() // Play from marker
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(event.name ?? "Unknown Event")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("Confidence: \(event.confidence, specifier: "%.2f")%")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("Time: \(Self.timeFormatter.string(from: event.timestamp?.timeIntervalSinceReferenceDate ?? 0) ?? "N/A")")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            // TODO: If you add 'duration' to SoundEvent, display it here
                                            // Text("Duration: \(event.duration, specifier: "%.1f")s")
                                        }
                                        Spacer()
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Recording Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.stopPlayback() // Stop playback before dismissing
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let fileName = audioFileName {
                    viewModel.loadAudio(fileName: fileName)
                } else {
                    viewModel.errorMessage = "No audio file name provided."
                }
            }
            .onDisappear {
                viewModel.stopPlayback() // Stop playback when view disappears
            }
        }
    }

    func markerColor(for eventName: String?) -> Color {
        switch eventName?.lowercased() {
        case "snoring", "snoring (speech-like)", "snoring (noise/breathing)": // Use your actual detected names
            return .red
        case "quiet", "silence":
            return .green
        case "speech":
            return .blue
        default:
            return .purple // For "other noises" or unknown
        }
    }
}