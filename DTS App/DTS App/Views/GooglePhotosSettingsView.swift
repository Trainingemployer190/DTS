//
//  GooglePhotosSettingsView.swift
//  DTS App
//
//  Settings view for Google Photos integration
//

import SwiftUI
import SwiftData

struct GooglePhotosSettingsView: View {
    @ObservedObject var googleAPI = GooglePhotosAPI.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allPhotos: [PhotoRecord]

    @State private var isSyncingAlbums = false
    @State private var isUploadingAll = false
    @State private var syncResult: String?
    @State private var uploadResult: String?
    @State private var uploadProgress: Int = 0
    @State private var uploadTotal: Int = 0

    // Photos that need album sync (uploaded but no album assigned)
    var photosNeedingSync: [PhotoRecord] {
        allPhotos.filter {
            $0.uploadedToGooglePhotos &&
            $0.googlePhotosMediaItemId != nil &&
            $0.googlePhotosAlbumId == nil &&
            $0.address != nil
        }
    }

    // Photos that haven't been uploaded yet
    var photosNeedingUpload: [PhotoRecord] {
        allPhotos.filter {
            !$0.uploadedToGooglePhotos &&
            $0.address != nil &&
            !$0.address!.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: googleAPI.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(googleAPI.isAuthenticated ? .green : .red)
                        Text(googleAPI.isAuthenticated ? "Connected" : "Not Connected")
                            .font(.headline)
                    }

                    if googleAPI.isPreconfiguredMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Using shared company account")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if googleAPI.isAuthenticated {
                                Text("Authenticated automatically")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }

