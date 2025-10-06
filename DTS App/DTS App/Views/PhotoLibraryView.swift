//
//  PhotoLibraryView.swift
//  DTS App
//
//  Standalone photo capture and management
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct PhotoLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoRecord.createdAt, order: .reverse) private var allPhotos: [PhotoRecord]
    @StateObject private var photoCaptureManager = PhotoCaptureManager()

    @State private var showingPhotoMenu = false
    @State private var selectedPhoto: PhotoRecord?
    @State private var searchText = ""
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var captureCount = 0

    var filteredPhotos: [PhotoRecord] {
        if searchText.isEmpty {
            return allPhotos
        }
        return allPhotos.filter { photo in
            photo.title.localizedCaseInsensitiveContains(searchText) ||
            photo.notes.localizedCaseInsensitiveContains(searchText) ||
            photo.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search photos...", text: $searchText)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                if filteredPhotos.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Photos Yet")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("Capture photos with annotations for your jobs")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { showingPhotoMenu = true }) {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 200)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Photo grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100), spacing: 8)
                        ], spacing: 8) {
                            ForEach(filteredPhotos, id: \.localId) { photo in
                                PhotoThumbnailCard(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Photo Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingPhotoMenu = true }) {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoMenu) {
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose from Library") {
                    showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    handleCapturedImage(image)
                }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    onImagePicked: { image in
                        handlePhotoLibraryImage(image)
                    }
                )
            }
            .sheet(item: $selectedPhoto) { (photo: PhotoRecord) in
                PhotoDetailView(photo: photo)
            }
        }
    }

    private func handleCapturedImage(_ image: UIImage) {
        // Add watermark with location if available
        let watermarkedImage = addWatermarkToImage(image)

        // Save to documents
        if let savedURL = saveImageToDocuments(watermarkedImage) {
            let photoRecord = PhotoRecord(fileURL: savedURL)
            photoRecord.latitude = photoCaptureManager.currentLocation?.coordinate.latitude
            photoRecord.longitude = photoCaptureManager.currentLocation?.coordinate.longitude

            modelContext.insert(photoRecord)
            try? modelContext.save()
        }
    }

    private func saveNewPhotos() {
        // Legacy function - no longer used with new camera API
    }

    private func handlePhotoLibraryImage(_ image: UIImage) {
        // Add watermark if location available
        let watermarkedImage = addWatermarkToImage(image)

        // Save to documents
        if let savedURL = saveImageToDocuments(watermarkedImage) {
            let photoRecord = PhotoRecord(fileURL: savedURL)
            photoRecord.latitude = photoCaptureManager.currentLocation?.coordinate.latitude
            photoRecord.longitude = photoCaptureManager.currentLocation?.coordinate.longitude

            modelContext.insert(photoRecord)
            try? modelContext.save()
        }
    }

    private func addWatermarkToImage(_ image: UIImage) -> UIImage {
        // Simple watermark with timestamp and location
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            // Draw original image
            image.draw(in: CGRect(origin: .zero, size: image.size))

            // Prepare watermark text
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
            let timestamp = dateFormatter.string(from: Date())

            let locationText: String
            if let location = photoCaptureManager.currentAddress {
                locationText = location
            } else if let lat = photoCaptureManager.currentLocation?.coordinate.latitude,
                      let lon = photoCaptureManager.currentLocation?.coordinate.longitude {
                locationText = String(format: "%.6f, %.6f", lat, lon)
            } else {
                locationText = "Location unavailable"
            }

            let watermarkText = "\(timestamp)\n\(locationText)"

            // Configure text attributes
            let fontSize = image.size.width * 0.03
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle,
                .strokeColor: UIColor.black,
                .strokeWidth: -3.0
            ]

            // Draw watermark in bottom-left corner
            let textPadding: CGFloat = 20
            let textRect = CGRect(
                x: textPadding,
                y: image.size.height - (fontSize * 3) - textPadding,
                width: image.size.width - (textPadding * 2),
                height: fontSize * 3
            )

            watermarkText.draw(in: textRect, withAttributes: attributes)
        }
    }

    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }

        let filename = "\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
}

// MARK: - Photo Thumbnail Card

struct PhotoThumbnailCard: View {
    let photo: PhotoRecord

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Photo thumbnail
            if let image = UIImage(contentsOfFile: photo.fileURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }

            // Title overlay if exists
            if !photo.title.isEmpty {
                Text(photo.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(4)
            }

            // Annotation indicator
            if !photo.annotations.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    PhotoLibraryView()
        .modelContainer(for: [PhotoRecord.self, AppSettings.self])
}
