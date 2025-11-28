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
    @State private var isProcessingPhotos = false

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedPhotos = Set<UUID>()
    @State private var showingActionSheet = false

    // Grouping mode
    @State private var isGroupedByAddress = true
    
    // Watermark editing
    @State private var editingWatermarkPhoto: PhotoRecord?
    @State private var showingWatermarkEditor = false
    
    // Album management
    @State private var movingPhoto: PhotoRecord?
    @State private var showingAlbumPicker = false
    @State private var showingAddPhotosToAlbum = false
    @State private var selectedAlbumAddress: String?
    @State private var renamingAlbum: String?
    @State private var showingAlbumRename = false

    var filteredPhotos: [PhotoRecord] {
        if searchText.isEmpty {
            return allPhotos
        }
        return allPhotos.filter { photo in
            photo.title.localizedCaseInsensitiveContains(searchText) ||
            photo.notes.localizedCaseInsensitiveContains(searchText) ||
            photo.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (photo.address?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var groupedPhotos: [String: [PhotoRecord]] {
        let grouped = Dictionary(grouping: filteredPhotos) { photo in
            photo.address ?? "No Address"
        }
        print("📊 Grouped photos by address: \(grouped.keys.sorted())")
        return grouped
    }

    @ViewBuilder
    var photoGridView: some View {
        ScrollView {
            if isGroupedByAddress {
                // Grouped view by address
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedPhotos.keys.sorted(), id: \.self) { address in
                        if let photos = groupedPhotos[address] {
                            GroupedAddressSection(
                                address: address,
                                photos: photos,
                                isSelectionMode: isSelectionMode,
                                selectedPhotos: $selectedPhotos,
                                selectedPhoto: $selectedPhoto,
                                onEditWatermark: editWatermark,
                                onMoveToAlbum: { photo in
                                    movingPhoto = photo
                                    showingAlbumPicker = true
                                },
                                onDelete: deletePhoto,
                                onAddPhotos: {
                                    selectedAlbumAddress = address
                                    showingPhotoMenu = true
                                },
                                onRenameAlbum: {
                                    renamingAlbum = address
                                    showingAlbumRename = true
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            } else {
                // Ungrouped view
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
                        .contextMenu {
                            Button {
                                editWatermark(for: photo)
                            } label: {
                                Label("Edit Watermark", systemImage: "text.bubble")
                            }
                            
                            Button {
                                movingPhoto = photo
                                showingAlbumPicker = true
                            } label: {
                                Label("Move to Album", systemImage: "folder")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                deletePhoto(photo)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
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
                    // Photo grid - grouped or ungrouped
                    photoGridView
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
                                // Group toggle button
                                Button(action: { isGroupedByAddress.toggle() }) {
                                    Image(systemName: isGroupedByAddress ? "square.grid.2x2" : "rectangle.3.group")
                                }

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
                MultiImagePicker { photosWithMetadata in
                    Task {
                        isProcessingPhotos = true

                        // Process photos with EXIF metadata and smart geocoding
                        await photoCaptureManager.processBatchImages(
                            photosWithMetadata,
                            quoteDraftId: nil,
                            jobId: nil,
                            jobAddress: nil
                        )

                        // Save PhotoRecord entries for each processed photo
                        await MainActor.run {
                            // Get the most recently captured photos
                            let recentPhotos = photoCaptureManager.capturedImages.suffix(photosWithMetadata.count)
                            
                            // Use selectedAlbumAddress if set for all photos in batch
                            let targetAddress = selectedAlbumAddress

                            for capturedPhoto in recentPhotos {
                                // Find the saved file URL from shared container
                                let storageDirectory = SharedContainerHelper.photosStorageDirectory
                                // The file was saved by processImage, we need to find it
                                // Since we don't have the exact filename, we'll re-save it
                                if let imageData = capturedPhoto.image.jpegData(compressionQuality: 0.7) {
                                    let fileName = "photo_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8)).jpg"
                                    let fileURL = storageDirectory.appendingPathComponent(fileName)

                                    do {
                                        try imageData.write(to: fileURL)

                                        let photoRecord = PhotoRecord(fileURL: fileURL.path)

                                        // Parse location from locationString if available
                                        if let locationString = capturedPhoto.location {
                                            let components = locationString.split(separator: ",")
                                            if components.count == 2,
                                               let lat = Double(components[0]),
                                               let lon = Double(components[1]) {
                                                photoRecord.latitude = lat
                                                photoRecord.longitude = lon
                                            }
                                        }

                                        // Use selectedAlbumAddress if set, otherwise use geocoded address
                                        let finalAddress = targetAddress ?? capturedPhoto.address
                                        photoRecord.address = finalAddress
                                        photoRecord.watermarkAddress = finalAddress
                                        photoRecord.originalTimestamp = capturedPhoto.timestamp

                                        print("📸 Saving photo with address: \(photoRecord.address ?? "nil")")

                                        modelContext.insert(photoRecord)
                                    } catch {
                                        print("❌ Error saving photo to library: \(error)")
                                    }
                                }
                            }

                            try? modelContext.save()
                            
                            // Clear selected album after use
                            selectedAlbumAddress = nil
                        }

                        isProcessingPhotos = false
                    }
                }
            }
            .sheet(item: $selectedPhoto) { (photo: PhotoRecord) in
                PhotoDetailView(photo: photo)
            }
            .sheet(isPresented: $showingWatermarkEditor) {
                if let photo = editingWatermarkPhoto {
                    let albumPhotos = photo.address.flatMap { addr in
                        groupedPhotos[addr]
                    }
                    EditWatermarkView(photo: photo, albumPhotos: albumPhotos)
                }
            }
            .sheet(isPresented: $showingAlbumPicker) {
                if let photo = movingPhoto {
                    AlbumPickerView(
                        photo: photo,
                        availableAlbums: Array(groupedPhotos.keys.sorted()),
                        onSelect: { newAddress in
                            movePhotoToAlbum(photo: photo, newAddress: newAddress)
                        }
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { showingAlbumRename && renamingAlbum != nil },
                set: { newValue in 
                    showingAlbumRename = newValue
                    if !newValue { renamingAlbum = nil }
                }
            )) {
                if let oldAddress = renamingAlbum {
                    AlbumRenameView(
                        currentAddress: oldAddress,
                        onRename: { newAddress in
                            renameAlbum(from: oldAddress, to: newAddress)
                        }
                    )
                }
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
            .overlay {
                if isProcessingPhotos {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Processing photos...")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Extracting location data and applying watermarks")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .opacity(0.95)
                        )
                    }
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
        case .text:
            // Draw text annotation
            if let text = annotation.text, !text.isEmpty {
                let textSize = (annotation.fontSize ?? annotation.size) * scaleFactor
                let font = UIFont.boldSystemFont(ofSize: textSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]

                let attributedString = NSAttributedString(string: text, attributes: attributes)
                attributedString.draw(at: annotation.position)
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
            
            // Use selectedAlbumAddress if set, otherwise use geocoded address
            let targetAddress = selectedAlbumAddress ?? photoCaptureManager.currentAddress
            photoRecord.address = targetAddress
            photoRecord.watermarkAddress = targetAddress
            photoRecord.originalTimestamp = Date()

            modelContext.insert(photoRecord)
            try? modelContext.save()
            
            // Clear selected album after use
            selectedAlbumAddress = nil
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
            
            // Use selectedAlbumAddress if set, otherwise use geocoded address
            let targetAddress = selectedAlbumAddress ?? photoCaptureManager.currentAddress
            photoRecord.address = targetAddress
            photoRecord.watermarkAddress = targetAddress
            photoRecord.originalTimestamp = Date()

            modelContext.insert(photoRecord)
            try? modelContext.save()
            
            // Clear selected album after use
            selectedAlbumAddress = nil
        }
    }

    private func handleMultiplePhotoLibraryImages(_ images: [UIImage]) {
        print("📸 Processing \(images.count) photos from library...")
        
        // Capture the target address before loop
        let targetAddress = selectedAlbumAddress ?? photoCaptureManager.currentAddress

        for (index, image) in images.enumerated() {
            // Add watermark if location available
            let watermarkedImage = addWatermarkToImage(image)

            // Save to documents
            if let savedURL = saveImageToDocuments(watermarkedImage) {
                let photoRecord = PhotoRecord(fileURL: savedURL)
                photoRecord.latitude = photoCaptureManager.currentLocation?.coordinate.latitude
                photoRecord.longitude = photoCaptureManager.currentLocation?.coordinate.longitude
                photoRecord.address = targetAddress
                photoRecord.watermarkAddress = targetAddress
                photoRecord.originalTimestamp = Date()

                modelContext.insert(photoRecord)

                print("✅ Added photo \(index + 1)/\(images.count)")
            } else {
                print("❌ Failed to save photo \(index + 1)/\(images.count)")
            }
        }

        // Save all changes at once
        do {
            try modelContext.save()
            print("✅ Successfully saved \(images.count) photos to library")
        } catch {
            print("❌ Failed to save photos: \(error)")
        }
        
        // Clear selected album after use
        selectedAlbumAddress = nil
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
        let storageDirectory = SharedContainerHelper.photosStorageDirectory
        let fileURL = storageDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
    
    // MARK: - Watermark and Album Management
    
    private func editWatermark(for photo: PhotoRecord) {
        editingWatermarkPhoto = photo
        showingWatermarkEditor = true
    }
    
    private func movePhotoToAlbum(photo: PhotoRecord, newAddress: String) {
        photo.address = newAddress
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to move photo to album: \(error)")
        }
    }
    
    private func renameAlbum(from oldAddress: String, to newAddress: String) {
        // Update address for all photos in the album
        if let photosInAlbum = groupedPhotos[oldAddress] {
            for photo in photosInAlbum {
                photo.address = newAddress
                // Also update watermark address if it matches the old album address
                if photo.watermarkAddress == oldAddress {
                    photo.watermarkAddress = newAddress
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to rename album: \(error)")
            }
        }
    }
    
    private func deletePhoto(_ photo: PhotoRecord) {
        // Delete file from disk
        let fileURL = URL(fileURLWithPath: photo.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        
        // Delete from SwiftData
        modelContext.delete(photo)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete photo: \(error)")
        }
    }
}

// MARK: - Grouped Address Section
struct GroupedAddressSection: View {
    let address: String
    let photos: [PhotoRecord]
    let isSelectionMode: Bool
    @Binding var selectedPhotos: Set<UUID>
    @Binding var selectedPhoto: PhotoRecord?
    var onEditWatermark: ((PhotoRecord) -> Void)? = nil
    var onMoveToAlbum: ((PhotoRecord) -> Void)? = nil
    var onDelete: ((PhotoRecord) -> Void)? = nil
    var onAddPhotos: (() -> Void)? = nil
    var onRenameAlbum: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Address header
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    Text(address)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let onRenameAlbum = onRenameAlbum {
                        Button(action: onRenameAlbum) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let onAddPhotos = onAddPhotos {
                        Button(action: onAddPhotos) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Photos grid for this address
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 8)
            ], spacing: 8) {
                ForEach(photos, id: \.localId) { photo in
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
                    .contextMenu {
                        Button {
                            onEditWatermark?(photo)
                        } label: {
                            Label("Edit Watermark", systemImage: "text.bubble")
                        }
                        
                        Button {
                            onMoveToAlbum?(photo)
                        } label: {
                            Label("Move to Album", systemImage: "folder")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            onDelete?(photo)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)
        }
    }

    private func toggleSelection(for photo: PhotoRecord) {
        if selectedPhotos.contains(photo.localId) {
            selectedPhotos.remove(photo.localId)
        } else {
            selectedPhotos.insert(photo.localId)
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
