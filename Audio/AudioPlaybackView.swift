import SwiftUI
import AVFoundation
import CoreData

struct AudioPlaybackView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AudioPlaybackViewModel // The viewModel will be our delegate

    // MARK: - State and FetchRequests
    @State private var selectedSessionID: UUID? {
        didSet {
            // print("Selected Session ID changed to: \(selectedSessionID?.uuidString ?? "nil")")
        }
    }
    @State private var selectedRecordingSession: RecordingSession?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: false)],
        animation: .default
    ) var allRecordingSessions: FetchedResults<RecordingSession>

    // No longer need @FetchRequest var soundEvents: FetchedResults<SoundEvent> here
    // as it's now managed by SoundEventListView's initializer.

    // MARK: - Initializer
    // Remove the _soundEvents initialization from here, it's in SoundEventListView now.
    init(viewModel: AudioPlaybackViewModel) {
        self.viewModel = viewModel
        // _soundEvents = FetchRequest... (This line is no longer needed here)
    }

    // MARK: - Date Formatters
    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // MARK: - Session Selector (Picker)
                Picker("Select Recording", selection: $selectedSessionID) {
                    Text("Select a Session").tag(nil as UUID?)

                    ForEach(allRecordingSessions) { session in
                        if let id = session.id, let startTime = session.startTime {
                            Text(session.title ?? AudioPlaybackView.sessionDateFormatter.string(from: startTime))
                                .tag(id as UUID?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .onChange(of: selectedSessionID) { oldValue, newID in
                    updateSelectedSessionAndLoadAudio(for: newID)
                }

                // MARK: - Playback UI
                if selectedRecordingSession == nil {
                    ContentUnavailableView("No Session Selected", systemImage: "music.note", description: Text("Please select a recorded session from the dropdown above to view its audio and events."))
                } else {
                    Text(selectedRecordingSession?.title ?? selectedRecordingSession?.audioFileName ?? "Unnamed Recording")
                        .font(.headline)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                    }

                    HStack {
                        Button(action: { viewModel.togglePlayback() }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                        }
                        .disabled(viewModel.duration == 0)
                        .accessibilityLabel(viewModel.isPlaying ? "Pause playback" : "Play audio")


                        Slider(value: $viewModel.currentTime, in: 0...viewModel.duration) { editing in
                            if !editing {
                                viewModel.seek(to: viewModel.currentTime)
                            }
                        }
                        .disabled(viewModel.duration == 0)
                        .accessibilityLabel("Audio playback progress")
                        .accessibilityValue(Self.timeFormatter.string(from: viewModel.currentTime) ?? "0 seconds")
                        .accessibilityInputLabels(["Seek audio"])

                        Text(Self.timeFormatter.string(from: viewModel.currentTime) ?? "00:00")
                            .font(.caption)
                        Text("/")
                        Text(Self.timeFormatter.string(from: viewModel.duration) ?? "00:00")
                            .font(.caption)
                    }
                    .padding(.horizontal)

                    // MARK: - Visual Timeline / Waveform (Conceptual)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Timeline with Events")
                            .font(.subheadline)
                            .padding(.leading)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 10)

                            GeometryReader { geometry in
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: max(0, CGFloat(viewModel.currentTime / viewModel.duration) * geometry.size.width), height: 10)
                            }

                            GeometryReader { geometry in
                                // Still need to decide how to pass soundEvents for EventMarker
                                // Option 1: Pass selectedRecordingSession.soundEvents (if relationship is to-many and ordered)
                                // Option 2: Keep a @FetchRequest here only for EventMarker
                                // For now, let's assume `soundEvents` is available via selectedRecordingSession
                                // Or better, pass the predicate to EventMarker directly if it also uses @FetchRequest
                                if let session = selectedRecordingSession,
                                   let events = session.events as? Set<SoundEvent> {
                                    // Convert Set to Array and sort if necessary for consistent display order
                                    let sortedEvents = Array(events).sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

                                    ForEach(sortedEvents) { event in
                                        EventMarker(event: event,
                                                    selectedRecordingSession: selectedRecordingSession,
                                                    viewModel: viewModel, // ViewModel here will directly update current time
                                                    timelineWidth: geometry.size.width,
                                                    audioDuration: viewModel.duration)
                                    }
                                }
                            }
                        }
                        .frame(height: 50)
                        .padding(.horizontal)
                    }

                    // MARK: - Event List for detailed view and selection
                    // Use the new SoundEventListView here!
                    // Pass the selected session and the viewModel as the delegate.
                    SoundEventListView(session: selectedRecordingSession, playbackDelegate: viewModel)
                        // Make sure to add .environment(\.managedObjectContext, viewContext)
                        // if SoundEventListView also needs access to the context for its @FetchRequest
                        .environment(\.managedObjectContext, viewContext)
                }

                Spacer()
            }
            .navigationTitle("Audio Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.stopPlayback()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedSessionID == nil {
                    if let mostRecentSession = allRecordingSessions.first {
                        selectedSessionID = mostRecentSession.id
                    } else {
                        viewModel.errorMessage = "No recording sessions found."
                        selectedRecordingSession = nil
                        // updateSoundEventsPredicate(for: nil) // No longer needed here
                        viewModel.unloadAudio()
                    }
                } else if let id = selectedSessionID {
                    updateSelectedSessionAndLoadAudio(for: id)
                }
            }
            .onDisappear {
                viewModel.stopPlayback()
            }
        }
    }

    // MARK: - Helper Functions
    private func updateSelectedSessionAndLoadAudio(for id: UUID?) {
        viewModel.stopPlayback()

        if let sessionID = id,
           let session = allRecordingSessions.first(where: { $0.id == sessionID }) {
            selectedRecordingSession = session
            // No need to update _soundEvents.wrappedValue.nsPredicate here
            // as SoundEventListView's init handles it directly.

            if let audioFileName = session.audioFileName {
                viewModel.loadAudio(fileName: audioFileName)
            } else {
                viewModel.errorMessage = "Audio file not found for this session."
                viewModel.duration = 0
            }
        } else {
            selectedRecordingSession = nil
            // No need to update _soundEvents.wrappedValue.nsPredicate here
            viewModel.unloadAudio()
            viewModel.errorMessage = nil
        }
    }

    // This function is no longer needed in AudioPlaybackView
    // private func updateSoundEventsPredicate(for sessionID: UUID?) { ... }
}
