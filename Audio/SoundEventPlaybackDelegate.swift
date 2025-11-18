//
//  SoundEventPlaybackDelegate.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//

import Foundation
import Foundation
import AVFoundation
import Combine
import CoreData

protocol SoundEventPlaybackDelegate: AnyObject {
    func seek(to time: TimeInterval)
    func play()
    func pause()
    func stop()
    func togglePlayback()
    func stopPlayback()
    func loadAudio(fileName: String)
    // ⭐️ MODIFIED: Added completion handler to signal readiness
    func loadAudio(for session: RecordingSession, completion: @escaping (Bool) -> Void)
    
    // ⭐️ NEW FUNCTION to handle SnoreEvent-specific playback
    func seekAndPlaySnoreEvent(session: RecordingSession, startTime: Date, duration: TimeInterval)
    
}
