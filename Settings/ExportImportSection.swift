//
//  ExportImportSection.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - File type so the picker recognises .zip

extension UTType {
    static let sleepBackup = UTType(exportedAs: "de.sinitpower.snoredoctordemo.backup", conformingTo: .zip)
}

// MARK: - Drop this section into your existing DataManagementSection
// (or replace the export/import area inside it)

struct ExportImportSection: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Export
    @State private var isExporting       = false

    // Import
    @State private var showFilePicker    = false
    @State private var showImportOptions = false
    @State private var pendingImportURL: URL?

    // Feedback
    @State private var isBusy            = false
    @State private var resultMessage: String?
    @State private var showResult        = false

    private let manager = DataExportImportManager()

    var body: some View {
        Section(header: Text("Backup & Restore".translate())) {

            // Export
            Button {
                Task { await runExport() }
            } label: {
                Label("Export Data".translate(), systemImage: "square.and.arrow.up")
                    .foregroundColor(Color("AppColor"))
            }
            .disabled(isBusy)

            // Import
            Button {
                showFilePicker = true
            } label: {
                Label("Import Data".translate(), systemImage: "square.and.arrow.down")
                    .foregroundColor(Color("AppColor"))
            }
            .disabled(isBusy)

            if isBusy {
                HStack {
                    ProgressView()
                    Text("Please wait…".translate())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.zip, .sleepBackup],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                pendingImportURL = urls.first
                showImportOptions = true
            case .failure(let error):
                resultMessage = error.localizedDescription
                showResult = true
            }
        }
        // Ask merge vs replace before importing
        .confirmationDialog("Import Options".translate(),
                            isPresented: $showImportOptions,
                            titleVisibility: .visible) {
            Button("Merge with existing data".translate()) {
                if let url = pendingImportURL { Task { await runImport(url: url, clear: false) } }
            }
            Button("Replace all data".translate(), role: .destructive) {
                if let url = pendingImportURL { Task { await runImport(url: url, clear: true) } }
            }
            Button("Cancel".translate(), role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("ImportOptions_Info".translate())   // "Merge keeps existing records. Replace removes everything first."
        }
        // Result alert
        .alert("", isPresented: $showResult) {
            Button("OK".translate(), role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: Actions

    private func runExport() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let url = try await manager.exportData(context: viewContext)
            presentShareSheet(url: url)
        } catch {
            resultMessage = error.localizedDescription
            showResult    = true
        }
    }

    private func runImport(url: URL, clear: Bool) async {
        isBusy = true
        defer { isBusy = false }
        // Security-scoped access for files from Files app / iCloud
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try await manager.importData(from: url, context: viewContext, clearBeforeImport: clear)
            resultMessage = "Import successful! ✓".translate()
            NotificationCenter.default.post(name: .dataDidClear, object: nil) // refresh UI
        } catch {
            resultMessage = error.localizedDescription
        }
        showResult = true
    }

    private func cleanupTempExport() {
        // No-op — file cleanup now handled after share sheet closes naturally
    }
}

// MARK: - Share via UIWindowScene (fixes instant-dismiss bug in SwiftUI sheets/forms)

func presentShareSheet(url: URL) {
    guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
          let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
        return
    }

    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)

    // On iPad, a source rect is required or it crashes
    if let popover = vc.popoverPresentationController {
        popover.sourceView = rootVC.view
        popover.sourceRect = CGRect(
            x: rootVC.view.bounds.midX,
            y: rootVC.view.bounds.midY,
            width: 0, height: 0
        )
        popover.permittedArrowDirections = []
    }

    // Find the topmost presented controller to avoid conflicts
    var presenter = rootVC
    while let presented = presenter.presentedViewController {
        presenter = presented
    }
    presenter.present(vc, animated: true)
}
