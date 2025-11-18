import Foundation
import AVFoundation
import CoreData // Required for NSManagedObjectID, assuming RecordingSession is a Core Data entity
import QuartzCore // Required for CADisplayLink


class AudioPlaybackViewModel: NSObject, ObservableObject, SoundEventPlaybackDelegate { // Inherits from NSObject
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    private var currentLoadedSessionID: NSManagedObjectID?
    private var currentLoadedAudioFileName: String?

    // Function to load and prepare an audio file
    func setupAudioPlayer(url: URL) {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0.0

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self // The ViewModel (self) is now a valid delegate
            duration = audioPlayer?.duration ?? 0.0
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
            audioPlayer?.delegate = self // Set delegate
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

    
  
    // MARK: - SoundEventPlaybackDelegate Conformance (Rewritten)

    // The protocol method signature should be:
    // func loadAudio(for session: RecordingSession, completion: @escaping (Bool) -> Void)
    // We are implementing the logic for this new signature.

    func loadAudio(for session: RecordingSession, completion: @escaping (Bool) -> Void) {
        // 1. Check if the correct audio is ALREADY loaded
        guard currentLoadedSessionID != session.objectID else {
            print("Audio for session \(session.title ?? "N/A") already loaded.")
            
            // Ensure properties are updated and signal success immediately
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            if !isPlaying { currentTime = 0.0 }
            
            completion(true) // Signal success right away
            return
        }

        stopPlayback()
        unloadAudio()

        // 2. Validate essential data
        guard let fileName = session.audioFileName, !fileName.isEmpty else {
            errorMessage = "Recording session has no audio file name."
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            completion(false) // Signal failure
            return
        }

        // 3. Construct file URL
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not find documents directory."
            completion(false) // Signal failure
            return
        }
        let audioFileURL = documentsDirectory.appendingPathComponent(fileName)

        // 4. Check if file exists
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            errorMessage = "Audio file not found at path: \(audioFileURL.lastPathComponent)"
            print("Error: Audio file not found at path: \(audioFileURL.path)")
            completion(false) // Signal failure
            return
        }

        // 5. Load and prepare AVAudioPlayer
        do {
            // Setup new player
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay() // This prepares the buffer, making seeking possible

            // Update view model state
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0
            errorMessage = nil
            currentLoadedSessionID = session.objectID
            currentLoadedAudioFileName = fileName
            
            print("Audio loaded: \(audioFileURL.lastPathComponent), Duration: \(duration) seconds")
            
            // ⭐️ Signal success after player setup
            completion(true)
        } catch {
            // Handle setup error
            errorMessage = "Failed to load audio file: \(error.localizedDescription)"
            duration = 0.0
            currentLoadedSessionID = nil
            currentLoadedAudioFileName = nil
            print("Error loading audio: \(error.localizedDescription)")
            
            // ⭐️ Signal failure after error
            completion(false)
        }
    }
    
    func seekAndPlaySnoreEvent(session: RecordingSession, startTime: Date, duration: TimeInterval) {
        guard let player = audioPlayer,
              let sessionStartTime = session.startTime else {
            print("Playback Error: Player or session start time not ready.")
            return
        }

        // 1. Calculate Seek Time with Context
        let contextTime: TimeInterval = 1.0 // Start 1 second before the event for context
        let eventSeekTime = startTime.timeIntervalSince(sessionStartTime)
        let finalSeekTime = max(0.0, eventSeekTime - contextTime)
        
        // Total playback time is the context time plus the snore event's duration
        let totalPlaybackDuration = contextTime + duration

        // 2. Clear any previous stop schedule (optional, but good practice if calling quickly)
        // NOTE: For a production app, you might use a cancellable DispatchWorkItem here.
        // For this simple example, we rely on the new scheduled task.
        
        // 3. Perform Seek
        player.currentTime = finalSeekTime
        self.currentTime = player.currentTime

        // 4. Start Playback
        self.play()

        // 5. Schedule Stop Action After Duration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalPlaybackDuration) {
            // Ensure the player is still active and playing the expected audio
            guard player.isPlaying else {
                return // Already stopped by user or finished naturally
            }
            
            // Stop playback
            self.pause()
            
            // Optional: Seek back to the start of the snore event (without context time)
            // to keep the slider positioned on the event after pausing.
            player.currentTime = eventSeekTime
            self.currentTime = eventSeekTime
            
            print("Playback automatically stopped after \(totalPlaybackDuration) seconds.")
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
        // Use self as the target since it inherits from NSObject and the selector is @objc
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
    // Called when a sound has finished playing.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = self.duration
            self.stopUpdatingPlaybackTime()
            print("Audio playback finished successfully: \(flag)")
        }
    }

    // Called when an audio file decode error has occurred.
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = "Audio decoding error: \(error?.localizedDescription ?? "Unknown error")"
            self.isPlaying = false
            self.stopUpdatingPlaybackTime()
            print("Audio decoding error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}
