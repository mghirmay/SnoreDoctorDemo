import Foundation
import SoundAnalysis
import AVFoundation
import Combine

/// A singleton class that encapsulates all CoreML sound recognition logic,
/// now acting as a full audio analysis service, managing AVAudioSession and interruptions.
final class SoundRecognitionManager: NSObject {
    static let shared = SoundRecognitionManager()

    // MARK: - Private Properties
    private var subscriptions = Set<AnyCancellable>()
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "sound_recognition_queue")
    private var retainedObservers: [SNResultsObserving]? // To hold the observer bridge
    
    // MARK: - Public Combine Interface

    /// A subject that publishes classification results.
    let classificationSubject = PassthroughSubject<SNClassificationResult, Error>()

    /// Public read-only property to check if the audio engine is currently running.
    var isRunning: Bool {
        // It is only "running" if the central engine is active
        // AND our specific analysis task is active.
        return  (self.analyzer != nil)
    }
    
    // MARK: - Private Initializer

    private override init() {
        super.init()
    }

    // MARK: - Public Control
    func startRecognition_with_custom_model(
        observer: SoundEventDetectionObserver,
        windowDuration: Double = 1.5,
        overlapFactor: Double = 0.9
    ) async throws {

        
        // 1. Ensure a clean state
        stopRecognition()
      
        // The Manager asks the Observer for the URL it needs
        guard let recordingURL = observer.activeRecordingSessionURL else {
            print("Manager: No active recording URL found in observer.")
            throw AudioAnalysisError.noActiveSession
        }
        
        // 2. Define the setup logic in a clean, safe block
        AudioEngineManager.shared.engineReadySubject
            .prefix(1)
            .sink { [weak self] engine in
                guard let self = self else { return }
                
                do {
                    // Analyzer setup
                    let inputNode = engine.inputNode
                    let nativeFormat = inputNode.inputFormat(forBus: 0)
                    let newAnalyzer = SNAudioStreamAnalyzer(format: nativeFormat)
                    
                    // --- ML Model ---
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuOnly

                    guard let modelURL = Bundle.main.url(
                        forResource: "MySoundClassifier1",
                        withExtension: "mlmodelc"
                    ) else {
                        throw NSError(
                            domain: "SoundRecognition",
                            code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "Model file not found"]
                        )
                    }

                    let model = try MLModel(contentsOf: modelURL, configuration: config)
                    let request = try SNClassifySoundRequest(mlModel: model)

                    request.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
                    request.overlapFactor = overlapFactor
                    
                    try newAnalyzer.add(request, withObserver: observer)
                    
                    // Assign safely now that creation succeeded
                    self.analyzer = newAnalyzer
                    self.retainedObservers = [observer]
                    
                    // Subscribe to audio buffers safely
                    AudioEngineManager.shared.audioBufferSubject
                        .sink { [weak self] buffer, time in
                            guard let self = self else { return }
                            self.analysisQueue.async {
                                self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                            }
                        }
                        .store(in: &self.subscriptions)
                    
                    try AudioRecorderManager.shared.startRecording(to: recordingURL)
                    print("Recording started at: \(recordingURL)")
                        
                } catch {
                    self.classificationSubject.send(completion: .failure(error))
                    self.stopRecognition()
                }
            }
            .store(in: &subscriptions)
        
        // 3. Trigger setup asynchronously
        // This is safe because we already have our subscription in place
        AudioEngineManager.shared.setup()
        startListeningForAudioSessionInterruptions()
    }
    

    
    func startRecognition_with_apple_version1_model(
        observer: SoundEventDetectionObserver,
        windowDuration: Double = 1.5,
        overlapFactor: Double = 0.9
    ) async throws {
        
        // 1. Ensure a clean state
        stopRecognition()
        
        // The Manager asks the Observer for the URL it needs
        guard let recordingURL = observer.activeRecordingSessionURL else {
            print("Manager: No active recording URL found in observer.")
            throw AudioAnalysisError.noActiveSession
        }
        
        // 2. Define the setup logic in a clean, safe block
        AudioEngineManager.shared.engineReadySubject
            .prefix(1)
            .sink { [weak self] engine in
                guard let self = self else { return }
                
                do {
                    // Analyzer setup
                    let inputNode = engine.inputNode
                    let nativeFormat = inputNode.inputFormat(forBus: 0)
                    let newAnalyzer = SNAudioStreamAnalyzer(format: nativeFormat)
                    
                    let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                    request.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
                    request.overlapFactor = overlapFactor
                    
                    try newAnalyzer.add(request, withObserver: observer)
                    
                    // Assign safely now that creation succeeded
                    self.analyzer = newAnalyzer
                    self.retainedObservers = [observer]
                    
                    // Subscribe to audio buffers safely
                    AudioEngineManager.shared.audioBufferSubject
                        .sink { [weak self] buffer, time in
                            guard let self = self else { return }
                            self.analysisQueue.async {
                                self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                            }
                        }
                        .store(in: &self.subscriptions)
                        
                    
                    try AudioRecorderManager.shared.startRecording(to: recordingURL)
                    print("Recording started at: \(recordingURL)")
                    
                } catch {
                    self.classificationSubject.send(completion: .failure(error))
                    self.stopRecognition()
                }
            }
            .store(in: &subscriptions)
        
        // 3. Trigger setup asynchronously
        // This is safe because we already have our subscription in place
        AudioEngineManager.shared.setup()
        startListeningForAudioSessionInterruptions()
    }
    
    
    /// Stops the current sound recognition session and audio input.
    func stopRecognition() {
        // 1. Stop Listening for interruptions
        stopListeningForAudioSessionInterruptions()

        // 2. Stop Audio Engine and Analysis
        AudioRecorderManager.shared.stopRecording()
        AudioPlaybackManager.shared.stopEverything()
        AudioEngineManager.shared.teardown();
   
        
        analyzer?.removeAllRequests()

        // 3. Clear References and Deactivate Session
        analyzer = nil
        retainedObservers = nil
        
        //stopAudioSession()
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

