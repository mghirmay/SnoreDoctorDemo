//
//  SnorePlaybackManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 23.01.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//



/// Manages the playback of random snore audio samples from the app bundle.
import AVFoundation

class SnorePlaybackManager {
    static let shared = SnorePlaybackManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var stopTimer: Timer?
    
    // The directory name as it appears in your project (Blue folder)
    private let subDirectory = "Resources"
    private let snippetLength: TimeInterval = 2.5
    private let fadeDuration: TimeInterval = 0.5
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔊 SnorePlaybackManager: Audio Session failed: \(error)")
        }
    }
    
    func playRandomSound() {
        DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.audioPlayer?.isPlaying == true { return }
                
                // 1. Look directly in the Main Bundle (since the files are at the top level)
                let fileManager = FileManager.default
                guard let bundlePath = Bundle.main.resourcePath else { return }
                
                do {
                    let allFiles = try fileManager.contentsOfDirectory(atPath: bundlePath)
                    
                    // 2. Filter for your naming pattern: Starts with "Sound" and is a .wav or .mp3
                    let audioFiles = allFiles.filter { file in
                        let isAudio = file.lowercased().hasSuffix(".wav") || file.lowercased().hasSuffix(".mp3")
                        let isSnoreFile = file.hasPrefix("Sound")
                        return isAudio && isSnoreFile
                    }
                    
                    // 3. Pick a random file
                    guard let randomFileName = audioFiles.randomElement(),
                          let fileURL = Bundle.main.url(forResource: randomFileName, withExtension: nil) else {
                        print("⚠️ SnorePlaybackManager: No files matching 'Sound XX.wav' found in Bundle.")
                        return
                    }
                    
                    // 4. Setup and Play
                    self.audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.volume = 1.0
                    self.audioPlayer?.play()
                    
                    print("✅ SnorePlaybackManager: Successfully playing from Bundle root: \(randomFileName)")
                    
                    self.scheduleStopTimer()
                    
                } catch {
                    print("❌ SnorePlaybackManager: Error scanning bundle: \(error.localizedDescription)")
                }
            }
    }
    
    // Helper to see what is actually inside your app's bundle
    private func debugListBundleContents() {
        print("📂 Checking Bundle contents...")
        if let path = Bundle.main.resourcePath {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            print("Main Bundle contains: \(items)")
        }
    }
    
    private func scheduleStopTimer() {
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: snippetLength, repeats: false) { [weak self] _ in
            self?.stopWithFade()
        }
    }
    
    private func stopWithFade() {
        audioPlayer?.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
            self?.stopTimer?.invalidate()
            self?.stopTimer = nil
        }
    }

    deinit {
        stopTimer?.invalidate()
    }
}
