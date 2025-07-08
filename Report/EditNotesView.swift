//
//  EditNotesView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 07.07.25.
//



// You will also need your EditNotesView.swift file, as previously provided:

//
//  EditNotesView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 08.05.25.
//
import SwiftUI
import CoreData

struct EditNotesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var session: RecordingSession

    @State private var notesText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Session Details") {
                    Text("Title: \(session.title ?? "Untitled Session")")
                    if let startTime = session.startTime {
                        Text("Started: \(startTime, formatter: Self.dateFormatter)")
                    }
                    if let endTime = session.endTime {
                        Text("Ended: \(endTime, formatter: Self.dateFormatter)")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notesText)
                        .frame(minHeight: 150)
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                }
            }
            .navigationTitle("Edit Session Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewContext.rollback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        session.notes = notesText
                        PersistenceController.shared.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                notesText = session.notes ?? ""
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

