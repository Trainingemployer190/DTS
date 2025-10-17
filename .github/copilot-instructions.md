# DTS App - AI Coding Agent Instructions

## Project Overview
**DTS App** is a professional iOS SwiftUI application for gutter installation and quote management, deeply integrated with Jobber CRM via GraphQL API. Built with SwiftUI (iOS 18+), SwiftData, and OAuth 2.0 authentication.

**Current Branch:** `feature/text-resize-improvements` - Photo annotation features with advanced text editing

**CURRENT PRIORITY:** Text annotation system needs to work properly - focus on coordinate conversion, text positioning, and user interaction bugs before adding new features.

## Critical Architecture Patterns

### 1. GraphQL Integration (ALWAYS VALIDATE FIRST)
**Before ANY GraphQL modification**, reference these files:
- `DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt` (60,218+ lines - complete schema)
- `DTS App/DTS App/Docs/GraphQL/JOBBER_API_REFERENCE.md` (structured field mappings)
- `DTS App/DTS App/Docs/GraphQL/The Jobber GraphQL API_*.pdf` (technical guide)

**Key Rules:**
- Jobber GraphQL returns **Base64-encoded IDs** (e.g., `Z2lkOi8vSm9iYmVyL0NsaWVudC84MDA0NDUzOA==`)
- Web URLs require **numeric IDs only** - decode Base64 to extract: `gid://Jobber/Client/80044538` → `80044538`
- Use `extractNumericId()` from `DataModels.swift` for URL construction
- Client URLs format: `https://secure.getjobber.com/clients/{numericId}`
- **Always validate field names exist in schema before suggesting changes**

### 2. Data Layer Architecture
**SwiftData Models** (`@Model` macro):
- `AppSettings` - Single source of truth for pricing/settings
- `QuoteDraft` - Combines `@Model` + `ObservableObject` for reactive quote editing
- `LineItem`, `PhotoRecord`, `OutboxOperation` - Supporting models

**API Models** (No `@Model`):
- `JobberJob` - API responses, uses `class` not `@Model` to avoid SwiftData conflicts
- All GraphQL response types live in `JobberAPI.swift` (2,584 lines)

**State Management:**
- `JobberAPI: ObservableObject` - Singleton for all Jobber interactions
- `AppRouter: ObservableObject` - Tab navigation state
- `PhotoCaptureManager: ObservableObject` - Camera/location services
- `TextHandlerManager: ObservableObject` - Drawsana-inspired annotation state management

### 3. Pricing Engine Logic
**Critical Formula** (`PricingEngine.swift`):
```swift
// Subtotal = Materials + Labor + AdditionalItems
// Markup applied to SUBTOTAL (not individual components)
// Proportional distribution maintains pricing ratios for Jobber sync
```

**Known Issue Fixed (Beta 2):** Jobber API expects final marked-up prices distributed proportionally across line items, not base costs. See `CHANGELOG.md` for details on proportional price distribution logic.

### 4. Location Services Pattern
**PhotoCaptureManager** uses continuous location updates:
- `startUpdatingLocation()` runs continuously (50m distance filter)
- Location pre-loaded before photo capture (no "Getting location..." delays)
- See `LOCATION_FIX_SUMMARY.md` for implementation details

### 5. Photo Upload Workflow
Photos follow this flow (`JOB_PHOTO_UPLOAD_FEATURE.md`):
1. Capture via camera or photo library
2. Add GPS watermark with `PhotoCaptureManager.addWatermark()`
3. Store in `CapturedPhoto` model with `jobId` or `quoteDraftId`
4. Upload to imgbb (third-party service)
5. Attach to Jobber via `jobCreateNote` or quote line items

### 6. Photo Annotation System - TEXT ANNOTATION FOCUS ⚠️
**CRITICAL: Text positioning bugs are the main issue - fix these before new features**

**Core Architecture:**
- `PhotoAnnotationCanvas.swift` - Handles coordinate conversion (normalized 0..1 ↔ view space)
- `PhotoAnnotationEditor.swift` (1,260 lines) - Main annotation interface
- `InlineTextAnnotationEditor.swift` - Simplified text-only editor

**Text Annotation Critical Issues to Debug:**

1. **Coordinate System Consistency** - THE ROOT CAUSE OF MOST BUGS:
   ```swift
   // STORAGE: All annotations stored in normalized coordinates (0..1)
   annotation.position = CGPoint(x: 0.5, y: 0.5) // Center of image

   // DISPLAY: Must convert to view coordinates for rendering
   let converters = CanvasConverters(
       toView: { normalized in /* 0..1 → screen pixels */ },
       toNormalized: { viewPoint in /* screen pixels → 0..1 */ }
   )
   let screenPoint = converters.toView(annotation.position)

   // SAVING: Must convert back and adjust for text center alignment
   // Text.draw() centers text, but NSAttributedString.draw(at:) draws from top-left
   let adjustedPoint = CGPoint(
       x: point.x - textSize.width / 2,   // Center horizontally
       y: point.y - textSize.height / 2   // Center vertically
   )
   ```

