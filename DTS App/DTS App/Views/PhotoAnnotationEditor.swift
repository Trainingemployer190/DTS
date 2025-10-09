//
//  PhotoAnnotationEditor.swift
//  DTS App
//
//  Fixed annotation editor for job photos with adjustable text size
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct PhotoAnnotationEditor: View {
    @Bindable var photo: PhotoRecord
    @Environment(\.dismiss) private var dismiss

    @State private var currentAnnotation: PhotoAnnotation?
    @State private var selectedTool: AnnotationTool = .freehand
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: CGFloat = 3.0
    @State private var selectedAnnotationIndex: Int?
    @State private var originalAnnotationPoints: [CGPoint] = []
    @State private var originalAnnotationPosition: CGPoint = .zero
    @State private var pressStartTime: Date?
    @State private var pressStartLocation: CGPoint?
    @State private var hasMoved: Bool = false

    // MARK: - Helper Functions

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

    private func convertToImageCoordinates(_ point: CGPoint, in containerSize: CGSize, imageSize: CGSize, image: UIImage) -> CGPoint {
        let scale = image.size.width / imageSize.width
        let xOffset = (containerSize.width - imageSize.width) / 2
        let yOffset = (containerSize.height - imageSize.height) / 2

        let adjustedX = (point.x - xOffset) * scale
        let adjustedY = (point.y - yOffset) * scale

        return CGPoint(x: adjustedX, y: adjustedY)
    }

    private func drawAnnotation(_ annotation: PhotoAnnotation, in context: inout GraphicsContext, scale: CGFloat, offset: CGPoint, isSelected: Bool = false) {
        let scaledPoints = annotation.points.map { CGPoint(x: $0.x * scale + offset.x, y: $0.y * scale + offset.y) }
        let color = Color(hex: annotation.color) ?? .red
        let lineWidth = isSelected ? annotation.size * 1.5 : annotation.size

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

        // Draw selection outline if selected - make it very visible
        if isSelected {
            // Yellow glow effect
            context.stroke(path, with: .color(.yellow), lineWidth: lineWidth + 4)
            context.stroke(path, with: .color(.white), lineWidth: lineWidth + 2)
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    enum AnnotationTool {
        case freehand, arrow, box, circle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Canvas area - Full screen
                GeometryReader { geometry in
                    ZStack {
                        // Base image
                        if let image = UIImage(contentsOfFile: photo.fileURL) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)

                            // Annotations overlay with proper coordinate handling
                            Canvas { context, size in
                                let imageSize = calculateImageSize(for: image, in: size)
                                let scale = imageSize.width / image.size.width

                                // Calculate offset to center the image (letterboxing/pillarboxing)
                                let xOffset = (size.width - imageSize.width) / 2
                                let yOffset = (size.height - imageSize.height) / 2

                                // Draw saved annotations
                                for (index, annotation) in photo.annotations.enumerated() {
                                    drawAnnotation(annotation, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset), isSelected: index == selectedAnnotationIndex)
                                }

                                // Draw current annotation
                                if let current = currentAnnotation {
                                    drawAnnotation(current, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset))
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Initialize press tracking on first touch
                                        if pressStartTime == nil {
                                            pressStartTime = Date()
                                            pressStartLocation = value.location

                                            // Capture the size for the timer closure
                                            let containerSize = geometry.size

                                            // Set up a timer to check for long press after 0.5 seconds
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                // Check if we're still pressing at the same location
                                                if let startTime = self.pressStartTime,
                                                   let startLoc = self.pressStartLocation,
                                                   Date().timeIntervalSince(startTime) >= 0.5,
                                                   !self.hasMoved,
                                                   self.selectedAnnotationIndex == nil,
                                                   let image = UIImage(contentsOfFile: self.photo.fileURL) {
                                                    // Long press detected - select annotation
                                                    let imageSize = self.calculateImageSize(for: image, in: containerSize)
                                                    let imagePoint = self.convertToImageCoordinates(startLoc, in: containerSize, imageSize: imageSize, image: image)

                                                    if let index = self.findAnnotationAt(point: imagePoint) {
                                                        self.selectedAnnotationIndex = index
                                                        self.originalAnnotationPoints = self.photo.annotations[index].points
                                                        self.originalAnnotationPosition = self.photo.annotations[index].position

                                                        // Haptic feedback
                                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                                        generator.impactOccurred()
                                                    }
                                                }
                                            }
                                        }

                                        // Check if moved significantly
                                        if let startLoc = pressStartLocation {
                                            let distance = hypot(value.location.x - startLoc.x, value.location.y - startLoc.y)
                                            if distance >= 10 && !hasMoved {
                                                hasMoved = true
                                            }
                                        }

                                        // Handle dragging
                                        if hasMoved {
                                            if selectedAnnotationIndex != nil {
                                                // Move selected annotation
                                                handleAnnotationDrag(value, in: geometry.size)
                                            } else {
                                                // Draw new annotation
                                                handleDragChanged(value, in: geometry.size)
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        // Reset state
                                        if selectedAnnotationIndex != nil {
                                            selectedAnnotationIndex = nil
                                            originalAnnotationPoints = []
                                            originalAnnotationPosition = .zero
                                        } else if hasMoved {
                                            handleDragEnded(value, in: geometry.size)
                                        }
                                        pressStartTime = nil
                                        pressStartLocation = nil
                                        hasMoved = false
                                    }
                            )
                        }
                    }
                }

                // Vertical toolbar on the right side
                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Tool buttons
                        Button(action: { selectedTool = .freehand }) {
                            Image(systemName: "scribble")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == .freehand ? Color.blue : Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button(action: { selectedTool = .arrow }) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == .arrow ? Color.blue : Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button(action: { selectedTool = .box }) {
                            Image(systemName: "rectangle")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == .box ? Color.blue : Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button(action: { selectedTool = .circle }) {
                            Image(systemName: "circle")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == .circle ? Color.blue : Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 30, height: 1)
                            .padding(.vertical, 4)

                        // Color picker
                        ForEach([Color.red, .yellow, .green, .blue, .purple, .white, .black], id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(selectedColor == color ? Color.white : Color.white.opacity(0.2), lineWidth: selectedColor == color ? 2.5 : 1)
                                    )
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 30, height: 1)
                            .padding(.vertical, 4)

                        // Undo button
                        Button(action: undoLastAnnotation) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 18))
                                .foregroundColor(photo.annotations.isEmpty ? .white.opacity(0.4) : .white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .disabled(photo.annotations.isEmpty)

                        // Clear all button
                        Button(action: {
                            photo.annotations.removeAll()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(photo.annotations.isEmpty ? .white.opacity(0.4) : .red)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .disabled(photo.annotations.isEmpty)
                    }
                    .padding(.trailing, 12)
                }
                .allowsHitTesting(true)
            }
            .navigationTitle("Annotate Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        guard let image = UIImage(contentsOfFile: photo.fileURL) else { return }

        let imageSize = calculateImageSize(for: image, in: size)
        let point = convertToImageCoordinates(value.location, in: size, imageSize: imageSize, image: image)

        if currentAnnotation == nil {
            // Start new annotation
            currentAnnotation = PhotoAnnotation(
                type: selectedTool.toAnnotationType(),
                points: [point],
                text: nil,
                color: selectedColor.toHex(),
                position: point,
                size: strokeWidth
            )
        } else {
            // Update current annotation
            if selectedTool == .freehand {
                currentAnnotation?.points.append(point)
            } else {
                // For shapes, update the end point
                if let first = currentAnnotation?.points.first {
                    currentAnnotation?.points = [first, point]
                }
            }
        }
    }

    private func handleAnnotationDrag(_ value: DragGesture.Value, in containerSize: CGSize) {
        guard let index = selectedAnnotationIndex, let image = UIImage(contentsOfFile: photo.fileURL) else { return }

        let imageSize = calculateImageSize(for: image, in: containerSize)
        let currentPoint = convertToImageCoordinates(value.location, in: containerSize, imageSize: imageSize, image: image)
        let startPoint = convertToImageCoordinates(pressStartLocation ?? value.startLocation, in: containerSize, imageSize: imageSize, image: image)

        let delta = CGPoint(x: currentPoint.x - startPoint.x, y: currentPoint.y - startPoint.y)

        // Move all points by delta
        photo.annotations[index].points = originalAnnotationPoints.map { point in
            CGPoint(x: point.x + delta.x, y: point.y + delta.y)
        }
        // Move position from original
        photo.annotations[index].position = CGPoint(
            x: originalAnnotationPosition.x + delta.x,
            y: originalAnnotationPosition.y + delta.y
        )
    }

    private func findAnnotationAt(point: CGPoint) -> Int? {
        // Check annotations in reverse order (newest first, on top)
        for (index, annotation) in photo.annotations.enumerated().reversed() {
            if annotationContains(annotation, point: point) {
                return index
            }
        }
        return nil
    }

    private func annotationContains(_ annotation: PhotoAnnotation, point: CGPoint) -> Bool {
        let tolerance: CGFloat = 30.0

        switch annotation.type {
        case .freehand:
            // Check if point is near any part of the path
            for i in 0..<annotation.points.count {
                let p = annotation.points[i]
                if hypot(p.x - point.x, p.y - point.y) < tolerance {
                    return true
                }
                // Also check segments between points
                if i > 0 {
                    let prev = annotation.points[i - 1]
                    if distanceToLineSegment(point: point, start: prev, end: p) < tolerance {
                        return true
                    }
                }
            }
            return false

        case .arrow:
            guard annotation.points.count >= 2 else { return false }
            let start = annotation.points.first!
            let end = annotation.points.last!
            return distanceToLineSegment(point: point, start: start, end: end) < tolerance

        case .box:
            guard annotation.points.count >= 2 else { return false }
            let start = annotation.points.first!
            let end = annotation.points.last!

            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )

            // Check if near any edge (prioritize edges over inside)
            let distanceToLeft = abs(point.x - rect.minX)
            let distanceToRight = abs(point.x - rect.maxX)
            let distanceToTop = abs(point.y - rect.minY)
            let distanceToBottom = abs(point.y - rect.maxY)

            let isNearVerticalEdge = (distanceToLeft < tolerance || distanceToRight < tolerance) &&
                                    point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
            let isNearHorizontalEdge = (distanceToTop < tolerance || distanceToBottom < tolerance) &&
                                       point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance

            return isNearVerticalEdge || isNearHorizontalEdge || rect.contains(point)

        case .circle:
            guard annotation.points.count >= 2 else { return false }
            let start = annotation.points.first!
            let end = annotation.points.last!

            // Calculate ellipse center and radii
            let centerX = (start.x + end.x) / 2
            let centerY = (start.y + end.y) / 2
            let radiusX = abs(end.x - start.x) / 2
            let radiusY = abs(end.y - start.y) / 2

            // Distance from point to center in normalized ellipse space
            let dx = (point.x - centerX) / radiusX
            let dy = (point.y - centerY) / radiusY
            let distanceFromCenter = sqrt(dx * dx + dy * dy)

            // Check if near the edge of the ellipse (within tolerance)
            let normalizedTolerance = tolerance / max(radiusX, radiusY)
            return abs(distanceFromCenter - 1.0) < normalizedTolerance || distanceFromCenter < 1.0
        }
    }

    private func distanceToLineSegment(point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projectionX = start.x + t * dx
        let projectionY = start.y + t * dy

        return hypot(point.x - projectionX, point.y - projectionY)
    }

    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard let annotation = currentAnnotation else { return }

        // Finalize annotation
        photo.annotations.append(annotation)
        currentAnnotation = nil
    }

    private func undoLastAnnotation() {
        guard !photo.annotations.isEmpty else { return }
        photo.annotations.removeLast()
    }
}

// MARK: - Helper Extensions

extension PhotoAnnotationEditor.AnnotationTool {
    func toAnnotationType() -> PhotoAnnotation.AnnotationType {
        switch self {
        case .freehand: return .freehand
        case .arrow: return .arrow
        case .box: return .box
        case .circle: return .circle
        }
    }

    var iconName: String {
        switch self {
        case .freehand: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .box: return "rectangle"
        case .circle: return "circle"
        }
    }

    var displayName: String {
        switch self {
        case .freehand: return "Draw"
        case .arrow: return "Arrow"
        case .box: return "Box"
        case .circle: return "Circle"
        }
    }
}

extension PhotoAnnotationEditor.AnnotationTool: Hashable {}

#Preview {
    PhotoAnnotationEditor(photo: PhotoRecord(fileURL: ""))
        .modelContainer(for: [PhotoRecord.self])
}
