# Drawsana vs DTS App - Architecture Comparison

## Core Architectural Differences

### **1. Framework & Language**
| Aspect | Drawsana (Reference) | DTS App (Current) |
|--------|---------------------|-------------------|
| Framework | UIKit | SwiftUI |
| Drawing | Core Graphics + UIBezierPath | SwiftUI Canvas |
| State Management | Delegates + Properties | @State + @Bindable |
| Gestures | UIGestureRecognizer subclasses | SwiftUI DragGesture |

---

## Text Annotation Architecture

### **2. Data Model**

#### Drawsana's `TextShape`:
```swift
class TextShape: Shape {
    var text: String
    var transform: ShapeTransform
    var font: UIFont
    var textColor: UIColor
    var explicitWidth: CGFloat?  // ← Key: Optional, nil = auto-size

    func computeBounds() -> CGRect {
        // Calculates actual rendered bounds
        // Returns different results based on explicitWidth
    }
}
```

#### DTS App's `PhotoAnnotation`:
```swift
struct PhotoAnnotation: Codable {
    var text: String?
    var position: CGPoint              // ← Simpler: position instead of transform
    var fontSize: CGFloat?
    var textBoxWidth: CGFloat?         // ← Always has value (200.0 default)
    var hasExplicitWidth: Bool = false // ← Similar concept, different implementation
}
```

**Key Differences:**
- ❌ **No Transform**: DTS uses simple position, Drawsana uses full CGAffineTransform (rotation/scale)
- ❌ **No Optional Width**: DTS always has a width value (defaults to 200.0)
- ✅ **Explicit Flag Added**: `hasExplicitWidth` mimics Drawsana's nil-check behavior
- ❌ **No Bounds Method**: DTS calculates bounds inline, not as a method on the model

---

### **3. Drag Handlers**

#### Drawsana's Handler Architecture:
```swift
// THREE SEPARATE CLASSES with full gesture lifecycle

class MoveHandler: DrawingOperationHandler {
    var shape: TextShape
    var initialPosition: CGPoint

    func handleTap(point: CGPoint) { }
    func handleDragStart(point: CGPoint) { }
    func handleDragContinue(point: CGPoint) {
        shape.transform.translation = ...
    }
    func handleDragEnd() { }
}

class ChangeWidthHandler: DrawingOperationHandler {
    var shape: TextShape
    var initialWidth: CGFloat

    func handleDragContinue(point: CGPoint) {
        shape.explicitWidth = calculateNewWidth(...)
    }
}

class ResizeAndRotateHandler: DrawingOperationHandler {
    var shape: TextShape
    var initialTransform: ShapeTransform
    var initialTouch: CGPoint

    func handleDragContinue(point: CGPoint) {
        // Updates both size AND rotation
        shape.transform.scale = ...
        shape.transform.rotation = ...
    }
}
```

#### DTS App's Handler Architecture:
```swift
// SINGLE ENUM with inline gesture handlers

enum TextDragMode {
    case none
    case movingText      // ← Equivalent to MoveHandler
    case resizingWidth   // ← Equivalent to ChangeWidthHandler
    case resizingFont    // ← Equivalent to ResizeAndRotateHandler (no rotation)
}

// Inline in View:
.gesture(
    DragGesture()
        .onChanged { value in
            if !isDraggingWidthHandle {
                activeDragMode = .resizingWidth
                // ... width resize logic ...
            }
        }
        .onEnded { value in
            activeDragMode = .none
        }
)
```

**Key Differences:**
- ❌ **No Separate Classes**: DTS uses inline closures, Drawsana uses class-based handlers
- ❌ **No Rotation Support**: DTS font handle only changes size, Drawsana also rotates
- ✅ **Similar Lifecycle**: Both track start/continue/end phases
- ✅ **Mode Tracking**: DTS enum serves same purpose as Drawsana's active handler

---

### **4. Bounds Computation**

#### Drawsana's `computeBounds()`:
```swift
func computeBounds() -> CGRect {
    let attributedText = NSAttributedString(string: text, attributes: [.font: font])

    // Case 1: Explicit width set by user
    if let width = explicitWidth {
        let constrainedSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingRect = attributedText.boundingRect(
            with: constrainedSize,
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        return boundingRect
    }

    // Case 2: Auto-size to content
    else {
        let unboundedSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let boundingRect = attributedText.boundingRect(
            with: unboundedSize,
            options: [],
            context: nil
        )
        return boundingRect
    }
}
```

