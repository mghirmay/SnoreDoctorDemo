//
//  AppSettings.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


// Extensions/Constants.swift (or similar file)
// You might already have a file for constants, if not, create one.

import Foundation
import AVFoundation

extension UserDefaults {

    // MARK: - Audio Recording Settings Enums

    enum AudioFormat: String, CaseIterable, Identifiable {
        case aac = "AAC (Compressed)" // .m4a
        case m4a = "Apple Lossless (ALAC)" // .m4a (lossless compression)
        case wav = "PCM (Uncompressed)" // .wav

        public var id: String { self.rawValue }

        public var formatID: AudioFormatID {
            switch self {
            case .aac: return kAudioFormatMPEG4AAC
            case .m4a: return kAudioFormatAppleLossless
            case .wav: return kAudioFormatLinearPCM
            }
        }

        public var fileExtension: String {
            switch self {
            case .aac, .m4a: return "m4a"
            case .wav: return "wav"
            }
        }
    }

    enum AudioRecordingQuality: String, CaseIterable, Identifiable {
        case min = "Minimum"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case max = "Maximum"

        public var id: String { self.rawValue }

        public var avAudioQuality: AVAudioQuality {
            switch self {
            case .min: return .min
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
            case .max: return .max
            }
        }
    }

    // MARK: - UserDefaults Stored Properties for Audio Settings

    // REMOVED @objc dynamic
    var audioFormatPreference: AudioFormat {
        get {
            let rawValue = string(forKey: "audioFormatPreference") ?? AudioFormat.aac.rawValue
            return AudioFormat(rawValue: rawValue) ?? .aac
        }
        set {
            set(newValue.rawValue, forKey: "audioFormatPreference")
        }
    }

    // REMOVED @objc dynamic
    var sampleRatePreference: Double {
        get {
            // Using `object(forKey:) == nil` is a robust way to check if a value has never been set.
            return object(forKey: "sampleRatePreference") == nil ? 44100.0 : double(forKey: "sampleRatePreference")
        }
        set {
            set(newValue, forKey: "sampleRatePreference")
        }
    }

    // REMOVED @objc dynamic
    var audioQualityPreference: AudioRecordingQuality {
        get {
            let rawValue = string(forKey: "audioQualityPreference") ?? AudioRecordingQuality.high.rawValue
            return AudioRecordingQuality(rawValue: rawValue) ?? .high
        }
        set {
            set(newValue.rawValue, forKey: "audioQualityPreference")
        }
    }

    // Keep your existing @objc dynamic extension for snoreConfidenceThreshold if you need KVO for it.
    // Otherwise, you can also remove @objc dynamic from here for consistency.
    // For this specific error, it's only the enum-backed properties that caused it.
    @objc dynamic var snoreConfidenceThreshold: Double {
        get { return double(forKey: "snoreConfidenceThreshold") }
        set { set(newValue, forKey: "snoreConfidenceThreshold") }
    }
}
