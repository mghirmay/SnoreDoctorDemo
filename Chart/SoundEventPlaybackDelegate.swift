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

// Assuming SoundEventPlaybackDelegate is defined elsewhere
protocol SoundEventPlaybackDelegate: AnyObject {
    func seek(to time: TimeInterval)
    func play()
    func pause()
    func stop()
    func togglePlayback()
    func stopPlayback()
    func loadAudio(fileName: String)
    func loadAudio(for session: RecordingSession)
}