#### DTS App's `computeTextBounds()`:
```swift
private func computeTextBounds(for annotation: PhotoAnnotation, scale: CGFloat, offset: CGPoint) -> CGRect {
    // Convert position to screen space
    let screenX = annotation.position.x * scale + offset.x
    let screenY = annotation.position.y * scale + offset.y

    // Apply font scaling (16pt minimum for readability)
    let imageFontSize = annotation.fontSize ?? annotation.size
    let rawScreenFontSize = imageFontSize * scale
    let screenFontSize = max(rawScreenFontSize, 16.0)

    // Get width - use explicit if set, otherwise auto-size
    let imageTextBoxWidth: CGFloat
    if annotation.hasExplicitWidth, let explicitWidth = annotation.textBoxWidth {
        imageTextBoxWidth = explicitWidth
    } else {
        imageTextBoxWidth = CGFloat(text.count) * imageFontSize * 0.6  // ← Simple estimation
    }

    // Convert to screen space with font adjustment
    let rawScreenTextBoxWidth = imageTextBoxWidth * scale
    let fontScaleAdjustment = screenFontSize / rawScreenFontSize
    let screenTextBoxWidth = rawScreenTextBoxWidth * fontScaleAdjustment

    // Compute height from actual wrapping
    let wrappedLines = wrapText(text, width: screenTextBoxWidth, fontSize: screenFontSize)
    let screenTextBoxHeight = CGFloat(wrappedLines.count) * screenFontSize * 1.2

    return CGRect(x: screenX, y: screenY, width: screenTextBoxWidth, height: screenTextBoxHeight)
}
```

**Key Differences:**
- ❌ **No NSAttributedString**: DTS uses simple character-based estimation
- ❌ **No System APIs**: Drawsana uses `boundingRect(with:options:context:)`, DTS custom wrapping
- ✅ **Similar Logic**: Both check explicit width flag before auto-sizing
- ⚠️ **Accuracy**: Drawsana's NSAttributedString is more accurate for complex text

---

### **5. Hit Testing**

#### Drawsana's Hit Testing:
```swift
class TextTool {
    func hitTest(point: CGPoint) -> TextShape? {
        for shape in shapes.reversed() {  // Top-most first
            let bounds = shape.computeBounds()  // ← Uses computed bounds
            let transformedBounds = bounds.applying(shape.transform.affineTransform)

            if transformedBounds.contains(point) {
                return shape
            }
        }
        return nil
    }
}
```

#### DTS App's Hit Testing:
```swift
private func findTextAnnotationAtScreenPoint(...) -> Int? {
    for (index, annotation) in photo.annotations.enumerated().reversed() {
        guard annotation.type == .text else { continue }

        // Use computed bounds (matches rendering)
        let screenRect = computeTextBounds(for: annotation, scale: scale, offset: offset)

        let tolerance: CGFloat = 20.0
        let hitTestRect = screenRect.insetBy(dx: -tolerance, dy: -tolerance)

        if hitTestRect.contains(screenPoint) {
            return index
        }
    }
    return nil
}
```

**Key Differences:**
- ❌ **No Transform Application**: DTS doesn't apply rotation/scale transforms to hit bounds
- ✅ **Uses Computed Bounds**: Both call bounds computation for accurate hit testing
- ✅ **Top-most First**: Both iterate in reverse order
- ✅ **Hit Tolerance**: DTS adds 20px tolerance, Drawsana varies by tool

---

### **6. Editing Flow**

#### Drawsana's Edit Lifecycle:
```swift
protocol TextToolDelegate {
    func textToolPointWasSelected(_ textTool: TextTool, text: inout String, point: CGPoint)
    func textToolWillUseEditingView(_ textTool: TextTool) -> DrawsanaTextEditingView
    func textToolDidTapAway(from textTool: TextTool)
}

class TextTool {
    func beginEditing(shape: TextShape) {
        shape.isBeingEdited = true  // ← Explicit editing state
        let editingView = delegate.textToolWillUseEditingView(self)
        editingView.text = shape.text
        // ... show editing UI ...
    }

    func endEditing(shape: TextShape, text: String) {
        shape.text = text
        shape.isBeingEdited = false

        // Auto-adjust width if not explicitly set
        if shape.explicitWidth == nil {
            let newBounds = computeBounds()
            // Width auto-adjusts based on content
        }
    }
}
```

