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
    @State private var isDraggingWidthHandle: Bool = false
    @State private var isDraggingFontHandle: Bool = false
    @State private var fontResizeDragLocation: CGPoint = .zero
    @State private var widthResizeDragLocation: CGPoint = .zero
    @State private var initialWidthHandlePosition: CGPoint = .zero
    @State private var initialFontHandlePosition: CGPoint = .zero
    
    // Arrow selection states
    @State private var selectedArrowAnnotationIndex: Int? = nil
    @State private var isDraggingArrowStart: Bool = false
    @State private var isDraggingArrowEnd: Bool = false

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
        // Scale stroke width from image space to screen space
        let scaledLineWidth = annotation.size * scale
        let lineWidth = isSelected ? scaledLineWidth * 1.5 : scaledLineWidth

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

                // Arrow head - scale proportionally to line width
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = max(15, scaledLineWidth * 5)  // Scale with line width
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

            // Get font size from annotation (already in image space)
            let imageFontSize = annotation.fontSize ?? 20.0

            // Convert to screen space for rendering
            let screenFontSize = imageFontSize * scale

            print("📝 TEXT RENDER for '\(text)'")
            print("   imageFontSize: \(String(format: "%.1f", imageFontSize))pt")
            print("   scale: \(String(format: "%.3f", scale))")
            print("   screenFontSize: \(String(format: "%.1f", screenFontSize))pt")

            // Get text box width and convert to screen space
            let imageTextBoxWidth = annotation.textBoxWidth ?? 200.0
            let screenTextBoxWidth = imageTextBoxWidth * scale

            // Wrap text using SCREEN SPACE dimensions
            let wrappedText = wrapText(text, width: screenTextBoxWidth, fontSize: screenFontSize)

            // Draw text with selection highlight if selected
            if isSelected && annotation.type == .text {
                // Yellow outline for selected text
                var yOffset: CGFloat = 0
                for line in wrappedText {
                    context.draw(
                        Text(line)
                            .font(.system(size: screenFontSize, weight: .bold))
                            .foregroundColor(.yellow),
                        at: CGPoint(x: textPosition.x - 2, y: textPosition.y + yOffset - 2),
                        anchor: .topLeading
                    )
                    yOffset += screenFontSize * 1.2
                }
            }

            var yOffset: CGFloat = 0
            for line in wrappedText {
                context.draw(
                    Text(line)
                        .font(.system(size: screenFontSize, weight: .bold))
                        .foregroundColor(color),
                    at: CGPoint(x: textPosition.x, y: textPosition.y + yOffset),
                    anchor: .topLeading
                )
                yOffset += screenFontSize * 1.2
            }
        }
    }

    enum AnnotationTool {
        case freehand, arrow, box, circle, text
    }

    // MARK: - Text Width Calculation
    private func calculateTextWidth(text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        return ceil(boundingRect.width) + 4  // Add 4pt padding
    }

    // MARK: - Canvas View Helper
    @ViewBuilder
    private func canvasView(geometry: GeometryProxy) -> some View {
        if let image = UIImage(contentsOfFile: photo.fileURL) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)

            annotationCanvas(image: image, geometry: geometry)
        }
    }

    @ViewBuilder
    private func annotationCanvas(image: UIImage, geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            let imageSize = calculateImageSize(for: image, in: size)
            let scale = imageSize.width / image.size.width

            // Calculate offset to center the image (letterboxing/pillarboxing)
            let xOffset = (size.width - imageSize.width) / 2
            let yOffset = (size.height - imageSize.height) / 2

            // Draw saved annotations
            for (index, annotation) in photo.annotations.enumerated() {
                let isSelected = index == selectedAnnotationIndex
                print("🎨 CANVAS DRAWING annotation \(index): type=\(annotation.type), isSelected=\(isSelected)")
                drawAnnotation(annotation, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset), isSelected: isSelected)
            }

            // Draw current annotation
            if let current = currentAnnotation {
                drawAnnotation(current, in: &context, scale: scale, offset: CGPoint(x: xOffset, y: yOffset))
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(Rectangle())
        .gesture(canvasDragGesture(geometry: geometry, image: image))
    }

    private func canvasDragGesture(geometry: GeometryProxy, image: UIImage) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStartTime == nil {
                    print("👆 CANVAS TAP STARTED at \(value.location)")
                }
                handleCanvasDragChanged(value, geometry: geometry, image: image)
            }
            .onEnded { value in
                print("👆 CANVAS TAP ENDED at \(value.location)")
                handleCanvasDragEnded(value, geometry: geometry, image: image)
            }
    }

    // MARK: - Gesture Handlers
    private func handleCanvasDragChanged(_ value: DragGesture.Value, geometry: GeometryProxy, image: UIImage) {
        // Handle text tool - check if dragging selected text
        if selectedTool == .text {
            if pressStartTime == nil {
                pressStartTime = Date()
                pressStartLocation = value.location
                hasMoved = false

                // Store original position when drag starts
                if let selectedIndex = selectedTextAnnotationIndex {
                    originalAnnotationPosition = photo.annotations[selectedIndex].position
                }
                return
            }

            // Check for movement
            if let startLoc = pressStartLocation {
                let distance = hypot(value.location.x - startLoc.x, value.location.y - startLoc.y)
                if distance >= 10 && !hasMoved {
                    hasMoved = true
                }
            }

            // If moving and text is selected, move it by delta
            if hasMoved, let selectedIndex = selectedTextAnnotationIndex, let startLoc = pressStartLocation {
                let imageSize = calculateImageSize(for: image, in: geometry.size)

                // Calculate delta in IMAGE coordinates
                let currentImagePoint = convertToImageCoordinates(value.location, in: geometry.size, imageSize: imageSize, image: image)
                let startImagePoint = convertToImageCoordinates(startLoc, in: geometry.size, imageSize: imageSize, image: image)
                let delta = CGPoint(x: currentImagePoint.x - startImagePoint.x, y: currentImagePoint.y - startImagePoint.y)

                // Apply delta to original position
                photo.annotations[selectedIndex].position = CGPoint(
                    x: originalAnnotationPosition.x + delta.x,
                    y: originalAnnotationPosition.y + delta.y
                )
            }
            return
        }

        // Initialize press tracking on first touch for other tools
        if pressStartTime == nil {
            pressStartTime = Date()
            pressStartLocation = value.location
            
            // If an arrow is already selected, store its original state for dragging
            if let selectedIndex = selectedArrowAnnotationIndex {
                originalAnnotationPoints = photo.annotations[selectedIndex].points
                originalAnnotationPosition = photo.annotations[selectedIndex].position
                print("🎯 Starting drag on selected arrow \(selectedIndex) - stored \(originalAnnotationPoints.count) points")
            }

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
                print("🚶 MOVEMENT DETECTED - Distance: \(String(format: "%.1f", distance))px from \(startLoc) to \(value.location)")
                hasMoved = true
            }
        }

        // Handle dragging
        if hasMoved {
            if selectedAnnotationIndex != nil || selectedArrowAnnotationIndex != nil {
                // Move selected annotation (either old system or arrow)
                handleAnnotationDrag(value, in: geometry.size)
            } else {
                // Draw new annotation
                handleDragChanged(value, in: geometry.size)
            }
        }
    }

    private func handleCanvasDragEnded(_ value: DragGesture.Value, geometry: GeometryProxy, image: UIImage) {
        print("🏁 GESTURE ENDED - Tool: \(selectedTool), Moved: \(hasMoved)")
        print("   📍 Tap location: \(value.location)")
        print("   🎯 Current selections - Arrow: \(selectedArrowAnnotationIndex?.description ?? "nil"), Text: \(selectedTextAnnotationIndex?.description ?? "nil")")

        // Get hit detection info for all annotation types first
        let imageSize = calculateImageSize(for: image, in: geometry.size)
        print("   📐 Image size: \(imageSize), Container size: \(geometry.size)")
        
        let tappedTextIndex = findTextAnnotationAtScreenPoint(screenPoint: value.location, containerSize: geometry.size, imageSize: imageSize, image: image)
        let tappedArrowIndex = findArrowAnnotationAtScreenPoint(screenPoint: value.location, containerSize: geometry.size, imageSize: imageSize, image: image)
        
        print("   🔍 Hit detection - Text index: \(tappedTextIndex?.description ?? "nil"), Arrow index: \(tappedArrowIndex?.description ?? "nil")")

        // Check for tap (not drag) interactions
        if !hasMoved {
            // Handle text annotation tap
            if let index = tappedTextIndex {
                print("🔍 Found text at index: \(index) - handling text tap")

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
                    selectedArrowAnnotationIndex = nil  // Deselect arrow if selected
                    editingTextAnnotationIndex = nil

                    // Initialize base values for resizing
                    let imageSpaceWidth = photo.annotations[index].textBoxWidth ?? 200.0
                    let localScale = imageSize.width / image.size.width
                    baseWidth = imageSpaceWidth * localScale
                    baseFontSize = photo.annotations[index].fontSize ?? 20.0
                    print("   📏 Base values initialized: imageWidth=\(imageSpaceWidth) → screenWidth=\(baseWidth), fontSize=\(baseFontSize)")
                }

                pressStartTime = nil
                pressStartLocation = nil
                hasMoved = false
                return
            }
            
            // Handle arrow annotation tap
            if let index = tappedArrowIndex {
                print("🏹 Found arrow at index: \(index) - handling arrow tap")
                
                if selectedArrowAnnotationIndex == index {
                    // Already selected - deselect it
                    print("❌ DESELECTING arrow at index \(index)")
                    selectedArrowAnnotationIndex = nil
                } else {
                    // Select it
                    print("🎯 SELECTING arrow at index \(index)")
                    selectedArrowAnnotationIndex = index
                    selectedTextAnnotationIndex = nil  // Deselect text if selected
                    editingTextAnnotationIndex = nil
                    
                    // Store original points and position for drag operations
                    originalAnnotationPoints = photo.annotations[index].points
                    originalAnnotationPosition = photo.annotations[index].position
                    print("   📦 Stored original points for dragging: \(originalAnnotationPoints.count) points")
                }
                
                // Don't clear press tracking - user might want to drag immediately
                // pressStartTime = nil
                // pressStartLocation = nil
                pressStartTime = nil  // Clear time but keep location for potential drag
                hasMoved = false
                return
            }

        // Priority 3: Handle text tool tap for creating new text (only if text tool is active)
        if selectedTool == .text && tappedTextIndex == nil && tappedArrowIndex == nil {
            print("✅ TEXT TAP DETECTED on empty space with text tool")
            let imagePoint = convertToImageCoordinates(value.location, in: geometry.size, imageSize: imageSize, image: image)
            print("📍 Converted to image coordinates: \(imagePoint)")

            // Create new text annotation
            print("✨ CREATING NEW TEXT annotation")

            // We want text to be ~20pt on screen for readability
            let targetScreenFontSize: CGFloat = 20.0
            let scale = imageSize.width / image.size.width
            let imageSpaceFontSize = targetScreenFontSize / scale

            // Calculate width needed for "Text" at screen size, then convert to image space
            let actualScreenWidth = calculateTextWidth(text: "Text", fontSize: targetScreenFontSize)
            let imageSpaceWidth = actualScreenWidth / scale

            let newAnnotation = PhotoAnnotation(
                id: UUID(),
                type: .text,
                points: [],
                text: "Text",
                color: selectedColor.toHex(),
                position: imagePoint,
                size: strokeWidth,
                fontSize: imageSpaceFontSize,
                textBoxWidth: imageSpaceWidth
            )
            photo.annotations.append(newAnnotation)
            selectedTextAnnotationIndex = photo.annotations.count - 1
            selectedArrowAnnotationIndex = nil  // Deselect any arrow
            editingTextAnnotationIndex = nil

            // Initialize base values for new text
            let newScale = imageSize.width / image.size.width
            baseWidth = imageSpaceWidth * newScale
            baseFontSize = imageSpaceFontSize
            print("   - New text at index: \(selectedTextAnnotationIndex?.description ?? "nil")")
            print("   📏 Base values initialized: imageWidth=\(imageSpaceWidth) → screenWidth=\(baseWidth), fontSize=\(baseFontSize)")

            pressStartTime = nil
            pressStartLocation = nil
            hasMoved = false
            return
        }

        // Priority 4: If we tapped on empty space (no annotations hit), deselect everything
        // This ONLY happens if nothing was tapped (no text, no arrow)
        // This includes taps outside the image bounds
        if tappedTextIndex == nil && tappedArrowIndex == nil {
            print("   ✅ Empty space tap detected - checking for deselections...")
            
            var deselected = false
            
            if selectedArrowAnnotationIndex != nil {
                print("      ❌ DESELECTING arrow (was at index \(selectedArrowAnnotationIndex!))")
                selectedArrowAnnotationIndex = nil
                deselected = true
            }
            
            if selectedTextAnnotationIndex != nil {
                print("      ❌ DESELECTING text (was at index \(selectedTextAnnotationIndex!))")
                selectedTextAnnotationIndex = nil
                editingTextAnnotationIndex = nil
                deselected = true
            }
            
            if !deselected {
                print("      ℹ️ Nothing was selected to deselect")
            } else {
                print("      ✅ Deselection complete")
            }
        } else {
            print("   ℹ️ Tapped on an annotation - not deselecting")
        }
        
    } else {
        // Had movement - this was a drag operation
        print("   ℹ️ Gesture had movement (hasMoved=true)")
        
        // Handle annotation dragging completion
        if selectedAnnotationIndex != nil {
            selectedAnnotationIndex = nil
            originalAnnotationPoints = []
            originalAnnotationPosition = .zero
            print("   ✅ Finished moving annotation")
        } else if currentAnnotation != nil {
            // Just finished drawing a new annotation
            handleDragEnded(value, in: geometry.size)
            print("   🔍 Checking for deselection after draw operation...")
            
            // After drawing, check if we should deselect anything
            // This ensures clean state after drawing
            if selectedArrowAnnotationIndex != nil || selectedTextAnnotationIndex != nil {
                print("      🧹 Clearing selections after draw")
                selectedArrowAnnotationIndex = nil
                selectedTextAnnotationIndex = nil
                editingTextAnnotationIndex = nil
            }
        }
    }
    
    // Always reset gesture tracking state
    pressStartTime = nil
    pressStartLocation = nil
    hasMoved = false
}    // MARK: - Toolbar View
    @ViewBuilder
    private var toolbarView: some View {
        HStack {
            Spacer()

            VStack(spacing: 12) {
                // Tool buttons
                Button(action: { selectedTool = .freehand }) {
                    toolButton(icon: "scribble", isSelected: selectedTool == .freehand)
                }

                Button(action: { selectedTool = .arrow }) {
                    toolButton(icon: "arrow.up.right", isSelected: selectedTool == .arrow)
                }

                Button(action: { selectedTool = .box }) {
                    toolButton(icon: "rectangle", isSelected: selectedTool == .box)
                }

                Button(action: { selectedTool = .circle }) {
                    toolButton(icon: "circle", isSelected: selectedTool == .circle)
                }

                Button(action: { selectedTool = .text }) {
                    toolButton(icon: "textformat", isSelected: selectedTool == .text)
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

    @ViewBuilder
    private func toolButton(icon: String, isSelected: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 22))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.blue : Color.black.opacity(0.7))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Canvas area - Full screen
                GeometryReader { geometry in
                    ZStack {
                        canvasView(geometry: geometry)
                    }
                }

                // Vertical toolbar on the right side
                toolbarView
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
                    ZStack {
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
                            let text = annotation.text ?? "Text"

                            let screenX = annotation.position.x * scale + xOffset
                            let screenY = annotation.position.y * scale + yOffset

                            ZStack {
                                // IMPORTANT: Calculate these INSIDE ZStack so they recalculate on every render
                                // when annotation.fontSize OR annotation.textBoxWidth changes during drag
                                let currentImageFontSize = annotation.fontSize ?? 20.0  // Get CURRENT value during drag
                                let screenFontSize = currentImageFontSize * scale  // This will update as fontSize changes

                                // Get CURRENT text box width (recalculates when green handle drags)
                                let imageTextBoxWidth = annotation.textBoxWidth ?? 200.0  // Image space
                                let screenTextBoxWidth = imageTextBoxWidth * scale  // Screen space

                                // Calculate ACTUAL wrapped lines to get accurate height
                                let wrappedLines = wrapText(text, width: screenTextBoxWidth, fontSize: screenFontSize)
                                let lineHeight = screenFontSize * 1.2
                                let actualLineCount = wrappedLines.count
                                let screenTextBoxHeight = CGFloat(actualLineCount) * lineHeight

                                // Dotted border around text box - this will now update position during font resize
                                Rectangle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    .foregroundColor(.blue)
                                    .frame(width: screenTextBoxWidth, height: screenTextBoxHeight)
                                    .position(x: screenX + screenTextBoxWidth/2, y: screenY + screenTextBoxHeight/2)
                                    .allowsHitTesting(false)  // Border should not capture hits

                                // Delete button (top-left corner)
                                // Clamp to stay within screen bounds (with 30px margin)
                                let rawDeleteButtonX = screenX - 12
                                let rawDeleteButtonY = screenY - 12
                                let deleteButtonX = max(30, min(geometry.size.width - 30, rawDeleteButtonX))
                                let deleteButtonY = max(30, min(geometry.size.height - 30, rawDeleteButtonY))

                                Button(action: {
                                    photo.annotations.remove(at: selectedIndex)
                                    selectedTextAnnotationIndex = nil
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .allowsHitTesting(true)  // Override parent to capture hits
                                .position(x: deleteButtonX, y: deleteButtonY)

                                // Right edge resize handle (middle-right for width adjustment)
                                // Clamp handle positions to stay within screen bounds (with 30px margin)
                                let rawWidthHandleX = screenX + screenTextBoxWidth
                                let rawWidthHandleY = screenY + screenTextBoxHeight/2
                                let widthHandleX = max(30, min(geometry.size.width - 30, rawWidthHandleX))
                                let widthHandleY = max(30, min(geometry.size.height - 30, rawWidthHandleY))

                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle().size(width: 50, height: 40))
                                    .allowsHitTesting(true)  // Override parent to capture hits
                                    .position(x: widthHandleX, y: widthHandleY)
                                .gesture(
                                    DragGesture(minimumDistance: 1)
                                        .onChanged { value in
                                            if !isDraggingWidthHandle {
                                                isDraggingWidthHandle = true
                                                initialWidthHandlePosition = CGPoint(x: widthHandleX, y: widthHandleY)
                                                let currentImageWidth = photo.annotations[selectedIndex].textBoxWidth ?? 200.0
                                                baseWidth = currentImageWidth  // Store IMAGE space width
                                                print("🟢 WIDTH RESIZE STARTED - baseWidth (IMAGE): \(String(format: "%.1f", baseWidth))")
                                            }

                                            // Convert screen drag to image space delta
                                            let screenDelta = value.translation.width
                                            let imageDelta = screenDelta / scale
                                            let newImageWidth = baseWidth + imageDelta

                                            // Limit width to screen width (convert to image space)
                                            let maxScreenWidth = geometry.size.width - 40  // 40px margin
                                            let maxImageWidth = maxScreenWidth / scale
                                            let clampedImageWidth = max(50, min(maxImageWidth, newImageWidth))

                                            // Update directly - triggers SwiftUI re-render
                                            photo.annotations[selectedIndex].textBoxWidth = clampedImageWidth
                                        }
                                        .onEnded { value in

                                            isDraggingWidthHandle = false
                                            let screenDelta = value.translation.width
                                            let imageDelta = screenDelta / scale

                                            // Limit width to screen width (convert to image space)
                                            let maxScreenWidth = geometry.size.width - 40  // 40px margin
                                            let maxImageWidth = maxScreenWidth / scale
                                            let finalWidth = max(50, min(maxImageWidth, baseWidth + imageDelta))
                                            photo.annotations[selectedIndex].textBoxWidth = finalWidth
                                            baseWidth = finalWidth
                                            print("� WIDTH RESIZE ENDED - Final: \(String(format: "%.1f", finalWidth)) (IMAGE space)")
                                        }
                                )

                                // Bottom-right corner resize handle (for font size)
                                // Recalculate position based on CURRENT height
                                // Clamp handle positions to stay within screen bounds (with 30px margin)
                                let rawFontHandleX = screenX + screenTextBoxWidth
                                let rawFontHandleY = screenY + screenTextBoxHeight
                                let fontHandleX = max(30, min(geometry.size.width - 30, rawFontHandleX))
                                let fontHandleY = max(30, min(geometry.size.height - 30, rawFontHandleY))

                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle().size(width: 50, height: 50))  // Larger hit area - use Rectangle for better tap detection
                                    .allowsHitTesting(true)  // Override parent to capture hits
                                    .position(x: fontHandleX, y: fontHandleY)
                                    .offset(
                                        x: isDraggingFontHandle ? fontResizeDragLocation.x - initialFontHandlePosition.x : 0,
                                        y: isDraggingFontHandle ? fontResizeDragLocation.y - initialFontHandlePosition.y : 0
                                    )
                                    // Ensure the blue font handle wins hit-testing when zones overlap
                                    .zIndex(1)
                                    .highPriorityGesture(  // Use highPriority so font resize wins when both handles overlap
                                        DragGesture(minimumDistance: 1)  // Reduced from 0 to 1 for better detection
                                        .onChanged { value in
                                            if !isDraggingFontHandle {
                                                isDraggingFontHandle = true
                                                // Store INITIAL handle position (won't change during drag)
                                                initialFontHandlePosition = CGPoint(x: fontHandleX, y: fontHandleY)
                                                // Initialize drag location to HANDLE'S position
                                                fontResizeDragLocation = CGPoint(x: fontHandleX, y: fontHandleY)
                                                // Get current font size from annotation (in IMAGE space)
                                                let currentStoredFontSize = photo.annotations[selectedIndex].fontSize ?? 20.0
                                                baseFontSize = currentStoredFontSize  // Store IMAGE space value
                                                // ALSO store initial width to scale proportionally with font
                                                baseWidth = photo.annotations[selectedIndex].textBoxWidth ?? 200.0
                                                print("� FONT RESIZE STARTED")
                                                print("   📍 Initial handle position: (\(String(format: "%.1f", fontHandleX)), \(String(format: "%.1f", fontHandleY)))")
                                                print("   🎯 Initial baseFontSize (IMAGE space): \(String(format: "%.1f", baseFontSize))pt")
                                                print("   📏 Scale factor: \(String(format: "%.3f", scale))")
                                            }

                                            // Update visual drag location
                                            fontResizeDragLocation = CGPoint(
                                                x: initialFontHandlePosition.x + value.translation.width,
                                                y: initialFontHandlePosition.y + value.translation.height
                                            )

                                            // Use diagonal distance for more intuitive resizing
                                            // Positive diagonal = bigger, negative = smaller
                                            let diagonalDelta = (value.translation.width + value.translation.height) / 2.0

                                            // Convert screen space delta to image space delta with sensitivity adjustment
                                            // Sensitivity: Lower = slower resize, Higher = faster resize
                                            let sensitivity: CGFloat = 0.3  // 30% of the calculated change for smoother control
                                            let imageSpaceDelta = (diagonalDelta / scale) * sensitivity

                                            // Calculate new font size in IMAGE space
                                            let calculatedNewSize = baseFontSize + imageSpaceDelta
                                            let clampedNewSize = max(12, min(1200, calculatedNewSize))  // Increased max to 1200

                                            print("🔵 FONT RESIZE")
                                            print("   � Translation: (w: \(String(format: "%.1f", value.translation.width)), h: \(String(format: "%.1f", value.translation.height)))")
                                            print("   🎯 Diagonal delta (SCREEN): \(String(format: "%.1f", diagonalDelta))px")
                                            print("   � Image space delta: \(String(format: "%.1f", imageSpaceDelta))pt")
                                            print("   📐 Font calculation: base(\(String(format: "%.1f", baseFontSize))) + delta(\(String(format: "%.1f", imageSpaceDelta))) = \(String(format: "%.1f", calculatedNewSize))")
                                            print("   ✂️  Clamped to: \(String(format: "%.1f", clampedNewSize))pt (IMAGE space)")

                                            // Update the annotation directly for immediate visual feedback
                                            // Also scale width proportionally to maintain text wrapping
                                            let fontSizeRatio = clampedNewSize / baseFontSize
                                            let newWidth = baseWidth * fontSizeRatio

                                            // Limit width to screen width (convert to image space)
                                            let maxScreenWidth = geometry.size.width - 40  // 40px margin
                                            let maxImageWidth = maxScreenWidth / scale
                                            let clampedNewWidth = max(50, min(maxImageWidth, newWidth))

                                            photo.annotations[selectedIndex].fontSize = clampedNewSize
                                            photo.annotations[selectedIndex].textBoxWidth = clampedNewWidth

                                            print("   ✅ Updated fontSize to: \(String(format: "%.1f", clampedNewSize))")
                                        }
                                        .onEnded { value in
                                            isDraggingFontHandle = false
                                            print("🔵 FONT RESIZE ENDED")

                                            // Calculate final size using same logic with sensitivity
                                            let diagonalDelta = (value.translation.width + value.translation.height) / 2.0
                                            let sensitivity: CGFloat = 0.3
                                            let imageSpaceDelta = (diagonalDelta / scale) * sensitivity
                                            let finalSize = max(12, min(1200, baseFontSize + imageSpaceDelta))  // Increased max to 1200

                                            // Scale width proportionally
                                            let fontSizeRatio = finalSize / baseFontSize
                                            let newWidth = baseWidth * fontSizeRatio

                                            // Limit width to screen width (convert to image space)
                                            let maxScreenWidth = geometry.size.width - 40  // 40px margin
                                            let maxImageWidth = maxScreenWidth / scale
                                            let finalWidth = max(50, min(maxImageWidth, newWidth))

                                            // Commit both final size and width
                                            photo.annotations[selectedIndex].fontSize = finalSize
                                            photo.annotations[selectedIndex].textBoxWidth = finalWidth
                                            baseFontSize = finalSize
                                            baseWidth = finalWidth

                                            print("   ✅ Final fontSize: \(String(format: "%.1f", finalSize)), width: \(String(format: "%.1f", finalWidth))")
                                        }
                                )
                            } // End ZStack for selection handles
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

                            // Calculate the actual text box bounds for this annotation
                            let imageFontSize = annotation.fontSize ?? 20.0
                            let screenFontSize = imageFontSize * scale
                            let imageTextBoxWidth = annotation.textBoxWidth ?? 200.0
                            let screenTextBoxWidth = imageTextBoxWidth * scale

                            // Get actual wrapped lines to calculate height
                            let wrappedLines = wrapText(annotation.text ?? "Text", width: screenTextBoxWidth, fontSize: screenFontSize)
                            let lineHeight = screenFontSize * 1.2
                            let screenTextBoxHeight = CGFloat(wrappedLines.count) * lineHeight

                            // Create the text box rectangle
                            let textBoxRect = CGRect(
                                x: screenX,
                                y: screenY,
                                width: screenTextBoxWidth,
                                height: screenTextBoxHeight
                            )

                            GeometryReader { editorGeometry in
                                ZStack {
                                    // Background overlay to detect taps outside
                                    Color.black.opacity(0.3)
                                        .frame(width: editorGeometry.size.width, height: editorGeometry.size.height)
                                        .contentShape(Rectangle())
                                        .onTapGesture { location in
                                            // Only close if tap is outside the text box area (with some padding)
                                            let paddedTextRect = textBoxRect.insetBy(dx: -20, dy: -20)

                                            if !paddedTextRect.contains(location) {
                                                print("🎯 Tap outside text box - saving text")
                                                let newText = textInput.isEmpty ? "Text" : textInput
                                                photo.annotations[editIndex].text = newText

                                                // Recalculate text box width
                                                let currentFontSize = photo.annotations[editIndex].fontSize ?? 20.0
                                                let screenWidth = calculateTextWidth(text: newText, fontSize: currentFontSize * scale)
                                                let imageWidth = screenWidth / scale

                                                // Limit width to screen width
                                                let maxScreenWidth = geometry.size.width - 40
                                                let maxImageWidth = maxScreenWidth / scale
                                                let clampedImageWidth = min(maxImageWidth, imageWidth)

                                                photo.annotations[editIndex].textBoxWidth = clampedImageWidth

                                                editingTextAnnotationIndex = nil
                                                selectedTextAnnotationIndex = editIndex
                                            } else {
                                                print("🎯 Tap inside text box area - keeping editor open")
                                            }
                                        }

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
                                            let newText = textInput.isEmpty ? "Text" : textInput
                                            photo.annotations[editIndex].text = newText

                                            // Recalculate text box width based on new text and current font size
                                            let currentFontSize = photo.annotations[editIndex].fontSize ?? 20.0
                                            let screenWidth = calculateTextWidth(text: newText, fontSize: currentFontSize * scale)
                                            let imageWidth = screenWidth / scale

                                            // Limit width to screen width (convert to image space)
                                            let maxScreenWidth = geometry.size.width - 40  // 40px margin
                                            let maxImageWidth = maxScreenWidth / scale
                                            let clampedImageWidth = min(maxImageWidth, imageWidth)

                                            photo.annotations[editIndex].textBoxWidth = clampedImageWidth

                                            print("   📏 Updated textBoxWidth to \(clampedImageWidth) (image space) for text: '\(newText)'")

                                            editingTextAnnotationIndex = nil
                                            selectedTextAnnotationIndex = editIndex
                                        }
                                    )
                                    .position(x: editorGeometry.size.width / 2, y: editorGeometry.size.height / 2)
                                    .onTapGesture {
                                        // Consume taps on the editor itself to prevent closing
                                        print("📝 Tap on editor - keeping it open")
                                    }
                                }
                            }
                        }
                        
                        // Show selection handles for selected arrow
                        if let selectedIndex = selectedArrowAnnotationIndex,
                           selectedIndex < photo.annotations.count,
                           photo.annotations[selectedIndex].type == .arrow,
                           photo.annotations[selectedIndex].points.count >= 2 {
                            let _ = print("🏹 RENDERING ARROW SELECTION HANDLES for index \(selectedIndex)")
                            let annotation = photo.annotations[selectedIndex]
                            
                            let start = annotation.points[0]
                            let end = annotation.points[annotation.points.count - 1]
                            
                            // Convert to screen coordinates
                            let screenStartX = start.x * scale + xOffset
                            let screenStartY = start.y * scale + yOffset
                            let screenEndX = end.x * scale + xOffset
                            let screenEndY = end.y * scale + yOffset
                            
                            // Calculate midpoint for delete button
                            let midX = (screenStartX + screenEndX) / 2
                            let midY = (screenStartY + screenEndY) / 2
                            
                            ZStack {
                                // Transparent background that doesn't capture hits
                                Color.clear
                                    .allowsHitTesting(false)
                                
                                // Start point handle (green circle)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                    .position(x: screenStartX, y: screenStartY)
                                    .contentShape(Circle())
                                    .allowsHitTesting(true)  // Override parent to capture hits
                                    .gesture(
                                        DragGesture(minimumDistance: 1)
                                            .onChanged { value in
                                                print("🟢 START HANDLE DRAG at \(value.location)")
                                                if !isDraggingArrowStart {
                                                    isDraggingArrowStart = true
                                                    print("🟢 START POINT DRAG STARTED")
                                                }
                                                
                                                // Convert screen drag to image coordinates
                                                let screenPoint = value.location
                                                let imagePoint = convertToImageCoordinates(
                                                    screenPoint,
                                                    in: geometry.size,
                                                    imageSize: imageSize,
                                                    image: image
                                                )
                                                
                                                // Update start point while keeping end point
                                                var newPoints = photo.annotations[selectedIndex].points
                                                newPoints[0] = imagePoint
                                                photo.annotations[selectedIndex].points = newPoints
                                            }
                                            .onEnded { _ in
                                                isDraggingArrowStart = false
                                                print("🟢 START POINT DRAG ENDED")
                                            }
                                    )
                                
                                // End point handle (blue circle)
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .position(x: screenEndX, y: screenEndY)
                                    .contentShape(Circle())
                                    .allowsHitTesting(true)  // Override parent to capture hits
                                    .gesture(
                                        DragGesture(minimumDistance: 1)
                                            .onChanged { value in
                                                print("🔵 END HANDLE DRAG at \(value.location)")
                                                if !isDraggingArrowEnd {
                                                    isDraggingArrowEnd = true
                                                    print("🔵 END POINT DRAG STARTED")
                                                }
                                                
                                                // Convert screen drag to image coordinates
                                                let screenPoint = value.location
                                                let imagePoint = convertToImageCoordinates(
                                                    screenPoint,
                                                    in: geometry.size,
                                                    imageSize: imageSize,
                                                    image: image
                                                )
                                                
                                                // Update end point while keeping start point
                                                var newPoints = photo.annotations[selectedIndex].points
                                                newPoints[newPoints.count - 1] = imagePoint
                                                photo.annotations[selectedIndex].points = newPoints
                                            }
                                            .onEnded { _ in
                                                isDraggingArrowEnd = false
                                                print("🔵 END POINT DRAG ENDED")
                                            }
                                    )
                                
                                // Delete button (red circle at midpoint - already calculated above)
                                Button(action: {
                                    photo.annotations.remove(at: selectedIndex)
                                    selectedArrowAnnotationIndex = nil
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .allowsHitTesting(true)  // Override parent to capture hits
                                .position(x: midX, y: midY)
                            }
                        }
                    }
                    } // End ZStack in GeometryReader
                }
                .onTapGesture { location in
                    // When tapping in the overlay but not on any interactive element, deselect
                    print("📱 OVERLAY TAP at \(location)")
                    if selectedArrowAnnotationIndex != nil {
                        print("   ❌ Deselecting arrow from overlay tap")
                        selectedArrowAnnotationIndex = nil
                    }
                    if selectedTextAnnotationIndex != nil {
                        print("   ❌ Deselecting text from overlay tap")
                        selectedTextAnnotationIndex = nil
                        editingTextAnnotationIndex = nil
                    }
                }
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        // Skip drag handling for text tool - text uses tap-to-place
        guard selectedTool != .text else { return }
        guard let image = UIImage(contentsOfFile: photo.fileURL) else { return }

        let imageSize = calculateImageSize(for: image, in: size)
        let scale = imageSize.width / image.size.width
        let point = convertToImageCoordinates(value.location, in: size, imageSize: imageSize, image: image)

        if currentAnnotation == nil {
            // Convert stroke width from screen space to image space
            let imageSpaceStrokeWidth = strokeWidth / scale
            
            // Start new annotation
            currentAnnotation = PhotoAnnotation(
                type: selectedTool.toAnnotationType(),
                points: [point],
                text: nil,
                color: selectedColor.toHex(),
                position: point,
                size: imageSpaceStrokeWidth  // Store in image space
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
        // Support both old selection system and new arrow selection system
        let index = selectedAnnotationIndex ?? selectedArrowAnnotationIndex
        guard let index = index, let image = UIImage(contentsOfFile: photo.fileURL) else { return }

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

            // Get font size and convert to screen space
            let imageFontSize = annotation.fontSize ?? 20.0
            let screenFontSize = imageFontSize * scale

            // Get text box width and convert to screen space
            let imageTextBoxWidth = annotation.textBoxWidth ?? 200.0
            let screenTextBoxWidth = imageTextBoxWidth * scale

            // Convert text position from image coordinates to screen coordinates
            // This is the TOP-LEFT position where text starts rendering
            let screenX = annotation.position.x * scale + offset.x
            let screenY = annotation.position.y * scale + offset.y

            // Calculate ACTUAL text box height using the same wrapping logic as rendering
            let wrappedLines = wrapText(text, width: screenTextBoxWidth, fontSize: screenFontSize)
            let lineHeight = screenFontSize * 1.2
            let actualLineCount = wrappedLines.count
            let screenTextBoxHeight = CGFloat(actualLineCount) * lineHeight

            // Create the hit test rectangle - this should match exactly where the text is rendered
            let screenRect = CGRect(
                x: screenX,
                y: screenY,
                width: screenTextBoxWidth,
                height: screenTextBoxHeight
            )

            print("   - Index \(index): '\(text)' at screen coords (\(screenX), \(screenY))")
            print("     Screen rect: \(screenRect)")
            print("     Lines: \(actualLineCount), height: \(screenTextBoxHeight)")

            // Use a smaller tolerance for more precise hit detection
            let tolerance: CGFloat = 10.0  // Reduced from 20.0
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
        
        // If start and end are the same point (with small epsilon for floating point comparison)
        if lengthSquared < 0.001 {
            return hypot(point.x - start.x, point.y - start.y)
        }
        
        // Calculate the parameter t that represents the closest point on the line segment
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        
        // Find the closest point on the line segment
        let closestPoint = CGPoint(
            x: start.x + t * dx,
            y: start.y + t * dy
        )
        
        // Return the distance from the point to the closest point on the line segment
        return hypot(point.x - closestPoint.x, point.y - closestPoint.y)
    }
    
    private func findArrowAnnotationAtScreenPoint(screenPoint: CGPoint, containerSize: CGSize, imageSize: CGSize, image: UIImage) -> Int? {
        print("🏹 findArrowAnnotationAtScreenPoint - screen point: \(screenPoint)")
        
        // Calculate scale and offset (same as rendering)
        let scale = imageSize.width / image.size.width
        let offset = CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )
        
        print("   Scale: \(scale), Offset: \(offset)")
        
        // First check if the tap point is even within the image bounds
        let imageRect = CGRect(x: offset.x, y: offset.y, width: imageSize.width, height: imageSize.height)
        if !imageRect.contains(screenPoint) {
            print("   ❌ Tap is outside image bounds")
            return nil
        }
        
        // Check arrow annotations in reverse order (top-most first)
        for (index, annotation) in photo.annotations.enumerated().reversed() {
            guard annotation.type == .arrow else { continue }
            guard annotation.points.count >= 2 else { continue }
            
            let start = annotation.points[0]
            let end = annotation.points[annotation.points.count - 1]
            
            // Convert to screen coordinates
            let screenStart = CGPoint(
                x: start.x * scale + offset.x,
                y: start.y * scale + offset.y
            )
            let screenEnd = CGPoint(
                x: end.x * scale + offset.x,
                y: end.y * scale + offset.y
            )
            
            // Check if tap is near the arrow line
            let distance = distanceToLineSegment(point: screenPoint, start: screenStart, end: screenEnd)
            
            // Use a balanced tolerance - easier to select but still reasonable
            let strokeWidth = annotation.size * scale
            let tolerance: CGFloat = max(12.0, min(20.0, strokeWidth * 2.5))  // Between 12-20 pixels
            
            print("   - Index \(index): arrow from \(screenStart) to \(screenEnd)")
            print("     Distance to arrow: \(String(format: "%.2f", distance))px, tolerance: \(String(format: "%.1f", tolerance))px")
            
            if distance <= tolerance {
                print("   ✅ HIT! Returning index \(index)")
                return index
            }
        }
        
        print("   ❌ No arrow hit")
        return nil
    }

    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        // Skip drag handling for text tool - text uses tap-to-place
        guard selectedTool != .text else { return }
        guard let annotation = currentAnnotation else { return }

        // Finalize annotation
        photo.annotations.append(annotation)
        
        // DON'T auto-select arrow after drawing - this causes confusion
        // Let user explicitly tap to select
        print("✅ Added new \(annotation.type) annotation at index \(photo.annotations.count - 1)")
        
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
