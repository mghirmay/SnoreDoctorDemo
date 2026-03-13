//
//  AudioRecorder.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//
import AVFoundation

final class AudioRecorderManager {

    static let shared = AudioRecorderManager()

    private var audioFile: AVAudioFile?
    private var isRecording = false

    private let writingQueue = DispatchQueue(label: "AudioRecorderManager.queue")

    private init() {}

    // MARK: - Start Recording

    func startRecording(to url: URL) throws {

        stopRecording()

        let engine = AudioEngineManager.shared.audioEngine
        let inputNode = engine!.inputNode
        let nativeFormat = inputNode.inputFormat(forBus: 0)

        audioFile = try AVAudioFile(
            forWriting: url,
            settings: nativeFormat.settings
        )

        isRecording = true
    }

    // MARK: - Stop Recording

    func stopRecording() {

        writingQueue.sync {
            self.isRecording = false
            self.audioFile = nil
        }
    }

    // MARK: - Receive Audio Buffer From Engine

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {

        guard isRecording else { return }

        writingQueue.async { [weak self] in
            guard let self = self else { return }
            guard let file = self.audioFile else { return }

            do {
                try file.write(from: buffer)
            }
            catch {
                print("AudioRecorderManager write error:", error)
            }
        }
    }

    // MARK: - State

    var recording: Bool {
        isRecording
    }
}
