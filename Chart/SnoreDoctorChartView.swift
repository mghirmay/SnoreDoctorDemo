//
//  SnoreDoctorChartView.swift
//  SnoreDoctorDemo
//
//  Created by [Your Name] on 2025/06/30.
//

import SwiftUI
import CoreData

struct SnoreDoctorChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // Add this line

    @StateObject private var soundDataManager: SoundDataManager


    
    @State private var selectedSessionID: UUID?
    @State private var selectedRecordingSession: RecordingSession?

    let isLiveSessionActive: Bool
    let currentLiveSessionID: UUID?

    @StateObject private var playbackViewModel = AudioPlaybackViewModel()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordingSession.startTime, ascending: false)],
        animation: .default
    ) var allRecordingSessions: FetchedResults<RecordingSession>

    @FetchRequest var soundEvents: FetchedResults<SoundEvent>
    @FetchRequest var snoreEvents: FetchedResults<SnoreEvent>

    init(initialSessionID: UUID?, isLiveSessionActive: Bool, currentLiveSessionID: UUID?) {
        _selectedSessionID = State(initialValue: initialSessionID)
        self.isLiveSessionActive = isLiveSessionActive
        self.currentLiveSessionID = currentLiveSessionID

        // Use PersistenceController.shared.container.viewContext for the main app
        _soundDataManager = StateObject(wrappedValue: SoundDataManager(context: PersistenceController.shared.container.viewContext))
        
        // Initialize with no data until a session is selected
        _soundEvents = FetchRequest<SoundEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: NSPredicate(value: false),
            animation: .default
        )

        _snoreEvents = FetchRequest<SnoreEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SnoreEvent.startTime, ascending: true)],
            predicate: NSPredicate(value: false),
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
                HStack { // Use HStack to place picker and button side-by-side
                    Picker("Select Session", selection: $selectedSessionID) {
                        if isLiveSessionActive {
                            Text("Live View").tag(nil as UUID?)
                        } else {
                            Text("Live View (Inactive)").tag(nil as UUID?).disabled(true)
                        }

                        ForEach(allRecordingSessions) { session in
                            if let id = session.id, let startTime = session.startTime {
                                Text(session.title ?? SnoreDoctorChartView.sessionDateFormatter.string(from: startTime))
                                    .tag(id as UUID?)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    // No padding here, let the HStack manage it
                    .onChange(of: selectedSessionID) { _, newID in
                        updateSoundEventsAndSnoreEventsPredicates(for: newID)
                        updateSelectedRecordingSession(for: newID)
                    }

                    Button("Process Now") {
                        if let session = selectedRecordingSession {
                            // Call DataManager to aggregate snore events
                            // DataManager will use SnoreEventPostProcessor internally
                            soundDataManager.aggregateSnoreEvents(for: session)
                            // After processing, the FetchRequests for snoreEvents will automatically update
                            // because Core Data changes are observed by FetchedResults.
                            print("Triggered 'Process Now' for session: \(session.title ?? "N/A")")
                        } else {
                            print("No session selected to process.")
                        }
                    }
                    .buttonStyle(.borderedProminent) // Use a prominent style for clarity
                    .disabled(selectedRecordingSession == nil) // Disable if no session is selected
                }
                .padding(.horizontal) // Apply padding to the entire HStack
                .padding(.top, 5)

                ScrollView {
                    VStack {
                        // MARK: - Chart Section
                        SnoreEventChartContent(snoreEvents: snoreEvents)

                        // MARK: - Event List Section
                        if soundEvents.isEmpty {
                            ContentUnavailableView(
                                "No Sound Events",
                                systemImage: "waveform",
                                description: Text("Start an analysis session or select a recorded session.")
                            )
                            .frame(minHeight: 400)
                        } else {
                            SoundEventListView(
                                session: selectedRecordingSession,
                                playbackDelegate: playbackViewModel
                            )
                            .frame(minHeight: 600, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Session Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        playbackViewModel.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Initial predicate update when the view appears
            updateSoundEventsAndSnoreEventsPredicates(for: selectedSessionID)
            updateSelectedRecordingSession(for: selectedSessionID)
        }
        .onDisappear {
            playbackViewModel.stop()
        }
    }

    // MARK: - Predicate Updater
    // Combined predicate update for both SoundEvents and SnoreEvents
    private func updateSoundEventsAndSnoreEventsPredicates(for id: UUID?) {
        var predicate: NSPredicate = NSPredicate(value: false) // Default to no results

        if let actualID = id {
            predicate = NSPredicate(format: "session.id == %@", actualID as CVarArg)
        } else if isLiveSessionActive, let liveID = currentLiveSessionID {
            // If "Live View" is selected and active, use the current live session's ID
            predicate = NSPredicate(format: "session.id == %@", liveID as CVarArg)
        }

        // Assign the predicate to both FetchRequests
        _soundEvents.wrappedValue.nsPredicate = predicate
        _snoreEvents.wrappedValue.nsPredicate = predicate
    }

    // MARK: - Selected Session Updater
    private func updateSelectedRecordingSession(for id: UUID?) {
        var sessionToSelect: RecordingSession? = nil

        if let actualID = id {
            sessionToSelect = allRecordingSessions.first(where: { $0.id == actualID })
        } else if isLiveSessionActive, let liveID = currentLiveSessionID {
            // If "Live View" is selected and active, use the current live session's ID
            sessionToSelect = allRecordingSessions.first(where: { $0.id == liveID })
        }

        selectedRecordingSession = sessionToSelect

        // Load audio file if available
        if let session = selectedRecordingSession,
           let audioFileName = session.audioFileName,
           !audioFileName.isEmpty {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioURL = documentsDirectory.appendingPathComponent(audioFileName)

            if FileManager.default.fileExists(atPath: audioURL.path) {
                playbackViewModel.setupAudioPlayer(url: audioURL)
            } else {
                print("Audio file not found: \(audioURL.lastPathComponent)")
                playbackViewModel.stop()
            }
        } else {
            playbackViewModel.stop()
        }
    }
}
