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
    @State private var showingDeleteConfirmation = false

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedPhotos = Set<UUID>()
    @State private var showingActionSheet = false

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
                                PhotoThumbnailCard(
                                    photo: photo,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedPhotos.contains(photo.localId)
                                )
                                .onTapGesture {
                                    if isSelectionMode {
                                        toggleSelection(for: photo)
                                    } else {
                                        selectedPhoto = photo
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Photo Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            exitSelectionMode()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        Button(selectedPhotos.isEmpty ? "Select All" : "Deselect All") {
                            if selectedPhotos.isEmpty {
                                selectAllPhotos()
                            } else {
                                selectedPhotos.removeAll()
                            }
                        }
                    } else {
                        HStack(spacing: 16) {
                            if !allPhotos.isEmpty {
                                Button(action: { isSelectionMode = true }) {
                                    Image(systemName: "checkmark.circle")
                                }
                            }

                            Button(action: { showingPhotoMenu = true }) {
                                Image(systemName: "camera.fill")
                            }
                        }
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
            .alert("Clear All Photos?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    deleteAllPhotos()
                }
            } message: {
                Text("This will permanently delete all \(allPhotos.count) photos and cannot be undone.")
            }
            .confirmationDialog("Delete Selected Photos?", isPresented: $showingActionSheet) {
                Button("Share", action: shareSelectedPhotos)
                Button("Delete \(selectedPhotos.count) Photo\(selectedPhotos.count == 1 ? "" : "s")", role: .destructive, action: deleteSelectedPhotos)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s") selected")
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode && !selectedPhotos.isEmpty {
                    selectionActionBar
                }
            }
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        HStack(spacing: 20) {
            Button(action: shareSelectedPhotos) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24))
                    Text("Share")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            Spacer()

            Text("\(selectedPhotos.count) Selected")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { showingActionSheet = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                    Text("Delete")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }

    // MARK: - Selection Mode Functions

    private func toggleSelection(for photo: PhotoRecord) {
        if selectedPhotos.contains(photo.localId) {
            selectedPhotos.remove(photo.localId)
        } else {
            selectedPhotos.insert(photo.localId)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotos.removeAll()
    }

    private func selectAllPhotos() {
        selectedPhotos = Set(filteredPhotos.map { $0.localId })
    }

    private func shareSelectedPhotos() {
        #if canImport(UIKit)
        let photosToShare = filteredPhotos.filter { selectedPhotos.contains($0.localId) }

        // Render annotations onto images before sharing
        let images = photosToShare.compactMap { photo -> UIImage? in
            guard let baseImage = UIImage(contentsOfFile: photo.fileURL) else { return nil }

            // If photo has annotations, render them onto the image
            if !photo.annotations.isEmpty {
                return renderAnnotationsOnImage(baseImage, annotations: photo.annotations)
            }

            // Return original image if no annotations
            return baseImage
        }

        guard !images.isEmpty else { return }

        let activityVC = UIActivityViewController(activityItems: images, applicationActivities: nil)

        // Present from the key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {

            // For iPad - set popover presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            rootViewController.present(activityVC, animated: true)
        }
        #endif
    }

    private func deleteSelectedPhotos() {
        let photosToDelete = filteredPhotos.filter { selectedPhotos.contains($0.localId) }

        print("🗑️ Deleting \(photosToDelete.count) selected photos...")

        // Delete photo files from disk
        for photo in photosToDelete {
            let fileURL = URL(fileURLWithPath: photo.fileURL)
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted file: \(photo.fileURL)")
            } catch {
                print("❌ Failed to delete file \(photo.fileURL): \(error)")
            }

            // Delete from database
            modelContext.delete(photo)
        }

        // Save changes
        do {
            try modelContext.save()
            print("✅ Successfully deleted \(photosToDelete.count) photos")
        } catch {
            print("❌ Failed to save context after deletion: \(error)")
        }

        // Exit selection mode
        exitSelectionMode()
    }

    // MARK: - Annotation Rendering

    private func renderAnnotationsOnImage(_ baseImage: UIImage, annotations: [PhotoAnnotation]) -> UIImage {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        return renderer.image { context in
            // Draw base image
            baseImage.draw(at: .zero)

            // Draw each annotation
            for annotation in annotations {
                drawAnnotationOnImage(annotation, in: context.cgContext, imageSize: baseImage.size)
            }
        }
        #else
        return baseImage
        #endif
    }

    private func drawAnnotationOnImage(_ annotation: PhotoAnnotation, in context: CGContext, imageSize: CGSize) {
        #if canImport(UIKit)
        let color = UIColor(Color(hex: annotation.color) ?? .red)
        context.setStrokeColor(color.cgColor)

        // Scale line width proportionally to image size
        let displayWidth: CGFloat = 400
        let scaleFactor = imageSize.width / displayWidth
        let scaledLineWidth = annotation.size * scaleFactor

        context.setLineWidth(scaledLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let points = annotation.points

        switch annotation.type {
        case .freehand:
            if let first = points.first {
                context.beginPath()
                context.move(to: first)
                for point in points.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
        case .arrow:
            if points.count >= 2, let start = points.first, let end = points.last {
                context.beginPath()
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()

                // Arrowhead - scale arrowLength
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 20 * scaleFactor
                let arrowAngle: CGFloat = .pi / 6

                context.beginPath()
                context.move(to: end)
                context.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                ))
                context.move(to: end)
                context.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                ))
                context.strokePath()
            }
        case .box:
            if points.count >= 2, let start = points.first, let end = points.last {
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                context.stroke(rect)
            }
        case .circle:
            if points.count >= 2, let start = points.first, let end = points.last {
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                context.strokeEllipse(in: rect)
            }
        }
        #endif
    }

    private func deleteAllPhotos() {
        print("🗑️ Deleting all \(allPhotos.count) photos...")

        // Delete all photo files from disk
        for photo in allPhotos {
            let fileURL = URL(fileURLWithPath: photo.fileURL)
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted file: \(photo.fileURL)")
            } catch {
                print("❌ Failed to delete file \(photo.fileURL): \(error)")
            }
        }

        // Delete all PhotoRecord entries from database
        for photo in allPhotos {
            modelContext.delete(photo)
        }

        // Save changes
        do {
            try modelContext.save()
            print("✅ Successfully deleted all photos from database")
        } catch {
            print("❌ Failed to save context after deletion: \(error)")
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
    var isSelectionMode: Bool = false
    var isSelected: Bool = false

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

            // Annotation indicator (only show if not in selection mode)
            if !isSelectionMode && !photo.annotations.isEmpty {
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

            // Selection overlay
            if isSelectionMode {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? .blue : .white)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.white : Color.clear)
                                    .frame(width: 20, height: 20)
                            )
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .opacity(isSelectionMode && !isSelected ? 0.6 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

#Preview {
    PhotoLibraryView()
        .modelContainer(for: [PhotoRecord.self, AppSettings.self])
}
