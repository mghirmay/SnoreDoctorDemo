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

               if let initialRecordingURL = try audioRecorder.startAndGetRecordingURL() {
                   self.currentSessionAudioFileName = initialRecordingURL.lastPathComponent
                   self.currentSessionStartTime = Date() // Record the start time
                   resultsObserver.currentRecordingFileName = self.currentSessionAudioFileName
                   print("Recording session started for file: \(self.currentSessionAudioFileName ?? "N/A")")
               } else {
                   throw AudioAnalysisError.requestCreationFailed(NSError(domain: "ViewController", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain initial recording URL."]))
               }

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
           resultsObserver.currentRecordingFileName = nil

           // Get the final URL from the recorder
           _ = audioRecorder.stopAndGetRecordingURL()

           // NEW: Save the RecordingSession Core Data entity
           if let fileName = self.currentSessionAudioFileName,
              let startTime = self.currentSessionStartTime {
               let endTime = Date()
               let context = PersistenceController.shared.container.viewContext
               let newSession = RecordingSession(context: context)
               newSession.id = UUID()
               newSession.startTime = startTime
               newSession.endTime = endTime
               newSession.audioFileName = fileName
               PersistenceController.shared.save()
               print("Saved Recording Session: \(fileName) from \(startTime) to \(endTime)")
           } else {
               print("Warning: Could not save RecordingSession. File name or start time missing.")
           }

           self.currentSessionAudioFileName = nil
           self.currentSessionStartTime = nil // Clear current session data

           updateResultsTextView(with: "Analysis stopped.\n")
           analysisButton?.setTitle("Start Analysis", for: .normal)
       }

       @IBAction func toggleAnalysis(_ sender: UIButton) {
           if audioStreamAnalyzer == nil {
               startAudioAnalysis()
               sender.setTitle("Stop Analysis", for: .normal) // Moved here for immediate update
           } else {
               stopAudioAnalysis()
               sender.setTitle("Start Analysis", for: .normal) // Moved here for immediate update
           }
       }

    // NEW: Action to show the chart view (already corrected in previous response)
    @IBAction func showSoundChart(_ sender: UIButton) {
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let chartView = SnoreDoctorChartView()
            .environment(\.managedObjectContext, managedObjectContext)

        let hostingController = UIHostingController(rootView: chartView)
        self.present(hostingController, animated: true, completion: nil)
    }
    
    
    
    // MARK: - New Action to show playback view
       @IBAction func showPlaybackView(_ sender: UIButton) {
           // Link this to a new button in your Storyboard
           guard let lastRecordedFileName = currentSessionAudioFileName else {
               showAlert(title: "No Recording", message: "Please record an audio session first.")
               return
           }

           let audioPlaybackVM = AudioPlaybackViewModel()
           let managedObjectContext = PersistenceController.shared.container.viewContext

           let playbackView = AudioPlaybackView(viewModel: audioPlaybackVM, audioFileName: lastRecordedFileName)
               .environment(\.managedObjectContext, managedObjectContext)

           let hostingController = UIHostingController(rootView: playbackView)
           self.present(hostingController, animated: true, completion: nil)
       }

    
    // NEW: Action to show the Settings view
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

class SnoreDoctorObserver: NSObject, SNResultsObserving {
    weak var delegate: SnoreDoctorObserverDelegate?
    private let soundDataManager = SoundDataManager()

    // NEW: Property to hold the current audio file name
    var currentRecordingFileName: String?

    init(delegate: SnoreDoctorObserverDelegate?) {
        self.delegate = delegate
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
           print("SnoreDoctorObserver - Received a result")

           guard let classificationResult = result as? SNClassificationResult else { return }

           var detectedSnoreEvent: (identifier: String, confidence: Double)? = nil

           let eventDuration: Double
           if let classifyRequest = request as? SNClassifySoundRequest {
               eventDuration = classifyRequest.windowDuration.seconds
           } else {
               eventDuration = 1.0
               print("Warning: Request is not an SNClassifySoundRequest or windowDuration not available. Using default duration.")
           }

           // NEW: Get the confidence threshold from UserDefaults
           let requiredConfidence = UserDefaults.standard.snoreConfidenceThreshold
           // Fallback for safety, though @AppStorage usually sets a default
           // if UserDefaults.standard.object(forKey: "snoreConfidenceThreshold") == nil {
           //     requiredConfidence = AppSettings.defaultSnoreConfidenceThreshold
           // }


           if let topClassification = classificationResult.classifications.first {
               // Your custom snore detection logic goes here.
               // ... (rest of your snore detection logic based on identifier and confidence) ...
               // Apply the configurable threshold
               if topClassification.confidence > requiredConfidence {
                   detectedSnoreEvent = (topClassification.identifier, topClassification.confidence)
               }
           } else {
                // Handle cases where no classification is returned (e.g., pure silence, or model failed)
                // You might want to save a "Silent" event with 100% confidence here
                // if no classification means silence.
               detectedSnoreEvent = ("Silence", 1.0) // Assume silence if no classification
           }

           if let (identifier, confidenceValue) = detectedSnoreEvent {
               let confidence = String(format: "%.2f", confidenceValue * 100)
               let outputString = "Detected: \(identifier) (Confidence: \(confidence)%)\n"

               DispatchQueue.main.async {
                   self.delegate?.didDetectSoundEvent(logString: outputString)

                   if let fileName = self.currentRecordingFileName {
                       self.soundDataManager.saveSnoreDoctorResult(
                           logString: outputString.trimmingCharacters(in: .whitespacesAndNewlines),
                           audioFileName: fileName,
                           duration: eventDuration
                       )
                   } else {
                       print("Warning: currentRecordingFileName is nil. SoundEvent not associated with a file.")
                       self.soundDataManager.saveSnoreDoctorResult(
                           logString: outputString.trimmingCharacters(in: .whitespacesAndNewlines),
                           audioFileName: "unknown_recording",
                           duration: eventDuration
                       )
                   }
               }
           }
       }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed with error: \(error)")
        DispatchQueue.main.async {
            self.delegate?.analysisDidFail(error: error)
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed.")
        DispatchQueue.main.async {
            self.delegate?.analysisDidComplete()
        }
    }
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
