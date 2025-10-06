//
//  AudioManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
// AudioManager.swift
import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    static let shared = AudioManager() // Singleton instance

    private init() {
        // Register for audio session interruption notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)

        // Register for route change notifications (e.g., headphones plugged/unplugged)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)

        // Register for media services reset notification (rare, but important)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesReset),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: nil)
    }

    // Deinitializer to remove observers when AudioManager is deallocated (though unlikely for a singleton)
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupAudioSessionForRecording(category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(category, mode: mode, options: options)
            // Crucial for background audio: the system needs to know your app intends to be active
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio Session configured for recording (Category: \(category.rawValue), Mode: \(mode.rawValue), Options: \(options)).")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            throw AudioAnalysisError.audioSessionSetupFailed(error)
        }
    }

    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio Session deactivated.")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
            // Consider throwing or handling this error more robustly if deactivation is critical
        }
    }

    // MARK: - Audio Session Interruption Handling

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio session interrupted (e.g., phone call, Siri, alarm)
            print("Audio session interruption began. Pausing recording.")
            // *** IMPORTANT: Notify your AudioRecorder or main logic to PAUSE recording ***
            // You might use a NotificationCenter post, a delegate, or a closure here.
            NotificationCenter.default.post(name: .audioSessionInterruptionBegan, object: nil)

        case .ended:
            // Audio session interruption ended
            print("Audio session interruption ended.")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Try to reactivate the audio session and then resume recording
                    print("Audio session interruption ended. Attempting to resume.")
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        // *** IMPORTANT: Notify your AudioRecorder or main logic to RESUME recording ***
                        NotificationCenter.default.post(name: .audioSessionInterruptionEndedShouldResume, object: nil)
                    } catch {
                        print("Failed to reactivate audio session after interruption: \(error.localizedDescription)")
                        NotificationCenter.default.post(name: .audioSessionInterruptionEndedCouldNotResume, object: nil)
                    }
                } else {
                    print("Audio session interruption ended. Should NOT resume. (e.g., call answered by another app)")
                    NotificationCenter.default.post(name: .audioSessionInterruptionEndedCouldNotResume, object: nil)
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            print("Audio route changed: New device available (e.g., headphones plugged in).")
        case .oldDeviceUnavailable:
            print("Audio route changed: Old device unavailable (e.g., headphones unplugged).")
            // If recording was happening via headphones and they're unplugged, you might want to restart or inform the user.
            // Consider if this affects your recording quality or the intended microphone.
        case .categoryChange:
            print("Audio route changed: Category changed.")
        case .override:
            print("Audio route changed: Override.")
        case .wakeFromSleep:
            print("Audio route changed: Wake from sleep.")
        case .noSuitableRouteForCategory:
            print("Audio route changed: No suitable route for category.")
        case .routeConfigurationChange:
            print("Audio route changed: Route configuration change.")
        case .unknown:
            print("Audio route changed: Unknown reason.")
        @unknown default:
            break
        }
        // You might need to reconfigure your audio session or recorder if the route change impacts your recording.
    }

    @objc private func handleMediaServicesReset(notification: Notification) {
        // This is a serious event, usually indicating a system-level issue with audio.
        // Your app's audio engine is no longer valid. You MUST re-initialize everything.
        print("Media services were reset. Reinitializing audio session and recorder.")
        NotificationCenter.default.post(name: .mediaServicesReset, object: nil)
        // You should re-attempt to setup your entire audio stack (session, recorder)
    }
}

// MARK: - Custom Notification Names for easier communication
extension Notification.Name {
    static let audioSessionInterruptionBegan = Notification.Name("audioSessionInterruptionBegan")
    static let audioSessionInterruptionEndedShouldResume = Notification.Name("audioSessionInterruptionEndedShouldResume")
    static let audioSessionInterruptionEndedCouldNotResume = Notification.Name("audioSessionInterruptionEndedCouldNotResume")
    static let mediaServicesReset = Notification.Name("mediaServicesReset")
}
