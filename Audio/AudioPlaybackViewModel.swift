// AudioPlaybackViewModel.swift (Example structure)
import Foundation
import AVFoundation
import Combine
import CoreData

// FIX: Make AudioPlaybackViewModel inherit from NSObject
class AudioPlaybackViewModel: NSObject, ObservableObject, SoundEventPlaybackDelegate { // <-- Add NSObject here
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    private var currentLoadedSessionID: NSManagedObjectID?
    private var currentLoadedAudioFileName: String?

    // Function to load and prepare an audio file
    func setupAudioPlayer(url: URL) { // Keep this for now, but consider removing as discussed
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0.0

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0 // Range: 0.0 (mute) to 1.0 (max)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self // This will now be valid
            print("Audio player setup for URL: \(url.lastPathComponent)")
        } catch {
            print("Error setting up audio player for \(url.lastPathComponent): \(error.localizedDescription)")
            audioPlayer = nil
        }
    }

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

    func pause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopUpdatingPlaybackTime()
        }
    }

    func stop() {
        stopPlayback()
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
        guard currentLoadedAudioFileName != fileName else {
            print("Audio for file '\(fileName)' already loaded. Preparing to play.")
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            if !isPlaying { currentTime = 0.0 }
            return
        }

        unloadAudio()

        guard !fileName.isEmpty else {
            errorMessage = "Audio file name cannot be empty."
            print("Error: Audio file name cannot be empty.")
            currentLoadedAudioFileName = nil
            currentLoadedSessionID = nil
            return
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not find documents directory."
            print("Error: Could not find documents directory.")
            currentLoadedAudioFileName = nil
            currentLoadedSessionID = nil
            return
        }
        let audioFileURL = documentsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            errorMessage = "Audio file not found at path: \(audioFileURL.lastPathComponent)"
            print("Error: Audio file not found at path: \(audioFileURL.path)")
            currentLoadedAudioFileName = nil
            currentLoadedSessionID = nil
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.delegate = self // This will now work
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0
            errorMessage = nil
            currentLoadedAudioFileName = fileName
            currentLoadedSessionID = nil
            print("Audio loaded: \(audioFileURL.lastPathComponent), Duration: \(duration) seconds.")
        } catch {
            errorMessage = "Failed to load audio file: \(error.localizedDescription)"
            duration = 0.0
            currentLoadedAudioFileName = nil
            currentLoadedSessionID = nil
            print("Error loading audio: \(error.localizedDescription)")
        }
    }

    func loadAudio(for session: RecordingSession) {
        guard currentLoadedSessionID != session.objectID else {
            print("Audio for session \(session.title ?? "N/A") already loaded.")
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            if !isPlaying { currentTime = 0.0 }
            return
        }

        stopPlayback()
        unloadAudio()

        guard let fileName = session.audioFileName, !fileName.isEmpty else {
            errorMessage = "Recording session has no audio file name."
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            return
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not find documents directory."
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            return
        }
        let audioFileURL = documentsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            errorMessage = "Audio file not found at path: \(audioFileURL.lastPathComponent)"
            print("Error: Audio file not found at path: \(audioFileURL.path)")
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.delegate = self // This will now work
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0
            errorMessage = nil
            currentLoadedSessionID = session.objectID
            currentLoadedAudioFileName = fileName
            print("Audio loaded: \(audioFileURL.lastPathComponent), Duration: \(duration) seconds")
        } catch {
            errorMessage = "Failed to load audio file: \(error.localizedDescription)"
            duration = 0.0
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            print("Error loading audio: \(error.localizedDescription)")
        }
    }

    func unloadAudio() {
        stopPlayback()
        audioPlayer = nil
        duration = 0.0
        currentTime = 0.0
        errorMessage = nil
        currentLoadedSessionID = nil
        currentLoadedAudioFileName = nil
    }

    private func startUpdatingPlaybackTime() {
        stopUpdatingPlaybackTime()
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.add(to: .current, forMode: .common)
    }

    private func stopUpdatingPlaybackTime() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        self.currentTime = player.currentTime
        if !player.isPlaying && self.currentTime >= self.duration {
            self.isPlaying = false
            self.currentTime = self.duration
            self.stopUpdatingPlaybackTime()
        }
    }

    deinit {
        unloadAudio()
    }
}

// MARK: - AVAudioPlayerDelegate Conformance
extension AudioPlaybackViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = self.duration
            self.stopUpdatingPlaybackTime()
            print("Audio playback finished successfully: \(flag)")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = "Audio decoding error: \(error?.localizedDescription ?? "Unknown error")"
            self.isPlaying = false
            self.stopUpdatingPlaybackTime()
            print("Audio decoding error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}

