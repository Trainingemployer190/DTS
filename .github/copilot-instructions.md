# DTS App - AI Coding Agent Instructions

## Project Overview
iOS SwiftUI app (iOS 18+) for DTS Gutters & Restoration: gutter quote management + roof material ordering, integrated with Jobber CRM via GraphQL.

**Current Branch:** `roof-order` - Roof material order feature with PDF parsing and Share Extension

## Architecture Quick Reference

### Data Layer (SwiftData)
```
DTS App/DTS App/Models/DataModels.swift     # All @Model definitions + API types
DTS App/DTS App/Services/PricingEngine.swift # Quote markup calculations
```

**SwiftData Models** (`@Model`): `AppSettings`, `QuoteDraft`, `LineItem`, `PhotoRecord`, `RoofMaterialOrder`, `RoofPresetTemplate`

**API-Only Classes** (NOT `@Model`): `JobberJob` - avoids SwiftData conflicts for GraphQL responses

### Tab Structure ([MainContentView.swift](DTS%20App/DTS%20App/MainContentView.swift))
| Tab | View | Purpose |
|-----|------|---------|
| 0 | HomeView | Jobber scheduled jobs |
| 1 | QuoteFormView | Create gutter quotes |
| 2 | QuoteHistoryView | Quote history + storage info |
| 3 | PhotoLibraryView | Photo library with search |
| 4 | RoofMaterialOrderView | Import roof PDFs |
| 5 | SettingsView | App settings + OAuth |

### Key Managers (Singletons)
- `JobberAPI.shared` - OAuth, GraphQL queries, quote/job sync
- `GooglePhotosAPI.shared` - Auto-upload photos to Google Photos
- `PhotoCaptureManager` - Camera, GPS, watermarking

## Critical Patterns

### GraphQL Integration - ALWAYS VALIDATE SCHEMA FIRST
```swift
// Reference: DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt (60k+ lines)

// Jobber returns Base64-encoded IDs
let base64Id = "Z2lkOi8vSm9iYmVyL0NsaWVudC84MDA0NDUzOA=="
// Decodes to: gid://Jobber/Client/80044538

// For web URLs, extract numeric ID only:
let numericId = extractNumericId(from: base64Id)  // → "80044538"
let url = "https://secure.getjobber.com/clients/\(numericId)"
```

### Pricing Engine - Proportional Distribution
```swift
// Subtotal = Materials + Labor + AdditionalItems
// Markup applied to SUBTOTAL (not individual items)
// Line items get proportionally distributed marked-up prices for Jobber sync
```

### Roof PDF Parser - Multi-Format Support
`RoofPDFParser.swift` auto-detects and parses these formats using **both keyword matching and structural analysis**:

| Format | Identifiers | Key Fields |
|--------|-------------|------------|
| **iRoof** | "iRoof", "iroof.com", "Total Squares:", "Area X Pitch" | Total Squares, Ridge, Valley, Rake, Eave, Hip, Step Flashing, Pitch |
| **EagleView** | "EagleView", "Pictometry" | Total Roof Area (sqft), Ridge/Hip, Valley, Rake, Eaves |
| **Hover** | "HOVER", "hover.to" | Same as EagleView |
| **RoofSnap** | "RoofSnap" | Same as iRoof |
| **Generic** | (fallback) | Attempts pattern matching on common measurements |

**Format Detection:** If no explicit brand identifier found, uses structural analysis:
- iRoof: Detected by feet'inches" format (e.g., `166'10"`) + "SQ" or "Pitch X/12"
- EagleView: Detected by "Total Roof Area" or "Facet" + "SF"

**Parsing logic:**
```swift
// Parse sqft FIRST to avoid confusion with SQ (squares)
// "2495.72 sqft" vs "24.96 SQ" - different units!
// Sanity check: squares < 200 for residential, >500 probably sqft

// Feet-inches conversion: "166'10\"" → 166.83 ft
// Handles various quote chars: ' " ′ ″ curly quotes

// Pitch extraction: "4/12" or "4:12" → multiplier lookup
// Multi-pitch: Finds predominant pitch from "Area X Pitch Y/12" breakdown
```

**RoofMeasurements struct fields:**
- `totalSquares`, `totalSqFt` - Area (1 square = 100 sqft)
- `ridgeFeet`, `valleyFeet`, `rakeFeet`, `eaveFeet`, `hipFeet` - Linear measurements
- `stepFlashingFeet` - Wall/chimney flashing
- `pitch`, `pitchMultiplier` - Roof slope
- `lowPitchSqFt`, `lowPitchAreas` - Areas requiring ice & water shield
- `transitionFeet`, `transitionDescriptions` - Where different pitches meet

### Roof Material Calculator
`RoofMaterialCalculator.swift` uses `AppSettings` or `RoofPresetTemplate` for calculation factors:
- Shingles: 3 bundles/square + waste factor
- Underlayment: GAF FeltBuster (1000 sqft/roll)
- Starter Strip: GAF Pro-Start (120 LF/bundle)
- Ridge Cap: GAF Seal-A-Ridge (25 LF/bundle)
- Ice & Water: Auto-add for valleys, low-pitch (<4/12), transitions
- Output format: ABC Supply order list