                        // Always show reconnect button in pre-configured mode
                        Button("Sign Out & Reconnect") {
                            googleAPI.signOut()
                            // Small delay then start new auth
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                googleAPI.startAuthentication()
                            }
                        }
                        .foregroundColor(.blue)
                    } else if googleAPI.isAuthenticated {
                        Button("Sign Out") {
                            googleAPI.signOut()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Sign In with Google") {
                            googleAPI.startAuthentication()
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if googleAPI.isPreconfiguredMode {
                        Text("This app is configured to use a shared Google Photos account for all team members. No sign-in required.")
                    }
                }

                // Re-authentication needed banner
                if googleAPI.needsReauth {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Album Permissions Required", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)

                            Text("To organize photos into albums, please reconnect your Google account with the new permissions.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Reconnect Google Photos") {
                                googleAPI.reauthenticate()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Section {
                    Toggle("Auto-Upload New Photos", isOn: Binding(
                        get: { googleAPI.autoUploadEnabled },
                        set: { googleAPI.setAutoUploadEnabled($0) }
                    ))
                    .disabled(!googleAPI.isAuthenticated)

                    if googleAPI.isUploading {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Uploading...")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ProgressView(value: googleAPI.uploadProgress)
                                .progressViewStyle(.linear)
                        }
                    }
                } header: {
                    Text("Auto-Upload")
                } footer: {
                    Text("When enabled, all photos captured in the app will automatically upload to your Google Photos library and be organized into albums by address.")
                }

                // Album sync section
                if googleAPI.isAuthenticated && !googleAPI.needsReauth {
                    // Upload All Photos section
                    Section {
                        Button {
                            uploadAllPhotos()
                        } label: {
                            HStack {
                                Label("Upload All Photos", systemImage: "icloud.and.arrow.up")
                                Spacer()
                                if isUploadingAll {
                                    if uploadTotal > 0 {
                                        Text("\(uploadProgress)/\(uploadTotal)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    ProgressView()
                                } else if !photosNeedingUpload.isEmpty {
                                    Text("\(photosNeedingUpload.count)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .disabled(isUploadingAll || photosNeedingUpload.isEmpty)

                        if let result = uploadResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } header: {
                        Text("Bulk Upload")
                    } footer: {
                        Text("Upload \(photosNeedingUpload.count) photos that haven't been uploaded to Google Photos yet. Photos will be organized into albums by address.")
                    }

                    // Sync to Albums section (for photos already uploaded but not in albums)
                    Section {
                        Button {
                            syncPhotosToAlbums()
                        } label: {
                            HStack {
                                Label("Sync Photos to Albums", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if isSyncingAlbums {
                                    ProgressView()
                                } else if !photosNeedingSync.isEmpty {
                                    Text("\(photosNeedingSync.count)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .disabled(isSyncingAlbums || photosNeedingSync.isEmpty)

                        if let result = syncResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } header: {
                        Text("Album Organization")
                    } footer: {
                        Text("Add \(photosNeedingSync.count) uploaded photos to their address-based albums.")
                    }
                }

                if let errorMessage = googleAPI.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    } header: {
                        Text("Error")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Google Photos Integration")
                            .font(.headline)

                        Text("This feature automatically backs up your photos to Google Photos when enabled. Photos are organized into albums by address.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Photos retain their GPS watermarks")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Albums created automatically by address")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Photos added to matching albums")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Your photos remain in the app even if upload fails")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Google Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func syncPhotosToAlbums() {
        isSyncingAlbums = true
        syncResult = nil

        print("🔄 Sync button pressed, preparing \(photosNeedingSync.count) photos")

        let photosToSync = photosNeedingSync.compactMap { photo -> (mediaItemId: String, address: String)? in
            guard let mediaItemId = photo.googlePhotosMediaItemId,
                  let address = photo.address else {
                return nil
            }
            return (mediaItemId: mediaItemId, address: address)
        }

        // Keep a reference to the photos for updating
        let photosSnapshot = photosNeedingSync

        Task {
            let syncResults = await GooglePhotosAPI.shared.syncPhotosToAlbums(photos: photosToSync)

            await MainActor.run {
                // Update PhotoRecords with album IDs
                var updatedCount = 0
                for photo in photosSnapshot {
                    if let mediaItemId = photo.googlePhotosMediaItemId,
                       let albumId = syncResults[mediaItemId] {
                        photo.googlePhotosAlbumId = albumId
                        updatedCount += 1
                        print("✅ Updated PhotoRecord with albumId: \(albumId)")
                    }
                }

                try? modelContext.save()
                isSyncingAlbums = false
                syncResult = "✅ Synced \(updatedCount) photos to albums"
                print("🔄 Sync complete: \(updatedCount) PhotoRecords updated")

                // Clear result after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    syncResult = nil
                }
            }
        }
    }

    private func uploadAllPhotos() {
        isUploadingAll = true
        uploadResult = nil
        uploadProgress = 0

        let photosToUpload = photosNeedingUpload
        uploadTotal = photosToUpload.count

        print("📤 Starting bulk upload of \(photosToUpload.count) photos")

        Task {
            var successCount = 0

            for (index, photo) in photosToUpload.enumerated() {
                await MainActor.run {
                    uploadProgress = index + 1
                }

                // Add delay between uploads to avoid rate limiting (429 errors)
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                }

                let fileURL = URL(fileURLWithPath: photo.fileURL)
                let address = photo.address ?? ""

                print("📤 Uploading photo \(index + 1)/\(photosToUpload.count): \(fileURL.lastPathComponent)")

                let result = await GooglePhotosAPI.shared.uploadPhotoToAlbum(
                    fileURL: fileURL,
                    address: address
                )

                if result.success {
                    await MainActor.run {
                        photo.uploadedToGooglePhotos = true
                        if let mediaItemId = result.mediaItemId {
                            photo.googlePhotosMediaItemId = mediaItemId
                        }
                        if let albumId = result.albumId {
                            photo.googlePhotosAlbumId = albumId
                        }
                        try? modelContext.save()
                    }
                    successCount += 1
                    print("✅ Uploaded \(index + 1)/\(photosToUpload.count)")
                } else {
                    print("❌ Failed to upload photo \(index + 1)")
                }
            }

            await MainActor.run {
                isUploadingAll = false
                uploadProgress = 0
                uploadTotal = 0
                uploadResult = "✅ Uploaded \(successCount) of \(photosToUpload.count) photos"
                print("📤 Bulk upload complete: \(successCount)/\(photosToUpload.count)")

                // Clear result after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    uploadResult = nil
                }
            }
        }
    }
}

#Preview {
    GooglePhotosSettingsView()
}
