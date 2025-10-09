//
//  PhotoDetailView.swift
//  DTS App
//
//  Photo detail with annotation support
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

// Wrapper to make UIImage identifiable for sheet presentation
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct PhotoDetailView: View {
    @Bindable var photo: PhotoRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnnotationEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var imageToShare: IdentifiableImage?
    @State private var isRenderingImage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Annotated photo display
                    if let image = UIImage(contentsOfFile: photo.fileURL) {
                        AnnotatedPhotoView(
                            image: image,
                            annotations: photo.annotations
                        )
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .padding()
                    }

                    // Quick actions
                    HStack(spacing: 12) {
                        Button(action: { showingAnnotationEditor = true }) {
                            Label("Annotate", systemImage: "pencil.tip.crop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: sharePhoto) {
                            if isRenderingImage {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRenderingImage)
                    }
                    .padding(.horizontal)

                    // Metadata section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            // Title
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Title")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter title...", text: $photo.title)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Divider()

                            // Date/Time
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.subheadline)

                            // Location
                            if let lat = photo.latitude, let lon = photo.longitude {
                                HStack {
                                    Image(systemName: "location")
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.6f, %.6f", lat, lon))
                                        .font(.caption)
                                }
                            }

                            // Category
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Category", selection: $photo.category) {
                                    Text("General").tag("General")
                                    Text("Before").tag("Before")
                                    Text("After").tag("After")
                                    Text("Damage").tag("Damage")
                                    Text("In Progress").tag("In Progress")
                                    Text("Detail").tag("Detail")
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    // Tags section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)

                            TagInputView(tags: $photo.tags)
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    // Notes section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)

                            TextEditor(text: $photo.notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    // Delete button
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Photo", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAnnotationEditor) {
                PhotoAnnotationEditor(photo: photo)
            }
            .sheet(item: $imageToShare) { identifiableImage in
                ShareSheet(activityItems: [identifiableImage.image])
            }
            .alert("Delete Photo?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deletePhoto()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func sharePhoto() {
        // If no annotations, share immediately without rendering
        if photo.annotations.isEmpty {
            if let image = UIImage(contentsOfFile: photo.fileURL) {
                imageToShare = IdentifiableImage(image: image)
            }
            return
        }

        // Show loading state
        isRenderingImage = true

        // Render on main thread (required for UIGraphicsImageRenderer)
        // but dispatch async to allow UI to update first
        DispatchQueue.main.async {
            guard let renderedImage = self.renderAnnotatedImage() else {
                self.isRenderingImage = false
                return
            }
            self.isRenderingImage = false
            self.imageToShare = IdentifiableImage(image: renderedImage)
        }
    }

    private func photoAsImage() -> Image {
        if let uiImage = UIImage(contentsOfFile: photo.fileURL) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }

    private func renderAnnotatedImage() -> UIImage? {
        guard let baseImage = UIImage(contentsOfFile: photo.fileURL) else { return nil }
        guard !photo.annotations.isEmpty else { return baseImage }

        // Optimize: render at a reasonable size (max 2048 width) for sharing
        // This makes rendering much faster while maintaining good quality
        let maxWidth: CGFloat = 2048
        let targetSize: CGSize
        if baseImage.size.width > maxWidth {
            let scale = maxWidth / baseImage.size.width
            targetSize = CGSize(width: maxWidth, height: baseImage.size.height * scale)
        } else {
            targetSize = baseImage.size
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: UIGraphicsImageRendererFormat.default())

        // Calculate scale for annotations
        let displayWidth: CGFloat = 400
        let annotationScale = targetSize.width / displayWidth
        let imageScale = targetSize.width / baseImage.size.width

        return renderer.image { context in
            // Draw the base image scaled to target size
            baseImage.draw(in: CGRect(origin: .zero, size: targetSize))

            // Draw each annotation with proper scaling
            for annotation in photo.annotations {
                // Scale annotation coordinates to match resized image
                let scaledAnnotation = scaleAnnotation(annotation, by: imageScale)
                drawAnnotationOnContext(scaledAnnotation, in: context.cgContext, scale: annotationScale)
            }
        }
    }

    private func scaleAnnotation(_ annotation: PhotoAnnotation, by scale: CGFloat) -> PhotoAnnotation {
        var scaled = annotation
        scaled.points = annotation.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        scaled.position = CGPoint(x: annotation.position.x * scale, y: annotation.position.y * scale)
        return scaled
    }

    private func drawAnnotationOnContext(_ annotation: PhotoAnnotation, in context: CGContext, scale: CGFloat) {
        context.saveGState()

        let color = UIColor(Color(hex: annotation.color) ?? .red)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)

        // Scale the stroke width proportionally to image size
        // annotation.size is in screen points, scale it to match image resolution
        let lineWidth = annotation.size * scale

        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.type {
        case .freehand:
            guard let firstPoint = annotation.points.first else { break }
            context.beginPath()
            context.move(to: firstPoint)
            for point in annotation.points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()

        case .arrow:
            guard annotation.points.count >= 2,
                  let start = annotation.points.first,
                  let end = annotation.points.last else { break }

            // Draw arrow line
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            // Draw arrowhead - scale proportionally to line width
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = 15 * scale  // Scale arrowhead size
            let arrowAngle: CGFloat = .pi / 6

            let point1 = CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            let point2 = CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )

            context.beginPath()
            context.move(to: end)
            context.addLine(to: point1)
            context.strokePath()

            context.beginPath()
            context.move(to: end)
            context.addLine(to: point2)
            context.strokePath()

        case .box:
            guard annotation.points.count >= 2,
                  let start = annotation.points.first,
                  let end = annotation.points.last else { break }

            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(rect)

        case .circle:
            guard annotation.points.count >= 2,
                  let start = annotation.points.first,
                  let end = annotation.points.last else { break }

            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.strokeEllipse(in: rect)
        }

        context.restoreGState()
    }

    private func deletePhoto() {
        // Delete file from disk
        try? FileManager.default.removeItem(atPath: photo.fileURL)

        // Delete from SwiftData (context will handle this)
        // The parent view should handle the actual deletion from context
    }
}

