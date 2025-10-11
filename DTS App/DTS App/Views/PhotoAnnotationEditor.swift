//
//  PhotoAnnotationEditor.swift
//  DTS App
//
//  Fixed annotation editor for job photos with adjustable text size
//

import SwiftUI
import SwiftData
import UIKit

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
    @State private var selectedTextAnnotationIndex: Int? = nil
    @State private var editingTextAnnotationIndex: Int? = nil
    @State private var textInput = ""
    @State private var tapCount: Int = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var baseWidth: CGFloat = 200.0
    @State private var baseFontSize: CGFloat = 20.0
    @State private var isDraggingHandle: Bool = false
    @State private var fontResizeDragLocation: CGPoint = .zero
    @State private var widthResizeDragLocation: CGPoint = .zero

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
        case .text:
            // Text is rendered separately below
            break
        }

        // Draw selection outline if selected - make it very visible
        if isSelected {
            // Yellow glow effect
            context.stroke(path, with: .color(.yellow), lineWidth: lineWidth + 4)
            context.stroke(path, with: .color(.white), lineWidth: lineWidth + 2)
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)

        // Render text annotations
        if annotation.type == .text, let text = annotation.text, !text.isEmpty {
            let textPosition = CGPoint(
                x: annotation.position.x * scale + offset.x,
                y: annotation.position.y * scale + offset.y
            )
            let textSize = annotation.fontSize ?? annotation.size

            // Get text box width (default to 200 if not set for backward compatibility)
            let textBoxWidth = annotation.textBoxWidth ?? 200.0

            // Manually wrap text based on width
            let wrappedText = wrapText(text, width: textBoxWidth, fontSize: textSize)

            // Draw text with selection highlight if selected
            if isSelected {
                // Yellow outline for selected text
                var yOffset: CGFloat = 0
                for line in wrappedText {
                    context.draw(
                        Text(line)
                            .font(.system(size: textSize, weight: .bold))
                            .foregroundColor(.yellow),
                        at: CGPoint(x: textPosition.x, y: textPosition.y + yOffset),
                        anchor: .topLeading
                    )
                    yOffset += textSize * 1.2
                }
            }

            var yOffset: CGFloat = 0
            for line in wrappedText {
                context.draw(
                    Text(line)
                        .font(.system(size: textSize, weight: .bold))
                        .foregroundColor(color),
                    at: CGPoint(x: textPosition.x, y: textPosition.y + yOffset),
                    anchor: .topLeading
                )
                yOffset += textSize * 1.2
            }
        }
    }

    enum AnnotationTool {
        case freehand, arrow, box, circle, text
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
                                        // Handle text tool - check if dragging selected text
                                        if selectedTool == .text {
                                            if pressStartTime == nil {
                                                pressStartTime = Date()
                                                pressStartLocation = value.location
                                                hasMoved = false
                                                return
                                            }

                                            // Check for movement
                                            if let startLoc = pressStartLocation {
                                                let distance = hypot(value.location.x - startLoc.x, value.location.y - startLoc.y)
                                                if distance >= 10 && !hasMoved {
                                                    hasMoved = true
                                                }
                                            }

                                            // If moving and text is selected, move it
                                            if hasMoved, let selectedIndex = selectedTextAnnotationIndex,
                                               let image = UIImage(contentsOfFile: photo.fileURL) {
                                                let imageSize = calculateImageSize(for: image, in: geometry.size)
                                                let newPosition = convertToImageCoordinates(value.location, in: geometry.size, imageSize: imageSize, image: image)
                                                photo.annotations[selectedIndex].position = newPosition
                                            }
                                            return
                                        }

                                        // Initialize press tracking on first touch for other tools
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
                                                print("🚶 MOVEMENT DETECTED - Distance: \(distance)px")
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
                                        print("🏁 GESTURE ENDED - Tool: \(selectedTool), Moved: \(hasMoved)")

                                        // Handle text tool tap (if didn't move)
                                        if selectedTool == .text && !hasMoved {
                                            print("✅ TEXT TAP DETECTED")
                                            guard let image = UIImage(contentsOfFile: photo.fileURL) else {
                                                print("❌ Failed to load image")
                                                pressStartTime = nil
                                                pressStartLocation = nil
                                                hasMoved = false
                                                return
                                            }
                                            let imageSize = calculateImageSize(for: image, in: geometry.size)
                                            print("📐 Screen tap: \(value.location), Container size: \(geometry.size), Image size: \(imageSize)")
                                            let imagePoint = convertToImageCoordinates(value.location, in: geometry.size, imageSize: imageSize, image: image)
                                            print("📍 Converted to image coordinates: \(imagePoint)")

                                            // Check if tapped on existing text annotation (in screen space for accurate hit detection)
                                            let tappedTextIndex = findTextAnnotationAtScreenPoint(screenPoint: value.location, containerSize: geometry.size, imageSize: imageSize, image: image)
                                            print("🔍 Found text at index: \(tappedTextIndex?.description ?? "none")")

                                            if let index = tappedTextIndex {
                                                // Tapped on existing text
                                                if selectedTextAnnotationIndex == index {
                                                    // Already selected - enter edit mode
                                                    print("✏️ ENTERING EDIT MODE for index \(index)")
                                                    editingTextAnnotationIndex = index
                                                    textInput = photo.annotations[index].text ?? "Text"
                                                    print("   - Text to edit: '\(textInput)'")
                                                } else {
                                                    // Select it
                                                    print("🎯 SELECTING text at index \(index)")
                                                    selectedTextAnnotationIndex = index
                                                    editingTextAnnotationIndex = nil

                                                    // Initialize base values for resizing
                                                    baseWidth = photo.annotations[index].textBoxWidth ?? 200.0
                                                    baseFontSize = photo.annotations[index].fontSize ?? 20.0
                                                    print("   📏 Base values initialized: width=\(baseWidth), fontSize=\(baseFontSize)")
                                                }
                                            } else {
                                                // Tapped outside any text
                                                if selectedTextAnnotationIndex != nil {
                                                    // Deselect
                                                    print("❌ DESELECTING text")
                                                    selectedTextAnnotationIndex = nil
                                                    editingTextAnnotationIndex = nil
                                                } else {
                                                    // Create new text annotation
                                                    print("✨ CREATING NEW TEXT annotation")
                                                    let newAnnotation = PhotoAnnotation(
                                                        id: UUID(),
                                                        type: .text,
                                                        points: [],
                                                        text: "Text",
                                                        color: selectedColor.toHex(),
                                                        position: imagePoint,
                                                        size: strokeWidth,
                                                        fontSize: 20.0,
                                                        textBoxWidth: 200.0
                                                    )
                                                    photo.annotations.append(newAnnotation)
                                                    selectedTextAnnotationIndex = photo.annotations.count - 1
                                                    editingTextAnnotationIndex = nil

                                                    // Initialize base values for new text
                                                    baseWidth = 200.0
                                                    baseFontSize = 20.0
                                                    print("   - New text at index: \(selectedTextAnnotationIndex?.description ?? "nil")")
                                                    print("   📏 Base values initialized: width=\(baseWidth), fontSize=\(baseFontSize)")
                                                }
                                            }

                                            pressStartTime = nil
                                            pressStartLocation = nil
                                            hasMoved = false
                                            return
                                        }

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

                        Button(action: { selectedTool = .text }) {
                            Image(systemName: "textformat")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == .text ? Color.blue : Color.black.opacity(0.7))
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
            // Text annotation overlay - selection handles or editor
            .overlay {
                let _ = print("🔍 OVERLAY EVALUATION - selectedIndex: \(selectedTextAnnotationIndex?.description ?? "nil"), editingIndex: \(editingTextAnnotationIndex?.description ?? "nil")")

                GeometryReader { geometry in
                    if let image = UIImage(contentsOfFile: photo.fileURL) {
                        let imageSize = calculateImageSize(for: image, in: geometry.size)
                        let scale = imageSize.width / image.size.width
                        let xOffset = (geometry.size.width - imageSize.width) / 2
                        let yOffset = (geometry.size.height - imageSize.height) / 2

                        // Show selection handles for selected text
                        if let selectedIndex = selectedTextAnnotationIndex,
                           selectedIndex < photo.annotations.count,
                           photo.annotations[selectedIndex].type == .text {
                            let _ = print("✅ RENDERING SELECTION HANDLES for index \(selectedIndex)")
                            let annotation = photo.annotations[selectedIndex]
                            let textSize = annotation.fontSize ?? 20.0
                            let text = annotation.text ?? "Text"
                            let textBoxWidth = annotation.textBoxWidth ?? 200.0

                            // Calculate text height based on content and wrapping
                            let lineHeight = textSize * 1.2
                            let charactersPerLine = Int(textBoxWidth / (textSize * 0.6))
                            let estimatedLines = max(1, (text.count + charactersPerLine - 1) / charactersPerLine)
                            let textBoxHeight = CGFloat(estimatedLines) * lineHeight

                            let screenX = annotation.position.x * scale + xOffset
                            let screenY = annotation.position.y * scale + yOffset

                            // Dotted border around text box
                            Rectangle()
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                .foregroundColor(.blue)
                                .frame(width: textBoxWidth, height: textBoxHeight)
                                .position(x: screenX + textBoxWidth/2, y: screenY + textBoxHeight/2)

                            // Delete button (top-left corner)
                            Button(action: {
                                photo.annotations.remove(at: selectedIndex)
                                selectedTextAnnotationIndex = nil
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.white))
                            }
                            .position(x: screenX - 12, y: screenY - 12)

                            // Right edge resize handle (middle-right for width adjustment)
                            let handleX = screenX + textBoxWidth
                            let handleY = screenY + textBoxHeight/2

                            Circle()
                                .fill(Color.green)
                                .frame(width: 20, height: 20)
                                .position(
                                    x: isDraggingHandle ? widthResizeDragLocation.x : handleX,
                                    y: isDraggingHandle ? widthResizeDragLocation.y : handleY
                                )
                                .id("width-handle-\(selectedIndex)-\(isDraggingHandle)")
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isDraggingHandle {
                                                isDraggingHandle = true
                                                widthResizeDragLocation = value.startLocation
                                                print("🟢 WIDTH RESIZE STARTED")
                                                print("   📍 Initial handle position: (\(String(format: "%.1f", handleX)), \(String(format: "%.1f", handleY)))")
                                                print("   👆 Initial touch (startLocation): (\(String(format: "%.1f", value.startLocation.x)), \(String(format: "%.1f", value.startLocation.y)))")
                                                print("   🎯 Initial baseWidth: \(String(format: "%.1f", baseWidth))")
                                                print("   📐 Initial stored width: \(String(format: "%.1f", photo.annotations[selectedIndex].textBoxWidth ?? 200.0))")
                                                print("   📏 Scale factor: \(String(format: "%.3f", scale))")
                                                print("   🖼️  ScreenX: \(String(format: "%.1f", screenX)), TextBoxWidth: \(String(format: "%.1f", textBoxWidth))")
                                            }

                                            // Update drag location to follow finger
                                            widthResizeDragLocation = value.location

                                            // Current touch position
                                            let touchX = value.location.x
                                            let touchY = value.location.y

                                            // Expected handle position with new width
                                            let currentWidth = photo.annotations[selectedIndex].textBoxWidth ?? 200.0
                                            let expectedHandleX = screenX + currentWidth

                                            // Distance between touch and where handle WOULD be without fix
                                            let offsetX = touchX - expectedHandleX
                                            let offsetY = touchY - handleY
                                            let lagDistance = sqrt(offsetX * offsetX + offsetY * offsetY)

                                            // Speed calculation
                                            let speed = abs(value.translation.width) > 0 ? abs(currentWidth - baseWidth) / abs(value.translation.width) : 0

                                            // Calculate new width based on drag (stay in screen space, don't convert to image space!)
                                            let dragDelta = value.translation.width  // Already in screen space
                                            let calculatedNewWidth = baseWidth + dragDelta
                                            let clampedNewWidth = max(50, min(500, calculatedNewWidth))

                                            print("🟢 WIDTH RESIZE")
                                            print("   👆 Finger at: (\(String(format: "%.1f", touchX)), \(String(format: "%.1f", touchY)))")
                                            print("   🎯 Drag handle visual at: (\(String(format: "%.1f", widthResizeDragLocation.x)), \(String(format: "%.1f", widthResizeDragLocation.y)))")
                                            print("   📍 Expected handle (old way): (\(String(format: "%.1f", expectedHandleX)), \(String(format: "%.1f", handleY)))")
                                            print("   📏 Lag prevented: \(String(format: "%.1f", lagDistance))px, Offset: (\(String(format: "%.1f", offsetX)), \(String(format: "%.1f", offsetY)))")
                                            print("   📊 Translation.width: \(String(format: "%.1f", value.translation.width))px (screen space)")
                                            print("   🔢 dragDelta (SCREEN space): \(String(format: "%.1f", dragDelta))px = translation (NO scale conversion!)")
                                            print("   📐 Width calculation: base(\(String(format: "%.1f", baseWidth))) + delta(\(String(format: "%.1f", dragDelta))) = \(String(format: "%.1f", calculatedNewWidth))")
                                            print("   ✂️  Clamped to: \(String(format: "%.1f", clampedNewWidth)) (min: 50, max: 500)")
                                            print("   💾 Setting annotation width to: \(String(format: "%.1f", clampedNewWidth))")
                                            print("   ⚡️ Speed factor: \(String(format: "%.3f", speed)) (width change / screen drag)")

                                            photo.annotations[selectedIndex].textBoxWidth = clampedNewWidth

                                            print("   ✅ Annotation width now: \(String(format: "%.1f", photo.annotations[selectedIndex].textBoxWidth ?? 0))")
                                        }
                                        .onEnded { value in
                                            isDraggingHandle = false
                                            print("🟢 WIDTH RESIZE ENDED")
                                            print("   📊 Final translation: \(String(format: "%.1f", value.translation.width))px")
                                            let finalWidth = photo.annotations[selectedIndex].textBoxWidth ?? 200.0
                                            print("   📐 Final width: \(String(format: "%.1f", finalWidth))")

                                            // Commit the final width as the new base (screen space, no scale conversion!)
                                            let dragDelta = value.translation.width  // Already in screen space
                                            baseWidth = max(50, min(500, baseWidth + dragDelta))
                                            photo.annotations[selectedIndex].textBoxWidth = baseWidth
                                            print("   ✅ New baseWidth committed: \(String(format: "%.1f", baseWidth))")
                                        }
                                )

                            // Bottom-right corner resize handle (for font size)
                            let fontHandleX = screenX + textBoxWidth + 10
                            let fontHandleY = screenY + textBoxHeight + 10

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                                .position(
                                    x: isDraggingHandle ? fontResizeDragLocation.x : fontHandleX,
                                    y: isDraggingHandle ? fontResizeDragLocation.y : fontHandleY
                                )
                                .id("font-handle-\(selectedIndex)-\(isDraggingHandle)")
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isDraggingHandle {
                                                isDraggingHandle = true
                                                fontResizeDragLocation = value.startLocation
                                                print("🔵 FONT RESIZE STARTED")
                                                print("   📍 Initial handle position: (\(String(format: "%.1f", fontHandleX)), \(String(format: "%.1f", fontHandleY)))")
                                                print("   👆 Initial touch (startLocation): (\(String(format: "%.1f", value.startLocation.x)), \(String(format: "%.1f", value.startLocation.y)))")
                                                print("   🎯 Initial baseFontSize: \(String(format: "%.1f", baseFontSize))")
                                                print("   📐 Initial stored fontSize: \(String(format: "%.1f", photo.annotations[selectedIndex].fontSize ?? 20.0))")
                                                print("   📏 Text: '\(text)', Width: \(String(format: "%.1f", textBoxWidth))")
                                            }

                                            // Update drag location to follow finger
                                            fontResizeDragLocation = value.location

                                            // Current touch position
                                            let touchX = value.location.x
                                            let touchY = value.location.y

                                            // Current font size
                                            let currentSize = photo.annotations[selectedIndex].fontSize ?? 20.0

                                            // Recalculate expected handle position with new font size (height changes)
                                            let wrappedLines = wrapText(text, width: textBoxWidth, fontSize: currentSize)
                                            let currentTextBoxHeight = CGFloat(wrappedLines.count) * currentSize * 1.2
                                            let expectedHandleX = screenX + textBoxWidth + 10
                                            let expectedHandleY = screenY + currentTextBoxHeight + 10

                                            // Distance between touch and where handle WOULD be without fix
                                            let offsetX = touchX - expectedHandleX
                                            let offsetY = touchY - expectedHandleY
                                            let lagDistance = sqrt(offsetX * offsetX + offsetY * offsetY)

                                            // Speed calculation
                                            let speed = abs(value.translation.height) > 0 ? abs(currentSize - baseFontSize) / abs(value.translation.height) : 0

                                            // Calculate new font size based on drag distance (divide by 5 for sensitivity)
                                            let fontDelta = value.translation.height / 5
                                            let calculatedNewSize = baseFontSize + fontDelta
                                            let clampedNewSize = max(12, min(72, calculatedNewSize))

                                            print("🔵 FONT RESIZE")
                                            print("   👆 Finger at: (\(String(format: "%.1f", touchX)), \(String(format: "%.1f", touchY)))")
                                            print("   🎯 Drag handle visual at: (\(String(format: "%.1f", fontResizeDragLocation.x)), \(String(format: "%.1f", fontResizeDragLocation.y)))")
                                            print("   📍 Expected handle (old way): (\(String(format: "%.1f", expectedHandleX)), \(String(format: "%.1f", expectedHandleY)))")
                                            print("   📏 Lag prevented: \(String(format: "%.1f", lagDistance))px, Offset: (\(String(format: "%.1f", offsetX)), \(String(format: "%.1f", offsetY)))")
                                            print("   📊 Translation.height: \(String(format: "%.1f", value.translation.height))px (vertical drag)")
                                            print("   � fontDelta: \(String(format: "%.1f", fontDelta))pt = translation(\(String(format: "%.1f", value.translation.height))) / 5")
                                            print("   📐 Font calculation: base(\(String(format: "%.1f", baseFontSize))) + delta(\(String(format: "%.1f", fontDelta))) = \(String(format: "%.1f", calculatedNewSize))")
                                            print("   ✂️  Clamped to: \(String(format: "%.1f", clampedNewSize))pt (min: 12, max: 72)")
                                            print("   📝 Wrapped lines: \(wrappedLines.count), Height: \(String(format: "%.1f", currentTextBoxHeight))px")
                                            print("   💾 Setting annotation fontSize to: \(String(format: "%.1f", clampedNewSize))")
                                            print("   ⚡️ Speed factor: \(String(format: "%.3f", speed)) (font change / screen drag)")

                                            photo.annotations[selectedIndex].fontSize = clampedNewSize

                                            print("   ✅ Annotation fontSize now: \(String(format: "%.1f", photo.annotations[selectedIndex].fontSize ?? 0))")
                                        }
                                        .onEnded { value in
                                            isDraggingHandle = false
                                            print("🔵 FONT RESIZE ENDED")
                                            print("   📊 Final translation: \(String(format: "%.1f", value.translation.height))px")
                                            let finalSize = photo.annotations[selectedIndex].fontSize ?? 20.0
                                            print("   📐 Final font size: \(String(format: "%.1f", finalSize))")

                                            // Commit the final size as the new base
                                            baseFontSize = max(12, min(72, baseFontSize + value.translation.height / 5))
                                            photo.annotations[selectedIndex].fontSize = baseFontSize
                                            print("   ✅ New baseFontSize committed: \(String(format: "%.1f", baseFontSize))")
                                        }
                                )
                        }

                        // Show inline editor for editing text
                        if let editIndex = editingTextAnnotationIndex,
                           editIndex < photo.annotations.count {
                            let _ = print("✏️ RENDERING TEXT EDITOR for index \(editIndex)")
                            let annotation = photo.annotations[editIndex]
                            let textSize = annotation.fontSize ?? 20.0
                            let _ = print("   - Text: '\(annotation.text ?? "nil")'")
                            let _ = print("   - Font size: \(textSize)")

                            let screenX = annotation.position.x * scale + xOffset
                            let screenY = annotation.position.y * scale + yOffset
                            let _ = print("   - Screen position: (\(screenX), \(screenY))")

                            // Simple text field overlay
                            TextEditorOverlay(
                                text: $textInput,
                                fontSize: textSize,
                                onCancel: {
                                    print("❌ CANCEL tapped")
                                    editingTextAnnotationIndex = nil
                                    selectedTextAnnotationIndex = nil
                                },
                                onDone: {
                                    print("✅ DONE tapped - saving text: '\(textInput)'")
                                    photo.annotations[editIndex].text = textInput.isEmpty ? "Text" : textInput
                                    editingTextAnnotationIndex = nil
                                    selectedTextAnnotationIndex = editIndex
                                }
                            )
                            .position(x: geometry.size.width / 2, y: max(150, min(screenY - 100, geometry.size.height - 150)))
                        }
                    }
                }
                .allowsHitTesting(true)
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        // Skip drag handling for text tool - text uses tap-to-place
        guard selectedTool != .text else { return }
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

    private func wrapText(_ text: String, width: CGFloat, fontSize: CGFloat) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentLine = ""

        let approximateCharWidth = fontSize * 0.6
        let maxCharsPerLine = Int(width / approximateCharWidth)

        for word in words {
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word

            if testLine.count <= maxCharsPerLine {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [text] : lines
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

        case .text:
            // Check if point is within text bounds (approximate)
            // Use a larger tolerance for text to make it easier to select
            guard let text = annotation.text, !text.isEmpty else { return false }
            let textSize = annotation.fontSize ?? annotation.size

            // Approximate text bounds (width based on character count, height based on font size)
            let approximateWidth = CGFloat(text.count) * textSize * 0.6
            let approximateHeight = textSize * 1.2

            let textRect = CGRect(
                x: annotation.position.x,
                y: annotation.position.y,
                width: approximateWidth,
                height: approximateHeight
            )

            return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    private func findTextAnnotationAtScreenPoint(screenPoint: CGPoint, containerSize: CGSize, imageSize: CGSize, image: UIImage) -> Int? {
        print("🔍 findTextAnnotationAtScreenPoint - screen point: \(screenPoint)")

        // Calculate scale and offset (same as rendering)
        let scale = imageSize.width / image.size.width
        let offset = CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )

        print("   Scale: \(scale), Offset: \(offset)")

        // Check text annotations in reverse order (top-most first)
        for (index, annotation) in photo.annotations.enumerated().reversed() {
            guard annotation.type == .text else { continue }
            guard let text = annotation.text, !text.isEmpty else { continue }

            let textSize = annotation.fontSize ?? 20.0
            let textBoxWidth = annotation.textBoxWidth ?? 200.0

            // Convert text position from image coordinates to screen coordinates
            let screenX = annotation.position.x * scale + offset.x
            let screenY = annotation.position.y * scale + offset.y

            // Calculate text box height based on wrapping
            let lineHeight = textSize * 1.2
            let charactersPerLine = Int(textBoxWidth / (textSize * 0.6))
            let estimatedLines = max(1, (text.count + charactersPerLine - 1) / charactersPerLine)
            let textBoxHeight = CGFloat(estimatedLines) * lineHeight

            let screenRect = CGRect(
                x: screenX,
                y: screenY,
                width: textBoxWidth,
                height: textBoxHeight
            )

            print("   - Index \(index): '\(text)' at screen coords (\(screenX), \(screenY)), rect: \(screenRect)")

            let tolerance: CGFloat = 20.0
            let hitTestRect = screenRect.insetBy(dx: -tolerance, dy: -tolerance)
            let isHit = hitTestRect.contains(screenPoint)

            print("     Hit test rect: \(hitTestRect), contains: \(isHit)")

            if isHit {
                print("   ✅ HIT! Returning index \(index)")
                return index
            }
        }

        print("   ❌ No text hit")
        return nil
    }

    private func findTextAnnotationAt(point: CGPoint, scale: CGFloat) -> Int? {
        print("🔍 findTextAnnotationAt called - point: \(point), scale: \(scale), total annotations: \(photo.annotations.count)")

        // Find text annotations in reverse order (top-most first)
        for (index, annotation) in photo.annotations.enumerated().reversed() {
            guard annotation.type == .text else {
                print("   - Index \(index): Skipping (not text type)")
                continue
            }
            guard let text = annotation.text, !text.isEmpty else {
                print("   - Index \(index): Skipping (no text)")
                continue
            }

            let textSize = annotation.fontSize ?? 20.0
            let approximateWidth = CGFloat(text.count) * textSize * 0.6
            let approximateHeight = textSize * 1.2

            let textRect = CGRect(
                x: annotation.position.x,
                y: annotation.position.y,
                width: approximateWidth,
                height: approximateHeight
            )

            print("   - Index \(index): text='\(text)', position=\(annotation.position)")
            print("     Text rect (image coords): \(textRect)")
            print("     Distance from tap: dx=\(abs(point.x - annotation.position.x)), dy=\(abs(point.y - annotation.position.y))")

            let tolerance: CGFloat = 20.0
            let hitTestRect = textRect.insetBy(dx: -tolerance, dy: -tolerance)
            let isHit = hitTestRect.contains(point)
            print("     Hit test rect: \(hitTestRect), contains point: \(isHit)")

            if isHit {
                print("   ✅ HIT! Returning index \(index)")
                return index
            }
        }
        print("   ❌ No hit found")
        return nil
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
        // Skip drag handling for text tool - text uses tap-to-place
        guard selectedTool != .text else { return }
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
        case .text: return .text
        }
    }

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

extension PhotoAnnotationEditor.AnnotationTool: Hashable {}

// MARK: - Text Editor Overlay Component
