# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DTS App is a professional iOS application for gutter installation quote management, built with SwiftUI (iOS 18+) and deeply integrated with Jobber CRM via GraphQL API. The app handles quote calculations, photo annotation, PDF generation, and bidirectional sync with Jobber.

**Current Branch**: `feature/text-resize-improvements` - Photo annotation features with text editing capabilities.

## Build Commands

### Primary Development Workflow (VS Code)
```bash
# Build for iOS Simulator (default build task)
# Shortcut: Cmd+Shift+B
xcodebuild -project "DTS App/DTS App.xcodeproj" \
  -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build

# Clean build artifacts
rm -rf build

# Discover available schemes and simulators
xcodebuild -list -project "DTS App/DTS App.xcodeproj"
xcrun simctl list devices | grep -E '(iPhone|iPad)' | grep -v 'unavailable'

# Install and run on simulator
xcrun simctl boot "iPhone 16 Pro"
xcrun simctl install "iPhone 16 Pro" "build/Build/Products/Debug-iphonesimulator/DTS App.app"
xcrun simctl launch "iPhone 16 Pro" "DTS.DTS-App"
```

### Alternative (Xcode)
```bash
cd "DTS App"
open "DTS App.xcodeproj"
```

**Note**: VS Code tasks are configured in `.vscode/tasks.json` for seamless development without Xcode.

## High-Level Architecture

### Data Layer - SwiftData Models
The app uses SwiftData for local persistence with a clear separation between persistent models and API response objects:

- **`AppSettings`** (@Model) - Single source of truth for pricing configuration (material costs, markup percentages, labor rates)
- **`QuoteDraft`** (@Model + ObservableObject) - Combines SwiftData persistence with reactive state management for quote editing
- **`PhotoRecord`** (@Model) - Stores captured photos with GPS watermarks
- **`LineItem`** (@Model) - Individual quote line items
- **`OutboxOperation`** (@Model) - Queue for deferred API operations

**Important**: `JobberJob` is NOT a `@Model` - it's a plain class for GraphQL response data to avoid SwiftData conflicts.

### State Management - ObservableObjects
- **`JobberAPI`** - Singleton managing OAuth flow, GraphQL queries, token refresh
- **`PhotoCaptureManager`** - Camera/location services with continuous GPS tracking (50m distance filter)
- **`AppRouter`** - Tab navigation state
- **`TextHandlerManager`** - Annotation editing state (Drawsana-inspired architecture)

### GraphQL Integration Critical Rules

**ALWAYS validate against schema before modifying GraphQL code:**
1. Reference `DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt` (60,218+ lines)
2. Jobber GraphQL returns **Base64-encoded IDs** (e.g., `Z2lkOi8vSm9iYmVyL0NsaWVudC84MDA0NDUzOA==`)
3. These decode to format: `gid://Jobber/Type/NumericId`
4. Web URLs require **numeric IDs only** - use `extractNumericId()` from `DataModels.swift`
5. Client URLs: `https://secure.getjobber.com/clients/{numericId}`

**Example GraphQL query pattern** (from `JobberAPI.swift`):
```swift
let query = """
query GetScheduledItems($first: Int!, $after: String) {
  scheduledItems(first: $first, after: $after) {
    edges {
      node {
        id
        client { id name }  # ← Validate nested fields in schema first
        request { id }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}
"""
```

### Pricing Engine Architecture

The pricing system applies markup to the **subtotal**, not individual line items, with proportional distribution for Jobber sync:

```swift
// Core formula (PricingEngine.swift)
// 1. Subtotal = Materials + Labor + AdditionalItems
// 2. Markup applied to SUBTOTAL (maintains 35% margin by default)
// 3. Proportional distribution across line items for Jobber API
```

**Critical fix in Beta 2**: Jobber API expects final marked-up prices distributed proportionally across line items, not base costs. See `CHANGELOG.md`.

### Photo Annotation System - Coordinate Conversion

The annotation system stores all coordinates in **normalized space (0..1)** and converts to view coordinates for display:

**Core architecture** (`PhotoAnnotationCanvas.swift`):
```swift
// STORAGE: Normalized coordinates (0..1)
annotation.position = CGPoint(x: 0.5, y: 0.5) // Center of image

// DISPLAY: Convert to view space
let converters = CanvasConverters(
    toView: { normalized in /* 0..1 → screen pixels */ },
    toNormalized: { viewPoint in /* screen pixels → 0..1 */ }
)
let screenPoint = converters.toView(annotation.position)

// SAVING: Adjust for text center alignment
// Text.draw() centers text, but NSAttributedString.draw(at:) draws from top-left
let adjustedPoint = CGPoint(
    x: point.x - textSize.width / 2,   // Center horizontally
    y: point.y - textSize.height / 2   // Center vertically
)
```

**Text annotation scaling**:
- `annotation.size` stores font size in IMAGE space (e.g., 32pt on 4000px wide image)
- Must scale for display: `let screenFontSize = annotation.size * scale`
- Minimum readable size: Always render at least 16pt on screen

**Critical files**:
- `PhotoAnnotationCanvas.swift` - Coordinate conversion
- `PhotoAnnotationEditor.swift` (2,204 lines) - Multi-tool annotation interface
- `QuotePhotoAnnotationEditor.swift` (2,311 lines) - Quote-specific annotation editor
- `TextAnnotationHandlers.swift` - Text interaction logic

### OAuth Configuration (DO NOT MODIFY)

