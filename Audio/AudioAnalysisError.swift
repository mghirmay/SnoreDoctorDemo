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
    case noActiveSession
    case audioSessionSetupFailed(Error)
    case recordingSetupFailed(Error)
    case permissionDenied
    case audioStreamInterrupted
    case invalidState(String)
    case unexpected(Error)
    case audioInputUnavailable(Error)
    case modelNotFound(name: String)
    case sessionURLUnavailable

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active Recording session found."
        case .audioSessionSetupFailed(let error):
            return "Failed to set up audio session: \(error.localizedDescription)"
        case .recordingSetupFailed(let error):
            return "Failed to set up audio recording: \(error.localizedDescription)"
        case .permissionDenied:
            return "Microphone permission denied. Please enable it in Settings."
        case .audioStreamInterrupted:
            return "The audio session was interrupted by the system (e.g., phone call)."
            
        case .invalidState(let message):
            return "Invalid app state: \(message)"
        case .unexpected(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .audioInputUnavailable(let error):
            return "An audioInput Unavailable error occurred: \(error.localizedDescription)"
      
        case .modelNotFound(let name):
            return "CoreML model '\(name).mlmodelc' was not found in the app bundle."
        case .sessionURLUnavailable:
                   return "Could not create a recording file. Check available storage."
              
        
        }
    }
}

