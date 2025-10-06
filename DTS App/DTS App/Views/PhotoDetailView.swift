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

struct PhotoDetailView: View {
    @Bindable var photo: PhotoRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnnotationEditor = false
    @State private var showingDeleteConfirmation = false

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

                        ShareLink(item: photoAsImage(), preview: SharePreview("Photo", image: photoAsImage())) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
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

    private func photoAsImage() -> Image {
        if let uiImage = UIImage(contentsOfFile: photo.fileURL) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
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
            ZStack {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Annotations overlay
                ForEach(annotations, id: \.id) { annotation in
                    AnnotationShape(annotation: annotation, imageSize: geometry.size)
                }
            }
        }
        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
    }
}

// MARK: - Annotation Shape Renderer

struct AnnotationShape: View {
    let annotation: PhotoAnnotation
    let imageSize: CGSize

    var color: Color {
        Color(hex: annotation.color) ?? .red
    }

    var body: some View {
        switch annotation.type {
        case .freehand:
            Path { path in
                guard let firstPoint = annotation.points.first else { return }
                path.move(to: firstPoint)
                for point in annotation.points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(color, lineWidth: annotation.size)

        case .arrow:
            ArrowShape(start: annotation.points.first ?? .zero,
                      end: annotation.points.last ?? .zero)
                .stroke(color, lineWidth: annotation.size)

        case .box:
            if let start = annotation.points.first, let end = annotation.points.last {
                Rectangle()
                    .path(in: CGRect(origin: start, size: CGSize(width: end.x - start.x, height: end.y - start.y)))
                    .stroke(color, lineWidth: annotation.size)
            }

        case .circle:
            if let center = annotation.points.first {
                let radius = annotation.points.last.map { sqrt(pow($0.x - center.x, 2) + pow($0.y - center.y, 2)) } ?? 50
                Circle()
                    .path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    .stroke(color, lineWidth: annotation.size)
            }

        case .text:
            if let text = annotation.text {
                Text(text)
                    .font(.system(size: annotation.size))
                    .foregroundColor(color)
                    .position(annotation.position)
            }
        }
    }
}

// MARK: - Arrow Shape

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        // Add arrowhead
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

        return path
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
