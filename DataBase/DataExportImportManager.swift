//
//  AppExportBundle.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 14.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//


import Foundation
import CoreData
import ZIPFoundation

// MARK: - DTOs

struct AppExportBundle: Codable {
    let exportVersion: Int          // bump when schema changes
    let exportDate: Date
    let sessions: [SessionDTO]
    let soundEvents: [SoundEventDTO]
    let snoreEvents: [SegmentDTO]
}

struct SessionDTO: Codable {
    let id: UUID
    let audioFileName: String?
    let endTime: Date?
    let lastUpdate: Date?
    let notes: String?
    let qualityScore: Double
    let startTime: Date?
    let title: String?
    let totalNonSnoreEvents: Int32
    let totalSnoreEvents: Int32
    let totalSnoreRelated: Int32
}

struct SegmentDTO: Codable {            // the entity with averageConfidence etc.
    let id: UUID
    let sessionID: UUID?                // foreign key back to SessionDTO
    let averageConfidence: Double
    let count: Int32
    let countNone: Int32
    let countSnores: Int32
    let duration: Double
    let endTime: Date?
    let maxConfidence: Double
    let medianConfidence: Double
    let minConfidence: Double
    let name: String?
    let soundEventNamesHistogram: Data? // stored as JSON-encoded Data in Core Data
    let startTime: Date?
}

struct SoundEventDTO: Codable {
    let id: UUID
    let sessionID: UUID?                // foreign key back to SessionDTO
    let audioFileName: String?
    let confidence: Double
    let name: String?
    let timestamp: Date?
}

// MARK: - Manager

final class DataExportImportManager {

