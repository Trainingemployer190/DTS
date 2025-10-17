# Text Annotation Coordinate System - Technical Reference

## Overview

Text annotations in DTS App use **normalized coordinates (0..1)** for position storage, ensuring scale-independent behavior across different screen sizes and image resolutions.

## Coordinate Systems Explained

### 1. Normalized Coordinates (0..1) - STORAGE
**Range**: `x: 0.0 to 1.0, y: 0.0 to 1.0`
**Where**: Stored in `PhotoAnnotation.position`

**Examples**:
- Center of image: `(0.5, 0.5)`
- Top-left corner: `(0.0, 0.0)`
- Bottom-right corner: `(1.0, 1.0)`
- Upper-right quadrant: `(0.75, 0.25)`

**Why normalized?**
- Works on any image size (100px or 10,000px)
- Works on any screen (iPhone SE to iPad Pro)
- Survives rotation, zoom, and resize operations
- Industry standard (used by Drawsana, Figma, Sketch)

### 2. Image Coordinates (Pixels) - INTERMEDIATE
**Range**: Full resolution image dimensions (e.g., 4000 x 3000)
**Where**: Temporary during coordinate conversions

**Example**: 4000x3000 image
- Center: `(2000, 1500)`
- Top-left: `(0, 0)`
- Bottom-right: `(4000, 3000)`

### 3. Screen Coordinates (Points) - DISPLAY
**Range**: Display size in iOS points (e.g., 400 x 600)
**Where**: Rendering on screen, hit detection

**Example**: Displayed at 400x600 on screen
- Center: `(200, 300)`
- Top-left: `(0, 0)`
- Bottom-right: `(400, 600)`

## Conversion Flow

### Creating New Text Annotation

```
User Tap
  ↓
Screen Point (200, 300)
  ↓
[Remove offset - account for letterboxing]
  ↓
Adjusted Screen Point (190, 285)
  ↓
[Divide by scale - convert to image space]
  ↓
Image Point (2000, 3000)
  ↓
[Divide by image.size - normalize]
  ↓
Normalized (0.5, 0.75) ← STORED
```

**Code**:
```swift
let imagePoint = convertToImageCoordinates(tap, in: containerSize, imageSize: displaySize, image: image)
let normalizedX = imagePoint.x / image.size.width
let normalizedY = imagePoint.y / image.size.height
annotation.position = CGPoint(x: normalizedX, y: normalizedY)
```

### Rendering Existing Text

```
Normalized (0.5, 0.75) ← FROM STORAGE
  ↓
[Multiply by image.size - denormalize]
  ↓
Image Point (2000, 3000)
  ↓
[Multiply by scale - convert to screen space]
  ↓
Screen Point (200, 300)
  ↓
[Add offset - account for letterboxing]
  ↓
Final Screen Point (210, 315) ← RENDERED
```

**Code**:
```swift
let imageX = annotation.position.x * image.size.width
let imageY = annotation.position.y * image.size.height
let screenX = imageX * scale + offset.x
let screenY = imageY * scale + offset.y
let renderPosition = CGPoint(x: screenX, y: screenY)
```

## Key Functions

### 1. `convertToImageCoordinates()`
**Purpose**: Screen tap → Image coordinates
**Input**: Screen point, container size, displayed image size, original image
**Output**: Image coordinates (pixels)

```swift
private func convertToImageCoordinates(
    _ point: CGPoint,
    in containerSize: CGSize,
    imageSize: CGSize,
    image: UIImage
) -> CGPoint {
    let scale = image.size.width / imageSize.width
    let xOffset = (containerSize.width - imageSize.width) / 2
    let yOffset = (containerSize.height - imageSize.height) / 2

    let adjustedX = (point.x - xOffset) * scale
    let adjustedY = (point.y - yOffset) * scale

    return CGPoint(x: adjustedX, y: adjustedY)
}
```

### 2. `computeTextBounds()`
**Purpose**: Calculate text box position and size on screen
**Input**: Annotation (normalized coords), image, scale, offset
**Output**: Screen rectangle (CGRect)

