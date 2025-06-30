//
//  SoundEventPlaybackDelegate.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//

//
// SoundEventPlaybackDelegate.swift
// SnoreDoctorDemo
//
// Created by [Your Name] on 2025/06/30.
//

import Foundation

// Define the protocol for playback actions
protocol SoundEventPlaybackDelegate: AnyObject {
    func seek(to time: TimeInterval)
    func play()
    // You might also add:
    // func pause()
    // var isPlaying: Bool { get }
}
