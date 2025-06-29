//
//  AudioManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//

import Foundation
import AVFoundation



// --- AudioManager.swift --- (Or where you define AudioManager)
// This file should contain your AudioManager class, ensuring it's properly defined.
// The setupAudioSessionForRecording method needs to accept parameters for category, mode, and options.

/* This is a placeholder for your AudioManager class definition.
   Ensure it's in a separate file or within this one if you prefer.
   The key is that setupAudioSessionForRecording now takes parameters.
*/
class AudioManager: ObservableObject {
    static let shared = AudioManager() // Singleton instance

    private init() {} // Private initializer for singleton

    func setupAudioSessionForRecording(category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(category, mode: mode, options: options)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation) // .notifyOthersOnDeactivation is good practice
            print("Audio Session configured for recording (Category: \(category.rawValue), Mode: \(mode.rawValue), Options: \(options)).")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            throw AudioAnalysisError.audioSessionSetupFailed(error) // Wrap in your custom error
        }
    }

    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio Session deactivated.")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
