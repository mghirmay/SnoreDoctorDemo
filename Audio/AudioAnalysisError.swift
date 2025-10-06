//
//  AudioAnalysisError.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 22.07.25.
//  Copyright © 2025 SinitPower.de. All rights reserved.
//


// Errors.swift (or similar)
import Foundation

enum AudioAnalysisError: Error, LocalizedError {
    case audioSessionSetupFailed(Error)
    case recordingSetupFailed(Error)
    case permissionDenied
    case invalidState(String)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .audioSessionSetupFailed(let error):
            return "Failed to set up audio session: \(error.localizedDescription)"
        case .recordingSetupFailed(let error):
            return "Failed to set up audio recording: \(error.localizedDescription)"
        case .permissionDenied:
            return "Microphone permission denied. Please enable it in Settings."
        case .invalidState(let message):
            return "Invalid app state: \(message)"
        case .unexpected(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