```swift
private func computeTextBounds(
    for annotation: PhotoAnnotation,
    image: UIImage,
    scale: CGFloat,
    offset: CGPoint
) -> CGRect {
    // Normalized → Image
    let imageX = annotation.position.x * image.size.width
    let imageY = annotation.position.y * image.size.height

    // Image → Screen
    let screenX = imageX * scale + offset.x
    let screenY = imageY * scale + offset.y

    // Calculate width/height...
    return CGRect(x: screenX, y: screenY, width: width, height: height)
}
```

## Scale and Offset Calculations

### Scale Factor
**Formula**: `scale = displayedImageWidth / originalImageWidth`

**Example**:
- Original image: 4000px wide
- Displayed on screen: 400px wide
- Scale: `400 / 4000 = 0.1`

### Offset (Letterboxing/Pillarboxing)
**Purpose**: Center the image in the container

**Formula**:
```swift
let xOffset = (containerWidth - displayedImageWidth) / 2
let yOffset = (containerHeight - displayedImageHeight) / 2
```

**Example**:
- Container: 420 x 640
- Image displayed: 400 x 600
- Offset: `((420-400)/2, (640-600)/2) = (10, 20)`

## Font Size Handling

### Storage
`annotation.size` stores font size in **screen points** (not pixels).

**Range**: 12.0 to 72.0 points

### Rendering
```swift
let screenFontSize = max(annotation.size, 16.0)  // Minimum 16pt for readability
```

**No scaling needed** - font size is already in the correct unit (points).

## Testing Normalized Coordinates

### Verify Correct Storage

Create text at these positions and check stored values:

| Tap Location | Expected Normalized Coords |
|--------------|----------------------------|
| Center | `(0.50, 0.50)` ± 0.05 |
| Top-left | `(0.10, 0.10)` ± 0.05 |
| Bottom-right | `(0.90, 0.90)` ± 0.05 |
| Middle-left | `(0.10, 0.50)` ± 0.05 |
| Middle-right | `(0.90, 0.50)` ± 0.05 |

### Verify Round-Trip Accuracy

```swift
// Create annotation at tap point
let normalizedPos = CGPoint(x: 0.5, y: 0.5)

// Render to screen
let screenPos = convertNormalizedToScreen(normalizedPos)

// Convert screen tap back to normalized
let recoveredNormalizedPos = convertScreenToNormalized(screenPos)

// Should match within rounding error
assert(abs(normalizedPos.x - recoveredNormalizedPos.x) < 0.01)
assert(abs(normalizedPos.y - recoveredNormalizedPos.y) < 0.01)
```

## Common Issues and Solutions

### Issue: Text appears offset after save
**Cause**: Conversion not symmetric (different math for save vs load)
**Fix**: Use same conversion functions for both operations

### Issue: Text position depends on screen size
**Cause**: Storing screen coordinates instead of normalized
**Fix**: Always store normalized, convert only when rendering

### Issue: Text jumps when rotating device
**Cause**: Absolute coordinates don't adapt to new orientation
**Fix**: Normalized coordinates automatically adapt

### Issue: Hit detection misses text
**Cause**: Hit test using different coordinates than render
**Fix**: Use `computeTextBounds()` for both render and hit test

## API Documentation

### PhotoAnnotation.position
```swift
var position: CGPoint  // NORMALIZED coordinates (0..1)
```

**Usage**:
```swift
// ✅ CORRECT: Store normalized
annotation.position = CGPoint(x: 0.5, y: 0.5)

// ❌ WRONG: Don't store screen or image coordinates
annotation.position = CGPoint(x: 200, y: 300)  // Will break
```

### PhotoAnnotation.size
```swift
var size: CGFloat  // Font size in screen points (12-72)
```

**Usage**:
```swift
// ✅ CORRECT: Screen points
annotation.size = 24.0

// ❌ WRONG: Don't scale by image size
annotation.size = 24.0 * scale  // Will render too small/large
```

## References

- **Drawsana**: Open-source annotation framework using same pattern
- **Core Graphics**: Apple's coordinate system documentation
- **PhotoAnnotationCanvas.swift**: Helper for coordinate conversions
- **CanvasConverters**: Utility functions for normalized ↔ view conversion

---

**Last Updated**: October 14, 2025
**Version**: 1.0 (Normalized Coordinate Implementation)
