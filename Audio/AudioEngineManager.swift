//
//  AudioManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
import Foundation
import AVFoundation
import Combine

final class AudioEngineManager: ObservableObject {
    static let shared = AudioEngineManager()

    // Engine is now optional so it can be fully destroyed and recreated
    private(set) var audioEngine: AVAudioEngine?
    private(set) var playerNode = AVAudioPlayerNode()

    let audioBufferSubject = PassthroughSubject<(AVAudioPCMBuffer, AVAudioTime), Never>()
    let engineReadySubject = PassthroughSubject<AVAudioEngine, Never>()
    
    private var cancellables = Set<AnyCancellable>()

    private init() {
        registerNotifications()
    }

    // MARK: - Lifecycle Management

    func setup() {
        // Prevent multiple simultaneous setups
        guard audioEngine == nil else { return }

        do {
            try configureAudioSession()
            
            // Create a fresh engine instance
            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            configureEngineGraph(engine: engine)
            installMicrophoneTap(engine: engine)
            
            try engine.start()
            engineReadySubject.send(engine)
            print("AudioEngine started successfully.")
            
        } catch {
            print("Setup failed: \(error.localizedDescription)")
            teardown()
        }
    }

    func teardown() {
        audioEngine?.stop()
        
        if let engine = audioEngine {
            inputNode(for: engine)?.removeTap(onBus: 0)
            engine.reset()
        }
        
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        print("AudioEngine fully torn down.")
    }

    // MARK: - Permission Handling

   
    
    // MARK: - Private Configuration
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)
    }

    private func configureEngineGraph(engine: AVAudioEngine) {
        engine.attach(playerNode)
        let format = engine.inputNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    private func installMicrophoneTap(engine: AVAudioEngine) {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, time in
            self?.audioBufferSubject.send((buffer, time))
        }
    }
    
    private func inputNode(for engine: AVAudioEngine) -> AVAudioInputNode? {
        return try? engine.inputNode
    }

    // MARK: - Notifications
    private func registerNotifications() {
        let center = NotificationCenter.default
        
        // 1. Handle hardware resets
        center.addObserver(self, selector: #selector(handleMediaReset),
                           name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        
        // 2. Handle phone calls, alarms, or other app audio
        center.addObserver(self, selector: #selector(handleInterruption),
                           name: AVAudioSession.interruptionNotification, object: nil)
        
        // 3. Handle routing changes (e.g., unplugging headphones)
        center.addObserver(self, selector: #selector(handleRouteChange),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleMediaReset() {
        print("⚠️ Media services reset. Recovering...")
        teardown()
        // Graceful delay for hardware availability
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setup()
        }
    }


    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("Interruption started: Stopping engine.")
            teardown()
        case .ended:
            print("Interruption ended: Resuming engine.")
            // Check if we should resume (e.g., option was provided)
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue) == .shouldResume {
                setup()
            } else {
                setup() // Standard behavior for recording apps
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // If headphones are unplugged, we might want to pause or alert the user
        if reason == .oldDeviceUnavailable {
            print("Audio route changed: Device unplugged.")
            // Optional: stopEngine() if you don't want audio through the speaker
        }
    }
}

extension Notification.Name {
    static let mediaServicesReset = Notification.Name("mediaServicesReset")
}
