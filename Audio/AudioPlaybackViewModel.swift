// AudioPlaybackViewModel.swift (Example structure)
import Foundation
import AVFoundation

class AudioPlaybackViewModel: ObservableObject, SoundEventPlaybackDelegate { // Conforms here
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink? // For updating currentTime

    // MARK: - SoundEventPlaybackDelegate Conformance
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }

    func play() {
        guard let player = audioPlayer else { return }
        if !player.isPlaying {
            player.play()
            isPlaying = true
            startUpdatingPlaybackTime()
        }
    }

    func pause() { // Add pause if you need it for the delegate
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopUpdatingPlaybackTime()
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0.0
        stopUpdatingPlaybackTime()
    }

    func loadAudio(fileName: String) {
        stopPlayback() // Stop any current playback

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not find documents directory."
            return
        }
        let audioFileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0 // Reset current time on new load
            errorMessage = nil // Clear any previous error
            print("Audio loaded: \(audioFileURL.lastPathComponent), Duration: \(duration) seconds")
        } catch {
            errorMessage = "Failed to load audio file: \(error.localizedDescription)"
            duration = 0.0
            print("Error loading audio: \(error.localizedDescription)")
        }
    }

    func unloadAudio() {
        stopPlayback()
        audioPlayer = nil
        duration = 0.0
        currentTime = 0.0
        errorMessage = nil
    }

    private func startUpdatingPlaybackTime() {
        stopUpdatingPlaybackTime() // Ensure only one display link is active
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.add(to: .current, forMode: .common)
    }

    private func stopUpdatingPlaybackTime() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        DispatchQueue.main.async {
            self.currentTime = player.currentTime
            if !player.isPlaying && self.currentTime >= self.duration {
                // Playback finished
                self.isPlaying = false
                self.currentTime = self.duration // Ensure it shows full duration at end
                self.stopUpdatingPlaybackTime()
            }
        }
    }

    deinit {
        stopUpdatingPlaybackTime()
        audioPlayer = nil
    }
}
