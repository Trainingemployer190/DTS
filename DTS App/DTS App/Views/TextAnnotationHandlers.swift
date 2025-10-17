//
//  TextAnnotationHandlers.swift
//
//  Encapsulates drag handlers for text annotations: move, change width, resize (font/box)
//

import SwiftUI
import Foundation
import CoreGraphics
import SwiftData

// MARK: - Base Handler Protocol

protocol TextDragHandler: AnyObject {
    var annotationIndex: Int { get set }
    var isActive: Bool { get set }
    func handleDragStart(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize)
    func handleDragChanged(to point: CGPoint, translation: CGSize, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize)
    func handleDragEnded(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize)
}

// MARK: Move Handler

class TextMoveHandler: TextDragHandler {
    var annotationIndex: Int
    var isActive: Bool = false
    private var initialImagePosition: CGPoint = .zero

    init(annotationIndex: Int) { self.annotationIndex = annotationIndex }

    func handleDragStart(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = true
        initialImagePosition = annotations[annotationIndex].position
        print("[HANDLER] MoveHandler activated for annotation index \(annotationIndex)")
    }

    func handleDragChanged(to point: CGPoint, translation: CGSize, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        let imageDX = translation.width / scale
        let imageDY = translation.height / scale
        let deltaNorm = CGPoint(x: imageDX / imageSize.width, y: imageDY / imageSize.height)
        annotations[annotationIndex].position = CGPoint(x: initialImagePosition.x + deltaNorm.x, y: initialImagePosition.y + deltaNorm.y)
    }

    func handleDragEnded(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = false
        print("MoveHandler end pos(normalized)=\(annotations[annotationIndex].position)")
    }
}

// MARK: Width Handler

class TextChangeWidthHandler: TextDragHandler {
    var annotationIndex: Int
    var isActive: Bool = false
    private var initialScreenWidth: CGFloat = 0

    init(annotationIndex: Int) { self.annotationIndex = annotationIndex }

    func handleDragStart(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = true
        print("[HANDLER] WidthHandler activated for annotation index \(annotationIndex)")
        let ann = annotations[annotationIndex]
        let imageWidth: CGFloat = ann.textBoxWidth ?? 200.0
        let imageFontSize: CGFloat = ann.fontSize ?? ann.size
        let rawScreenFont: CGFloat = imageFontSize * scale
        let screenFont: CGFloat = max(rawScreenFont, 16.0)
        let fontAdjust: CGFloat = rawScreenFont > 0 ? (screenFont / rawScreenFont) : 1.0
        initialScreenWidth = imageWidth * scale * fontAdjust
    }

    func handleDragChanged(to point: CGPoint, translation: CGSize, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        print("🟢 WIDTH HANDLE: Updating - translation: (\(translation.width), \(translation.height))")
        print("   📊 BEFORE mutation:")
        print("      textBoxWidth: \(annotations[annotationIndex].textBoxWidth ?? 0)")
        print("      hasExplicitWidth: \(annotations[annotationIndex].hasExplicitWidth)")

        let newScreenWidth: CGFloat = max(50.0, min(800.0, initialScreenWidth + translation.width))
        let fontSize: CGFloat = annotations[annotationIndex].fontSize ?? annotations[annotationIndex].size
        let rawScreenFont: CGFloat = fontSize * scale
        let screenFont: CGFloat = max(rawScreenFont, 16.0)
        let fontAdjust: CGFloat = rawScreenFont > 0 ? (screenFont / rawScreenFont) : 1.0
        let unadjusted: CGFloat = newScreenWidth / fontAdjust
        let imageWidth: CGFloat = unadjusted / scale

        print("   🧮 Calculated values:")
        print("      newScreenWidth: \(newScreenWidth)")
        print("      imageWidth: \(imageWidth)")

        annotations[annotationIndex].textBoxWidth = imageWidth
        annotations[annotationIndex].hasExplicitWidth = true

        print("   ✅ AFTER mutation:")
        print("      textBoxWidth: \(annotations[annotationIndex].textBoxWidth ?? 0)")
        print("      hasExplicitWidth: \(annotations[annotationIndex].hasExplicitWidth)")
    }

    func handleDragEnded(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = false
    }
}

// MARK: Resize (Font) Handler

class TextResizeAndRotateHandler: TextDragHandler {
    var annotationIndex: Int
    var isActive: Bool = false
    private var initialFontSize: CGFloat = 20

    init(annotationIndex: Int) { self.annotationIndex = annotationIndex }

    func handleDragStart(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = true
        initialFontSize = annotations[annotationIndex].fontSize ?? annotations[annotationIndex].size
    }

    func handleDragChanged(to point: CGPoint, translation: CGSize, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        // Simple: dragging down increases font, up decreases it
        // translation.height is already in screen pixels from the gesture
        // Just convert to image space and apply directly
        let imageDeltaFont = translation.height / scale
        let newFont: CGFloat = max(12.0, min(400.0, initialFontSize + imageDeltaFont))
        
        var ann = annotations[annotationIndex]
        let oldFont: CGFloat = ann.fontSize ?? initialFontSize
        ann.fontSize = newFont
        
        // Scale width proportionally if not explicitly set
        if !ann.hasExplicitWidth, let w = ann.textBoxWidth {
            let ratio: CGFloat = newFont / max(oldFont, 1.0)
            ann.textBoxWidth = min(800.0, max(40.0, w * ratio))
        }

        annotations[annotationIndex] = ann
    }

