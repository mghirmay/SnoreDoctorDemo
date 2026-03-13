//
//  SnorePlaybackManager.swift
//  SnoreDoctorDemo
//

import AVFoundation
import Combine

/// Playback manager that reuses the shared AudioEngineManager for all output.
/// Supports snore detection cycles, volume ramping, and a watchdog auto-stop.
class AudioPlaybackManager: NSObject {

    static let shared = AudioPlaybackManager()
    private let playbackQueue = DispatchQueue(label: "com.snoredoctor.playbackQueue")

    private var audioPlayerNode: AVAudioPlayerNode {
            AudioEngineManager.shared.playerNode
        }

    private var audioFileBufferCache: [URL: AVAudioPCMBuffer] = [:]
    private var watchdogTimer: Timer?

    private var isSnoringDetected = false
    private var lastPlayedFileName: String?

    private var sessionVolume: Double = UserDefaults.standard.initialVolume
    private var initialVolume: Double { UserDefaults.standard.initialVolume}
    private var volumeStep: Double { UserDefaults.standard.volumeStep }
    private var silenceTimeout: TimeInterval { UserDefaults.standard.silenceTimeout }

    private var subscriptions = Set<AnyCancellable>()

    private override init() {
        super.init()
        debugBundleStructure()
    }

    // MARK: - Debug Bundle

    private func debugBundleStructure() {
        let bundleURL = Bundle.main.bundleURL
        print("DEBUG: Root Bundle Path: \(bundleURL.path)")

        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                print("Found item at: \(fileURL.path)")
            }
        }
    }

    // MARK: - Public API

    /// Called when snoring is detected, triggering playback cycles.
    func notifySnoreDetected() {
        resetWatchdog()
        print("🌙 Snore cycle started.")
        playbackQueue.async { [weak self] in
            guard let self = self, !self.isSnoringDetected else { return }
            self.isSnoringDetected = true
            self.sessionVolume = self.initialVolume
            self.playNextCycle()
        }
    }

    func stopEverything() {
        isSnoringDetected = false
        watchdogTimer?.invalidate()
        watchdogTimer = nil

        audioPlayerNode.stop()
        audioPlayerNode.reset()
    }

    // MARK: - Playback Cycle

    private func playNextCycle() {
        // This runs on the playbackQueue, protecting isSnoringDetected
        guard isSnoringDetected else { return }
        self.playRandomSound(volume: sessionVolume)
    }

    
    private func playRandomSound(volume: Double) {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
            let allAudioFiles = fileURLs.filter {
                let name = $0.lastPathComponent
                return name.hasPrefix("AntiSchnarch") &&
                    (name.lowercased().hasSuffix(".wav") || name.lowercased().hasSuffix(".mp3"))
            }

            let availableFiles = allAudioFiles.filter { $0.lastPathComponent != lastPlayedFileName }
            guard let randomFileURL = availableFiles.randomElement() ?? allAudioFiles.randomElement() else {
                print("⚠️ No audio files found. Stopping.")
                stopEverything()
                return
            }

            lastPlayedFileName = randomFileURL.lastPathComponent
              
            // 1. Get the target format from the player node
            let outputFormat = audioPlayerNode.outputFormat(forBus: 0)
            
            // 2. Load and potentially convert the buffer
            let buffer: AVAudioPCMBuffer
            if let cached = audioFileBufferCache[randomFileURL] {
                buffer = cached
            } else {
                // Use the new converter method
                buffer = try loadAndConvertFile(url: randomFileURL, to: outputFormat)
                audioFileBufferCache[randomFileURL] = buffer
            }

            // 3. Schedule playback
            audioPlayerNode.volume = Float(volume)
            audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
                guard let self = self else { return }
                self.playbackQueue.asyncAfter(deadline: .now() + 5.0) {
                    self.playNextCycle()
                }
            }

            if !audioPlayerNode.isPlaying {
                audioPlayerNode.play()
            }

            sessionVolume = min(sessionVolume + volumeStep, 1.0)

        } catch {
            print("❌ Playback error: \(error)")
            stopEverything()
        }
    }
    
    private func loadAndConvertFile(url: URL, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        
        // 1. Create the buffer based on the TARGET format
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Buffer creation failed"])
        }
        
        // 2. Setup the converter
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: format) else {
            // Fallback: if conversion isn't needed, try direct read
            try audioFile.read(into: buffer)
            return buffer
        }
        
        // 3. Perform the conversion
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: inNumPackets)!
            do {
                try audioFile.read(into: inputBuffer)
                return inputBuffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        converter.convert(to: buffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error { throw error }
        return buffer
    }

    // MARK: - Watchdog

    private func resetWatchdog() {
        watchdogTimer?.invalidate()
        let timer = Timer(timeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            print("🤫 Watchdog: Timer expired!")
            self?.stopEverything()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }
}
