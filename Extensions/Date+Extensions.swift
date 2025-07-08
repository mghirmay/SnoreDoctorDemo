//
//  Date+Extensions.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 02.07.25.
//

import Foundation

// Extension to help with Date calculations
//(can be placed in a separate file or at the top level)
public extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        let date = Calendar.current.date(byAdding: components, to: self.startOfDay)
        return (date?.addingTimeInterval(-1))!
    }
}
