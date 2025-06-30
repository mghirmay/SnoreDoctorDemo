//
//  ViewController.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 08.05.25.
//
import UIKit
import SoundAnalysis
import AVFoundation
import SwiftUI // Import SwiftUI to use UIHostingController
import CoreData // Import CoreData if not already present, for AppDelegate context

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


class ViewController: UIViewController {
    private let multicastViewModel = MulticastServiceViewModel()

    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var analysisButton: UIButton?
    @IBOutlet weak var showChartButton: UIButton? // Outlet for the button to show the chart
    @IBOutlet weak var showPlaybackButton: UIButton? // Outlet for the playback button
    @IBOutlet weak var settingsButton: UIButton? // NEW: Outlet for the settings button

    // Add a property to store the current recording file name
    private var currentSessionAudioFileName: String? // To track the current recording file
    private var currentSessionStartTime: Date? // NEW: Track session start time
    // CHANGED: Now holds the current RecordingSession object
    private var currentRecordingSession: RecordingSession?

    
    // Add a property to hold the AVAudioEngine
    private var audioEngine: AVAudioEngine?
    // private var audioSession: AVAudioSession! // We'll manage session via AudioManager
    private var audioStreamAnalyzer: SNAudioStreamAnalyzer?

    private let analysisQueue = DispatchQueue(label:"de.sinitpower.SnoreDoctor.analysisQueue") // More specific label

    private var soundClassifierRequest: SNClassifySoundRequest?

    // Instance of SoundDataManager
    private let soundDataManager = SoundDataManager()
    // Instance of AudioRecorder - now used for recording to file
    private let audioRecorder = AudioRecorder()
    // Instance of AudioManager - now used for consistent audio session setup
    private let audioManager = AudioManager.shared // Use the singleton AudioManager

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        updateResultsTextView(with: "Ready to analyze sounds... \n", append: false)
        // Let the user tap the button.
        // Ensure analysisButton is disabled initially until permission is granted
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
          analysisButton?.setTitle("Start Analysis", for: .normal)

    }

    deinit {
        // Ensure all audio resources are stopped and released when ViewController is deinitialized
        stopAudioAnalysis()
        print("ViewController deinitialized")
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

    // Moved audio session setup to AudioManager, and now called directly before starting analysis/recording
    // private func setupAudioSession() { ... } // REMOVED

    // MARK: - Sound Analysis Setup

    private func setupSoundClassifier() {
        do {
            // For a real Snore Doctor, replace this with your custom Core ML model
            // Example if you had a 'SnoreDetector.mlmodel':
            // let config = MLModelConfiguration()
            // let model = try SnoreDetector(configuration: config).model
            // soundClassifierRequest = try SNClassifySoundRequest(model: model)
            soundClassifierRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)

            // Optional: Set a minimum confidence for results to be reported
            // soundClassifierRequest?.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 1000)
            // soundClassifierRequest?.overlapFactor = 0.5 // Adjust for more frequent analysis
            // soundClassifierRequest?.sensitivity = 1.0 // 0.0 (less sensitive) to 1.0 (more sensitive)

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


               if let initialRecordingURL = try audioRecorder.startAndGetRecordingURL() {
                   newSession.audioFileName = initialRecordingURL.lastPathComponent
                   // Generate a simple title for the session
                   let dateFormatter = DateFormatter()
                   dateFormatter.dateFormat = "MMM d, h:mm a"
                   
                   // Use optional binding to safely unwrap startTime
                   if let startTime = newSession.startTime {
                       newSession.title = "Session \(dateFormatter.string(from: startTime))"
                   } else {
                       // This case should ideally not happen immediately after setting startTime
                       newSession.title = "Session (Unknown Time)"
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
            analysisButton?.setTitle("Start Analysis", for: .normal)
        }

        @IBAction func toggleAnalysis(_ sender: UIButton) {
            if audioStreamAnalyzer == nil {
                startAudioAnalysis()
                sender.setTitle("Stop Analysis", for: .normal)
            } else {
                stopAudioAnalysis()
                sender.setTitle("Start Analysis", for: .normal)
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
           self.present(hostingController, animated: true, completion: nil)
       }

    
        @IBAction func showSettings(_ sender: UIButton) {
            let managedObjectContext = PersistenceController.shared.container.viewContext
            let settingsView = SettingsView()
                .environment(\.managedObjectContext, managedObjectContext)

            let hostingController = UIHostingController(rootView: settingsView)
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
}


// MARK: - SnoreDoctorObserver

// Make SnoreDoctorObserver conform to an explicit protocol for better structure
protocol SnoreDoctorObserverDelegate: AnyObject { // Use AnyObject for weak reference requirement
    func didDetectSoundEvent(logString: String)
    func analysisDidFail(error: Error)
    func analysisDidComplete()
    // Potentially add more methods for progress updates, etc.
}


// MARK: - SnoreDoctorObserverDelegate Extension for ViewController
extension ViewController: SnoreDoctorObserverDelegate {
    func didDetectSoundEvent(logString: String) {
        updateResultsTextView(with: logString)
        multicastViewModelSendData(data: logString)
    }

    func analysisDidFail(error: Error) {
        updateResultsTextView(with: "Error: \(error.localizedDescription)\n")
        stopAudioAnalysis() // Attempt to stop analysis on error
    }

    func analysisDidComplete() {
        updateResultsTextView(with: "Analysis completed.\n")
        stopAudioAnalysis() // Analysis completed, stop fully
    }
}
