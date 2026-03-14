import Foundation
@preconcurrency import SoundAnalysis
import AVFoundation
import Combine
import CoreML

// MARK: - Supporting Types

enum ModelSource {
    case custom(modelName: String)
    case appleVersion1
}

enum RecognitionState {
    case idle
    case starting
    case running
}

// MARK: - SoundRecognitionManager

final class SoundRecognitionManager: NSObject {
    static let shared = SoundRecognitionManager()

    // MARK: - Private Properties

    private var subscriptions = Set<AnyCancellable>()
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "sound_recognition_queue")
    private var retainedObserver: SoundEventDetectionObserver?

    // MARK: - Public Interface

    let classificationSubject = PassthroughSubject<SNClassificationResult, Error>()

    /// Three-state lifecycle. The call site can reliably check `.running`
    /// only after `startRecognition` has returned without throwing.
    private(set) var state: RecognitionState = .idle

    var isRunning: Bool { state == .running }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Public Control

    /// Starts recognition and **suspends until the engine is fully running**.
    /// Only returns once audio buffers are flowing and the analyzer is attached,
    /// so `isRunning` is guaranteed to be `true` on the line after `try await`.
    func startRecognition(
        observer: SoundEventDetectionObserver,
        modelSource: ModelSource,
        windowDuration: Double = 1.5,
        overlapFactor: Double = 0.9
    ) async throws {

        // Tear down any previous session first.
        stopRecognition()
        state = .starting

        // Start a new Core Data session on the observer before doing anything else.
        // This guarantees activeRecordingSessionURL is populated when we need it.
        observer.startNewSession(context: PersistenceController.shared.container.viewContext)

        guard let recordingURL = observer.activeRecordingSessionURL else {
            state = .idle
            throw AudioAnalysisError.sessionURLUnavailable
        }

        // Use a CheckedContinuation so the async call truly waits
        // until the engine fires engineReadySubject before returning.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in

            AudioEngineManager.shared.engineReadySubject
                .prefix(1)
                .sink { [weak self] engine in
                    guard let self else {
                        continuation.resume(throwing: AudioAnalysisError.noActiveSession)
                        return
                    }
                    do {
                        let request = try self.buildRequest(
                            modelSource: modelSource,
                            windowDuration: windowDuration,
                            overlapFactor: overlapFactor
                        )
                        try self.setupAnalyzer(
                            engine: engine,
                            request: request,
                            observer: observer,
                            recordingURL: recordingURL
                        )
                        // Resume the awaiting caller only after full setup succeeds.
                        continuation.resume()
                    } catch {
                        self.stopRecognition()
                        continuation.resume(throwing: error)
                    }
                }
                .store(in: &subscriptions)

            AudioEngineManager.shared.setup()
            startListeningForAudioSessionInterruptions()
        }
    }

    /// Stops recognition, finalises the Core Data session, and resets all state.
    func stopRecognition() {
        // Cancel Combine pipelines first to prevent any late buffer callbacks.
        subscriptions.removeAll()

        stopListeningForAudioSessionInterruptions()

        // Only finalise if a session was actually started.
        if retainedObserver?.currentRecordingSession != nil {
            retainedObserver?.finalizeSession()
        }

        AudioPlaybackManager.shared.stopEverything()
        AudioRecorderManager.shared.stopRecording()
        AudioEngineManager.shared.teardown()

        analyzer?.removeAllRequests()
        analyzer = nil
        retainedObserver = nil

        state = .idle
    }

    // MARK: - Private Helpers

    private func buildRequest(
        modelSource: ModelSource,
        windowDuration: Double,
        overlapFactor: Double
    ) throws -> SNClassifySoundRequest {

        let request: SNClassifySoundRequest

        switch modelSource {
        case .custom(let modelName):
            guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
                throw AudioAnalysisError.modelNotFound(name: modelName)
            }
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            request = try SNClassifySoundRequest(mlModel: model)

        case .appleVersion1:
            request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        }

        request.windowDuration = CMTime(seconds: windowDuration, preferredTimescale: 1000)
        request.overlapFactor = overlapFactor
        return request
    }

    private func setupAnalyzer(
        engine: AVAudioEngine,
        request: SNClassifySoundRequest,
        observer: SoundEventDetectionObserver,
        recordingURL: URL
    ) throws {

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        let newAnalyzer = SNAudioStreamAnalyzer(format: nativeFormat)

        try newAnalyzer.add(request, withObserver: observer)

        analyzer = newAnalyzer
        retainedObserver = observer

        AudioEngineManager.shared.audioBufferSubject
            .sink { [weak self] buffer, time in
                guard let self else { return }
                self.analysisQueue.async {
                    self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                }
            }
            .store(in: &subscriptions)

        try AudioRecorderManager.shared.startRecording(to: recordingURL)

        state = .running
        print("SoundRecognitionManager: Recording started at \(recordingURL)")
    }

    // MARK: - Interruption Handling

    private func startListeningForAudioSessionInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil
        )
    }

    private func stopListeningForAudioSessionInterruptions() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil
        )
    }

    @objc
    private func handleAudioSessionInterruption(_ notification: Notification) {
        classificationSubject.send(completion: .failure(AudioAnalysisError.audioStreamInterrupted))
        stopRecognition()
    }
}
