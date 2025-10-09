# DTS App - AI Coding Agent Instructions

## Project Overview
**DTS App** is a professional iOS SwiftUI application for gutter installation and quote management, deeply integrated with Jobber CRM via GraphQL API. Built with SwiftUI (iOS 18+), SwiftData, and OAuth 2.0 authentication.

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
| `DataModels.swift` | SwiftData schemas, Jobber API models, ID extraction |
| `PricingEngine.swift` | Markup calculations, profit margins, proportional distribution |
| `PhotoCaptureManager.swift` | Camera, location services, GPS watermarking |
| `PDFGenerator.swift` | Quote PDF generation with photos |
| `MainContentView.swift` | TabView root with SwiftData model container |
| `DTSApp.swift` | App entry point, background token refresh |

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

## Documentation References
- `README.md` - Setup, tasks, Jobber API configuration
- `CHANGELOG.md` - Version history, critical bug fixes
- `JOB_PHOTO_UPLOAD_FEATURE.md` - Photo workflow implementation
- `LOCATION_FIX_SUMMARY.md` - Location services architecture
- Existing `.copilot-instructions.md` - GraphQL-specific rules (preserve this)

---

**When in doubt:** Search the GraphQL schema first, follow existing patterns in `JobberAPI.swift`, and test pricing calculations against `PricingEngine` logic.