    func handleDragEnded(at point: CGPoint, in annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        isActive = false
    }
}

// MARK: Handler Manager

class TextHandlerManager: ObservableObject {
    @Published var activeHandler: (any TextDragHandler)? = nil
    private var moveHandler: TextMoveHandler?
    private var widthHandler: TextChangeWidthHandler?
    private var resizeHandler: TextResizeAndRotateHandler?

    func selectHandler(
        at screenPoint: CGPoint,
        for annotationIndex: Int,
        annotation: PhotoAnnotation,
        scale: CGFloat,
        offset: CGPoint,
        imageSize: CGSize
    ) -> (any TextDragHandler)? {
        // Convert normalized to screen
        let imagePos = CGPoint(x: annotation.position.x * imageSize.width, y: annotation.position.y * imageSize.height)
        let screenY = imagePos.y * scale + offset.y
        let screenX = imagePos.x * scale + offset.x

        // Font metrics - MUST MATCH PhotoAnnotationEditor rendering
        let imageFont: CGFloat = annotation.fontSize ?? annotation.size
        let rawScreenFont: CGFloat = imageFont * scale
        let screenFontSize: CGFloat = max(rawScreenFont, 12.0)  // Match editor's minimum of 12pt
        
        // Text box width
        let imageWidth: CGFloat = annotation.textBoxWidth ?? 200.0
        let screenWidth: CGFloat = imageWidth * scale
        
        // Height estimate - for wrapped text, estimate based on text length
        // Most single-line text will have height around screenFontSize * 1.2
        let text = annotation.text ?? "Text"
        let estimatedLineHeight = screenFontSize * 1.2
        
        // Better estimate: most text in this app is 1-2 lines, so default to 1 line
        // We'll expand hit detection zones to be forgiving
        let estimatedScreenHeight = estimatedLineHeight

        // Apply topPadding offset SAME AS PhotoAnnotationEditor
        let topPadding = screenFontSize * 0.2
        let adjustedScreenY = screenY - topPadding
        let screenOrigin = CGPoint(x: screenX, y: adjustedScreenY)

        // Create a larger hit detection area for the text body itself
        // This allows dragging anywhere on the text to move it
        let bodyPadding: CGFloat = 8  // 8 pixel padding around text box
        let bodyRect = CGRect(
            x: screenOrigin.x - bodyPadding,
            y: screenOrigin.y - bodyPadding,
            width: screenWidth + bodyPadding * 2,
            height: estimatedScreenHeight + bodyPadding * 2
        )

        // Hit zones - MUST ALIGN with PhotoAnnotationEditor handle positions
        let widthHandleCenter = CGPoint(x: screenOrigin.x + screenWidth, y: screenOrigin.y + estimatedScreenHeight / 2)
        let widthHandleRect = CGRect(x: widthHandleCenter.x - 15, y: widthHandleCenter.y - 18, width: 30, height: 36)

        let cornerHandleCenter = CGPoint(x: screenOrigin.x + screenWidth + 6, y: screenOrigin.y + estimatedScreenHeight + 6)
        let cornerHandleRect = CGRect(x: cornerHandleCenter.x - 18, y: cornerHandleCenter.y - 18, width: 36, height: 36)

        // Debug logging
        print("[HANDLER] selectHandler called:")
        print("  screenPoint: \(screenPoint)")
        print("  screenOrigin: \(screenOrigin), screenWidth: \(screenWidth), estimatedHeight: \(estimatedScreenHeight)")
        print("  cornerHandleRect: \(cornerHandleRect)")
        print("  widthHandleRect: \(widthHandleRect)")
        print("  bodyRect: \(bodyRect)")

        if cornerHandleRect.contains(screenPoint) {
            print("[HANDLER SELECT] Blue font size handle hit at: \(screenPoint)")
            resizeHandler = TextResizeAndRotateHandler(annotationIndex: annotationIndex)
            return resizeHandler
        }
        if widthHandleRect.contains(screenPoint) {
            print("[HANDLER SELECT] Green width handle hit at: \(screenPoint)")
            widthHandler = TextChangeWidthHandler(annotationIndex: annotationIndex)
            return widthHandler
        }
        if bodyRect.contains(screenPoint) {
            print("[HANDLER SELECT] Move handle hit at: \(screenPoint)")
            moveHandler = TextMoveHandler(annotationIndex: annotationIndex)
            return moveHandler
        }
        print("[HANDLER SELECT] No handle hit at: \(screenPoint) (outside all rects)")
        return nil
    }

    func startDrag(at point: CGPoint, handler: any TextDragHandler, annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        activeHandler = handler
        handler.handleDragStart(at: point, in: &annotations, scale: scale, offset: offset, imageSize: imageSize)
    }
    func updateDrag(to point: CGPoint, translation: CGSize, annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        activeHandler?.handleDragChanged(to: point, translation: translation, in: &annotations, scale: scale, offset: offset, imageSize: imageSize)
    }
    func endDrag(at point: CGPoint, annotations: inout [PhotoAnnotation], scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
        activeHandler?.handleDragEnded(at: point, in: &annotations, scale: scale, offset: offset, imageSize: imageSize)
        activeHandler = nil
    }
}