// MARK: - Annotated Photo View

struct AnnotatedPhotoView: View {
    let image: UIImage
    let annotations: [PhotoAnnotation]

    var body: some View {
        GeometryReader { geometry in
            let imageSize = calculateImageSize(for: image, in: geometry.size)
            let scale = imageSize.width / image.size.width
            let xOffset = (geometry.size.width - imageSize.width) / 2
            let yOffset = (geometry.size.height - imageSize.height) / 2

            ZStack {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Annotations overlay using Canvas for proper coordinate transformation
                Canvas { context, size in
                    for annotation in annotations {
                        drawAnnotation(annotation, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
    }

    private func calculateImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private func drawAnnotation(_ annotation: PhotoAnnotation, in context: inout GraphicsContext, scale: CGFloat, offset: CGPoint) {
        let scaledPoints = annotation.points.map { CGPoint(x: $0.x * scale + offset.x, y: $0.y * scale + offset.y) }
        let color = Color(hex: annotation.color) ?? .red
        let lineWidth = annotation.size

        var path = Path()

        switch annotation.type {
        case .freehand:
            if let first = scaledPoints.first {
                path.move(to: first)
                for point in scaledPoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
        case .arrow:
            if scaledPoints.count >= 2, let start = scaledPoints.first, let end = scaledPoints.last {
                // Arrow line
                path.move(to: start)
                path.addLine(to: end)

                // Arrow head
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 15
                let arrowAngle: CGFloat = .pi / 6

                let point1 = CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                )
                let point2 = CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                )

                path.move(to: end)
                path.addLine(to: point1)
                path.move(to: end)
                path.addLine(to: point2)
            }
        case .box:
            if scaledPoints.count >= 2, let start = scaledPoints.first, let end = scaledPoints.last {
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.addRect(rect)
            }
        case .circle:
            if scaledPoints.count >= 2, let start = scaledPoints.first, let end = scaledPoints.last {
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.addEllipse(in: rect)
            }
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}

// MARK: - Tag Input View

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTag = ""

    // Suggested tags
    let suggestedTags = ["Damage", "Before", "After", "Gutter", "Downspout", "Fascia", "Roof", "Detail"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag, onDelete: { removeTag(tag) })
                    }
                }
            }

            // Add new tag
            HStack {
                TextField("Add tag...", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTag.isEmpty)
            }

            // Suggested tags
            if tags.count < 5 {
                Text("Suggested:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(suggestedTags.filter { !tags.contains($0) }, id: \.self) { tag in
                        Button(action: { addSuggestedTag(tag) }) {
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func addSuggestedTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let totalHeight = rows.reduce(0) { result, row in
            result + row.height + spacing
        }
        return CGSize(
            width: proposal.width ?? 0,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(indices: [Int], height: CGFloat)] {
        var rows: [(indices: [Int], height: CGFloat)] = []
        var currentRow: [Int] = []
        var currentX: CGFloat = 0
        var currentHeight: CGFloat = 0

        let maxWidth = proposal.width ?? .infinity

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && !currentRow.isEmpty {
                rows.append((indices: currentRow, height: currentHeight))
                currentRow = [index]
                currentX = size.width + spacing
                currentHeight = size.height
            } else {
                currentRow.append(index)
                currentX += size.width + spacing
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentRow.isEmpty {
            rows.append((indices: currentRow, height: currentHeight))
        }

        return rows
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FF0000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    PhotoDetailView(photo: PhotoRecord(fileURL: ""))
        .modelContainer(for: [PhotoRecord.self])
}
