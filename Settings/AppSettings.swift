//
//  AppSettings.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


import Foundation
import AVFoundation

// Your existing AppSettings struct - ADD THE NEW DEFAULT VALUES HERE
struct AppSettings {
    static let defaultSnoreConfidenceThreshold: Double = 0.6
    static let defaultAnalysisWindowDuration: Double = 1.0
    static let defaultAnalysisOverlapFactor: Double = 0.5

    // --- NEW: Default values for Snore Event Post-Processing ---
    static let defaultPostProcessGapThreshold: Double = 5.0
    static let defaultPostProcessSmoothingWindowSize: Int = 3
    static let defaultPostProcessShortInterruptionThreshold: Double = 1.0

    // --- NEW: Snore Identifiers (used by both aggregator and post-processor) ---
    static let snoreEventIdentifier: String = "snoring"
    static let snoreEventRelatedIdentifiers: Set<String> = ["snoring", "gasp", "breathing", "sigh", "whispering"]
}


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


    var audioFormatPreference: AudioFormat {
        get {
            let rawValue = string(forKey: "audioFormatPreference") ?? AudioFormat.aac.rawValue
            return AudioFormat(rawValue: rawValue) ?? .aac
        }
        set {
            set(newValue.rawValue, forKey: "audioFormatPreference")
        }
    }

    var sampleRatePreference: Double {
        get {
            // Using `object(forKey:) == nil` is a robust way to check if a value has never been set.
            return object(forKey: "sampleRatePreference") == nil ? 44100.0 : double(forKey: "sampleRatePreference")
        }
        set {
            set(newValue, forKey: "sampleRatePreference")
        }
    }

    var audioQualityPreference: AudioRecordingQuality {
        get {
            let rawValue = string(forKey: "audioQualityPreference") ?? AudioRecordingQuality.high.rawValue
            return AudioRecordingQuality(rawValue: rawValue) ?? .high
        }
        set {
            set(newValue.rawValue, forKey: "audioQualityPreference")
        }
    }

    @objc dynamic var snoreConfidenceThreshold: Double {
        get {
            // Default to a reasonable threshold if not set
            return object(forKey: "snoreConfidenceThreshold") == nil ? 0.6 : double(forKey: "snoreConfidenceThreshold")
        }
        set { set(newValue, forKey: "snoreConfidenceThreshold") }
    }
    
    // MARK: - Sound Analysis Settings
    var analysisWindowDuration: Double {
        get {
            // Default to 1.0 second if not set
            return object(forKey: "analysisWindowDuration") == nil ? 1.0 : double(forKey: "analysisWindowDuration")
        }
        set {
            set(newValue, forKey: "analysisWindowDuration")
        }
    }

    var analysisOverlapFactor: Double {
        get {
            // Default to 0.5 if not set
            return object(forKey: "analysisOverlapFactor") == nil ? 0.5 : double(forKey: "analysisOverlapFactor")
        }
        set {
            set(newValue, forKey: "analysisOverlapFactor")
        }
    }

    // MARK: - Snore Event Post-Processing Settings (NEWLY ADDED)

    var postProcessGapThreshold: Double {
        get {
            // Default to 5.0 seconds if not set
            return object(forKey: "postProcessGapThreshold") == nil ? 5.0 : double(forKey: "postProcessGapThreshold")
        }
        set {
            set(newValue, forKey: "postProcessGapThreshold")
        }
    }

    var postProcessSmoothingWindowSize: Int {
        get {
            // Default to 3 events if not set
            return object(forKey: "postProcessSmoothingWindowSize") == nil ? 3 : integer(forKey: "postProcessSmoothingWindowSize")
        }
        set {
            set(newValue, forKey: "postProcessSmoothingWindowSize")
        }
    }

    var postProcessShortInterruptionThreshold: Double {
        get {
            // Default to 1.0 second if not set
            return object(forKey: "postProcessShortInterruptionThreshold") == nil ? 1.0 : double(forKey: "postProcessShortInterruptionThreshold")
        }
        set {
            set(newValue, forKey: "postProcessShortInterruptionThreshold")
        }
    }
}
