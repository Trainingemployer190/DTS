//
//  SharedContainerHelper.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Manage shared photo storage that persists across app installations
//

import Foundation

enum SharedContainerHelper {
    /// App Group identifier - MUST match the one configured in Xcode capabilities
    /// Format: group.{bundle-identifier}
    private static let appGroupIdentifier = "group.DTS.DTS-App"

    /// Get the shared container URL for persistent photo storage
    /// This directory persists across app installations and updates
    static var sharedPhotosDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Failed to access App Group container: \(appGroupIdentifier)")
            print("⚠️  Make sure App Groups capability is enabled in Xcode with identifier: \(appGroupIdentifier)")
            return nil
        }

        let photosDir = containerURL.appendingPathComponent("Photos", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: photosDir.path) {
            do {
                try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created shared photos directory: \(photosDir.path)")
            } catch {
                print("❌ Failed to create shared photos directory: \(error)")
                return nil
            }
        }

        return photosDir
    }

    /// Fallback to Documents directory if App Groups is not configured
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Get the best available storage directory (shared container preferred, Documents fallback)
    static var photosStorageDirectory: URL {
        if let sharedDir = sharedPhotosDirectory {
            return sharedDir
        } else {
            print("⚠️  Using Documents directory fallback - photos will be lost on reinstall")
            return documentsDirectory
        }
    }

    /// Migrate photos from old Documents location to shared container
    /// Call this once on first launch after implementing shared container
    static func migrateExistingPhotos(completion: @escaping (Int, [Error]) -> Void) {
        guard let sharedDir = sharedPhotosDirectory else {
            print("❌ Cannot migrate - shared container not available")
            completion(0, [NSError(domain: "Migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Shared container not available"])])
            return
        }

        let documentsDir = documentsDirectory
        var migratedCount = 0
        var errors: [Error] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let photoFiles = files.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "png" }

            print("📦 Found \(photoFiles.count) photos to migrate from Documents")

            for oldURL in photoFiles {
                let filename = oldURL.lastPathComponent
                let newURL = sharedDir.appendingPathComponent(filename)

                // Skip if already exists in shared container
                if FileManager.default.fileExists(atPath: newURL.path) {
                    print("⏭️  Skipping \(filename) - already exists in shared container")
                    continue
                }

                do {
                    try FileManager.default.copyItem(at: oldURL, to: newURL)
                    migratedCount += 1
                    print("✅ Migrated: \(filename)")

                    // Optionally delete old file after successful copy
                    // Uncomment if you want to clean up old files
                    // try FileManager.default.removeItem(at: oldURL)
                } catch {
                    print("❌ Failed to migrate \(filename): \(error)")
                    errors.append(error)
                }
            }

            print("✅ Migration complete: \(migratedCount) photos migrated, \(errors.count) errors")
            completion(migratedCount, errors)

        } catch {
            print("❌ Failed to read Documents directory: \(error)")
            completion(0, [error])
        }
    }

    /// Check if migration is needed (has photos in Documents but not migrated yet)
    static func needsMigration() -> Bool {
        let documentsDir = documentsDirectory

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let photoFiles = files.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "png" }
            return !photoFiles.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Roof PDF Storage

    /// Get the shared container URL for roof measurement PDF storage
    /// This directory persists across app installations and updates
    static var sharedRoofPDFsDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Failed to access App Group container for PDFs: \(appGroupIdentifier)")
            return nil
        }

        let pdfDir = containerURL.appendingPathComponent("RoofPDFs", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: pdfDir.path) {
            do {
                try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created shared roof PDFs directory: \(pdfDir.path)")
            } catch {
                print("❌ Failed to create shared roof PDFs directory: \(error)")
                return nil
            }
        }

        return pdfDir
    }

    /// Get the best available storage directory for roof PDFs
    static var roofPDFStorageDirectory: URL {
        if let sharedDir = sharedRoofPDFsDirectory {
            return sharedDir
        } else {
            print("⚠️  Using Documents directory fallback for PDFs")
            return documentsDirectory.appendingPathComponent("RoofPDFs")
        }
    }

    /// Save a PDF to the shared roof PDFs directory
    /// - Parameters:
    ///   - data: The PDF file data
    ///   - filename: Optional filename (defaults to UUID-based name)
    /// - Returns: The URL where the PDF was saved, or nil on failure
    static func saveRoofPDF(data: Data, filename: String? = nil) -> URL? {
        let pdfDir = roofPDFStorageDirectory

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: pdfDir.path) {
            do {
                try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed to create PDF directory: \(error)")
                return nil
            }
        }

        let name = filename ?? "\(UUID().uuidString).pdf"
        let fileURL = pdfDir.appendingPathComponent(name)

        do {
            try data.write(to: fileURL)
            print("✅ Saved roof PDF: \(name)")
            return fileURL
        } catch {
            print("❌ Failed to save roof PDF: \(error)")
            return nil
        }
    }

    /// Copy a PDF from a URL to the shared roof PDFs directory
    /// - Parameter sourceURL: The source PDF URL (e.g., from share extension)
    /// - Returns: The URL where the PDF was copied, or nil on failure
    static func copyRoofPDF(from sourceURL: URL) -> URL? {
        let pdfDir = roofPDFStorageDirectory

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: pdfDir.path) {
            do {
                try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed to create PDF directory: \(error)")
                return nil
            }
        }

        // Generate unique filename preserving original extension
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        let uniqueName = "\(UUID().uuidString)_\(originalName).\(ext)"
        let destURL = pdfDir.appendingPathComponent(uniqueName)

        do {
            // Start accessing security-scoped resource if needed
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            print("✅ Copied roof PDF: \(uniqueName)")
            return destURL
        } catch {
            print("❌ Failed to copy roof PDF: \(error)")
            return nil
        }
    }

    /// List all PDF files in the roof PDFs directory
    /// - Returns: Array of PDF file URLs
    static func listRoofPDFs() -> [URL] {
        let pdfDir = roofPDFStorageDirectory

        guard FileManager.default.fileExists(atPath: pdfDir.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: pdfDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            return files.filter { $0.pathExtension.lowercased() == "pdf" }
        } catch {
            print("❌ Failed to list roof PDFs: \(error)")
            return []
        }
    }

    /// Get file info for a roof PDF
    /// - Parameter url: The PDF file URL
    /// - Returns: Tuple with file size in bytes and creation date, or nil on failure
    static func getRoofPDFInfo(url: URL) -> (size: Int64, created: Date)? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            let created = attributes[.creationDate] as? Date ?? Date()
            return (size, created)
        } catch {
            print("❌ Failed to get PDF info: \(error)")
            return nil
        }
    }

    /// Delete a roof PDF file
    /// - Parameter url: The PDF file URL to delete
    /// - Returns: True if deletion was successful
    @discardableResult
    static func deleteRoofPDF(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Deleted roof PDF: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to delete roof PDF: \(error)")
            return false
        }
    }

    /// Find orphaned roof PDFs (PDFs that don't have matching RoofMaterialOrder records)
    /// - Parameter validFilenames: Set of PDF filenames that are still referenced by orders
    /// - Returns: Array of orphaned PDF URLs
    static func findOrphanedRoofPDFs(validFilenames: Set<String>) -> [URL] {
        let allPDFs = listRoofPDFs()
        return allPDFs.filter { !validFilenames.contains($0.lastPathComponent) }
    }

    /// Delete all orphaned roof PDFs
    /// - Parameter validFilenames: Set of PDF filenames that are still referenced by orders
    /// - Returns: Number of files deleted
    @discardableResult
    static func cleanupOrphanedRoofPDFs(validFilenames: Set<String>) -> Int {
        let orphaned = findOrphanedRoofPDFs(validFilenames: validFilenames)
        var deletedCount = 0

        for pdfURL in orphaned {
            if deleteRoofPDF(at: pdfURL) {
                deletedCount += 1
            }
        }

        print("✅ Cleaned up \(deletedCount) orphaned roof PDFs")
        return deletedCount
    }

    /// Get total size of all roof PDFs in bytes
    static var totalRoofPDFSize: Int64 {
        let pdfs = listRoofPDFs()
        var total: Int64 = 0

        for pdf in pdfs {
            if let info = getRoofPDFInfo(url: pdf) {
                total += info.size
            }
        }

        return total
    }

    /// Format bytes as human-readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
