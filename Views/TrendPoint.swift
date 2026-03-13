//
//  TrendPoint.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData


struct TrendPoint: Identifiable {
    let id = UUID()
    let time: Date
    let averageConfidence: Double
    let snoreCount: Int
    
    // The "Heat" value: Confidence weighted by frequency
    var snoreLoad: Double {
        averageConfidence * Double(snoreCount)
    }
}
