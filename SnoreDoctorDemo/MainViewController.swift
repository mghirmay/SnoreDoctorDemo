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

// Assuming you have this somewhere, perhaps in AudioManager.swift or a dedicated error file
enum AudioAnalysisError: LocalizedError {
    case inputNodeMissing
    case requestCreationFailed(Error)
    case audioSessionSetupFailed(Error)

    var errorDescription: String? {
        switch self {
        case .inputNodeMissing:
            return "Audio engine input node is not available."
        case .requestCreationFailed(let underlyingError):
            return "Failed to create sound analysis request: \(underlyingError.localizedDescription)"
        case .audioSessionSetupFailed(let underlyingError):
            return "Failed to set up audio session: \(underlyingError.localizedDescription)"
        }
    }
}


class MainViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    private let multicastViewModel = MulticastServiceViewModel()

    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var analysisButton: UIButton?
    @IBOutlet weak var showChartButton: UIButton?
    @IBOutlet weak var showPlaybackButton: UIButton?
    @IBOutlet weak var settingsButton: UIButton?

    // NEW: IBOutlet for the table view from Storyboard
    @IBOutlet weak var sessionsTableView: UITableView! // Connect this in your Storyboard!

    // CHANGED: Now holds the current RecordingSession object
    private var currentRecordingSession: RecordingSession?

    // Add a property to hold the AVAudioEngine
    private var audioEngine: AVAudioEngine?
    private var audioStreamAnalyzer: SNAudioStreamAnalyzer?

    private let analysisQueue = DispatchQueue(label:"de.sinitpower.SnoreDoctor.analysisQueue")

    private var soundClassifierRequest: SNClassifySoundRequest?

    // Instance of SoundDataManager
    private let soundDataManager = SoundDataManager()
    // Instance of AudioRecorder - now used for recording to file
    private let audioRecorder = AudioRecorder()
    // Instance of AudioManager - now used for consistent audio session setup
    private let audioManager = AudioManager.shared // Use the singleton AudioManager

    // NEW: NSFetchedResultsController for RecordingSessions
    private lazy var fetchedResultsController: NSFetchedResultsController<RecordingSession> = {
        let fetchRequest: NSFetchRequest<RecordingSession> = RecordingSession.fetchRequest()
        // Sort by startTime descending to show newest sessions first
        let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: PersistenceController.shared.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil // Set a cache name if you have many sections and want performance improvements
        )
        controller.delegate = self
        return controller
    }()

    func checkMicrophonePermission() -> AVAuthorizationStatus {
        let microphonePermissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch microphonePermissionStatus {
        case .authorized:
            // The user has previously granted permission to use the microphone
            return .authorized
            
        case .denied, .restricted:
            // The user has explicitly denied or restricted microphone access
            return .denied
            
        case .notDetermined:
            // The user has not yet been asked for microphone access
            return .notDetermined
            
        @unknown default:
            // Handle future cases if necessary
            return .denied
        }
    }
    
    var alertNoPermission = UIAlertController()
    
    func noPermission() {
        
        let message = String(format: NSLocalizedString("NoPermission_message", comment: ""))
        alertNoPermission = UIAlertController(title: NSLocalizedString("NoPermission_Headline", comment: "") , message: message, preferredStyle: .alert)
        
        
        
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            alertNoPermission.addAction(UIAlertAction(title: "Cancel".translate(), style: .cancel, handler: { _ in }))
        case .pad:
            alertNoPermission.addAction(UIAlertAction(title: "Cancel".translate(), style: .default, handler: { _ in }))
        default:
            alertNoPermission.addAction(UIAlertAction(title: "Cancel".translate(), style: .default, handler: { _ in }))
        }
        alertNoPermission.popoverPresentationController?.sourceView = self.view
        alertNoPermission.popoverPresentationController?.sourceRect = CGRect(    // the place to display the popover
            origin: CGPoint(
                x: self.view.bounds.midX,
                y: self.view.bounds.midY
            ),
            size: .zero
        )
        alertNoPermission.popoverPresentationController?.permittedArrowDirections = [] // the direction of the arrow
        alertNoPermission.popoverPresentationController?.delegate = self
        
        self.present(alertNoPermission, animated: true, completion: nil)
    }
    
    @objc func checkPermission() {
        let deadLine = DispatchTime.now() + 5
        
        DispatchQueue.main.asyncAfter(deadline: deadLine) {
            
            let microphonePermission = self.checkMicrophonePermission()
            print("microphonePermission",microphonePermission)
            switch microphonePermission {
            case .authorized:
                // Microphone permission is granted, you can use the microphone
                print("Microphone permission granted")
                
            case .denied, .restricted:
                // Microphone permission is denied or restricted, inform the user
                print("Microphone permission denied or restricted")
                self.noPermission()
            case .notDetermined:
                // Microphone permission is not determined, request permission
                print("Microphone permission not determined")
                self.checkPermission()
            @unknown default:
                // Handle future cases if necessary
                break
            }
        }
    }
    
    

    // MARK: - UI Updates & Multicast

    public func updateResultsTextView(with text: String, append: Bool = true) {
        DispatchQueue.main.async {
            if append {
                self.resultsTextView.text += text
            } else {
                self.resultsTextView.text = text
            }
            // Scroll to the bottom
            let bottom = NSRange(location: self.resultsTextView.text.count, length: 0)
            self.resultsTextView.scrollRangeToVisible(bottom)
        }
    }

    public func multicastViewModelSendData(data: String){
        DispatchQueue.main.async{
            self.multicastViewModel.send(message: data)
        }
    }

    // MARK: - Audio Session & Permission

    // Centralized permission request
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { // Ensure completion is on main thread
                completion(granted)
            }
        }
    }
    // MARK: - Sound Analysis Setup
    private func setupSoundClassifier() {
        do {
            soundClassifierRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)

            // Retrieve values from UserDefaults
            let windowDuration = UserDefaults.standard.analysisWindowDuration
            let overlapFactor = UserDefaults.standard.analysisOverlapFactor

            // Apply settings
            soundClassifierRequest?.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
            soundClassifierRequest?.overlapFactor = overlapFactor

        } catch {
            print("Failed to create sound classification request: \(error.localizedDescription)")
            updateResultsTextView(with: "Error: Could not load sound classifier. \(error.localizedDescription)\n")
            analysisButton?.isEnabled = false // Disable analysis if model fails to load
        }
    }
    
    
    // MARK: - Audio Analysis Control

    private func startAudioAnalysis() {
        guard audioStreamAnalyzer == nil else {
            updateResultsTextView(with: "Audio analysis is already running. \n")
            return
        }

        updateResultsTextView(with: "Starting audio analysis... \n", append: false)

        do {
            try audioManager.setupAudioSessionForRecording(
                category: .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )

            // 1. Create a new RecordingSession object
            let context = PersistenceController.shared.container.viewContext
            let newSession = RecordingSession(context: context)
            newSession.id = UUID()
            newSession.startTime = Date()
            newSession.notes = nil // NEW: Initialize notes as nil

            if let initialRecordingURL = try audioRecorder.startAndGetRecordingURL() {
                   newSession.audioFileName = initialRecordingURL.lastPathComponent
                   let dateFormatter = DateFormatter()
                   // NEW DATE FORMAT: EEEE for full weekday name
                   dateFormatter.dateFormat = "EEEE, MMM d, h:mm a" // e.g., "Monday, Jun 30, 9:30 PM"

                   if let startTime = newSession.startTime {
                       // REMOVED "Session " prefix
                       newSession.title = dateFormatter.string(from: startTime)
                   } else {
                       newSession.title = "Unknown Time" // Adjusted for clarity if time is missing
                   }
            } else {
                throw AudioAnalysisError.requestCreationFailed(NSError(domain: "ViewController", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain initial recording URL."]))
            }

            self.currentRecordingSession = newSession // Store the new session
            resultsObserver.currentRecordingSession = newSession // Pass to the observer

            print("Recording session started for file: \(newSession.audioFileName ?? ("udefined filename"))")
            let newAudioEngine = AVAudioEngine()
            let inputNode = newAudioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            audioStreamAnalyzer = SNAudioStreamAnalyzer(format: recordingFormat)

            guard let analyzer = audioStreamAnalyzer, let request = soundClassifierRequest else {
                let errorMessage = "Error: Failed to initialize audio stream analyzer or sound classifier request."
                print(errorMessage)
                updateResultsTextView(with: errorMessage)
                stopAudioAnalysis()
                return
            }

            let bufferSize = AVAudioFrameCount(2048)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                guard let self = self, let analyzer = self.audioStreamAnalyzer else { return }
                self.analysisQueue.async {
                    analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
                }
            }

            try analyzer.add(request, withObserver: resultsObserver)
            try newAudioEngine.start()
            print("Audio engine started.")
            self.audioEngine = newAudioEngine
            updateResultsTextView(with: "Analysis started.\n")
            // Set button image to filled circle
            analysisButton?.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)


        } catch let error as AudioAnalysisError {
            print("Audio analysis setup failed: \(error.localizedDescription)")
            updateResultsTextView(with: "Analysis setup failed: \(error.localizedDescription)\n")
            stopAudioAnalysis()
        } catch {
            print("Audio analysis setup failed with generic error: \(error.localizedDescription)")
            updateResultsTextView(with: "Analysis setup failed: \(error.localizedDescription)\n")
            stopAudioAnalysis()
        }
    }

    private func stopAudioAnalysis() {
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        audioEngine = nil

        audioStreamAnalyzer?.removeAllRequests()
        audioStreamAnalyzer = nil
        resultsObserver.currentRecordingSession = nil // Clear session from observer

        _ = audioRecorder.stopAndGetRecordingURL() // Stop the audio recording file

        // 2. Set endTime for the current session and save it
        if let session = self.currentRecordingSession {
            session.endTime = Date()
            PersistenceController.shared.save() // Save the session (and its related events)
            print("Saved Recording Session: \(session.title ?? session.id?.uuidString ?? "N/A")")
        } else {
            print("Warning: No currentRecordingSession to save.")
        }

        self.currentRecordingSession = nil // Clear current session from ViewController

        updateResultsTextView(with: "Analysis stopped.\n")
        // Set button image to outline circle
        analysisButton?.setImage(UIImage(systemName: "record.circle"), for: .normal)
    }

    @IBAction func toggleAnalysis(_ sender: UIButton) {
        if audioStreamAnalyzer == nil {
            startAudioAnalysis()
            // The image will be set in startAudioAnalysis()
            
            let title = NSAttributedString(string: "Stop Session".translate(), attributes: attributesBold)
            analysisButton?.setAttributedTitle(title, for: .normal)
            
        } else {
            stopAudioAnalysis()
            
            analysisButton?.setImage(UIImage(systemName: "record.circle"), for: .normal)
            let title = NSAttributedString(string: "Start New Session".translate(), attributes: attributesBold)
            analysisButton?.setAttributedTitle(title, for: .normal)
            
            
            // The image will be set in stopAudioAnalysis()
        }
    }

    @IBAction func showSoundChart(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext

        // Determine live session status and ID
        let isCurrentSessionRecording = (self.currentRecordingSession != nil && self.audioStreamAnalyzer != nil)
        let currentLiveSessionID = self.currentRecordingSession?.id

        // Initialize SnoreDoctorChartView.
        // If you want to initially show the live session, pass currentLiveSessionID.
        // If you want to initially show the *last* recorded session, you'd need to fetch it here.
        // For simplicity, let's say we always try to show live first if active, otherwise no initial selection.
        let initialChartSessionID: UUID?
        if isCurrentSessionRecording {
            initialChartSessionID = currentLiveSessionID
        } else {
            initialChartSessionID = nil // Or fetch the ID of the most recent past session here if desired
        }

        let chartView = SnoreDoctorChartView(
            initialSessionID: initialChartSessionID,
            isLiveSessionActive: isCurrentSessionRecording,
            currentLiveSessionID: currentLiveSessionID
        )
        .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: chartView)
        
        //(Optional) Configure presentation style
        // .fullScreen covers the entire screen.
        // .pageSheet presents as a sheet on iPad, or full screen on iPhone.
        // .formSheet also presents as a sheet, typically for forms.
        hostingController.modalPresentationStyle = .fullScreen

        self.present(hostingController, animated: true, completion: nil)
    }


    @IBAction func showPlaybackView(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext

        let audioPlaybackViewModel = AudioPlaybackViewModel()

        // Create the SwiftUI view
        let audioPlaybackView = AudioPlaybackView(viewModel: audioPlaybackViewModel)

        // Then apply the environment modifier explicitly
        let hostedView = audioPlaybackView.environment(\.managedObjectContext, managedObjectContext)

        // Pass the modified view to UIHostingController
        let hostingController = UIHostingController(rootView: hostedView)
       
        // (Optional) Configure presentation style
        // .fullScreen covers the entire screen.
        // .pageSheet presents as a sheet on iPad, or full screen on iPhone.
        // .formSheet also presents as a sheet, typically for forms.
        hostingController.modalPresentationStyle = .fullScreen
        
        self.present(hostingController, animated: true, completion: nil)
    }

    // Action for the show Histogram button
    @IBAction func showHistogram(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext

        // Renamed here:
        let histogramView = SnoreDoctorEventNameHistogramView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: histogramView)
        hostingController.modalPresentationStyle = .pageSheet
        self.present(hostingController, animated: true, completion: nil)
    }

    @IBAction func showSleepReport(_ sender: UIButton) {
            // 1. Get the Core Data managed object context
            // You already have PersistenceController.shared, so this is straightforward.
            let managedObjectContext = PersistenceController.shared.container.viewContext

            // 2. Instantiate your SwiftUI SleepReportView
            let sleepReportView = SleepReportView()
                // 3. Inject the managed object context into the SwiftUI environment
                .environment(\.managedObjectContext, managedObjectContext)

            // 4. Create a UIHostingController with your SwiftUI view as its root view
            let hostingController = UIHostingController(rootView: sleepReportView)

            // (Optional) Configure presentation style
            // .fullScreen covers the entire screen.
            // .pageSheet presents as a sheet on iPad, or full screen on iPhone.
            // .formSheet also presents as a sheet, typically for forms.
           hostingController.modalPresentationStyle = .fullScreen

            // 6. Present the UIHostingController
            self.present(hostingController, animated: true, completion: nil)
        }
    
    @IBAction func showSettings(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let settingsView = SettingsView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: settingsView)
        
        // (Optional) Configure presentation style
        // .fullScreen covers the entire screen.
        // .pageSheet presents as a sheet on iPad, or full screen on iPhone.
        // .formSheet also presents as a sheet, typically for forms.
        hostingController.modalPresentationStyle = .fullScreen
        
        self.present(hostingController, animated: true, completion: nil)
    }

    // MARK: - SNResultsObserving Delegate (from SnoreDoctorObserver)

    // Using lazy var to ensure resultsObserver is initialized when first accessed
    // and is holding a weak reference to self.
    private lazy var resultsObserver = SnoreDoctorObserver(delegate: self)


    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    let attributesBold: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 21, weight: .bold)
    ]
    
    
    // MARK: - ViewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateResultsTextView(with: "Ready to analyze sounds... \n", append: false)
        
        // Configure Table View
        sessionsTableView.dataSource = self
        sessionsTableView.delegate = self
        // If you're using the prototype cell from the storyboard, you don't need to register it here.
        // If you were creating a custom cell programmatically, you'd register it:
        // sessionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "RecordingSessionCell")
        
        
        // Perform initial fetch for the table view
        do {
            try fetchedResultsController.performFetch()
            sessionsTableView.reloadData() // Populate table view with existing data
        } catch {
            print("Failed to perform initial fetch for RecordingSessions: \(error.localizedDescription)")
            showAlert(title: "Error", message: "Could not load past sessions: \(error.localizedDescription)")
        }
        
        // Let the user tap the button.
        // Ensure analysisButton is disabled initially until permission is granted
        
        
        analysisButton?.layer.cornerRadius = 10
        
        
        let title = NSAttributedString(string: "Start New Session".translate(), attributes: attributesBold)
        analysisButton?.setAttributedTitle(title, for: .normal)
        
        
        
        analysisButton?.isEnabled = false
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.analysisButton?.isEnabled = granted
                if !granted {
                    self?.updateResultsTextView(with: "Microphone access denied. Please grant permission in Settings.\n")
                }
            }
        }
        setupSoundClassifier()
        multicastViewModel.start()
        // Set initial image for the button
        analysisButton?.setImage(UIImage(systemName: "record.circle"), for: .normal)
    }
    
    deinit {
        // Ensure all audio resources are stopped and released when ViewController is deinitialized
        stopAudioAnalysis()
        print("ViewController deinitialized")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkPermission()
    }
    
}


