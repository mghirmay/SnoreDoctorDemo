//
//  AudioRecorder.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL? // This will hold the URL of the current recording

    // Removed the fixed recordingSettings dictionary.
    // Settings will now be determined dynamically from UserDefaults.

    // New method: Starts recording and returns the URL
    func startAndGetRecordingURL() throws -> URL? {
        // 1. Get user preferences from UserDefaults
        let userDefaults = UserDefaults.standard
        let preferredFormat = userDefaults.audioFormatPreference
        let preferredSampleRate = userDefaults.sampleRatePreference
        let preferredAudioQuality = userDefaults.audioQualityPreference

        // 2. Define recording settings based on preferences
        var settings: [String: Any] = [:]

        // Common settings for all formats
        settings[AVSampleRateKey] = preferredSampleRate
        settings[AVNumberOfChannelsKey] = 1 // Mono for analysis is usually sufficient and saves space
        settings[AVEncoderAudioQualityKey] = preferredAudioQuality.avAudioQuality.rawValue // Use AVAudioQuality from enum

        // Format-specific settings
        switch preferredFormat {
        case .aac:
            settings[AVFormatIDKey] = preferredFormat.formatID // kAudioFormatMPEG4AAC
            settings[AVEncoderBitRateKey] = 64000 // Example bitrate for AAC. Adjust as needed (e.g., 96000 for better)
        case .m4a: // Apple Lossless (ALAC)
            settings[AVFormatIDKey] = preferredFormat.formatID // kAudioFormatAppleLossless
            // ALAC generally doesn't use AVEncoderBitRateKey, its compression is lossless.
            // You could add AVEncoderBitRateStrategyKey if you want to fine-tune ALAC encoding.
        case .wav: // Uncompressed PCM
            settings[AVFormatIDKey] = preferredFormat.formatID // kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16 // 16-bit is common for PCM
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsFloatKey] = false
            // No bitrate needed for uncompressed PCM
        }

        // 3. Create a unique file URL for the recording with the correct extension
        let filename = UUID().uuidString + "." + preferredFormat.fileExtension
        audioURL = getDocumentsDirectory().appendingPathComponent(filename)

        guard let url = audioURL else {
            print("Error: Could not create audio URL.")
            throw NSError(domain: "AudioRecorder", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create audio file URL."])
        }

        // 4. Initialize and start AVAudioRecorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            print("Audio file recording started at: \(url.lastPathComponent) with settings: \(settings)")
            return url // Return the URL now
        } catch {
            audioRecorder = nil
            print("Failed to start audio file recording: \(error.localizedDescription)")
            throw error
        }
    }

    // Modify existing stopRecording to return the URL for completion handling
    func stopAndGetRecordingURL() -> URL? {
        let urlToReturn = audioURL // Capture the URL before stopping and nil-ing
        audioRecorder?.stop()
        audioRecorder = nil
        print("Audio file recording stopped.")
        return urlToReturn
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - AVAudioRecorderDelegate Methods (unchanged)
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Audio file recording failed or was interrupted.")
        } else {
            print("Audio file recording finished successfully.")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio file recording encode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}