2. **Font Size Scaling Issues**:
   - `annotation.size` stores font size in IMAGE space (e.g., 32pt on 4000px wide image)
   - Must scale for display: `let screenFontSize = annotation.size * scale`
   - Minimum readable size: Always render at least 16pt on screen
   - When saving: Use original `annotation.size` directly (no scaling)

3. **Text Interaction State Machine**:
   ```swift
   @State private var selectedTextAnnotationIndex: Int?  // Shows blue border + handles
   @State private var editingTextAnnotationIndex: Int?   // Shows text field + keyboard

   // Tap once: selectedTextAnnotationIndex = index (select mode)
   // Tap twice: editingTextAnnotationIndex = index (edit mode)
   // Drag text body: Update position, stay in select mode
   // Drag resize handle: Update fontSize, set hasExplicitWidth = true
   ```

4. **Common Text Bugs to Watch For**:
   - **Position Drift**: Text appears in different spot after save → Check center alignment adjustment
   - **Size Mismatch**: Text too small/large after save → Verify scale factor consistency
   - **Tap Not Working**: Can't select text → Check hit detection radius calculation
   - **Handle Positioning**: Resize handles in wrong place → Verify view coordinate conversion
   - **Editing Fails**: Keyboard doesn't appear → Check `editingTextAnnotationIndex` is set

5. **Text Annotation Data Model** (in `DataModels.swift`):
   ```swift
   struct PhotoAnnotation: Codable {
       var type: AnnotationType      // .text for text annotations
       var points: [CGPoint]          // Usually single point [position]
       var text: String?              // The actual text content
       var position: CGPoint          // NORMALIZED (0..1) position
       var size: CGFloat              // Font size in IMAGE space
       var fontSize: CGFloat?         // Optional font size (prefer using .size)
       var hasExplicitWidth: Bool     // True if user manually resized width
       // ... other fields
   }
   ```

**Debug Workflow for Text Issues:**
1. Add logging to `converters.toView()` and `converters.toNormalized()` - verify conversion math
2. Log `annotation.position` vs `screenPoint` - should be consistent during display
3. Check `scale` factor calculation - should match between editor and save operation
4. Verify text size calculation matches between SwiftUI Text and UIFont rendering
5. Test tap point → normalized → view conversion round-trip

**When Fixing Text Bugs:**
- ✅ Always test: Create text → Save → Reopen editor → Verify position matches
- ✅ Test different image sizes (portrait/landscape, small/large)
- ✅ Test font sizes (minimum 12pt, maximum 72pt)
- ✅ Test edge cases (text near image borders)
- ❌ Don't add new features until core positioning works reliably

### 7. Photo Library & Selection Mode
**PhotoLibraryView** - 4th tab in main navigation:
- Grid view with search (title/notes/tags/location)
- Selection mode: Multi-select with share/delete actions
- "Clear All" for bulk deletion
- Orphaned photo cleanup in Quote History → Storage Info

**Storage Locations:**
- Temporary: `/tmp/DTS_Photos/` (quote draft photos)
- Documents: `/Documents/` (photo library photos)

## Build & Development Workflows

### VS Code Tasks (Preferred)
- **Build:** `Cmd+Shift+B` → Runs "Build iOS Simulator" task
- **Run:** Command Palette → "Run on Simulator" (auto-builds first)
- **Clean:** "Clean Build Folder" task removes `build/` artifacts
- **Discover:** "Discover Project Info" lists schemes/simulators

### Configuration
Edit `.vscode/tasks.json` inputs to change:
- `projectPath`: "DTS App/DTS App.xcodeproj"
- `schemeName`: "DTS App"
- `simulatorName`: "iPhone 16 Pro"

### Manual Xcode Build
```bash
cd "DTS App"
xcodebuild -project "DTS App.xcodeproj" -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath ../build clean build
```

## Key File Responsibilities

| File | Purpose |
|------|---------|
| `JobberAPI.swift` | OAuth flow, GraphQL queries, token refresh, quote/job sync |
| `DataModels.swift` | SwiftData schemas, Jobber API models, ID extraction, PhotoAnnotation |
| `PricingEngine.swift` | Markup calculations, profit margins, proportional distribution |
| `PhotoCaptureManager.swift` | Camera, location services, GPS watermarking |
| `PDFGenerator.swift` | Quote PDF generation with photos |
| `MainContentView.swift` | TabView root with SwiftData model container |
| `DTSApp.swift` | App entry point, background token refresh |
| `PhotoAnnotationCanvas.swift` | Coordinate conversion (normalized ↔ view space) |
| `PhotoAnnotationEditor.swift` | Multi-tool annotation system (1,260 lines) |
| `InlineTextAnnotationEditor.swift` | Simplified text-only editor |
| `TextHandlerManager.swift` | State management for text interaction modes |
| `PhotoLibraryView.swift` | 4th tab - photo grid, search, selection mode |