// MARK: - SnoreDoctorObserverDelegate Extension for ViewController
extension MainViewController: SnoreDoctorObserverDelegate {
    func didDetectSoundEvent(logString: String) {
        updateResultsTextView(with: logString)
        multicastViewModelSendData(data: logString)
    }

    func analysisDidFail(error: Error) {
        updateResultsTextView(with: "Error: \(error.localizedDescription)\n")
        stopAudioAnalysis() // Attempt to stop analysis on error
        showAlert(title: "Analysis Error", message: "An error occurred during analysis: \(error.localizedDescription)")
    }

    func analysisDidComplete() {
        updateResultsTextView(with: "Analysis completed.\n")
        stopAudioAnalysis() // Analysis completed, stop fully
        showAlert(title: "Analysis Complete", message: "Your recording session has ended.")
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
        // Use the reuse identifier from your Storyboard prototype cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordingSessionCell", for: indexPath)
        let session = fetchedResultsController.object(at: indexPath)

        // Configure the cell's content using defaultContentConfiguration for modern cells
        var content = cell.defaultContentConfiguration()

        content.text = session.title // Use the generated title
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy, h:mm a" // Adjusted date format for clarity

        var detailText = ""
        if let startTime = session.startTime, let endTime = session.endTime {
            detailText = "\(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        } else if let startTime = session.startTime {
            detailText = "\(dateFormatter.string(from: startTime)) (Ongoing/Unfinished)"
        } else {
            detailText = "Invalid Session Time"
        }

        // Add notes snippet if available
        if let notes = session.notes, !notes.isEmpty {
            let noteSnippet = notes.prefix(50) // Show first 50 characters
            detailText += "\nNotes: \(noteSnippet)\(notes.count > 50 ? "..." : "")"
            content.secondaryTextProperties.numberOfLines = 0 // Allow multiple lines for notes
        }
        content.secondaryText = detailText

        cell.contentConfiguration = content
        
        // Add a disclosure indicator to show it's tappable for details/editing
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    // Optional: Add swipe-to-delete functionality
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let sessionToDelete = fetchedResultsController.object(at: indexPath)
            PersistenceController.shared.container.viewContext.delete(sessionToDelete)
            PersistenceController.shared.save() // Save changes to persist deletion
        }
    }
}

// MARK: - UITableViewDelegate
extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // Deselect immediately

        let session = fetchedResultsController.object(at: indexPath)
        presentEditNotesView(for: session)
    }

    // Helper to present the EditNotesView
    private func presentEditNotesView(for session: RecordingSession) {
        let managedObjectContext = PersistenceController.shared.container.viewContext

        // Pass the session object directly to the SwiftUI view
        let editNotesView = EditNotesView(session: session)
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: editNotesView)
        hostingController.modalPresentationStyle = .formSheet // or .pageSheet
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
                // Instead of reconfiguring the cell manually (which can be complex for custom cells)
                // or reloading just one row, asking the table view to reload that row works well
                // with NSFetchedResultsController's batch updates.
                sessionsTableView.reloadRows(at: [indexPath], with: .none) // Use .none for less disruptive update
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