The OAuth flow is working and fragile. Configuration in `JobberAPI.swift:94-96`:
```swift
private let clientId = "bc74e0a3-3f65-4373-b758-a512536ded90"
private let clientSecret = "c4cc587785949060e4dd052e598a702d0ed8e91410302ceed2702d30413a6c03"
private let redirectURI = "https://trainingemployer190.github.io/dtsapp-oauth-redirect/"
```

**Required scopes**: `read_clients write_clients read_requests write_requests read_quotes write_quotes read_jobs write_jobs read_scheduled_items write_scheduled_items`

**URL scheme in Info.plist**: `dts-app` (for deep linking: `dts-app://oauth/callback`)

## Key File Responsibilities

| File | Lines | Purpose |
|------|-------|---------|
| `JobberAPI.swift` | 2,583 | OAuth flow, GraphQL queries, token refresh, quote/job sync |
| `DataModels.swift` | ~500 | SwiftData schemas, API models, ID extraction, PhotoAnnotation struct |
| `PricingEngine.swift` | ~300 | Markup calculations, proportional distribution, profit margins |
| `PhotoCaptureManager.swift` | ~550 | Camera, continuous location tracking, GPS watermarking |
| `PDFGenerator.swift` | ~600 | Quote PDF generation with photos and pricing details |
| `PhotoAnnotationCanvas.swift` | ~150 | Coordinate conversion (normalized ↔ view space) |
| `MainContentView.swift` | 74 | TabView root with 5 tabs: Home, Quotes, History, Photos, Settings |
| `DTSApp.swift` | 86 | App entry point, background token refresh via BGTaskScheduler |

## Common Development Patterns

### Accessing Settings
```swift
@Query private var settings: [AppSettings]
var currentSettings: AppSettings {
    settings.first ?? AppSettings()
}
```

### Creating a New GraphQL Query
```swift
// 1. ALWAYS validate fields in jobber_schema.graphql.txt first
// 2. Follow existing patterns in JobberAPI.swift
// 3. Handle Base64 ID conversion for web URLs
// 4. Add proper error handling and logging

let query = """
query GetData($id: ID!) {
  node(id: $id) {
    ... on Client {
      id
      name
      # ← Verify all nested fields exist in schema
    }
  }
}
"""
```

### Handling Coordinate Conversion in Annotations
```swift
// Use CanvasConverters from PhotoAnnotationCanvas
let screenPoint = converters.toView(annotation.position)
let normalizedPoint = converters.toNormalized(tapLocation)

// Always adjust for text center alignment when saving
let textSize = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: fontSize)])
let centeredPosition = CGPoint(
    x: position.x - textSize.width / 2,
    y: position.y - textSize.height / 2
)
```

## Critical Testing Considerations

### Location Services
- Limited simulator functionality - **test on real device** for GPS watermarking
- Grant "While Using App" permission
- First location fix takes a few seconds (continuous tracking pre-loads location)

### Text Annotation Testing Checklist
When fixing or adding text annotation features:
- [ ] Create text → Save → Reopen editor → Verify position matches
- [ ] Test different image sizes (portrait/landscape, small/large)
- [ ] Test font sizes (minimum 12pt, maximum 72pt)
- [ ] Test edge cases (text near image borders)
- [ ] Verify tap detection works reliably
- [ ] Check resize handles position correctly

### Pricing Verification
- Use debug logging in `PricingEngine` to verify markup calculations
- Cross-reference final totals with Jobber quotes
- Test proportional distribution logic with various line item combinations

## Known Issues & Debugging

### Text Annotation Position Drift
**Symptom**: Text appears in different location after save/reopen
**Root Cause**: Incorrect center alignment adjustment or scale factor mismatch
**Debug**: Add logging to `converters.toView()` and verify adjustment calculation

### GraphQL Field Errors
**Symptom**: API returns null or "field does not exist" error
**Root Cause**: Field name not validated against schema
**Fix**: Search `jobber_schema.graphql.txt` for correct field names

### Pricing Discrepancy with Jobber
**Symptom**: Quote total in Jobber differs from app calculation
**Root Cause**: Not using proportional distribution for line item prices
**Fix**: Reference proportional distribution logic in `PricingEngine.swift`

## Recent Major Changes

- **Beta 2 (Dec 2024)**: Fixed pricing discrepancy with proportional distribution
- **Location Fix**: Continuous GPS updates instead of one-time `requestLocation()`
- **Photo Annotation (Oct 2024)**: Drawsana-inspired multi-tool editor with text/shapes
- **Photo Library**: 4th tab with search, selection mode, share/delete functionality
- **Text Interactions**: Tap-to-select, drag-to-move, tap-again-to-edit pattern

## Documentation References

- `README.md` - Setup, VS Code tasks, Jobber OAuth configuration
- `CHANGELOG.md` - Version history, critical bug fixes
- `.copilot-instructions.md` - GraphQL integration guidelines
- `.github/copilot-instructions.md` - Detailed AI coding agent instructions
- `PHOTO_ANNOTATION_IMPLEMENTATION.md` - Complete annotation feature overview
- `DRAWSANA_REFACTOR_SUMMARY.md` - Text annotation architecture patterns
- `JOB_PHOTO_UPLOAD_FEATURE.md` - Photo workflow implementation

## Important Notes

1. **GraphQL Changes**: Always validate against schema before modifying queries
2. **OAuth Flow**: Do NOT modify - it's working and fragile
3. **Pricing Logic**: Test against Jobber API after any calculation changes
4. **Text Annotations**: Current priority - fix coordinate conversion bugs before new features
5. **Location Services**: Use continuous tracking, not one-time requests
