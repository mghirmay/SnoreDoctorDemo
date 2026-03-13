//
//  ViewExtension.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    // This helper helps you debug missing environment objects
    func safelyInjectSoundManager(_ manager: SoundDataManager) -> some View {
        self.environmentObject(manager)
    }
}
