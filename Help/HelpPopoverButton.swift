//
//  HelpPopoverButton.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 11.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import CoreData


struct HelpPopoverButton: View {
    let info: HelpDefinition
    @State private var showInfo = false
    
    var body: some View {
        Button(action: { showInfo = true }) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        }
        .popover(isPresented: $showInfo) {
            VStack(alignment: .leading, spacing: 12) {
                Text(info.title).font(.headline)
                Text(info.definition).font(.subheadline)
                
                if let url = info.sourceURL {
                    Link("Learn more: \(info.sourceName)", destination: url)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .frame(minWidth: 250)
        }
    }
}
