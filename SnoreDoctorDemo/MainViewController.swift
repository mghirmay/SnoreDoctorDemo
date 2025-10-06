//
//  MainViewController.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 08.05.25.
//

import UIKit
import SoundAnalysis
import AVFoundation
import SwiftUI // Import SwiftUI to use UIHostingController
import CoreData // Import CoreData

// Make sure your custom error type is accessible, e.g., in Errors.swift
// If it's not globally accessible, you might need to make it public or include it here.
// For demonstration, let's assume it's in a separate file and public.
// import AudioAnalysisError // If you have a dedicated file

class MainViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    // MARK: - Properties

    private let multicastViewModel = MulticastServiceViewModel()

    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var analysisButton: UIButton?
    @IBOutlet weak var showChartButton: UIButton?
    @IBOutlet weak var showPlaybackButton: UIButton?
    @IBOutlet weak var settingsButton: UIButton?

    @IBOutlet weak var sessionsTableView: UITableView!

    private var currentRecordingSession: RecordingSession? // Manages Core Data session object

    private var audioEngine: AVAudioEngine? // Handles real-time audio input
    private var audioStreamAnalyzer: SNAudioStreamAnalyzer? // For SoundAnalysis framework

    private let analysisQueue = DispatchQueue(label: "de.sinitpower.SnoreDoctor.analysisQueue")

    private var soundClassifierRequest: SNClassifySoundRequest?

    // Instances of your managers
    private let audioRecorder = AudioRecorder()
    private let audioManager = AudioManager.shared // Use the singleton AudioManager

    // Using lazy var to ensure resultsObserver is initialized when first accessed
    // and is holding a weak reference to self.
    private lazy var resultsObserver = SoundEventDetectionObserver(delegate: self)

    // NSFetchedResultsController for RecordingSessions
    private lazy var fetchedResultsController: NSFetchedResultsController<RecordingSession> = {
        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: PersistenceController.shared.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        return controller
    }()

    // UI Styling Attributes
    let attributesBold: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 21, weight: .bold)
    ]

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupAudioAnalysisComponents()
        setupFetchedResultsController()
        setupNotificationObservers()

        // Request microphone permission on launch
        requestMicrophonePermission()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // No redundant permission checks here; viewDidLoad handles initial request.
    }

    deinit {
        // Ensure all audio resources are stopped and released
        stopAudioAnalysis()
        // Remove all observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
        print("MainViewController deinitialized")
    }

    // MARK: - Setup Methods

    private func setupUI() {
        updateResultsTextView(with: "Ready to analyze sounds... \n", append: false)

        sessionsTableView.dataSource = self
        sessionsTableView.delegate = self

        analysisButton?.layer.cornerRadius = 10
        updateAnalysisButtonState(isRecording: false) // Set initial state

        // Initialize and start multicast service
        multicastViewModel.start()
    }

    private func setupAudioAnalysisComponents() {
        do {
            soundClassifierRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)

            let windowDuration = UserDefaults.standard.analysisWindowDuration
            let overlapFactor = UserDefaults.standard.analysisOverlapFactor

            soundClassifierRequest?.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
            soundClassifierRequest?.overlapFactor = overlapFactor

        } catch {
            print("Failed to create sound classification request: \(error.localizedDescription)")
            updateResultsTextView(with: "Error: Could not load sound classifier. \(error.localizedDescription)\n")
            analysisButton?.isEnabled = false // Disable analysis if model fails to load
        }
    }

    private func setupFetchedResultsController() {
        do {
            try fetchedResultsController.performFetch()
            sessionsTableView.reloadData()
        } catch {
            print("Failed to perform initial fetch for RecordingSessions: \(error.localizedDescription)")
            showAlert(title: "Error", message: "Could not load past sessions: \(error.localizedDescription)")
        }
    }

    private func setupNotificationObservers() {
        // Listen for audio session interruption and media services reset notifications from AudioManager
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruptionBegan),
                                               name: .audioSessionInterruptionBegan,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruptionEndedShouldResume),
                                               name: .audioSessionInterruptionEndedShouldResume,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruptionEndedCouldNotResume),
                                               name: .audioSessionInterruptionEndedCouldNotResume,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesReset),
                                               name: .mediaServicesReset,
                                               object: nil)
    }

    // MARK: - Microphone Permission

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.analysisButton?.isEnabled = granted
                if !granted {
                    self.showPermissionDeniedAlert()
                } else {
                    self.updateResultsTextView(with: "Microphone access granted. Ready.\n")
                }
            }
        }
    }

    private func showPermissionDeniedAlert() {
        let message = String(format: NSLocalizedString("NoPermission_message", comment: ""), Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "this app")
        let alert = UIAlertController(title: NSLocalizedString("NoPermission_Headline", comment: "") , message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Go to Settings".translate(), style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel".translate(), style: .cancel, handler: nil))

        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY), size: .zero)
        alert.popoverPresentationController?.permittedArrowDirections = []
        alert.popoverPresentationController?.delegate = self

        self.present(alert, animated: true, completion: nil)
        updateResultsTextView(with: "Microphone access denied. Please enable it in Settings.\n")
    }

    // MARK: - Audio Analysis Control

    @IBAction func toggleAnalysis(_ sender: UIButton) {
        if audioEngine == nil { // Or audioStreamAnalyzer == nil, they should be consistent
            startAudioAnalysis()
            UIApplication.shared.isIdleTimerDisabled = true  // 👈 Keeps screen/CPU active
          
        } else {
            stopAudioAnalysis()
            UIApplication.shared.isIdleTimerDisabled = false  // 👈 Let the system sleep again

        }
    }

    private func startAudioAnalysis() {
        guard analysisButton?.isEnabled == true else {
            updateResultsTextView(with: "Microphone permission not granted or analysis disabled.\n")
            return
        }
        guard audioEngine == nil else {
            updateResultsTextView(with: "Audio analysis is already running. \n")
            return
        }

        updateResultsTextView(with: "Starting audio analysis... \n", append: false)

        do {
            // Start audio recording to file (this also configures AVAudioSession)
            guard let initialRecordingURL = try audioRecorder.startAndGetRecordingURL() else {
                throw AudioAnalysisError.invalidState("Failed to obtain initial recording URL from AudioRecorder.")
            }

            // Create a new Core Data RecordingSession
            let context = PersistenceController.shared.container.viewContext
            let newSession = RecordingSession(context: context)
            newSession.id = UUID()
            newSession.startTime = Date()
            newSession.notes = nil
            newSession.audioFileName = initialRecordingURL.lastPathComponent

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMM d, h:mm a"
            newSession.title = dateFormatter.string(from: newSession.startTime ?? Date())

            self.currentRecordingSession = newSession
            resultsObserver.currentRecordingSession = newSession // Pass to the observer

            print("Recording session started for file: \(newSession.audioFileName ?? "undefined filename")")

            // Setup AVAudioEngine for real-time analysis
            let newAudioEngine = AVAudioEngine()
            let inputNode = newAudioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            audioStreamAnalyzer = SNAudioStreamAnalyzer(format: recordingFormat)

            guard let analyzer = audioStreamAnalyzer, let request = soundClassifierRequest else {
                throw AudioAnalysisError.invalidState("Failed to initialize audio stream analyzer or sound classifier request.")
            }

            // Install tap on the input node to feed audio to the analyzer
            let bufferSize = AVAudioFrameCount(2048)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                guard let self = self else { return }
                self.analysisQueue.async {
                    analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
                }
            }

            try analyzer.add(request, withObserver: resultsObserver)
            try newAudioEngine.start()
            print("Audio engine started.")
            self.audioEngine = newAudioEngine
            updateResultsTextView(with: "Analysis started.\n")
            updateAnalysisButtonState(isRecording: true)

        } catch let error as AudioAnalysisError {
            print("Audio analysis setup failed: \(error.localizedDescription)")
            updateResultsTextView(with: "Analysis setup failed: \(error.localizedDescription)\n")
            stopAudioAnalysis() // Ensure clean shutdown on error
            showAlert(title: "Analysis Setup Error", message: error.localizedDescription)
        } catch {
            print("Audio analysis setup failed with generic error: \(error.localizedDescription)")
            updateResultsTextView(with: "Analysis setup failed: \(error.localizedDescription)\n")
            stopAudioAnalysis() // Ensure clean shutdown on error
            showAlert(title: "Analysis Setup Error", message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    private func stopAudioAnalysis() {
        // Remove tap from input node
        audioEngine?.inputNode.removeTap(onBus: 0)
        // Stop audio engine
        audioEngine?.stop()
        audioEngine = nil

        // Remove all analysis requests
        audioStreamAnalyzer?.removeAllRequests()
        audioStreamAnalyzer = nil

        // Stop the file recording and deactivate audio session
        _ = audioRecorder.stopAndGetRecordingURL()

        // Update Core Data session end time and save
        if let session = self.currentRecordingSession {
            session.endTime = Date() // Set the end time for the session
            resultsObserver.updateSessionCountsAndSave() // Ensure counts are saved
            PersistenceController.shared.save() // Save the updated session
            resultsObserver.currentRecordingSession = nil // Clear session from observer
        }
        self.currentRecordingSession = nil // Clear current session from ViewController

        updateResultsTextView(with: "Analysis stopped.\n")
        updateAnalysisButtonState(isRecording: false)
    }

    // MARK: - UI Update Helpers

    private func updateResultsTextView(with text: String, append: Bool = true) {
        DispatchQueue.main.async {
            if append {
                self.resultsTextView.text += text
            } else {
                self.resultsTextView.text = text
            }
            let bottom = NSRange(location: self.resultsTextView.text.count, length: 0)
            self.resultsTextView.scrollRangeToVisible(bottom)
        }
    }

    private func updateAnalysisButtonState(isRecording: Bool) {
        if isRecording {
            analysisButton?.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
            let title = NSAttributedString(string: "Stop Session".translate(), attributes: attributesBold)
            analysisButton?.setAttributedTitle(title, for: .normal)
        } else {
            analysisButton?.setImage(UIImage(systemName: "record.circle"), for: .normal)
            let title = NSAttributedString(string: "Start New Session".translate(), attributes: attributesBold)
            analysisButton?.setAttributedTitle(title, for: .normal)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    public func multicastViewModelSendData(data: String){
        DispatchQueue.main.async{
            self.multicastViewModel.send(message: data)
        }
    }

    // MARK: - Button Actions (Presenting SwiftUI Views)

    @IBAction func showSoundChart(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext

        let isCurrentSessionRecording = (self.currentRecordingSession != nil && self.audioEngine != nil)
        let currentLiveSessionID = self.currentRecordingSession?.id

        let initialChartSessionID: UUID?
        if isCurrentSessionRecording {
            initialChartSessionID = currentLiveSessionID
        } else {
            // Optionally, fetch the ID of the most recent past session if no live session
            initialChartSessionID = fetchedResultsController.fetchedObjects?.first?.id
        }

        let chartView = SnoreDoctorChartView(
            initialSessionID: initialChartSessionID,
            isLiveSessionActive: isCurrentSessionRecording,
            currentLiveSessionID: currentLiveSessionID
        )
        .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: chartView)
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showPlaybackView(_ sender: UIButton) {
        // TODO: Implement playback view presentation
        showAlert(title: "Coming Soon", message: "Playback functionality will be available in a future update!")
    }

    @IBAction func showHistogram(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let histogramView = SnoreDoctorEventNameHistogramView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: histogramView)
        hostingController.modalPresentationStyle = .pageSheet
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showSleepReport(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let sleepReportView = SleepReportView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: sleepReportView)
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showSettings(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let settingsView = SettingsView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }
}

// MARK: - SnoreDoctorObserverDelegate Extension for ViewController

extension MainViewController: SoundEventDetectionObserverDelegate {
    func didDetectSoundEvent(logString: String) {
        updateResultsTextView(with: logString)
        multicastViewModelSendData(data: logString)
    }

    func analysisDidFail(error: Error) {
        updateResultsTextView(with: "Error during analysis: \(error.localizedDescription)\n")
        stopAudioAnalysis() // Attempt to stop analysis on error
        showAlert(title: "Analysis Error", message: "An error occurred during analysis: \(error.localizedDescription)")
    }

    func analysisDidComplete() {
        updateResultsTextView(with: "Analysis completed.\n")
        stopAudioAnalysis() // Analysis completed, stop fully
        showAlert(title: "Analysis Complete", message: "Your recording session has ended.")
    }
}

// MARK: - Audio Session Notification Handlers

extension MainViewController {
    @objc private func handleAudioSessionInterruptionBegan() {
        DispatchQueue.main.async {
            self.updateResultsTextView(with: "Audio session interrupted. Analysis paused.\n")
            self.audioEngine?.pause() // Pause the audio engine
            self.resultsObserver.pauseMonitoring() // Tell your observer to pause if it has state
            self.updateAnalysisButtonState(isRecording: false) // Update UI
        }
    }

    @objc private func handleAudioSessionInterruptionEndedShouldResume() {
        DispatchQueue.main.async {
            self.updateResultsTextView(with: "Audio session resumed. Attempting to restart analysis.\n")
            do {
                try self.audioEngine?.start()
                self.resultsObserver.resumeMonitoring() // Tell your observer to resume
                self.updateAnalysisButtonState(isRecording: true) // Update UI
            } catch {
                self.updateResultsTextView(with: "Failed to restart audio engine after interruption: \(error.localizedDescription)\n")
                self.stopAudioAnalysis() // If restart fails, stop gracefully
                self.showAlert(title: "Analysis Issue", message: "Could not resume analysis after interruption. Please restart manually.")
            }
        }
    }

    @objc private func handleAudioSessionInterruptionEndedCouldNotResume() {
        DispatchQueue.main.async {
            self.updateResultsTextView(with: "Audio session could not resume. Analysis stopped.\n")
            self.stopAudioAnalysis() // Force stop the analysis
            self.showAlert(title: "Analysis Stopped", message: "Audio session could not resume. Your analysis session has ended.")
        }
    }

    @objc private func handleMediaServicesReset() {
        DispatchQueue.main.async {
            self.updateResultsTextView(with: "Critical: Audio services reset by system. Analysis stopped.\n")
            self.stopAudioAnalysis() // Stop current session immediately
            self.showAlert(title: "System Audio Reset", message: "The audio system experienced a critical error. Please try starting a new analysis session. If the problem persists, restarting the app might help.")
        }
    }
}

// MARK: - UITableViewDataSource

extension MainViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordingSessionCell", for: indexPath)
        let session = fetchedResultsController.object(at: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = session.title

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy, h:mm a"

        var detailText = ""
        if let startTime = session.startTime, let endTime = session.endTime {
            detailText = "\(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        } else if let startTime = session.startTime {
            detailText = "\(dateFormatter.string(from: startTime)) (Ongoing/Unfinished)"
        } else {
            detailText = "Invalid Session Time"
        }

        if let notes = session.notes, !notes.isEmpty {
            let noteSnippet = notes.prefix(50)
            detailText += "\nNotes: \(noteSnippet)\(notes.count > 50 ? "..." : "")"
            content.secondaryTextProperties.numberOfLines = 0
        }
        content.secondaryText = detailText

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let sessionToDelete = fetchedResultsController.object(at: indexPath)
            PersistenceController.shared.container.viewContext.delete(sessionToDelete)
            PersistenceController.shared.save()
        }
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let session = fetchedResultsController.object(at: indexPath)
        presentSessionDetails(for: session)
    }

    private func presentSessionDetails(for session: RecordingSession) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let sessionDetailView = SessionDetailView(session: session)
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: sessionDetailView)
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true)
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MainViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        sessionsTableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                sessionsTableView.insertRows(at: [newIndexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                sessionsTableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .update:
            if let indexPath = indexPath {
                sessionsTableView.reloadRows(at: [indexPath], with: .none)
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                sessionsTableView.deleteRows(at: [indexPath], with: .fade)
                sessionsTableView.insertRows(at: [newIndexPath], with: .fade)
            }
        @unknown default:
            fatalError("Unknown NSFetchedResultsChangeType")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        sessionsTableView.endUpdates()
    }
}
