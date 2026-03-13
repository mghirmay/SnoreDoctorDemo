//
//  AppSettings.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 29.06.25.
//


import Foundation
import AVFoundation


struct SoundIdentifiers {
    // Direct matches for the primary sound
    static let snore = "snoring"
    
    // Sounds that often indicate airway resistance or "related" distress
    static let snoreRelated: Set<String> = [
        "snoring",
        "pig_oink",
        "gasping",     // Highly relevant for sleep apnea
        "choking",     // Highly relevant for obstructive events
        "heavy_breathing"
    ]
    
    // Clearly distinct sounds
    static let nonSnore: Set<String> = [
        "speech",
        "coughing",
        "laughing",
        "background_noise"
    ]
}


// MARK: - Constants & Default Values
struct AppSettings {
    
    // Playback Settings
    static let defaultInitialVolume: Double = 0.5
    static let defaultVolumeStep: Double = 0.1
    static let defaultSilenceTimeout: TimeInterval = 27.0 //seconds

    // Analysis Defaults
    static let defaultUseCustomLLModel: Bool = false
    static let defaultSnoreConfidenceThreshold: Double = 0.6
    static let defaultAnalysisWindowDuration: Double = 1.0
    static let defaultAnalysisOverlapFactor: Double = 0.5
    static let defaultSampleRate: Double = 44100.0

    // Post-Processing Defaults
    static let defaultPostProcessGapThreshold: Double = 10.0
    static let defaultPostProcessSmoothingWindowSize: Int = 3
    static let defaultPostProcessShortInterruptionThreshold: Double = 1.0

}

// MARK: - UserDefaults Extension
extension UserDefaults {

    // MARK: - Enums
    enum AudioFormat: String, CaseIterable, Identifiable {
        case aac = "AAC (Compressed)"
        case m4a = "Apple Lossless (ALAC)"
        case wav = "PCM (Uncompressed)"

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
        case min = "Minimum", low = "Low", medium = "Medium", high = "High", max = "Maximum"

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

    // MARK: - Audio Recording Preferences
    @objc dynamic var useCustomLLModel: Bool {
            get {
                // If the object doesn't exist yet, return our default
                return object(forKey: "useCustomLLModel") as? Bool ?? AppSettings.defaultUseCustomLLModel
            }
            set { set(newValue, forKey: "useCustomLLModel") }
    }
    
    var audioFormatPreference: AudioFormat {
        get {
            let rawValue = string(forKey: "audioFormatPreference") ?? AudioFormat.aac.rawValue
            return AudioFormat(rawValue: rawValue) ?? .aac
        }
        set { set(newValue.rawValue, forKey: "audioFormatPreference") }
    }

    var sampleRatePreference: Double {
        get { object(forKey: "sampleRatePreference") as? Double ?? AppSettings.defaultSampleRate }
        set { set(newValue, forKey: "sampleRatePreference") }
    }

    var audioQualityPreference: AudioRecordingQuality {
        get {
            let rawValue = string(forKey: "audioQualityPreference") ?? AudioRecordingQuality.high.rawValue
            return AudioRecordingQuality(rawValue: rawValue) ?? .high
        }
        set { set(newValue.rawValue, forKey: "audioQualityPreference") }
    }

    // MARK: - Sound Analysis Settings
    // @objc dynamic allows for Key-Value Observing (KVO) or Combine publishers
    @objc dynamic var snoreConfidenceThreshold: Double {
        get { object(forKey: "snoreConfidenceThreshold") as? Double ?? AppSettings.defaultSnoreConfidenceThreshold }
        set { set(newValue, forKey: "snoreConfidenceThreshold") }
    }

    @objc dynamic var analysisWindowDuration: Double {
        get { object(forKey: "analysisWindowDuration") as? Double ?? AppSettings.defaultAnalysisWindowDuration }
        set { set(newValue, forKey: "analysisWindowDuration") }
    }

    @objc dynamic var analysisOverlapFactor: Double {
        get { object(forKey: "analysisOverlapFactor") as? Double ?? AppSettings.defaultAnalysisOverlapFactor }
        set { set(newValue, forKey: "analysisOverlapFactor") }
    }

    // MARK: - Post-Processing Settings
    var postProcessGapThreshold: Double {
        get { object(forKey: "postProcessGapThreshold") as? Double ?? AppSettings.defaultPostProcessGapThreshold }
        set { set(newValue, forKey: "postProcessGapThreshold") }
    }

    var postProcessSmoothingWindowSize: Int {
        get { object(forKey: "postProcessSmoothingWindowSize") as? Int ?? AppSettings.defaultPostProcessSmoothingWindowSize }
        set { set(newValue, forKey: "postProcessSmoothingWindowSize") }
    }

    var postProcessShortInterruptionThreshold: Double {
        get { object(forKey: "postProcessShortInterruptionThreshold") as? Double ?? AppSettings.defaultPostProcessShortInterruptionThreshold }
        set { set(newValue, forKey: "postProcessShortInterruptionThreshold") }
    }
    
    @objc dynamic var initialVolume: Double {
        get { double(forKey: "initialVolume") != 0 ? double(forKey: "initialVolume") : AppSettings.defaultInitialVolume }
            set { set(newValue, forKey: "initialVolume") }
        }

        @objc dynamic var volumeStep: Double {
            get { double(forKey: "volumeStep") != 0 ? double(forKey: "volumeStep") : AppSettings.defaultVolumeStep }
            set { set(newValue, forKey: "volumeStep") }
        }

        @objc dynamic var silenceTimeout: TimeInterval {
            get { object(forKey: "silenceTimeout") as? TimeInterval ?? AppSettings.defaultSilenceTimeout }
            set { set(newValue, forKey: "silenceTimeout") }
        }
}
