//
//  TestToolbarView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//


import SwiftUI

struct TestToolbarView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Test View")
            }
            .navigationTitle("Test Title")
            .toolbar {
                // Try your specific problematic line here
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TestToolbarView()
}