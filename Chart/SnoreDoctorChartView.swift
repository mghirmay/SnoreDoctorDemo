//
// SnoreDoctorChartView.swift
// SnoreDoctorDemo
//
// Created by [Your Name] on 2025/06/30.
//

import SwiftUI
import CoreData
import Charts

struct SnoreDoctorChartView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedSessionID: UUID?
    // This state now holds the actual RecordingSession object corresponding to selectedSessionID
    @State private var selectedRecordingSession: RecordingSession?

    let isLiveSessionActive: Bool
    let currentLiveSessionID: UUID? // Used for the "Live View" predicate

    // Instantiate your playback view model
    @StateObject private var playbackViewModel = AudioPlaybackViewModel()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: false)],
        animation: .default
    ) var allRecordingSessions: FetchedResults<RecordingSession>

    // This FetchRequest's predicate will be updated based on selectedSessionID
    @FetchRequest var soundEvents: FetchedResults<SoundEvent>

    init(initialSessionID: UUID?, isLiveSessionActive: Bool, currentLiveSessionID: UUID?) {
        _selectedSessionID = State(initialValue: initialSessionID)
        self.isLiveSessionActive = isLiveSessionActive
        self.currentLiveSessionID = currentLiveSessionID

        // Initialize soundEvents with a predicate that fetches nothing initially
        _soundEvents = FetchRequest<SoundEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: NSPredicate(value: false), // Placeholder predicate
            animation: .default
        )
    }

    static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack {
                Text(selectedSessionID == nil ? "Live Session Chart" : "Session Chart")
                    .font(.largeTitle)
                    .padding(.top)

                Picker("Select Session", selection: $selectedSessionID) {
                    if isLiveSessionActive {
                        Text("Live View").tag(nil as UUID?)
                    } else {
                        // Disable "Live View" if no live session is active
                        Text("Live View (Inactive)").tag(nil as UUID?).disabled(true)
                    }
                    // Iterate through all fetched recording sessions
                    ForEach(allRecordingSessions) { session in
                        if let id = session.id, let startTime = session.startTime {
                            Text(session.title ?? SnoreDoctorChartView.sessionDateFormatter.string(from: startTime))
                                .tag(id as UUID?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                // When selectedSessionID changes, update both the sound events predicate
                // and the actual selected RecordingSession object.
                .onChange(of: selectedSessionID) { oldValue, newID in
                    updateSoundEventsPredicate(for: newID)
                    updateSelectedRecordingSession(for: newID)
                }

                Divider()

                // Use a ScrollView to allow both chart and list to scroll
                ScrollView {
                    VStack {
                        // Display ContentUnavailableView if no data for the chart
                        if soundEvents.isEmpty {
                            ContentUnavailableView("No Data for this Session", systemImage: "chart.bar.fill", description: Text("Start an analysis session or select a recorded session."))
                        } else {
                            // MARK: - Chart View Content
                            // Pass the fetched sound events and helper functions
                            ChartViewContent(
                                soundEvents: soundEvents,
                                markerColor: chartMarkerColor, // Assuming this is a global function
                                formatTimeInterval: formatTimeInterval
                            )
                            .frame(height: 300) // Give the chart a fixed height for consistency

                            Divider()
                                .padding(.vertical)

                            // MARK: - Event List View Content
                            // Pass the selected RecordingSession object and the playback view model as delegate
                            SoundEventListView(
                                session: selectedRecordingSession, // This is the actual CoreData object
                                playbackDelegate: playbackViewModel // Pass the view model
                            )
                            // The list will expand to fill available height, but won't push content off screen due to ScrollView
                            .frame(minHeight: 200, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Session Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        // Stop playback when dismissing the view
                        playbackViewModel.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // On initial appearance, set the predicate and selected session
            updateSoundEventsPredicate(for: selectedSessionID)
            updateSelectedRecordingSession(for: selectedSessionID)
        }
        .onDisappear {
            // Stop playback when the view disappears
            playbackViewModel.stop()
        }
    }

    // MARK: - Helper Functions

    // Updates the predicate for the soundEvents FetchRequest
    private func updateSoundEventsPredicate(for id: UUID?) {
        var predicate: NSPredicate? = nil
        if let actualID = id {
            predicate = NSPredicate(format: "session.id == %@", actualID as CVarArg)
        } else {
            // Logic for "Live View"
            if isLiveSessionActive, let liveID = currentLiveSessionID {
                predicate = NSPredicate(format: "session.id == %@", liveID as CVarArg)
            } else {
                // If live view is selected but inactive or no live ID, show no events
                predicate = NSPredicate(value: false)
            }
        }
        _soundEvents.wrappedValue.nsPredicate = predicate
    }

    // Updates the @State selectedRecordingSession object
    private func updateSelectedRecordingSession(for id: UUID?) {
        var sessionToSelect: RecordingSession? = nil

        if let actualID = id {
            sessionToSelect = allRecordingSessions.first(where: { $0.id == actualID })
        } else {
            // Logic for "Live View"
            if isLiveSessionActive, let liveID = currentLiveSessionID {
                sessionToSelect = allRecordingSessions.first(where: { $0.id == liveID })
            } else {
                // No live session active or no currentLiveSessionID, so no session to select for live view
                sessionToSelect = nil
            }
        }
        selectedRecordingSession = sessionToSelect

        // Crucial: Load audio for the newly selected session
        if let session = selectedRecordingSession,
             let audioFileName = session.audioFileName, // Corrected to use 'audioFileName'
             !audioFileName.isEmpty // Ensure the file name is not empty
          {
              // 1. Get the URL to the app's Documents directory
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

              // 2. Append the audioFileName to get the full file URL
              let audioURL = documentsDirectory.appendingPathComponent(audioFileName)

              // 3. Verify if the file actually exists at this URL before setting up the player
              if FileManager.default.fileExists(atPath: audioURL.path) {
                  playbackViewModel.setupAudioPlayer(url: audioURL)
              } else {
                  print("Audio file not found at: \(audioURL.lastPathComponent). Cannot set up playback.")
                  playbackViewModel.stop()
                  //playbackViewModel.audioPlayer = nil
              }
          } else {
              // If no session is selected or audioFileName is nil/empty
              playbackViewModel.stop() // Stop any current playback
              //playbackViewModel.audioPlayer = nil // Clear the player
          }
    }

    // Formats a TimeInterval into a human-readable string (e.g., "01:23:45")
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "00:%02d", seconds)
        }
    }
}

// Ensure you also have the `ChartViewContent` struct, `SoundEventType` enum,
// and `chartMarkerColor` function (from ChartColorProvider.swift) in your project.
