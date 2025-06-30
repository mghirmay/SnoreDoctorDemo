//
// SnoreDoctorPlaybackViewModel.swift
// SnoreDoctorDemo
//
// Created by [Your Name] on 2025/06/30.
//

import Foundation
import AVFoundation // For AVAudioPlayer

// Change: Inherit from NSObject
class SnoreDoctorPlaybackViewModel: NSObject, ObservableObject, SoundEventPlaybackDelegate {
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0

    private var timer: Timer?

    // Function to load and prepare an audio file
    func setupAudioPlayer(url: URL) {
        audioPlayer?.stop()
        timer?.invalidate()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0.0

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self // 'self' is now an NSObject, so this is valid
            print("Audio player setup for URL: \(url.lastPathComponent)")
        } catch {
            print("Error setting up audio player for \(url.lastPathComponent): \(error.localizedDescription)")
            audioPlayer = nil
        }
    }

    // MARK: - SoundEventPlaybackDelegate Methods

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else {
            print("Audio player not available to seek.")
            return
        }
        player.currentTime = time
        currentTime = time
        print("Seeking to: \(time) seconds")
    }

    func play() {
        guard let player = audioPlayer else {
            print("Audio player not available to play.")
            return
        }
        if !player.isPlaying {
            player.play()
            isPlaying = true
            startTimer()
            print("Playing audio...")
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        print("Pausing audio...")
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0.0
        timer?.invalidate()
        print("Stopping audio.")
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            if !player.isPlaying {
                self.stop()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - AVAudioPlayerDelegate
// This extension is now valid because SnoreDoctorPlaybackViewModel inherits from NSObject
extension SnoreDoctorPlaybackViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished: \(flag ? "successfully" : "unsuccessfully")")
        stop()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "unknown error")")
        stop()
    }
}
