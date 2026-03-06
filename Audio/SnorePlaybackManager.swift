//
//  SnorePlaybackManager.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 23.01.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import AVFoundation

class SnorePlaybackManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SnorePlaybackManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var watchdogTimer: Timer?
    
    private var isSnoringDetected = false
    private var lastPlayedFileName: String? // Store the previous filename

    private var sessionVolume: Double  =  UserDefaults.standard.initialVolume;
    private var initialVolume: Double { UserDefaults.standard.initialVolume }
    private var volumeStep: Double { UserDefaults.standard.volumeStep }
    private var silenceTimeout: TimeInterval { UserDefaults.standard.silenceTimeout }

    private override init() {
        super.init()
        debugBundleStructure()
        configureAudioSession()
    }
    
    func debugBundleStructure() {
        let bundleURL = Bundle.main.bundleURL
        print("DEBUG: Root Bundle Path: \(bundleURL.path)")
        
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                print("Found item at: \(fileURL.path)")
            }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔊 Session error: \(error)")
        }
    }

    /// Your detector calls this every time it hears a snore
    func notifySnoreDetected() {
        // 1. Kick the "Stop Timer" down the road
        resetWatchdog()

        // 2. If we aren't currently in a playback loop, start one
        if !isSnoringDetected {
            print("🌙 Snore cycle started.")
            isSnoringDetected = true
            sessionVolume = initialVolume
            playNextCycle()
        }
    }

    private func playNextCycle() {
        // Ensure the state is still active
        guard isSnoringDetected else { return }
        playRandomSound(volume: sessionVolume)
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isSnoringDetected else { return }

        print("⌛️ Sound ended. Waiting 5 seconds before next potential play...")
        
        // The 5-second gap starts AFTER the sound ends
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.playNextCycle()
        }
    }

    // MARK: - Auto-Stop Logic (The Watchdog)
    private func resetWatchdog() {
        watchdogTimer?.invalidate()
        let timer = Timer(timeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            print("🤫 Watchdog: Timer expired!")
            self?.stopEverything()
        }
        // Explicitly add to main runloop
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    func stopEverything() {
        isSnoringDetected = false
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
    


    private func playRandomSound(volume: Double) {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
            let allAudioFiles = fileURLs.filter {
                let name = $0.lastPathComponent
                return name.hasPrefix("AntiSchnarch") && (name.lowercased().hasSuffix(".wav") || name.lowercased().hasSuffix(".mp3"))
            }
            
            let availableFiles = allAudioFiles.filter { $0.lastPathComponent != lastPlayedFileName }
            
            // If we can't find a file, stop everything and exit
            guard let randomFileURL = availableFiles.randomElement() ?? allAudioFiles.randomElement() else {
                print("⚠️ No audio files found. Stopping.")
                stopEverything()
                return
            }
            
            lastPlayedFileName = randomFileURL.lastPathComponent
            
            audioPlayer = try AVAudioPlayer(contentsOf: randomFileURL)
            audioPlayer?.delegate = self
            // Since volume is a Double from your UserDefaults, cast it to Float:
            audioPlayer?.volume = Float(volume)
            audioPlayer?.play()
            
            sessionVolume = min(sessionVolume + volumeStep, 1.0)
            
        } catch {
            print("❌ Error reading bundle: \(error)")
            stopEverything() // Stop if there's any file access error
        }
    }
}
