//
//  PencilKitPhotoEditor.swift
//  DTS App
//
//  PencilKit-based photo annotation editor with custom shape tools
//  Replicates Apple Photos markup experience
//

import SwiftUI
import PencilKit
import UIKit

struct PencilKitPhotoEditor: View {
    @Bindable var photo: PhotoRecord
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var hasUnsavedChanges = false
    @State private var selectedShapeTool: ShapeTool?
    @State private var showingHelpBanner = true

    enum ShapeTool {
        case arrow, circle, rectangle, line, text
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = UIImage(contentsOfFile: photo.fileURL) {
                    PencilKitCanvasView(
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        image: image,
                        existingDrawing: loadExistingDrawing(),
                        onDrawingChanged: { hasUnsavedChanges = true }
                    )

                    // Help banner at top
                    if showingHelpBanner {
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("💡 Tip: Use Lasso Tool to Move Shapes")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("Tap shapes on right → Use lasso (bottom toolbar) to select & move")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white)

                                Spacer()

                                Button(action: { showingHelpBanner = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.9))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.top, 8)

                            Spacer()
                        }
                        .allowsHitTesting(true)
                    }

                    // Custom shape toolbar (vertical, right side - like your current system)
                    VStack(spacing: 16) {
                        Spacer()

                        shapeToolButton(tool: .arrow, icon: "arrow.up.right", label: "Arrow")
                        shapeToolButton(tool: .rectangle, icon: "rectangle", label: "Box")
                        shapeToolButton(tool: .circle, icon: "circle", label: "Circle")
                        shapeToolButton(tool: .line, icon: "minus", label: "Line")
                        shapeToolButton(tool: .text, icon: "textformat", label: "Text")

                        Spacer()
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("Unable to load image")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Markup Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // TODO: Show confirmation alert
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveDrawing()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Show the tool picker (drawing tools palette)
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                toolPicker.addObserver(canvasView)
            }
        }
    }

    // MARK: - Shape Tool Button

    private func shapeToolButton(tool: ShapeTool, icon: String, label: String) -> some View {
        Button(action: {
            selectedShapeTool = tool
            addShape(tool)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(selectedShapeTool == tool ? Color.blue : Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Shape Drawing Functions

    private func addShape(_ tool: ShapeTool) {
        let drawing = canvasView.drawing
        var strokes: [PKStroke] = []

        // Get canvas bounds for centering shapes
        let canvasBounds = canvasView.bounds
        let centerX = canvasBounds.width / 2
        let centerY = canvasBounds.height / 2

        switch tool {
        case .arrow:
            strokes = createArrowStrokes(at: CGPoint(x: centerX, y: centerY))
        case .circle:
            strokes = createCircleStrokes(at: CGPoint(x: centerX, y: centerY))
        case .rectangle:
            strokes = createRectangleStrokes(at: CGPoint(x: centerX, y: centerY))
        case .line:
            strokes = createLineStrokes(at: CGPoint(x: centerX, y: centerY))
        case .text:
            // For text, users should use PencilKit's built-in text tool from the tool picker
            // We just show a hint that they should select the text tool
            print("💡 Use the text tool from the bottom toolbar to add text")
            return
        }

        // Add strokes to drawing
        var newDrawing = drawing
        for stroke in strokes {
            newDrawing.strokes.append(stroke)
        }
        canvasView.drawing = newDrawing
        hasUnsavedChanges = true
    }

    private func createArrowStrokes(at center: CGPoint) -> [PKStroke] {
        var strokes: [PKStroke] = []
        let ink = PKInk(.pen, color: .red)

        // Arrow shaft (vertical line going up)
        let shaftStart = CGPoint(x: center.x, y: center.y + 50)
        let shaftEnd = CGPoint(x: center.x, y: center.y - 50)
        strokes.append(createStroke(from: shaftStart, to: shaftEnd, ink: ink))

        // Arrow head (two lines forming a V)
        let headLeft = CGPoint(x: center.x - 20, y: center.y - 30)
        strokes.append(createStroke(from: shaftEnd, to: headLeft, ink: ink))

        let headRight = CGPoint(x: center.x + 20, y: center.y - 30)
        strokes.append(createStroke(from: shaftEnd, to: headRight, ink: ink))

        return strokes
    }

    private func createCircleStrokes(at center: CGPoint) -> [PKStroke] {
        let ink = PKInk(.pen, color: .blue)
        let radius: CGFloat = 50
        let segments = 60

        var points: [PKStrokePoint] = []
        for i in 0...segments {
            let angle = (CGFloat(i) / CGFloat(segments)) * 2 * .pi
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: CGSize(width: 3, height: 3),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
            points.append(point)
        }

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return [PKStroke(ink: ink, path: path)]
    }

    private func createRectangleStrokes(at center: CGPoint) -> [PKStroke] {
        var strokes: [PKStroke] = []
        let ink = PKInk(.pen, color: .green)
        let width: CGFloat = 100
        let height: CGFloat = 80

        let topLeft = CGPoint(x: center.x - width/2, y: center.y - height/2)
        let topRight = CGPoint(x: center.x + width/2, y: center.y - height/2)
        let bottomRight = CGPoint(x: center.x + width/2, y: center.y + height/2)
        let bottomLeft = CGPoint(x: center.x - width/2, y: center.y + height/2)

        strokes.append(createStroke(from: topLeft, to: topRight, ink: ink))
        strokes.append(createStroke(from: topRight, to: bottomRight, ink: ink))
        strokes.append(createStroke(from: bottomRight, to: bottomLeft, ink: ink))
        strokes.append(createStroke(from: bottomLeft, to: topLeft, ink: ink))

        return strokes
    }

    private func createLineStrokes(at center: CGPoint) -> [PKStroke] {
        let ink = PKInk(.pen, color: .orange)
        let start = CGPoint(x: center.x - 75, y: center.y)
        let end = CGPoint(x: center.x + 75, y: center.y)
        return [createStroke(from: start, to: end, ink: ink)]
    }

    private func createStroke(from start: CGPoint, to end: CGPoint, ink: PKInk) -> PKStroke {
        let points = [
            PKStrokePoint(
                location: start,
                timeOffset: 0,
                size: CGSize(width: 3, height: 3),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: end,
                timeOffset: 0.1,
                size: CGSize(width: 3, height: 3),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
        ]

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    // MARK: - Drawing Persistence

    private func loadExistingDrawing() -> PKDrawing? {
        // Try to load existing PKDrawing data if available
        guard let drawingData = photo.pencilKitDrawingData else { return nil }
        return try? PKDrawing(data: drawingData)
    }

    private func saveDrawing() {
        // Save the PKDrawing data to the photo record
        let drawing = canvasView.drawing
        let data = drawing.dataRepresentation()
        photo.pencilKitDrawingData = data
        print("✅ Saved PencilKit drawing (\(data.count) bytes)")
    }
}

// MARK: - UIViewRepresentable Wrapper

struct PencilKitCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    let image: UIImage
    let existingDrawing: PKDrawing?
    let onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        // Configure canvas
        canvasView.drawingPolicy = .anyInput  // Works with finger or Apple Pencil
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        // Load existing drawing if available
        if let drawing = existingDrawing {
            canvasView.drawing = drawing
        }

        // Add the photo as a background subview
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.insertSubview(imageView, at: 0)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: canvasView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: canvasView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: canvasView.bottomAnchor)
        ])

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Updates handled by coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: () -> Void

        init(onDrawingChanged: @escaping () -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
    }
}

// MARK: - Export Function

extension PencilKitPhotoEditor {
    /// Generate final image with annotations baked in (for Jobber upload)
    func generateAnnotatedImage() -> UIImage? {
        guard let originalImage = UIImage(contentsOfFile: photo.fileURL) else { return nil }

        let drawing = canvasView.drawing
        let imageSize = originalImage.size

        // Create image context
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            // Draw original photo
            originalImage.draw(at: .zero)

            // Draw PencilKit annotations on top
            let drawingImage = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
            drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Requires a PhotoRecord with SwiftData context
    Text("PencilKit Photo Editor Preview")
}
