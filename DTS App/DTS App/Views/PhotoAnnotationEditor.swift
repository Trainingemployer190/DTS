//
//  PhotoAnnotationEditor.swift
//  DTS App
//
//  Draw annotations on photos
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
    @State private var showingTextInput = false
    @State private var showingTextEditor = false
    @State private var textInput = ""
    @State private var pendingTextPoint: CGPoint?

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
                        }

                        // Existing annotations
                        ForEach(photo.annotations, id: \.id) { annotation in
                            DrawingAnnotation(annotation: annotation)
                        }

                        // Current drawing
                        if let current = currentAnnotation {
                            DrawingAnnotation(annotation: current)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDragChanged(value, in: geometry.size)
                            }
                            .onEnded { value in
                                handleDragEnded(value, in: geometry.size)
                            }
                    )
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

                        Button(action: {
                            selectedTool = .text
                            showingTextEditor = true
                        }) {
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
                                selectedTool = .freehand
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
                                    photo.annotations.append(annotation)
                                    textInput = ""
                                    pendingTextPoint = nil
                                    showingTextEditor = false
                                    selectedTool = .freehand
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

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let point = value.location

        if currentAnnotation == nil {
            // Start new annotation
            currentAnnotation = PhotoAnnotation(
                type: selectedTool.toAnnotationType(),
                points: [point],
                text: selectedTool == .text ? textInput : nil,
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

    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard var annotation = currentAnnotation else { return }

        // Finalize annotation
        if selectedTool == .text {
            annotation.text = textInput
            textInput = ""
        }

        photo.annotations.append(annotation)
        currentAnnotation = nil
    }

    private func undoLastAnnotation() {
        guard !photo.annotations.isEmpty else { return }
        photo.annotations.removeLast()
    }
}

// MARK: - Drawing Annotation View

struct DrawingAnnotation: View {
    let annotation: PhotoAnnotation

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
            if let start = annotation.points.first, let end = annotation.points.last {
                ArrowShape(start: start, end: end)
                    .stroke(color, lineWidth: annotation.size)
            }

        case .box:
            if let start = annotation.points.first, let end = annotation.points.last {
                Rectangle()
                    .path(in: CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    ))
                    .stroke(color, lineWidth: annotation.size)
            }

        case .circle:
            if let start = annotation.points.first, let end = annotation.points.last {
                let radius = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
                Circle()
                    .path(in: CGRect(
                        x: start.x - radius,
                        y: start.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    .stroke(color, lineWidth: annotation.size)
            }

        case .text:
            if let text = annotation.text {
                Text(text)
                    .font(.system(size: annotation.size * 3))
                    .foregroundColor(color)
                    .position(annotation.position)
            }
        }
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

#Preview {
    PhotoAnnotationEditor(photo: PhotoRecord(fileURL: ""))
        .modelContainer(for: [PhotoRecord.self])
}
