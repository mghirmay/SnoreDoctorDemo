//
//  FileManagerExtension.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 12.03.26.
//  Copyright © 2026 SinitPower.de. All rights reserved.
//

import Foundation
import CoreData // Essential for Core Data operations


extension FileManager {
    
    /// generates a unique folder name in App Documents directory
     static func getURL(forSessionID id: UUID) throws -> URL {
         let folder = try getRecordingsFolderURL()
         return folder.appendingPathComponent("recording_\(id.uuidString).caf")
     }
    
    /// Returns the URL to the dedicated "Recordings" sub-folder within the Documents directory.
    static func getRecordingsFolderURL() throws -> URL {
        let fileManager = FileManager.default
        
        // 1. Locate the Documents directory
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // 2. Define the "Recordings" sub-folder
        let recordingsFolder = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        
        // 3. Create it if it doesn't exist
        if !fileManager.fileExists(atPath: recordingsFolder.path) {
            try fileManager.createDirectory(
                at: recordingsFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return recordingsFolder
    }

    
    func sizeOfFolder(at url: URL) -> String {
            let folderPath = url.path
            var totalSize: Int64 = 0
            
            do {
                let files = try contentsOfDirectory(atPath: folderPath)
                for file in files {
                    let path = url.appendingPathComponent(file).path
                    let attributes = try attributesOfItem(atPath: path)
                    if let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                }
            } catch {
                return "0 MB"
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        }

}
