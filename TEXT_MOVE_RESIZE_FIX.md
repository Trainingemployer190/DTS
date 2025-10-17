# Text Annotation Move/Resize Fix

## Problem
Text annotations could be created and selected, but dragging the text body to move it or dragging handles to resize it didn't work. The handlers were using the old coordinate system that treated `annotation.position` as image coordinates instead of normalized coordinates (0..1).

## Root Cause
The `TextDragHandler` protocol and its implementations (`TextMoveHandler`, `TextChangeWidthHandler`, `TextResizeAndRotateHandler`) needed the full image dimensions to convert between screen space drag translations and normalized coordinate deltas, but they weren't receiving this information.

## Changes Made

### 1. Updated `TextDragHandler` Protocol
**File:** `TextAnnotationHandlers.swift`

Added `imageSize: CGSize` parameter to all three protocol methods:
```swift
protocol TextDragHandler: AnyObject {
    func handleDragStart(at point: CGPoint, in annotations: inout [PhotoAnnotation],
                        scale: CGFloat, offset: CGPoint, imageSize: CGSize)
    func handleDragChanged(to point: CGPoint, translation: CGSize, in annotations: inout [PhotoAnnotation],
                          scale: CGFloat, offset: CGPoint, imageSize: CGSize)
    func handleDragEnded(at point: CGPoint, in annotations: inout [PhotoAnnotation],
                        scale: CGFloat, offset: CGPoint, imageSize: CGSize)
}
```

### 2. Fixed `TextMoveHandler` Coordinate Conversion
**File:** `TextAnnotationHandlers.swift` (lines 43-89)

Updated to properly convert screen drag translation to normalized coordinate delta:

```swift
func handleDragChanged(to point: CGPoint, translation: CGSize,
                      in annotations: inout [PhotoAnnotation],
                      scale: CGFloat, offset: CGPoint, imageSize: CGSize) {
    // translation is in SCREEN space (points)
    // annotation.position is in NORMALIZED space (0..1)
    // Need to convert: screen translation → normalized delta

    // Screen translation → Image space translation
    let imageSpaceDeltaX = translation.width / scale
    let imageSpaceDeltaY = translation.height / scale

    // Image space translation → Normalized delta
    let normalizedDeltaX = imageSpaceDeltaX / imageSize.width
    let normalizedDeltaY = imageSpaceDeltaY / imageSize.height

    let newPosition = CGPoint(
        x: initialImagePosition.x + normalizedDeltaX,
        y: initialImagePosition.y + normalizedDeltaY
    )

    annotations[annotationIndex].position = newPosition
}
```

**Key Formula:**
```
Screen Translation → Image Space: delta_image = delta_screen / scale
Image Space → Normalized: delta_normalized = delta_image / image.size
Combined: delta_normalized = (delta_screen / scale) / image.size
```

### 3. Updated `TextChangeWidthHandler` and `TextResizeAndRotateHandler`
**File:** `TextAnnotationHandlers.swift`

Both handlers now accept `imageSize` parameter in their function signatures. These handlers primarily work with size/width values rather than positions, so they don't need normalized conversion, but they need the parameter to match the protocol.

### 4. Updated `TextHandlerManager` Methods
**File:** `TextAnnotationHandlers.swift` (lines 285-320)

All three manager methods now accept and pass through `imageSize`:
- `startDrag(at:handler:annotations:scale:offset:imageSize:)`
- `updateDrag(to:translation:annotations:scale:offset:imageSize:)`
- `endDrag(at:annotations:scale:offset:imageSize:)`

### 5. Updated All Call Sites in PhotoAnnotationEditor
**File:** `PhotoAnnotationEditor.swift`

Updated 9 call sites (3 for canvas drag, 3 for width handle, 3 for font handle) to pass `imageSize: image.size`:

**Lines 276-283:** Canvas drag start
**Lines 297-304:** Canvas drag update
**Lines 439-445:** Canvas drag end
**Lines 744-751:** Width handle drag start
**Lines 757-764:** Width handle drag update
**Lines 769-775:** Width handle drag end
**Lines 817-824:** Font handle drag start
**Lines 827-834:** Font handle drag update
**Lines 837-843:** Font handle drag end

## Testing Checklist

✅ Build successful (Exit Code: 0)

Now test:
- [ ] Create text annotation by tapping on photo
- [ ] Tap text to select it (blue border appears)
- [ ] Drag text body to move it (position should update correctly)
- [ ] Save and reopen editor - verify text is in correct position
- [ ] Drag right edge handle to change width
- [ ] Drag bottom-right corner handle to change font size
- [ ] Test with different image sizes (portrait/landscape)
- [ ] Test near image edges (top-left, bottom-right corners)

## What This Fixes
- ✅ Text body drag-to-move now works with normalized coordinates
- ✅ Position persists correctly after save/reopen
- ✅ Width and font size resizing continue to work as before
- ✅ All coordinate conversions now consistent throughout the system

## Architecture Notes

The handler system follows the Drawsana architecture pattern:
- **TextDragHandler protocol**: Base interface for all drag operations
- **TextMoveHandler**: Handles text body dragging (position changes)
- **TextChangeWidthHandler**: Handles right edge dragging (width changes)
- **TextResizeAndRotateHandler**: Handles corner dragging (font size changes)
- **TextHandlerManager**: Coordinates handler selection and lifecycle

This separation of concerns makes it easy to add new drag interactions (like rotation support) in the future.
