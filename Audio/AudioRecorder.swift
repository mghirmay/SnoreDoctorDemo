//
//  AudioRecorder.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
// AudioRecorder.swift
import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL? // This will hold the URL of the current recording
    private var isRecordingPausedByInterruption: Bool = false // New flag

    override init() {
        super.init()
        // Observe audio session interruption notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruptionBegan),
                                               name: .audioSessionInterruptionBegan,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruptionEndedShouldResume),
                                               name: .audioSessionInterruptionEndedShouldResume,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruptionEndedCouldNotResume),
                                               name: .audioSessionInterruptionEndedCouldNotResume,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesReset),
                                               name: .mediaServicesReset,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // ... (Your existing startAndGetRecordingURL and stopAndGetRecordingURL methods) ...

    func startAndGetRecordingURL() throws -> URL? {
        // Ensure the audio session is active BEFORE trying to start the recorder
        do {
            // This setup call will ensure the session is active with appropriate background settings
            try AudioManager.shared.setupAudioSessionForRecording(
                category: .playAndRecord,
                mode: .measurement,
                options: [.mixWithOthers, .allowBluetooth] // Essential options for background audio and flexibility
            )
        } catch {
            throw error // Propagate the error from AudioManager setup
        }

        let userDefaults = UserDefaults.standard
        let preferredFormat = userDefaults.audioFormatPreference
        let preferredSampleRate = userDefaults.sampleRatePreference
        let preferredAudioQuality = userDefaults.audioQualityPreference

        var settings: [String: Any] = [:]
        settings[AVSampleRateKey] = preferredSampleRate
        settings[AVNumberOfChannelsKey] = 1
        settings[AVEncoderAudioQualityKey] = preferredAudioQuality.avAudioQuality.rawValue

        switch preferredFormat {
        case .aac:
            settings[AVFormatIDKey] = preferredFormat.formatID
            settings[AVEncoderBitRateKey] = 64000
        case .m4a:
            settings[AVFormatIDKey] = preferredFormat.formatID
        case .wav:
            settings[AVFormatIDKey] = preferredFormat.formatID
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsFloatKey] = false
        }

        let filename = UUID().uuidString + "." + preferredFormat.fileExtension
        audioURL = getDocumentsDirectory().appendingPathComponent(filename)

        guard let url = audioURL else {
            print("Error: Could not create audio URL.")
            throw AudioAnalysisError.invalidState("Could not create audio file URL.")
        }

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            print("Audio file recording started at: \(url.lastPathComponent) with settings: \(settings)")
            isRecordingPausedByInterruption = false // Reset state
            return url
        } catch {
            audioRecorder = nil
            print("Failed to start audio file recording: \(error.localizedDescription)")
            throw AudioAnalysisError.recordingSetupFailed(error)
        }
    }

    func stopAndGetRecordingURL() -> URL? {
        let urlToReturn = audioURL
        audioRecorder?.stop()
        audioRecorder = nil
        print("Audio file recording stopped.")
        isRecordingPausedByInterruption = false // Reset state
        AudioManager.shared.deactivateAudioSession() // Deactivate when done with recording
        return urlToReturn
    }

    func pauseRecording() {
        if audioRecorder?.isRecording == true {
            audioRecorder?.pause()
            isRecordingPausedByInterruption = true
            print("Recording paused.")
        }
    }

    func resumeRecording() {
        if isRecordingPausedByInterruption && audioRecorder?.isRecording == false {
            audioRecorder?.record()
            isRecordingPausedByInterruption = false
            print("Recording resumed.")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - AVAudioRecorderDelegate Methods
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Audio file recording failed or was interrupted by system.")
            // Handle cases where system stops recording (e.g., during an interruption)
            if isRecordingPausedByInterruption {
                print("Recording was paused by interruption and finished.")
            }
            // You might want to save current state or log this.
        } else {
            print("Audio file recording finished successfully.")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio file recording encode error: \(error?.localizedDescription ?? "Unknown error")")
        // Handle this error, potentially stopping the recording session.
    }

    // MARK: - Notification Handlers for Audio Session Events

    @objc private func handleInterruptionBegan() {
        pauseRecording()
    }

    @objc private func handleInterruptionEndedShouldResume() {
        // We only resume if it was paused due to an interruption
        if isRecordingPausedByInterruption {
            resumeRecording()
        }
    }

    @objc private func handleInterruptionEndedCouldNotResume() {
        // If we couldn't resume, consider what to do:
        // - Stop recording entirely and inform the user.
        // - Try to restart recording from scratch (less ideal for continuous).
        print("Interruption ended, but could not resume recording.")
        stopAndGetRecordingURL() // Stop the current session
        // Potentially notify the UI that recording stopped unexpectedly
    }

    @objc private func handleMediaServicesReset() {
        // This is critical. The audio engine is gone.
        print("AudioRecorder: Media services reset. Stopping recording and resetting.")
        audioRecorder?.stop()
        audioRecorder = nil
        audioURL = nil
        isRecordingPausedByInterruption = false
        // You should prompt the user to restart the recording session, or
        // your main app logic should re-initialize AudioRecorder and start a new session.
    }
}