    enum AppExportError: LocalizedError {
        case exportFailed(String)
        case importFailed(String)
        case invalidBundle
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .exportFailed(let m):     return "Export failed: \(m)"
            case .importFailed(let m):     return "Import failed: \(m)"
            case .invalidBundle:           return "Not a valid backup file."
            case .unsupportedVersion(let v): return "Backup version \(v) is not supported."
            }
        }
    }

    private let currentExportVersion = 1

    // MARK: - Export

    /// Returns URL to a temporary .zip ready for sharing.
    func exportData(context: NSManagedObjectContext) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let zip = try self._buildZip(context: context)
                    continuation.resume(returning: zip)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func _buildZip(context: NSManagedObjectContext) throws -> URL {
        // 1. Fetch
        let sessions  = try context.fetch(RecordingSession.fetchRequest())
        let events    = try context.fetch(SoundEvent.fetchRequest())
        let segFetch  = SnoreEvent.fetchRequest()
        let segments  = try context.fetch(segFetch)

        // 2. Build DTOs
        let sessionDTOs = sessions.map { s in
            SessionDTO(
                id:                  s.id ?? UUID(),
                audioFileName:       s.audioFileName,
                endTime:             s.endTime,
                lastUpdate:          s.lastUpdate,
                notes:               s.notes,
                qualityScore:        s.qualityScore,
                startTime:           s.startTime,
                title:               s.title,
                totalNonSnoreEvents: s.totalNonSnoreEvents,
                totalSnoreEvents:    s.totalSnoreEvents,
                totalSnoreRelated:   s.totalSnoreRelated
            )
        }

        let eventDTOs = events.map { e in
            SoundEventDTO(
                id:            e.id ?? UUID(),
                sessionID:     (e.value(forKey: "session") as? RecordingSession)?.id,
                audioFileName: e.audioFileName,
                confidence:    e.confidence,
                name:          e.name,
                timestamp:     e.timestamp
            )
        }

        let segmentDTOs = segments.map { seg -> SegmentDTO in
            SegmentDTO(
                id:                        (seg.value(forKey: "id") as? UUID) ?? UUID(),
                sessionID:                 (seg.value(forKey: "session") as? RecordingSession)?.id,
                averageConfidence:         seg.value(forKey: "averageConfidence") as? Double ?? 0,
                count:                     seg.value(forKey: "count") as? Int32 ?? 0,
                countNone:                 seg.value(forKey: "countNone") as? Int32 ?? 0,
                countSnores:               seg.value(forKey: "countSnores") as? Int32 ?? 0,
                duration:                  seg.value(forKey: "duration") as? Double ?? 0,
                endTime:                   seg.value(forKey: "endTime") as? Date,
                maxConfidence:             seg.value(forKey: "maxConfidence") as? Double ?? 0,
                medianConfidence:          seg.value(forKey: "medianConfidence") as? Double ?? 0,
                minConfidence:             seg.value(forKey: "minConfidence") as? Double ?? 0,
                name:                      seg.value(forKey: "name") as? String,
                soundEventNamesHistogram:  seg.value(forKey: "soundEventNamesHistogram") as? Data,
                startTime:                 seg.value(forKey: "startTime") as? Date
            )
        }

        // 3. Encode JSON
        let bundle = AppExportBundle(
            exportVersion: currentExportVersion,
            exportDate:    Date(),
            sessions:      sessionDTOs,
            soundEvents:   eventDTOs,
            snoreEvents:   segmentDTOs
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(bundle)

        // 4. Create temp ZIP
        let tmp      = FileManager.default.temporaryDirectory
        let jsonURL  = tmp.appendingPathComponent("data.json")
        let zipURL   = tmp.appendingPathComponent("SleepBackup_\(Self.dateStamp()).zip")
        try jsonData.write(to: jsonURL)
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw AppExportError.exportFailed("Could not create ZIP archive.")
        }

        // 5. Add JSON
        try archive.addEntry(with: "data.json", fileURL: jsonURL)

        // 6. Add audio files
        let recordingsFolder = try FileManager.getRecordingsFolderURL()
        let allAudioFiles = sessionDTOs.compactMap(\.audioFileName)
            + eventDTOs.compactMap(\.audioFileName)

        for fileName in Set(allAudioFiles) {
            let fileURL = recordingsFolder.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try archive.addEntry(with: "audio/\(fileName)", fileURL: fileURL)
            }
        }

        return zipURL
    }

    // MARK: - Import

    /// Imports data from a .zip previously exported by this app.
    /// Pass `mergePolicy` = true to keep existing records, false to clear first.
    func importData(from zipURL: URL,
                    context: NSManagedObjectContext,
                    clearBeforeImport: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try self._unzipAndImport(from: zipURL, context: context, clearBeforeImport: clearBeforeImport)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func _unzipAndImport(from zipURL: URL,
                                  context: NSManagedObjectContext,
                                  clearBeforeImport: Bool) throws {
        // 1. Open archive
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw AppExportError.invalidBundle
        }

        // 2. Extract to temp dir
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepImport_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }

        for entry in archive {
            let dest = extractDir.appendingPathComponent(entry.path)
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: dest)
        }

        // 3. Decode JSON
        let jsonURL = extractDir.appendingPathComponent("data.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw AppExportError.invalidBundle
        }
        let jsonData = try Data(contentsOf: jsonURL)
        let decoder  = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle   = try decoder.decode(AppExportBundle.self, from: jsonData)

        guard bundle.exportVersion <= currentExportVersion else {
            throw AppExportError.unsupportedVersion(bundle.exportVersion)
        }

        // 4. Optionally clear existing data
        if clearBeforeImport {
            try context.execute(NSBatchDeleteRequest(fetchRequest: SoundEvent.fetchRequest()))
            try context.execute(NSBatchDeleteRequest(fetchRequest: SnoreEvent.fetchRequest()))
            try context.execute(NSBatchDeleteRequest(fetchRequest: RecordingSession.fetchRequest()))
            context.reset()
        }

        // 5. Insert Sessions, build UUID → NSManagedObject map
        var sessionMap = [UUID: RecordingSession]()
        for dto in bundle.sessions {
            // Skip duplicates if merging
            if !clearBeforeImport,
               let existing = try? fetchSession(id: dto.id, context: context) {
                sessionMap[dto.id] = existing
                continue
            }
            let s = RecordingSession(context: context)
            s.id                  = dto.id
            s.audioFileName       = dto.audioFileName
            s.endTime             = dto.endTime
            s.lastUpdate          = dto.lastUpdate
            s.notes               = dto.notes
            s.qualityScore        = dto.qualityScore
            s.startTime           = dto.startTime
            s.title               = dto.title
            s.totalNonSnoreEvents = dto.totalNonSnoreEvents
            s.totalSnoreEvents    = dto.totalSnoreEvents
            s.totalSnoreRelated   = dto.totalSnoreRelated
            sessionMap[dto.id]    = s
        }

        // 6. Insert SoundEvents
        for dto in bundle.soundEvents {
            if !clearBeforeImport,
               (try? fetchEvent(id: dto.id, context: context)) != nil { continue }
            let e = SoundEvent(context: context)
            e.id            = dto.id
            e.audioFileName = dto.audioFileName
            e.confidence    = dto.confidence
            e.name          = dto.name
            e.timestamp     = dto.timestamp
            if let sid = dto.sessionID { e.setValue(sessionMap[sid], forKey: "session") }
        }

        // 7. Insert Segments
        for dto in bundle.snoreEvents {
            if !clearBeforeImport {
                let fr = SnoreEvent.fetchRequest()
                fr.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                if (try? context.fetch(fr))?.isEmpty == false { continue }
            }
            let seg = SnoreEvent(context: context)
            seg.setValue(dto.id,                       forKey: "id")
            seg.setValue(dto.averageConfidence,        forKey: "averageConfidence")
            seg.setValue(dto.count,                    forKey: "count")
            seg.setValue(dto.countNone,                forKey: "countNone")
            seg.setValue(dto.countSnores,              forKey: "countSnores")
            seg.setValue(dto.duration,                 forKey: "duration")
            seg.setValue(dto.endTime,                  forKey: "endTime")
            seg.setValue(dto.maxConfidence,            forKey: "maxConfidence")
            seg.setValue(dto.medianConfidence,         forKey: "medianConfidence")
            seg.setValue(dto.minConfidence,            forKey: "minConfidence")
            seg.setValue(dto.name,                     forKey: "name")
            seg.setValue(dto.soundEventNamesHistogram, forKey: "soundEventNamesHistogram")
            seg.setValue(dto.startTime,                forKey: "startTime")
            if let sid = dto.sessionID { seg.setValue(sessionMap[sid], forKey: "session") }
        }

        // 8. Copy audio files
        let recordingsFolder = try FileManager.getRecordingsFolderURL()
        let audioDir = extractDir.appendingPathComponent("audio")
        if FileManager.default.fileExists(atPath: audioDir.path) {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir, includingPropertiesForKeys: nil)
            for file in files {
                let dest = recordingsFolder.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.copyItem(at: file, to: dest)
                }
            }
        }

        // 9. Save
        if context.hasChanges { try context.save() }
    }

    // MARK: - Helpers

    private func fetchSession(id: UUID, context: NSManagedObjectContext) throws -> RecordingSession? {
        let fr = RecordingSession.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        return try context.fetch(fr).first
    }

    private func fetchEvent(id: UUID, context: NSManagedObjectContext) throws -> SoundEvent? {
        let fr = SoundEvent.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        return try context.fetch(fr).first
    }

    private static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}