#### DTS App's Edit Lifecycle:
```swift
// State-based with @State variables
@State private var selectedTextAnnotationIndex: Int? = nil
@State private var editingTextAnnotationIndex: Int? = nil  // ← Separate editing state
@State private var textInput = ""

// In view:
TextEditorOverlay(
    text: $textInput,
    onDone: {
        photo.annotations[editIndex].text = textInput

        // Auto-adjust width if not explicitly set (NEW - matches Drawsana)
        if !photo.annotations[editIndex].hasExplicitWidth {
            let newText = textInput.isEmpty ? "Text" : textInput
            let fontSize = photo.annotations[editIndex].fontSize ?? 20.0
            let estimatedWidth = CGFloat(newText.count) * fontSize * 0.6
            photo.annotations[editIndex].textBoxWidth = min(estimatedWidth, 400.0)
        }

        editingTextAnnotationIndex = nil
        selectedTextAnnotationIndex = editIndex
    }
)
```

**Key Differences:**
- ❌ **No Delegate Pattern**: DTS uses closure callbacks, Drawsana uses delegates
- ❌ **No `isBeingEdited` Flag**: DTS uses separate state variable (`editingTextAnnotationIndex`)
- ✅ **Similar Auto-Width Logic**: Both adjust width when not explicitly set
- ✅ **Two-Stage Selection**: Both distinguish between "selected" and "editing"

---

## What's Missing from DTS App

### ❌ **1. Rotation Support**
- Drawsana: Full rotation via `ResizeAndRotateHandler`
- DTS: Only font size resize, no rotation

### ❌ **2. Transform System**
- Drawsana: Uses `CGAffineTransform` for position/rotation/scale
- DTS: Simple `CGPoint` position only

### ❌ **3. Tool Context/Undo**
- Drawsana: Full undo/redo with operation history
- DTS: Basic "undo last annotation" only

### ❌ **4. Delegate Customization**
- Drawsana: Rich delegate protocol for custom behavior
- DTS: Hardcoded behavior

### ❌ **5. Multi-Selection**
- Drawsana: Can select/move multiple shapes
- DTS: Single selection only

### ❌ **6. Alignment/Distribution Tools**
- Drawsana: Has alignment helpers
- DTS: Manual positioning only

---

## What DTS App Does Well

### ✅ **1. SwiftUI Integration**
- Native SwiftUI means automatic dark mode, accessibility, etc.
- Drawsana requires bridging to SwiftUI

### ✅ **2. Photo-Specific Features**
- GPS watermarking
- Jobber CRM integration
- Quote PDF generation

### ✅ **3. Simplified Model**
- No complex transform math
- Easier to persist (Codable)
- Smaller learning curve

### ✅ **4. Recent Improvements**
- Added `hasExplicitWidth` (matches Drawsana pattern)
- Added `computeTextBounds()` (matches Drawsana pattern)
- Added drag mode tracking (matches Drawsana handler separation)
- Auto-width adjustment on edit (matches Drawsana behavior)

---

## Summary: Philosophical Differences

### Drawsana's Approach
**"Full-featured annotation library with maximum flexibility"**
- Class-based, UIKit architecture
- Extensive delegate protocols
- Complex but powerful transform system
- Designed for general-purpose drawing apps

### DTS App's Approach
**"Streamlined photo annotation for construction quotes"**
- Struct-based, SwiftUI architecture
- Inline closures and @State
- Simple position-only model
- Designed for specific business use case

---

## Recommended Next Steps

### High Priority (Close Gaps with Drawsana)
1. ✅ **DONE**: Add explicit width tracking
2. ✅ **DONE**: Implement bounds computation
3. ✅ **DONE**: Separate drag handler modes
4. ✅ **DONE**: Auto-width on content change

### Medium Priority (Nice to Have)
5. ⏳ **TODO**: Add rotation support (complex math required)
6. ⏳ **TODO**: Improve text measurement (use NSAttributedString)
7. ⏳ **TODO**: Add alignment guides

### Low Priority (DTS-Specific)
8. ⏳ **TODO**: Better undo/redo system
9. ⏳ **TODO**: Multi-selection support
10. ⏳ **TODO**: Custom text styles (bold/italic)

---

## Testing Comparison

### What to Test Against Drawsana Behavior

| Feature | Drawsana Expected | DTS Current Status |
|---------|-------------------|-------------------|
| New text auto-sizes | ✅ Yes | ✅ Yes (after fix) |
| Manual resize locks width | ✅ Yes | ✅ Yes (after fix) |
| Edit preserves manual width | ✅ Yes | ✅ Yes (after fix) |
| Hit detection accurate | ✅ Yes | ✅ Yes (after fix) |
| Rotation support | ✅ Yes | ❌ No (not needed?) |
| Multi-line wrapping | ✅ Accurate | ⚠️ Estimated |

---

**Conclusion**: DTS App now implements the **core patterns** from Drawsana (explicit width, bounds computation, handler separation) but in a SwiftUI-idiomatic way. The main missing features (rotation, transforms) are by design for the specific use case.
