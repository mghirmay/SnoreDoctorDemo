//
//  AudioPlaybackViewModel.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// AudioPlaybackViewModel.swift
import Foundation
import AVFoundation
import Combine

class AudioPlaybackViewModel: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var errorMessage: String? = nil

    private var player: AVPlayer?
    private var timeObserverToken: Any?

    // Combine for observing audio events
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        // Observe AVPlayerItemDidPlayToEndTime notification
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.player?.seek(to: .zero) // Reset to beginning
                    self.currentTime = 0.0
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        removeTimeObserver()
        player?.pause()
        cancellables.forEach { $0.cancel() }
    }

    func loadAudio(fileName: String) {
        // Stop any existing playback
        stopPlayback()

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file not found: \(fileName)"
            print("Error: Audio file not found at \(audioURL.path)")
            return
        }

        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)

        // Observe duration
        player?.currentItem?.publisher(for: \.duration)
            .compactMap { $0.isValid ? $0.seconds : nil }
            .sink { [weak self] newDuration in
                DispatchQueue.main.async {
                    self?.duration = newDuration
                    self?.errorMessage = nil // Clear error if successful
                }
            }
            .store(in: &cancellables)

        // Add time observer to update current playback time
        addTimeObserver()
    }

    func togglePlayback() {
        guard let player = player else {
            errorMessage = "No audio loaded."
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
            print("Paused playback at \(currentTime) / \(duration)")
        } else {
            player.play()
            isPlaying = true
            print("Started playback from \(currentTime) / \(duration)")
        }
    }

    func stopPlayback() {
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
        removeTimeObserver()
        errorMessage = nil
        print("Stopped playback and reset.")
    }

    func seek(to time: TimeInterval) {
        guard let player = player, time >= 0, time <= duration else { return }
        let newTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: newTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = time
            }
        }
    }

    private func addTimeObserver() {
        guard let player = player else { return }
        // Update UI every 0.1 seconds
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}