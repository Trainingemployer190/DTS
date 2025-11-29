//
//  EditWatermarkView.swift
//  DTS App
//
//  View for editing photo watermarks with single/batch update options
//

import SwiftUI
import SwiftData

struct EditWatermarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Photo being edited (for single edit mode)
    let photo: PhotoRecord

    // Optional: All photos in same album (for batch edit mode)
    let albumPhotos: [PhotoRecord]?

    @State private var newAddress: String
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(photo: PhotoRecord, albumPhotos: [PhotoRecord]? = nil) {
        self.photo = photo
        self.albumPhotos = albumPhotos
        // Initialize with current watermark address or album address
        _newAddress = State(initialValue: photo.watermarkAddress ?? photo.address ?? "Address not available")
    }

    var body: some View {
        NavigationView {
            Form {
                // Current watermark section
                Section("Current Watermark") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address: \(photo.watermarkAddress ?? "Not set")")
                            .font(.subheadline)
                        if let timestamp = photo.originalTimestamp {
                            Text("Captured: \(timestamp, style: .date) at \(timestamp, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Edit address section
                Section("New Address") {
                    TextField("Street address", text: $newAddress)
                        .autocapitalization(.words)

                    Text("Enter the address to display on the watermark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Preview section
                Section("Preview") {
                    let imageURL = URL(fileURLWithPath: photo.fileURL)
                    if FileManager.default.fileExists(atPath: imageURL.path) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                            case .failure:
                                Text("Failed to load preview")
                                    .foregroundColor(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Text("Preview not available")
                            .foregroundColor(.secondary)
                    }

                    Text("The watermark will show: \(newAddress)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Action buttons
                Section {
                    Button {
                        Task {
                            await updateSinglePhoto()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "photo")
                            Text("Apply to This Photo")
                        }
                    }
                    .disabled(isProcessing || newAddress.isEmpty)

                    if let albumPhotos = albumPhotos, albumPhotos.count > 1 {
                        Button {
                            Task {
                                await updateAlbumPhotos()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "photo.stack")
                                Text("Apply to All \(albumPhotos.count) Photos in Album")
                            }
                        }
                        .disabled(isProcessing || newAddress.isEmpty)
                    }
                }

                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Updating watermarks...")
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .navigationTitle("Edit Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Update Functions

    @MainActor
    private func updateSinglePhoto() async {
        guard !newAddress.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(UIKit)
        // Regenerate watermark for single photo
        guard let newFileURL = WatermarkUtility.regenerateWatermark(
            photo: photo,
            newAddress: newAddress,
            preserveTimestamp: true
        ) else {
            errorMessage = "Failed to regenerate watermark"
            showError = true
            return
        }

        // Update the photo record
        photo.watermarkAddress = newAddress
        photo.fileURL = newFileURL.path

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showError = true
        }
        #else
        errorMessage = "Watermark editing requires iOS platform"
        showError = true
        #endif
    }

    @MainActor
    private func updateAlbumPhotos() async {
        guard !newAddress.isEmpty,
              let albumPhotos = albumPhotos else { return }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(UIKit)
        var successCount = 0
        var failureCount = 0

        for albumPhoto in albumPhotos {
            guard let newFileURL = WatermarkUtility.regenerateWatermark(
                photo: albumPhoto,
                newAddress: newAddress,
                preserveTimestamp: true
            ) else {
                print("Failed to regenerate watermark for photo \(albumPhoto.id)")
                failureCount += 1
                continue
            }

            albumPhoto.watermarkAddress = newAddress
            albumPhoto.fileURL = newFileURL.path
            // Update album address to match the new watermark address
            albumPhoto.address = newAddress
            successCount += 1
        }

        do {
            try modelContext.save()

            if failureCount > 0 {
                errorMessage = "Updated \(successCount) photos, \(failureCount) failed"
                showError = true
            } else {
                dismiss()
            }

        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showError = true
        }
        #else
        errorMessage = "Watermark editing requires iOS platform"
        showError = true
        #endif
    }
}

// MARK: - Preview

#if DEBUG && canImport(UIKit)
struct EditWatermarkView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PhotoRecord.self, configurations: config)

        let samplePhoto = PhotoRecord(
            fileURL: "sample.jpg",
            address: "123 Main St, City, State"
        )
        samplePhoto.watermarkAddress = "123 Main St, City, State"
        samplePhoto.originalTimestamp = Date()

        container.mainContext.insert(samplePhoto)

        return EditWatermarkView(photo: samplePhoto)
            .modelContainer(container)
    }
}
#endif
