//
//  Strings.swift
//  SnoreDoctorDemo
//
//  Created by Klaus Paul on 03.07.25.
//

import Foundation

extension String {
    func translate() -> String {
        return NSLocalizedString(self, comment: "")
    }
    func transtateWithValue(value: String) -> String {
        return String(format: NSLocalizedString(self, comment: ""),  value)
    }
    
}
