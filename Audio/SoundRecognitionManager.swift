import Foundation
import SoundAnalysis
import AVFoundation
import Combine

/// A singleton class that encapsulates all CoreML sound recognition logic,
/// now acting as a full audio analysis service, managing AVAudioSession and interruptions.
class SoundRecognitionManager: NSObject {
    static let shared = SoundRecognitionManager()

    // MARK: - Private Properties

    internal var audioEngine: AVAudioEngine? // Changed to internal for UI state checking
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "sound_recognition_queue")
    private var retainedObservers: [SNResultsObserving]? // To hold the observer bridge
    
    // MARK: - Public Combine Interface

    /// A subject that publishes classification results.
    let classificationSubject = PassthroughSubject<SNClassificationResult, Error>()

    /// Public read-only property to check if the audio engine is currently running.
    var isRunning: Bool {
        return audioEngine?.isRunning ?? false
    }

    // MARK: - Private Initializer

    private override init() {
        super.init()
    }

    // MARK: - Public Control
    func startRecognition(observer: SNResultsObserving,
                              windowDuration: Double = 1.5,
                              overlapFactor: Double = 0.9) async throws {

            stopRecognition() // Ensure a clean start

            do {
                // 1. Session, Permission, and Interruption Setup
                try ensureMicrophoneAccess()
                try startAudioSession()
                startListeningForAudioSessionInterruptions()

                // 2. Engine and Analyzer Setup
                let engine = AVAudioEngine()
                audioEngine = engine

                let inputNode = engine.inputNode
                let inputFormat = inputNode.outputFormat(forBus: 0)

                let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
                self.analyzer = analyzer

                // --- NEW MODEL SETUP ---
                let config = MLModelConfiguration()
                // .all is usually better for M2 to leverage the Neural Engine,
                // but keep .cpuOnly if you need strict stability testing.
                config.computeUnits = .cpuOnly

                // IMPORTANT: Ensure "ESC50_Model" matches the name in your Xcode Project navigator
                // IMPORTANT: Ensure "MySoundClassifier1" matches the name in your Xcode Project navigator
                guard let modelURL = Bundle.main.url(forResource: "MySoundClassifier1", withExtension: "mlmodelc") else {
                    throw NSError(domain: "SoundRecognition", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])
                }
                
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                // -----------------------

                // 3. Request and Observer Bridge Setup
                // SoundAnalysis (SNClassifySoundRequest) handles the conversion of audio
                // into the spectrogram shape [1, 512, 108, 1] automatically!
                let request = try SNClassifySoundRequest(mlModel: model)
                
                //*** deactivated for keras model ESC50 dataset
                request.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
                request.overlapFactor = overlapFactor

                // 5. Attach YOUR Custom Observer
                try analyzer.add(request, withObserver: observer)
                
                // CRITICAL: We retain the observer here so it doesn't get deallocated
                retainedObservers = [observer]

                // 4. Install Tap
                let bufferSize = AVAudioFrameCount(4096)
                inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, time in
                    self.analysisQueue.async {
                        self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                    }
                }

                // 5. Start Engine
                try engine.start()
            } catch {
                classificationSubject.send(completion: .failure(error))
                stopRecognition() // Clean up on error
            }
        }
    
    
    /// Starts the audio engine and attaches the provided observer.
        /// - Parameters:
        ///   - observer: Your custom `SoundEventDetectionObserver`.
        ///   - windowDuration: Duration of audio chunks (default 1.5s).
        ///   - overlapFactor: How much windows overlap (default 0.9).
    func startRecognition_orginal(observer: SNResultsObserving,
                              windowDuration: Double = 1.5,
                              overlapFactor: Double = 0.9) async throws {

        stopRecognition() // Ensure a clean start

        do {
            // 1. Session, Permission, and Interruption Setup
            try ensureMicrophoneAccess()
            try startAudioSession()
            startListeningForAudioSessionInterruptions()

            // 2. Engine and Analyzer Setup
            let engine = AVAudioEngine()
            audioEngine = engine

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
            self.analyzer = analyzer

            
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly   // CPU-only execution
            let modelURL = Bundle.main.url(forResource: "MySoundClassifier", withExtension: "mlmodelc")!
            let model = try MLModel(contentsOf: modelURL, configuration: config)

            
            // 3. Request and Observer Bridge Setup
            let request = try SNClassifySoundRequest(mlModel: model)
            //let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
           
           
            request.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
            request.overlapFactor = overlapFactor


            // 5. Attach YOUR Custom Observer
            try analyzer.add(request, withObserver: observer)
            
            // CRITICAL: We retain the observer here so it doesn't get deallocated
            retainedObservers = [observer]

            // 4. Install Tap
            let bufferSize = AVAudioFrameCount(4096)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, time in
                self.analysisQueue.async {
                    self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                }
            }

            // 5. Start Engine
            try engine.start()
        } catch {
            classificationSubject.send(completion: .failure(error))
            stopRecognition() // Clean up on error
        }
    }

    /// Stops the current sound recognition session and audio input.
    func stopRecognition() {
        // 1. Stop Listening for interruptions
        stopListeningForAudioSessionInterruptions()

        // 2. Stop Audio Engine and Analysis
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        analyzer?.removeAllRequests()

        // 3. Clear References and Deactivate Session
        audioEngine = nil
        analyzer = nil
        retainedObservers = nil
        
        stopAudioSession()
    }

    // MARK: - Audio Session Management

    /// Requests permission to access microphone input, throwing an error if the user denies access.
    private func ensureMicrophoneAccess() throws {
        var hasMicrophoneAccess = false
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            // Use a semaphore to wait for the result in a synchronous context (common for service setup)
            let sem = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { success in
                hasMicrophoneAccess = success
                sem.signal()
            })
            _ = sem.wait(timeout: .now() + 5.0) // Wait up to 5 seconds
        case .denied, .restricted:
            break
        case .authorized:
            hasMicrophoneAccess = true
        @unknown default:
            fatalError("Unknown authorization status for microphone access")
        }

        if !hasMicrophoneAccess {
            // Use a specific error defined for this context if possible
            // Assuming SystemAudioClassificationError from the prompt's context is available
            throw AudioAnalysisError.permissionDenied
        }
    }

    /// Configures and activates an AVAudioSession.
    private func startAudioSession() throws {
        stopAudioSession() // Always ensure clean state before starting
        do {
            let audioSession = AVAudioSession.sharedInstance()
            //try audioSession.setCategory(.record, mode: .default)
            try audioSession.setCategory(.record, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            stopAudioSession()
            throw error
        }
    }

    /// Deactivates the app's AVAudioSession.
    private func stopAudioSession() {
        // Deactivating the session should be tolerant of errors
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Interruption Handling

    private func startListeningForAudioSessionInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil)
    }

    private func stopListeningForAudioSessionInterruptions() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil)
    }

    @objc
    private func handleAudioSessionInterruption(_ notification: Notification) {
        // Send a failure signal to the Combine subject
        let error = AudioAnalysisError.audioStreamInterrupted
        classificationSubject.send(completion: .failure(error))
        
        // Terminate the session completely, the calling UI must restart it.
        stopRecognition()
    }
}

