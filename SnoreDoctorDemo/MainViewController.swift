//
//  MainViewController.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 08.05.25.
//

import UIKit
import SoundAnalysis
import AVFoundation
import SwiftUI // Import SwiftUI to use UIHostingController
import CoreData // Import CoreData
import CoreML
import Combine // Import Combine for reactive handling

// Assume AudioAnalysisError, PersistenceController, AudioRecorder, AudioManager,
// RecordingSession, MulticastServiceViewModel, and helper extensions exist elsewhere.

class MainViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    

    // MARK: - Properties

    //private let multicastViewModel = MulticastServiceViewModel()

    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var analysisButton: UIButton?
    @IBOutlet weak var showChartButton: UIButton?
    @IBOutlet weak var showPlaybackButton: UIButton?
    @IBOutlet weak var settingsButton: UIButton?

    @IBOutlet weak var sessionsTableView: UITableView!

  
    // Shared instance of your Data Manager
    let soundDataManager = SoundDataManager()
    let persistenceController = PersistenceController.shared
    
    // 🔥 NEW: Combine subscription to monitor the SoundRecognitionManager's output
    private var analysisSubscription: AnyCancellable?
    private lazy var resultsObserver = SoundEventDetectionObserver(delegate: self, soundDataManager : soundDataManager)

    // Instances of your managers
    private let audioRecorderManager = AudioRecorderManager.shared
    private let audioEngineManager = AudioEngineManager.shared // Use the singleton AudioManager

    
    // NSFetchedResultsController for RecordingSessions
    private lazy var fetchedResultsController: NSFetchedResultsController<RecordingSession> = {
        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: persistenceController.container.viewContext,
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
       setupNotificationObservers()

        // Request microphone permission on launch
        requestMicrophonePermission()
        AudioEngineManager.shared.setup()
   
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // No redundant permission checks here; viewDidLoad handles initial request.
        // Keep the screen awake while the user is monitoring their snoring
        UIApplication.shared.isIdleTimerDisabled = true
       
    }
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        // The view is now in the hierarchy, safe to layout!
        // Only fetch if we haven't already or if we need to refresh
        if fetchedResultsController.fetchedObjects == nil {
            setupFetchedResultsController()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Give control back to the system when they leave the screen
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    deinit {
        // Ensure all audio resources are stopped and released
        stopAudioAnalysis()
        // Cancel the Combine subscription
        analysisSubscription?.cancel()
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
       // multicastViewModel.start()
    }

    // setupAudioAnalysisComponents is removed as logic is now in SoundRecognitionManager
    
    @objc private func handleDataCleared() {
        setupFetchedResultsController()
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
        
        NotificationCenter.default.addObserver(
            forName: .dataDidClear,
            object: nil,
            queue: .main // Ensures the UI update happens on the main thread
        ) { [weak self] _ in
            // Inline implementation of the refresh logic
            self?.setupFetchedResultsController()
        }
        
        // 🔥 REMOVED: Audio session interruption and media services reset notifications
        // are now handled internally by SoundRecognitionManager, which will send a
        // .failure signal via Combine.

        // We only keep the Media Services Reset handler here as an emergency stop,
        // in case the internal manager fails to catch a critical system failure.
        NotificationCenter.default.addObserver(self,
                                                selector: #selector(handleMediaServicesReset),
                                                name: .mediaServicesReset,
                                                object: nil)
        
       
    }

    // MARK: - Microphone Permission

    private func requestMicrophonePermission() {
        // We still request permission here for initial UI state setup,
        // but the SoundRecognitionManager performs its own check during startRecognition.
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
        // 🔥 Check state using the manager's public `isRunning` property
        if SoundRecognitionManager.shared.isRunning {
            stopAudioAnalysis()
        } else {
            startAudioAnalysis()
        }
    }
    
    private func startAudioAnalysis() {
        guard analysisButton?.isEnabled == true else {
            updateResultsTextView(with: "Microphone permission not granted or analysis disabled.\n")
            return
        }
        guard !SoundRecognitionManager.shared.isRunning else {
            updateResultsTextView(with: "Audio analysis is already running.\n")
            return
        }

        updateResultsTextView(with: "Starting audio analysis...\n", append: false)

        // Disable immediately to block double-taps during async setup.
        analysisButton?.isEnabled = false

        Task { @MainActor in
            do {
                setupAnalysisSubscription()

                let modelSource: ModelSource = UserDefaults.standard.useCustomLLModel
                    ? .custom(modelName: "MySoundClassifier1")
                    : .appleVersion1

                try await SoundRecognitionManager.shared.startRecognition(
                    observer: resultsObserver,
                    modelSource: modelSource,
                    windowDuration: UserDefaults.standard.analysisWindowDuration,
                    overlapFactor: UserDefaults.standard.analysisOverlapFactor
                )

                // Only reached if setup fully succeeded.
                updateResultsTextView(with: "Analysis started.\n")
                updateAnalysisButtonState(isRecording: true)
                analysisButton?.isEnabled = true

            } catch {
                // Clean up the manager (won't crash even if setup never completed).
                SoundRecognitionManager.shared.stopRecognition()

                // Always re-enable the button so the user can try again.
                analysisButton?.isEnabled = true
                updateAnalysisButtonState(isRecording: false)

                let message = (error as? AudioAnalysisError)?.errorDescription
                    ?? error.localizedDescription

                updateResultsTextView(with: "Failed to start: \(message)\n")
                showAlert(title: "Analysis Setup Error", message: message)
            }
        }
    }

    private func stopAudioAnalysis() {
        
        // 1. Stop recognition in the singleton
        SoundRecognitionManager.shared.stopRecognition()
        
     
        // 2. Cancel the Combine subscription
        analysisSubscription?.cancel()
        analysisSubscription = nil
        
    
        persistenceController.save() // Save the updated session
  
        updateResultsTextView(with: "Analysis stopped.\n")
        updateAnalysisButtonState(isRecording: false)
    }

    // MARK: - Combine Result Handling
    private func setupAnalysisSubscription() {
        analysisSubscription = SoundRecognitionManager.shared.classificationSubject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    self?.analysisDidComplete()
                case .failure(let error):
                    self?.analysisDidFail(error: error)
                }
            }, receiveValue: { _ in
                // ⚠️ IGNORE VALUES HERE
                // We ignore the classification result here because `resultsObserver`
                // is already handling the data and calling `didDetectSoundEvent`.
                //self?.handleClassificationResult(classificationResult)
            })
    }
   

    private func handleClassificationResult(_ result: SNClassificationResult) {
      
        // --- Log Generation (Simplified from old observer logic) ---
        let sortedClassifications = result.classifications.sorted { $0.confidence > $1.confidence }
        
        guard let topClassification = sortedClassifications.first else { return }

        // Only log if confidence meets a threshold (e.g., 90%)
        // Assuming 'confidenceThreshold' exists in UserDefaults
        let confidenceThreshold = UserDefaults.standard.float(forKey: "confidenceThreshold")
        
        if topClassification.confidence >= Double(confidenceThreshold) {
            
            let eventName = topClassification.identifier
            let confidence = String(format: "%.2f", topClassification.confidence)
            let timestamp = String(format: "%.2f", result.timeRange.start.seconds)

            // Example log string
            let logString = "[\(timestamp)s] Detected: **\(eventName)** (\(confidence))\n"

            // 4. Update UI and Multicast
            updateResultsTextView(with: logString)
            multicastViewModelSendData(data: logString)
            
            // 🔥 REMINDER: Add logic here to update the currentRecordingSession's counts
            // e.g., if eventName == "Snoring" { session.snoreCount += 1 }
        }
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
           // self.multicastViewModel.send(message: data)
        }
    }

    // MARK: - Button Actions (Presenting SwiftUI Views)
    @IBAction func showSoundChart(_ sender: UIButton) {
        let managedObjectContext = persistenceController.container.viewContext

        // 1. Get the session reference from the observer instead of the ViewController
        let activeSession = resultsObserver.currentRecordingSession
        let isRecording = (activeSession != nil && SoundRecognitionManager.shared.isRunning)
        
        // 2. Use the ID directly from the active session object
        let currentLiveSessionID = activeSession?.id

        let initialChartSessionID: UUID?
        if isRecording {
            initialChartSessionID = currentLiveSessionID
        } else {
            // Fallback to the most recent session in the database
            initialChartSessionID = fetchedResultsController.fetchedObjects?.first?.id
        }

        // 3. Initialize your SwiftUI view
        let chartView = SnoreAnalysisReport(
            initialSessionID: initialChartSessionID,
            isLiveSessionActive: isRecording,
            currentLiveSessionID: currentLiveSessionID
        )
        .environment(\.managedObjectContext, managedObjectContext)
        .environmentObject(soundDataManager)

        let hostingController = UIHostingController(rootView: chartView)
        hostingController.view.backgroundColor = .systemBackground
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }

   

    @IBAction func showPlaybackView(_ sender: UIButton) {
        // TODO: Implement playback view presentation
        showAlert(title: "Coming Soon", message: "Playback functionality will be available in a future update!")
    }

    @IBAction func showHistogram(_ sender: UIButton) {
        let managedObjectContext = persistenceController.container.viewContext
        let histogramView = SnoreDoctorEventNameHistogramView()
            .environment(\.managedObjectContext, managedObjectContext)
            .environmentObject(soundDataManager)

        let hostingController = UIHostingController(rootView: histogramView)
        hostingController.modalPresentationStyle = .pageSheet
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showSleepReport(_ sender: UIButton) {
        let managedObjectContext = persistenceController.container.viewContext
        let sleepReportView = CalenderSleepReport()
            .environment(\.managedObjectContext, managedObjectContext)
            .environmentObject(soundDataManager)

        let hostingController = UIHostingController(rootView: sleepReportView)
        // This tells the hosting controller to let the SwiftUI view
        // decide how to fill the space, ignoring the UIKit "readable" margins.
        hostingController.view.backgroundColor = .systemBackground
        
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showSettings(_ sender: UIButton) {
        let managedObjectContext = persistenceController.container.viewContext
        
        // 2. Inject both the Context AND the Manager
        let settingsView = SettingsView()
                .environment(\.managedObjectContext, managedObjectContext)
                .environmentObject(soundDataManager) 
        
        let hostingController = UIHostingController(rootView: settingsView)
        // This tells the hosting controller to let the SwiftUI view
        // decide how to fill the space, ignoring the UIKit "readable" margins.
        hostingController.view.backgroundColor = .systemBackground
        
        hostingController.modalPresentationStyle = .fullScreen
        self.present(hostingController, animated: true, completion: nil)
    }
}

// MARK: - SnoreDoctorObserverDelegate Extension for ViewController

extension MainViewController: SoundEventDetectionObserverDelegate {
    func didDetectSoundEvent(logString: String) {
        updateResultsTextView(with: logString)
        //multicastViewModelSendData(data: logString)
    }

    
     func analysisDidFail(error: Error) {
        updateResultsTextView(with: "Error during analysis: \(error.localizedDescription)\n")
        // Since SoundRecognitionManager calls stopRecognition internally upon failure,
        // we just need to update the UI state.
          resultsObserver.finalizeSession()
         persistenceController.save()

        
        updateAnalysisButtonState(isRecording: false)
        showAlert(title: "Analysis Stopped", message: "Analysis stopped due to an error: \(error.localizedDescription)")
    }

     func analysisDidComplete() {
        updateResultsTextView(with: "Analysis completed.\n")
        stopAudioAnalysis() // Ensures full teardown and save
        showAlert(title: "Analysis Complete", message: "Your recording session has ended.")
    }

}
// MARK: - Audio Session Notification Handlers (Minimal)

extension MainViewController {
    
    // This remains as a fail-safe for critical system failures not caught by the manager.
    @objc private func handleMediaServicesReset() {
        DispatchQueue.main.async {
            self.updateResultsTextView(with: "Critical: Audio services reset by system. Analysis stopped.\n")
            self.stopAudioAnalysis() // Stop current session immediately
            self.showAlert(title: "System Audio Reset", message: "The audio system experienced a critical error. Please try starting a new analysis session. If the problem persists, restarting the app might help.")
        }
    }
    
    // Removed: handleAudioSessionInterruptionBegan
    // Removed: handleAudioSessionInterruptionEndedShouldResume
    // Removed: handleAudioSessionInterruptionEndedCouldNotResume
}

// MARK: - UITableViewDataSource


extension MainViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

  
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Ensure the section index actually exists before accessing it
        guard let sections = fetchedResultsController.sections, section < sections.count else {
            return 0
        }
        return sections[section].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let session = fetchedResultsController.object(at: indexPath)
        presentSessionDetails(for: session)
    }
    
    
    
    ///TODO:: try to use SessionTableViewCell 
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordingSessionCell", for: indexPath)
        let session = fetchedResultsController.object(at: indexPath)
        var content = cell.defaultContentConfiguration()

        // 1. Title
        content.text = session.title

        // 2. Date String
        var dateString = "Invalid Date"
        if let start = session.startTime {
            dateString = AppFormatters.sessionDateFormatter.string(from: start)
        }

        // 3. Duration String
        var durationString = ""
        if let start = session.startTime, let end = session.endTime {
            let interval = end.timeIntervalSince(start)
            durationString = AppFormatters.durationFormatter.string(from: interval) ?? ""
        } else if session.startTime != nil {
            durationString = "Ongoing"
        }

        // Combine into secondary text
        content.secondaryText = "\(dateString) • \(durationString)"
        
        // Handle notes snippet as before...
        if let notes = session.notes, !notes.isEmpty {
            content.secondaryText! += "\nNotes: \(notes.prefix(50))\(notes.count > 50 ? "..." : "")"
        }

        cell.contentConfiguration = content
        return cell
    }
    

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let sessionToDelete = fetchedResultsController.object(at: indexPath)
            persistenceController.container.viewContext.delete(sessionToDelete)
            persistenceController.save()
        }
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {
   

    private func presentSessionDetails(for session: RecordingSession) {
        let managedObjectContext = persistenceController.container.viewContext
        let sessionDetailView = SessionDetailReport(session: session)
            .environment(\.managedObjectContext, managedObjectContext)
            .environmentObject(soundDataManager)

        let hostingController = UIHostingController(rootView: sessionDetailView)
        // This tells the hosting controller to let the SwiftUI view
        // decide how to fill the space, ignoring the UIKit "readable" margins.
        hostingController.view.backgroundColor = .clear
        
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