### Photo Annotations - Coordinate System
```swift
// STORAGE: Normalized coordinates (0..1)
annotation.position = CGPoint(x: 0.5, y: 0.5)  // Center of image

// DISPLAY: Convert to view pixels via CanvasConverters
let screenPoint = converters.toView(annotation.position)

// SAVING: Adjust for text center alignment (NSAttributedString draws from top-left)
let adjustedPoint = CGPoint(
    x: point.x - textSize.width / 2,
    y: point.y - textSize.height / 2
)
```

**Font size scaling:**
- `annotation.size` = font size in IMAGE space (e.g., 32pt on 4000px image)
- Display: `screenFontSize = annotation.size * scale`
- Minimum readable: Always render at least 16pt on screen

**Text interaction state:**
```swift
// Tap once → selectedTextAnnotationIndex (blue border + handles)
// Tap twice → editingTextAnnotationIndex (text field + keyboard)
// Drag body → update position
// Drag handle → update fontSize, set hasExplicitWidth = true
```

## Google Photos Integration
`GooglePhotosAPI.swift` handles auto-upload to shared company account:

**Pre-configured mode** (recommended):
```swift
// Refresh token stored in Keychain (not hardcoded)
GooglePhotosAPI.shared.setPreConfiguredRefreshToken("token")  // One-time setup
// After setup, auto-upload is automatic
```

**Album organization:**
- Photos grouped by job address
- Address shortened for album name: "713 Olive Ave Vista CA" → "713 Olive Ave"
- Album cache prevents duplicate creation

**Scopes required:**
- `photoslibrary.appendonly` - Upload photos
- `photoslibrary` - Create/read albums

**Re-auth flow:** If scope upgrade needed, `needsReauth = true` triggers UI prompt.

## Build Commands

### VS Code (Preferred)
- **Build:** `Cmd+Shift+B`
- **Run:** Tasks → "Run on Simulator" (auto-builds)
- **Clean:** Tasks → "Clean Build Folder"

### Terminal
```bash
xcodebuild -project "DTS App/DTS App.xcodeproj" -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath build clean build
```

## OAuth Configuration (DO NOT MODIFY)
**Jobber OAuth** in `JobberAPI.swift` is working and fragile:
- Redirect URI: `https://trainingemployer190.github.io/dtsapp-oauth-redirect/`
- URL Scheme: `dts-app://oauth/callback`
- Uses ASWebAuthenticationSession + Keychain storage

**Google Photos OAuth** in `GooglePhotosAPI.swift`:
- Client ID: `871965263646-...apps.googleusercontent.com`
- Redirect URI: `com.googleusercontent.apps.871965263646-...:/oauth2redirect`
- Pre-configured mode with shared company account
- Refresh token stored in Keychain via `KeychainManager`

## App Groups & Share Extension
```swift
// Shared container for cross-app data:
let appGroupId = "group.DTS.DTS-App"
SharedContainerHelper.sharedPhotosDirectory  // Persistent photo storage
SharedContainerHelper.pendingPDFDirectory    // PDFs from Share Extension
```

**Share Extension** (`DTS Share Extension/`):
1. User shares PDF from Files/Mail/etc.
2. Extension saves to App Group container
3. Main app detects on launch via `checkForPendingRoofImport()`
4. Auto-navigates to Roof Orders tab with import dialog

## SwiftData Access Pattern
```swift
@Query private var settings: [AppSettings]
var currentSettings: AppSettings {
    settings.first ?? AppSettings()
}
```

## Key Files
| File | Purpose |
|------|---------|
| [JobberAPI.swift](DTS%20App/DTS%20App/Managers/JobberAPI.swift) | OAuth + GraphQL (2,500+ lines) |
| [GooglePhotosAPI.swift](DTS%20App/DTS%20App/Managers/GooglePhotosAPI.swift) | Photo uploads + albums (864 lines) |
| [DataModels.swift](DTS%20App/DTS%20App/Models/DataModels.swift) | All data models (1,000+ lines) |
| [RoofPDFParser.swift](DTS%20App/DTS%20App/Utilities/RoofPDFParser.swift) | Multi-format PDF extraction (669 lines) |
| [RoofMaterialCalculator.swift](DTS%20App/DTS%20App/Utilities/RoofMaterialCalculator.swift) | Material calculations (452 lines) |
| [PhotoAnnotationEditor.swift](DTS%20App/DTS%20App/Views/PhotoAnnotationEditor.swift) | Annotation UI |
| [SharedContainerHelper.swift](DTS%20App/DTS%20App/Utilities/SharedContainerHelper.swift) | App Group storage |

## Git Rules
**NEVER commit autonomously.** Only commit when user explicitly says "commit this" or similar.

## Testing Notes
- **Location:** Test GPS watermarking on **real device** (simulator limited)
- **Roof PDFs:** Test with iRoof, EagleView, Hover sample PDFs in `Iroof PDF/` folder
- **Pricing:** Cross-reference final totals with Jobber quotes
- **Google Photos:** Check album creation and photo upload in shared account
- **Share Extension:** Test PDF import from Files app, Mail attachments

