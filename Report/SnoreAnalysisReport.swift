//
//  SnoreDoctorChartView.swift
//  SnoreDoctorDemo
//
//  Created by [Your Name] on 2025/06/30.
//

import SwiftUI
import CoreData
//
//  SnoreDoctorChartView.swift
//  SnoreDoctorDemo
//

import SwiftUI
import CoreData



struct SnoreAnalysisReport: View {
    @EnvironmentObject var soundDataManager: SoundDataManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

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

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: - Session Info Card
                if let session = selectedRecordingSession {
                    SessionInfoCard(session: session, dateFormatter: Self.detailDateFormatter)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

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
                    SnoreEventListView(
                        session: selectedRecordingSession,
                        playbackDelegate: playbackViewModel
                    )
                    .frame(minHeight: 600, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        playbackViewModel.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Select Session", selection: $selectedSessionID) {
                        if isLiveSessionActive {
                            Text("Live View").tag(nil as UUID?)
                        } else {
                            Text("Live View (Inactive)").tag(nil as UUID?).disabled(true)
                        }
                        ForEach(allRecordingSessions) { session in
                            if let id = session.id, let startTime = session.startTime {
                                Text(session.title ?? SnoreAnalysisReport.sessionDateFormatter.string(from: startTime))
                                    .tag(id as UUID?)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSessionID) { _, newID in
                        updateSoundEventsAndSnoreEventsPredicates(for: newID)
                        updateSelectedRecordingSession(for: newID)
                    }
                }
            }
        }
        .onAppear {
            updateSoundEventsAndSnoreEventsPredicates(for: selectedSessionID)
            updateSelectedRecordingSession(for: selectedSessionID)
        }
        .onDisappear {
            playbackViewModel.stop()
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Predicate Updater
    private func updateSoundEventsAndSnoreEventsPredicates(for id: UUID?) {
        var predicate: NSPredicate = NSPredicate(value: false)

        if let actualID = id {
            predicate = NSPredicate(format: "session.id == %@", actualID as CVarArg)
        } else if isLiveSessionActive, let liveID = currentLiveSessionID {
            predicate = NSPredicate(format: "session.id == %@", liveID as CVarArg)
        }

        _soundEvents.wrappedValue.nsPredicate = predicate
        _snoreEvents.wrappedValue.nsPredicate = predicate
    }

    // MARK: - Selected Session Updater
    private func updateSelectedRecordingSession(for id: UUID?) {
        var sessionToSelect: RecordingSession? = nil

        if let actualID = id {
            sessionToSelect = allRecordingSessions.first(where: { $0.id == actualID })
        } else if isLiveSessionActive, let liveID = currentLiveSessionID {
            sessionToSelect = allRecordingSessions.first(where: { $0.id == liveID })
        }

        selectedRecordingSession = sessionToSelect

        if let session = selectedRecordingSession,
           let fileName = session.audioFileName, !fileName.isEmpty {
            do {
                let recordingsFolder = try FileManager.getRecordingsFolderURL()
                let audioURL = recordingsFolder.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: audioURL.path) {
                    playbackViewModel.setupAudioPlayer(url: audioURL)
                } else {
                    print("File defined in DB but not found on disk: \(fileName)")
                }
            } catch {
                print("Could not resolve recordings directory: \(error)")
            }
        } else {
            playbackViewModel.stop()
        }
    }
}