## Common Patterns

### Accessing Settings
```swift
@Query private var settings: [AppSettings]
var currentSettings: AppSettings {
    settings.first ?? AppSettings()
}
```

### Creating GraphQL Query
```swift
// 1. Validate fields in jobber_schema.graphql.txt
// 2. Follow existing patterns in JobberAPI.swift
let query = """
query GetData($id: ID!) {
  node(id: $id) {
    ... on Request {
      id
      client { name }  # ← Verify nested fields exist
    }
  }
}
"""
```

### Handling Jobber IDs
```swift
// Extract numeric ID for web URLs
let numericId = extractNumericId(from: base64JobId)
let url = "https://secure.getjobber.com/clients/\(numericId)"
```

## Testing & Debugging

### Test on Real Device
Location services have limited simulator functionality. For GPS watermarking:
- Use real iPhone/iPad
- Grant "While Using App" location permission
- First location fix takes a few seconds

### Debug Logging
- GraphQL responses: Check console for ID transformations
- Pricing: `PricingEngine` logs detailed breakdowns
- Location: `PhotoCaptureManager` logs geocoding results

## OAuth Setup (Jobber Integration)
**CRITICAL: DO NOT MODIFY OAuth flow structure - it's working and fragile**

OAuth credentials in `JobberAPI.swift` (lines ~94-96):
```swift
private let clientId = "bc74e0a3-3f65-4373-b758-a512536ded90"
private let clientSecret = "c4cc587785949060e4dd052e598a702d0ed8e91410302ceed2702d30413a6c03"
private let redirectURI = "https://trainingemployer190.github.io/dtsapp-oauth-redirect/"
```

**Required Configuration Points:**
1. **Redirect URI** must be exactly `https://trainingemployer190.github.io/dtsapp-oauth-redirect/`
   - Matches Jobber Developer Portal configuration
   - GitHub Pages handles OAuth callback redirect

2. **URL Scheme** in `Info.plist`:
   - Scheme: `dts-app` (for deep linking back to app)
   - Callback pattern: `dts-app://oauth/callback`

3. **OAuth Scopes** (line ~97):
   ```swift
   private let scopes = "read_clients write_clients read_requests write_requests read_quotes write_quotes read_jobs write_jobs read_scheduled_items write_scheduled_items"
   ```
   - All scopes required for full CRM integration
   - Do not reduce scope list - features depend on these permissions

**When Adding OAuth Features:**
- ✅ Add new API calls using existing `accessToken`
- ✅ Extend `JobberAPI` methods following existing patterns
- ❌ DO NOT change redirect URI format
- ❌ DO NOT modify `ASWebAuthenticationSession` flow in `startOAuthFlow()`
- ❌ DO NOT alter token storage/refresh logic (uses Keychain + UserDefaults)

## Recent Major Changes
- **Beta 2 (Dec 2024):** Fixed pricing discrepancy with Jobber quotes via proportional distribution
- **Location Fix:** Switched from one-time `requestLocation()` to continuous updates
- **Photo Upload:** Added two-option menu (camera + library) with auto-upload to Jobber
- **Photo Annotation (Oct 2025):** Drawsana-inspired multi-tool editor with text/drawing annotations
- **Photo Library:** New 4th tab with search, selection mode, share/delete functionality
- **Text Interactions:** Tap-to-select, drag-to-move, tap-again-to-edit pattern for text annotations

## Documentation References
- `README.md` - Setup, tasks, Jobber API configuration
- `CHANGELOG.md` - Version history, critical bug fixes
- `JOB_PHOTO_UPLOAD_FEATURE.md` - Photo workflow implementation
- `LOCATION_FIX_SUMMARY.md` - Location services architecture
- `PHOTO_ANNOTATION_IMPLEMENTATION.md` - Complete annotation feature overview
- `DRAWSANA_REFACTOR_SUMMARY.md` - Text annotation architecture patterns
- `TEXT_ANNOTATION_INTERACTION_GUIDE.md` - User interaction design patterns
- `PHOTO_SELECTION_QUICK_GUIDE.md` - Multi-select feature documentation
- `PHOTO_CLEANUP_FEATURE.md` - Storage management and orphaned photo cleanup

---

**When in doubt:** Search the GraphQL schema first, follow existing patterns in `JobberAPI.swift`, and test pricing calculations against `PricingEngine` logic.
