//
//  AudioRecorder.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
// --- AudioRecorder.swift --- (Or where you define AudioRecorder)
/* This is a placeholder for your AudioRecorder class definition.
   Ensure it's in a separate file or within this one.
   It should use the shared AudioManager for session setup.
*/// AudioRecorder.swift


import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL? // This will hold the URL of the current recording

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
    ]

    // New method: Starts recording and returns the URL
    func startAndGetRecordingURL() throws -> URL? {
        let filename = UUID().uuidString + ".m4a"
        audioURL = getDocumentsDirectory().appendingPathComponent(filename)

        guard let url = audioURL else {
            print("Error: Could not create audio URL.")
            throw NSError(domain: "AudioRecorder", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create audio file URL."])
        }

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            print("Audio file recording started at: \(url.lastPathComponent)")
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
        // AudioManager.shared.deactivateAudioSession() // This is now done by ViewController's stopAudioAnalysis for consistency
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
        // AudioManager.shared.deactivateAudioSession() // Now handled by ViewController
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio file recording encode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}
