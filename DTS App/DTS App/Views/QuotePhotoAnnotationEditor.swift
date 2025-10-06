//
//  QuotePhotoAnnotationEditor.swift
//  DTS App
//
//  Simplified annotation editor for quote photos (in-memory)
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct QuotePhotoAnnotationEditor: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onSave: (UIImage) -> Void

    @State private var annotations: [PhotoAnnotation] = []
    @State private var currentDrawing: [CGPoint] = []
    @State private var selectedTool: PhotoAnnotation.AnnotationType = .freehand
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: CGFloat = 3.0
    @State private var textInput: String = ""
    @State private var showingTextInput = false
    @State private var showingTextEditor = false
    @State private var pendingTextPoint: CGPoint?
    @State private var selectedAnnotationIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var originalAnnotationPoints: [CGPoint] = []
    @State private var originalAnnotationPosition: CGPoint = .zero
    @State private var pressStartTime: Date?
    @State private var pressStartLocation: CGPoint?
    @State private var hasMoved: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Canvas area - Full screen
                GeometryReader { geometry in
                    ZStack {
                        // Base image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        // Annotations overlay
                        Canvas { context, size in
                            let imageSize = calculateImageSize(in: size)
                            let scale = imageSize.width / image.size.width

                            // Calculate offset to center the image (letterboxing/pillarboxing)
                            let xOffset = (size.width - imageSize.width) / 2
                            let yOffset = (size.height - imageSize.height) / 2

                            // Draw saved annotations
                            for (index, annotation) in annotations.enumerated() {
                                drawAnnotation(annotation, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset), isSelected: index == selectedAnnotationIndex)
                            }

                            // Draw current drawing
                            if !currentDrawing.isEmpty {
                                let scaledPoints = currentDrawing.map { CGPoint(x: $0.x * scale + xOffset, y: $0.y * scale + yOffset) }
                                var path = Path()

                                switch selectedTool {
                                case .freehand:
                                    if let first = scaledPoints.first {
                                        path.move(to: first)
                                        for point in scaledPoints.dropFirst() {
                                            path.addLine(to: point)
                                        }
                                    }
                                case .arrow:
                                    if scaledPoints.count >= 2, let start = scaledPoints.first, let end = scaledPoints.last {
                                        path.move(to: start)
                                        path.addLine(to: end)
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
                                case .text:
                                    break
                                }

                                context.stroke(path, with: .color(selectedColor), lineWidth: strokeWidth)
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
                                               self.selectedAnnotationIndex == nil {
                                                // Long press detected - select annotation
                                                let imagePoint = self.convertToImageCoordinates(startLoc, in: containerSize)

                                                print("🎯 Long press detected at screen: \(startLoc), image: \(imagePoint)")
                                                print("🎯 Looking for annotation among \(self.annotations.count) annotations")

                                                if let index = self.findAnnotationAt(point: imagePoint) {
                                                    print("✅ Found annotation at index \(index)")
                                                    self.selectedAnnotationIndex = index
                                                    self.originalAnnotationPoints = self.annotations[index].points
                                                    self.originalAnnotationPosition = self.annotations[index].position
                                                } else {
                                                    print("❌ No annotation found at that point")
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
                                        } else if selectedTool != .text {
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
                                    } else if selectedTool != .text && hasMoved {
                                        handleDragEnded(value, in: geometry.size)
                                    }
                                    pressStartTime = nil
                                    pressStartLocation = nil
                                    hasMoved = false
                                }
                        )
                        .onTapGesture { location in
                            if selectedTool == .text {
                                pendingTextPoint = convertToImageCoordinates(location, in: geometry.size)
                                showingTextEditor = true
                            }
                        }
                    }
                }

                // Vertical toolbar on the right side
                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Tool buttons
                        ForEach([PhotoAnnotation.AnnotationType.freehand, .arrow, .box, .circle, .text], id: \.self) { tool in
                            Button(action: { selectedTool = tool }) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(selectedTool == tool ? Color.blue : Color.black.opacity(0.7))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
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
                        Button(action: {
                            if !annotations.isEmpty {
                                annotations.removeLast()
                            }
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 18))
                                .foregroundColor(annotations.isEmpty ? .white.opacity(0.4) : .white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .disabled(annotations.isEmpty)

                        // Clear all button
                        Button(action: {
                            annotations.removeAll()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(annotations.isEmpty ? .white.opacity(0.4) : .red)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .disabled(annotations.isEmpty)
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
                    Button("Save") {
                        saveAnnotatedImage()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingTextEditor) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("Add Text Annotation")
                            .font(.headline)
                            .padding(.top)

                        TextEditor(text: $textInput)
                            .frame(height: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)

                        Text("Tap on the image to place the text")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .navigationTitle("Text Annotation")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                textInput = ""
                                pendingTextPoint = nil
                                showingTextEditor = false
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                if let point = pendingTextPoint, !textInput.isEmpty {
                                    let annotation = PhotoAnnotation(
                                        type: .text,
                                        points: [point],
                                        text: textInput,
                                        color: selectedColor.toHex(),
                                        position: point,
                                        size: strokeWidth * 8 // Make text larger
                                    )
                                    annotations.append(annotation)
                                    textInput = ""
                                    pendingTextPoint = nil
                                    showingTextEditor = false
                                }
                            }
                            .fontWeight(.semibold)
                            .disabled(textInput.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private func convertToImageCoordinates(_ point: CGPoint, in containerSize: CGSize) -> CGPoint {
        let imageSize = calculateImageSize(in: containerSize)
        let scale = image.size.width / imageSize.width

        // Adjust for centering
        let xOffset = (containerSize.width - imageSize.width) / 2
        let yOffset = (containerSize.height - imageSize.height) / 2

        let adjustedX = point.x - xOffset
        let adjustedY = point.y - yOffset

        print("📐 Container: \(containerSize), Image: \(imageSize), Original image: \(image.size)")
        print("📐 Offsets: x=\(xOffset), y=\(yOffset), Scale: \(scale)")
        print("📐 Point: \(point) -> Adjusted: (\(adjustedX), \(adjustedY)) -> Scaled: (\(adjustedX * scale), \(adjustedY * scale))")

        return CGPoint(x: adjustedX * scale, y: adjustedY * scale)
    }

    private func handleAnnotationDrag(_ value: DragGesture.Value, in containerSize: CGSize) {
        guard let index = selectedAnnotationIndex else { return }

        // Convert both start and current location to image coordinates
        let startImagePoint = convertToImageCoordinates(value.startLocation, in: containerSize)
        let currentImagePoint = convertToImageCoordinates(value.location, in: containerSize)

        // Calculate delta in image coordinates
        let delta = CGPoint(
            x: currentImagePoint.x - startImagePoint.x,
            y: currentImagePoint.y - startImagePoint.y
        )

        // Move all points from original positions
        annotations[index].points = originalAnnotationPoints.map { point in
            CGPoint(x: point.x + delta.x, y: point.y + delta.y)
        }
        // Move position from original
        annotations[index].position = CGPoint(
            x: originalAnnotationPosition.x + delta.x,
            y: originalAnnotationPosition.y + delta.y
        )
    }

    private func findAnnotationAt(point: CGPoint) -> Int? {
        print("🔍 Finding annotation at image point: \(point)")
        // Check annotations in reverse order (newest first, on top)
        for (index, annotation) in annotations.enumerated().reversed() {
            let contains = annotationContains(annotation, point: point)

            // Show actual bounds for debugging
            var boundsInfo = ""
            if annotation.type == .box && annotation.points.count >= 2 {
                let start = annotation.points[0]
                let end = annotation.points[1]
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                boundsInfo = " bounds=[\(rect.minX),\(rect.minY) to \(rect.maxX),\(rect.maxY)]"
            }

            print("🔍 Annotation \(index) (\(annotation.type)): position=\(annotation.position), points=\(annotation.points)\(boundsInfo), contains=\(contains)")
            if contains {
                return index
            }
        }
        return nil
    }

    private func annotationContains(_ annotation: PhotoAnnotation, point: CGPoint) -> Bool {
        let tolerance: CGFloat = 30.0 // Reduced tolerance for more precise selection

        switch annotation.type {
        case .text:
            // Check if point is near text position - use larger area for text
            let textSize = annotation.size * 8 // Match the text size calculation
            let textRect = CGRect(
                x: annotation.position.x - tolerance,
                y: annotation.position.y - tolerance,
                width: textSize * CGFloat((annotation.text ?? "").count) / 2 + tolerance * 2,
                height: textSize + tolerance * 2
            )
            return textRect.contains(point)

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

    private func handleDragChanged(_ value: DragGesture.Value, in containerSize: CGSize) {
        let imagePoint = convertToImageCoordinates(value.location, in: containerSize)

        switch selectedTool {
        case .freehand:
            currentDrawing.append(imagePoint)
        case .arrow, .box, .circle:
            if currentDrawing.isEmpty {
                currentDrawing.append(imagePoint)
            } else {
                currentDrawing = [currentDrawing[0], imagePoint]
            }
        case .text:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, in containerSize: CGSize) {
        guard !currentDrawing.isEmpty else { return }

        let position = currentDrawing.first ?? .zero
        let annotation = PhotoAnnotation(
            type: selectedTool,
            points: currentDrawing,
            text: nil,
            color: selectedColor.toHex(),
            position: position,
            size: strokeWidth
        )

        annotations.append(annotation)
        currentDrawing.removeAll()
    }

    private func drawAnnotation(_ annotation: PhotoAnnotation, in context: inout GraphicsContext, scale: CGFloat, offset: CGPoint, isSelected: Bool = false) {
        let scaledPoints = annotation.points.map { CGPoint(x: $0.x * scale + offset.x, y: $0.y * scale + offset.y) }
        let color = Color(hex: annotation.color) ?? .red
        let lineWidth = isSelected ? annotation.size * 1.5 : annotation.size // Make selected annotations thicker

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
                path.move(to: start)
                path.addLine(to: end)

                // Add arrowhead
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 15
                let arrowAngle: CGFloat = .pi / 6

                let arrowPoint1 = CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                )
                let arrowPoint2 = CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                )

                path.move(to: end)
                path.addLine(to: arrowPoint1)
                path.move(to: end)
                path.addLine(to: arrowPoint2)
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
        case .text:
            if let point = scaledPoints.first, let text = annotation.text {
                // Draw selection background if selected
                if isSelected {
                    let textSize = CGSize(width: CGFloat(text.count) * 15, height: 30)
                    let backgroundRect = CGRect(
                        x: point.x - 5,
                        y: point.y - textSize.height / 2 - 5,
                        width: textSize.width + 10,
                        height: textSize.height + 10
                    )
                    context.fill(Path(roundedRect: backgroundRect, cornerRadius: 5), with: .color(.yellow.opacity(0.3)))
                }

                context.draw(
                    Text(text)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(color),
                    at: point
                )
            }
            return
        }

        // Draw selection outline if selected - make it very visible
        if isSelected {
            // Yellow glow effect
            context.stroke(path, with: .color(.yellow), lineWidth: lineWidth + 4)
            context.stroke(path, with: .color(.white), lineWidth: lineWidth + 2)
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func saveAnnotatedImage() {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let annotatedImage = renderer.image { context in
            // Draw base image
            image.draw(at: .zero)

            // Draw annotations
            for annotation in annotations {
                drawAnnotationOnUIImage(annotation, in: context.cgContext)
            }
        }

        onSave(annotatedImage)
    }

    private func drawAnnotationOnUIImage(_ annotation: PhotoAnnotation, in context: CGContext) {
        let color = UIColor(Color(hex: annotation.color) ?? .red)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(annotation.size)
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

                // Arrowhead
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 20
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
            if let point = points.first, let text = annotation.text {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 32),
                    .foregroundColor: color
                ]
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                attributedString.draw(at: point)
            }
        }
    }
}

extension PhotoAnnotation.AnnotationType {
    var iconName: String {
        switch self {
        case .freehand: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .box: return "rectangle"
        case .circle: return "circle"
        case .text: return "textformat"
        }
    }

    var displayName: String {
        switch self {
        case .freehand: return "Draw"
        case .arrow: return "Arrow"
        case .box: return "Box"
        case .circle: return "Circle"
        case .text: return "Text"
        }
    }
}

#endif
