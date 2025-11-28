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
}
