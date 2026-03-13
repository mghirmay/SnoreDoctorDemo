import SwiftUI
import CoreData
import Charts
struct SnoreDoctorEventNameHistogramView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
        animation: .default)
    private var soundEvents: FetchedResults<SoundEvent>

    @State private var histogramData: [EventNameBin] = []

    // MARK: - Use your actual AudioPlaybackViewModel
    @StateObject private var playbackViewModel = AudioPlaybackViewModel()

    // Since this view is for global statistics, we need to decide:
    // 1. Should the SoundEventListView below show ALL events (no session context for playback)?
    // 2. Or, should we allow the user to select a session within this view?
    // Let's go with the first option, meaning playback for individual events in the list
    // will require the user to first "activate" the session's audio.
    // For now, SoundEventListView will display all events, but playback will be enabled
    // ONLY IF playbackViewModel.loadAudio(for: someSession) has been called.

    // If you want to enable playback for a specific session from this view,
    // you'd need a @State var selectedPlaybackSession: RecordingSession?
    // and a way to set it (e.g., a picker or a button).
    // For now, let's keep it simple and just show all events, with playback tied
    // to whether the view model has *any* audio loaded.

    // MARK: - EventNameBin Structure
    struct EventNameBin: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Sound Event Name Distribution")
                    .font(.largeTitle)
                    .padding(.top)
                    .padding(.bottom, 5)

                Divider()

                // Histogram Section
                ScrollView {
                    VStack {
                        if histogramData.isEmpty {
                            ContentUnavailableView("No Sound Events Recorded Yet", systemImage: "chart.bar.fill", description: Text("Start an analysis session to accumulate data."))
                                .foregroundColor(.secondary)
                                .scaleEffect(1.1)
                                .padding(.vertical, 50)
                        } else {
                            EventNameHistogramChartContent(histogramData: histogramData)
                                .padding()
                                .frame(height: max(300, CGFloat(histogramData.count) * 40))
                        }
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height / 2) // Limit histogram height

                Divider()

                // MARK: - Playback Controls for the currently loaded audio (optional but useful)
                // If this view is truly global, these controls would apply to whichever session's audio
                // is currently loaded in the playbackViewModel.
                if let error = playbackViewModel.errorMessage {
                    Text("Playback Error: \(error)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                HStack {
                    Spacer()
                    Button(action: {
                        // This play/pause button would control the currently loaded audio
                        playbackViewModel.togglePlayback()
                    }) {
                        Image(systemName: playbackViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .padding()
                    }
                    .disabled(playbackViewModel.duration == 0.0) // Disable if no audio loaded
                    Spacer()
                }
                .background(Color.gray.opacity(0.1))
                .padding(.vertical, 5)

                Divider()

                // MARK: - SoundEventListView Integration
                // To allow playback, SoundEventListView needs a 'selectedRecordingSession'
                // and a playbackDelegate.
                // Since this is a global view showing all events, we can't just pick one session.
                //
                // Option A: If you want to enable playback for a specific event's session,
                // you would need to store the 'active' session here and pass it.
                // For now, SoundEventListView's `selectedRecordingSession` will be `nil`
                // by default, meaning playback won't be active *from this view's context*.
                //
                // The `SoundEventListView` will now call `playbackViewModel.loadAudio(for: session)`
                // when an event is tapped, so it will attempt to load the correct audio file.
                SoundEventListView(session: nil, playbackDelegate: playbackViewModel)
                    .navigationTitle("Event Names") // Title for this section, if needed
            }
            .navigationTitle("Event Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        playbackViewModel.unloadAudio() // Clean up audio on dismiss
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: calculateEventNameHistogram)
        .onChange(of: soundEvents.count) { _ in
            calculateEventNameHistogram()
        }
    }

    // MARK: - Histogram Calculation Logic for Event Names
    private func calculateEventNameHistogram() {
        var tempBins: [String: Int] = [:]

        for event in soundEvents {
            guard let eventName = event.name else {
                print("Warning: SoundEvent found with no name, skipping for histogram.")
                continue
            }
            tempBins[eventName, default: 0] += 1
        }

        self.histogramData = tempBins.map { (name, count) in
            EventNameBin(name: name, count: count)
        }.sorted { $0.count > $1.count }
    }

    // Chart Content Sub-View for Event Names (no changes)
    private struct EventNameHistogramChartContent: View {
        typealias EventNameBin = SnoreDoctorEventNameHistogramView.EventNameBin

        let histogramData: [EventNameBin]

        var body: some View {
            Chart(histogramData) { bin in
                BarMark(
                    x: .value("Number of Events", bin.count),
                    y: .value("Event Name", bin.name)
                )
                .accessibilityLabel("Event Name \(bin.name)")
                .accessibilityValue("\(bin.count) events")
                .foregroundStyle(Color.purple)
                .annotation(position: .trailing) {
                    Text("\(bin.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartScrollableAxes(.vertical)
        }
    }
}
