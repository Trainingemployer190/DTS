# Text Annotation Bug Fix - October 14, 2025

## Problems Identified

### 1. **Mixed Coordinate Systems**
The code currently mixes two coordinate systems:
- **Image Coordinates**: Full resolution (e.g., 4000x3000px) - stored in `annotation.position`
- **Screen Coordinates**: Display size (e.g., 400x300px) - used for rendering

**Current Bug**: Text position is converted to image coords when created, but rendering assumes screen coords.

### 2. **Inconsistent Scale Calculations**
- Text rendering scales font size: `annotation.size * scale`
- But position isn't scaled consistently between create/render/save operations

### 3. **Hit Detection Issues**
- `findTextAnnotationAtScreenPoint()` converts screen tap to image coords
- But text bounding box calculation doesn't match render positioning

## Root Cause

**Line 370 in PhotoAnnotationEditor.swift:**
```swift
let imagePoint = convertToImageCoordinates(value.location, in: geometry.size, imageSize: imageSize, image: image)
```

This converts the tap location to image coordinates (e.g., 2000x1500 on a 4000x3000 image).

**Line 407 creates annotation:**
```swift
PhotoAnnotation(
    position: imagePoint,  // ← Stored in IMAGE coordinates
    ...
)
```

**Line 165 renders text:**
```swift
let textPosition = CGPoint(
    x: annotation.position.x * scale + offset.x,  // ← Converts to SCREEN coordinates
    y: annotation.position.y * scale + offset.y
)
```

## The Fix Strategy

### Option A: Store in Normalized Coordinates (0..1) - RECOMMENDED
This is what `PhotoAnnotationCanvas.swift` was designed for!

**Advantages:**
- Scale-independent (works on any screen size)
- Matches best practices (Drawsana pattern)
- Already have `CanvasConverters` infrastructure
- Easier to test round-trip conversion

**Changes needed:**
1. Create text: Convert screen tap → normalized (0..1)
2. Render text: Convert normalized → screen coords
3. Hit detection: Convert screen tap → normalized → test bounds
4. Save: Use normalized coords directly (no conversion needed)

### Option B: Store in Image Coordinates (Current) - FIX INCONSISTENCIES
Keep current approach but fix all conversion bugs.

**Advantages:**
- Less refactoring
- Font sizes naturally in image space

**Changes needed:**
1. Verify convertToImageCoordinates() is correct
2. Fix rendering scale calculation
3. Fix hit detection to use same math as rendering
4. Add extensive logging to verify consistency

## Recommended Solution: Option A (Normalized Coordinates)

### Implementation Plan:

1. **Update PhotoAnnotation creation** (Line ~407):
```swift
// Convert screen tap to normalized (0..1)
let normalizedX = (imagePoint.x / image.size.width)
let normalizedY = (imagePoint.y / image.size.height)

PhotoAnnotation(
    position: CGPoint(x: normalizedX, y: normalizedY),  // ← 0..1 range
    size: 20.0,  // ← Font size in points (screen space)
    ...
)
```

2. **Update text rendering** (Line ~165):
```swift
// Convert normalized to screen
let screenX = annotation.position.x * imageSize.width * scale + offset.x
let screenY = annotation.position.y * imageSize.height * scale + offset.y
let textPosition = CGPoint(x: screenX, y: screenY)

// Font size already in screen space
let screenFontSize = max(annotation.size, 16.0)
```

3. **Update hit detection** (Line ~1170):
```swift
// Convert screen tap to normalized
let normalizedTapX = (imagePoint.x / image.size.width)
let normalizedTapY = (imagePoint.y / image.size.height)

// Test against normalized bounds
let textWidth = CGFloat(text.count) * (annotation.size / image.size.width) * 0.6
let textHeight = (annotation.size / image.size.height) * 1.2
```

4. **Update drag/move operations**:
- Convert drag delta to normalized space
- Update position in normalized coords

## Testing Checklist

After fix, verify:
- [ ] Create text at center of screen → position ~(0.5, 0.5)
- [ ] Create text at top-left → position ~(0.1, 0.1)
- [ ] Create text at bottom-right → position ~(0.9, 0.9)
- [ ] Rotate device → text stays in same relative position
- [ ] Different image sizes (portrait/landscape) → consistent behavior
- [ ] Font size 12pt → text readable and consistently sized
- [ ] Font size 72pt → text properly scaled
- [ ] Save and reopen → text appears in exact same spot
- [ ] Drag text → follows finger precisely
- [ ] Resize text → handles appear in correct position

## Files to Modify

1. **PhotoAnnotationEditor.swift** (main file):
   - Line ~370: Text creation coordinate conversion
   - Line ~407: PhotoAnnotation initialization
   - Line ~165: Text rendering
   - Line ~290: Text drag handling
   - Line ~1170: Hit detection

2. **DataModels.swift**:
   - Add documentation to PhotoAnnotation.position explaining normalized coords

3. **PhotoAnnotationCanvas.swift**:
   - Already correct! Use CanvasConverters pattern

## Next Steps

1. Implement normalized coordinate system
2. Add debug logging for coordinate conversions
3. Test on multiple image sizes
4. Update documentation

---

**Current Status**: Ready to implement Option A (Normalized Coordinates)
