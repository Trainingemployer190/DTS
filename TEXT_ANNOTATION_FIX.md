# Text Annotation Fix & Enhancements - October 6, 2025

## Issue
Text annotations on photos were not appearing in the correct position when the annotated image was saved. The text would appear centered correctly in the editor view, but when saved to a final image, the text position would be off.

## Enhancements Added
1. **Adjustable Font Size** - Added slider control (20-60pt) for text size
2. **Haptic Feedback** - Vibration confirmation when annotation is selected
3. **Improved Selection Logic** - More accurate hit detection for text annotations
4. **Cleaner Code** - Removed debug logging, simplified state management

## Root Cause
The issue was caused by a mismatch in anchor points between two different drawing methods:

1. **SwiftUI Canvas Drawing** (preview/editor view):
   - Uses `context.draw(Text(...), at: point)`
   - This method centers the text at the given point

2. **UIKit/CoreGraphics Drawing** (final saved image):
   - Uses `NSAttributedString.draw(at: point)`
   - This method draws from the **top-left corner** at the given point

Since the same `point` coordinate was used in both methods but they have different anchor points, the text appeared in different positions.

## Solution
Modified `QuotePhotoAnnotationEditor.swift` (lines 750-761) to adjust the drawing position when saving the final image:

```swift
case .text:
    if let point = points.first, let text = annotation.text {
        // Scale text size proportionally
        let scaledFontSize = 32 * scaleFactor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: scaledFontSize),
            .foregroundColor: color
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // Adjust position to center the text (NSAttributedString draws from top-left)
        // SwiftUI's context.draw(Text) uses center anchoring, so we need to match that
        let adjustedPoint = CGPoint(
            x: point.x - textSize.width / 2,
            y: point.y - textSize.height / 2
        )
        attributedString.draw(at: adjustedPoint)
    }
```

The fix:
1. Calculates the text size using `attributedString.size()`
2. Adjusts the drawing point by subtracting half the width and height
3. This centers the text at the original point, matching the SwiftUI Canvas behavior

## Files Modified
- `/Users/chandlerstaton/Desktop/DTS APP/DTS App/DTS App/Views/QuotePhotoAnnotationEditor.swift`

## Testing
Build and run the app with:
```bash
# Build
xcodebuild -project "DTS App/DTS App.xcodeproj" -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath build clean build

# Run
xcrun simctl install 'iPhone 16 Pro' "build/Build/Products/Debug-iphonesimulator/DTS App.app"
xcrun simctl launch 'iPhone 16 Pro' "DTS.DTS-App"
```

## Note
`PhotoDetailView.swift` already had the correct implementation for text centering (lines 345-362), which was used as a reference for this fix. This same centering logic is used when sharing/exporting photos from the job photo gallery.

## Related Components
- **QuotePhotoAnnotationEditor**: Used for annotating photos in quote drafts (before syncing to Jobber)
- **PhotoAnnotationEditor**: Used for annotating job photos (persisted in SwiftData)
- **PhotoDetailView**: Displays photos with annotations and handles sharing/exporting
