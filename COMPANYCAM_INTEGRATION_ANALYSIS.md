# CompanyCam Integration Analysis for DTS App

## Executive Summary
CompanyCam offers a REST API that could replace your current imgbb photo upload workflow. The integration would provide better organization, project-based photo management, and native integration capabilities with other contractor tools.

## Current DTS App Photo Architecture

### Existing Flow (imgbb)
```
1. Capture photo with GPS watermark (PhotoCaptureManager)
2. Upload to imgbb (third-party image hosting)
3. Get image URL from imgbb
4. Attach URL to Jobber via jobCreateNote GraphQL mutation
```

**Current Implementation:**
- File: `JobberAPI.swift` lines ~1887-1970
- Service: imgbb API (https://api.imgbb.com/1/upload)
- API Key: Hardcoded `5e439e5a4e3c937ef15899d5efd99b30`
- Format: Multipart form data with JPEG compression (0.9 quality)
- Storage: Centralized image URLs attached to Jobber jobs/quotes

## CompanyCam API Architecture

### Authentication
**Type:** Bearer Token (API Key based)
- Similar to imgbb - simpler than OAuth
- Get API key from CompanyCam account settings
- Add to Authorization header: `Bearer {your_api_key}`

### Key Endpoints

#### 1. **Projects** (equivalent to Jobs)
```
GET  https://api.companycam.com/v2/projects
POST https://api.companycam.com/v2/projects
```
Projects are the primary organizational unit - similar to your Jobber jobs.

#### 2. **Photos**
```
GET  https://api.companycam.com/v2/photos
POST https://api.companycam.com/v2/photos
```
Photos belong to projects and include:
- GPS coordinates (lat/long)
- Timestamps
- Tags/labels
- Comments
- Photo metadata

#### 3. **Additional Features**
- **Tags:** Organize photos (e.g., "Before", "After", "Damage", "Gutter Install")
- **Comments:** Team collaboration on photos
- **Groups:** User organization/permissions
- **Webhooks:** Real-time notifications for photo uploads

## Integration Comparison

| Feature | imgbb (Current) | CompanyCam |
|---------|----------------|------------|
| **Authentication** | API Key (simple) | API Key (Bearer token) |
| **Photo Upload** | ✅ Direct URL | ✅ Structured upload |
| **Organization** | ❌ No structure | ✅ Projects + Tags |
| **GPS/Location** | ✅ Via watermark | ✅ Native coordinates |
| **Metadata** | ❌ None | ✅ Rich metadata |
| **Team Features** | ❌ None | ✅ Comments, sharing |
| **Integration** | ✅ Works with Jobber | ✅ Native integrations |
| **Cost** | Free (with limits) | Paid service |
| **Storage Limits** | Free tier limits | Based on plan |

## Recommended Integration Pattern

### Option 1: Replace imgbb Entirely
**Pros:**
- Better organization and searchability
- Native contractor features (tags, before/after)
- Team collaboration on photos
- Professional photo management

**Cons:**
- Requires CompanyCam subscription
- More complex API (projects, photos, tags)
- Migration needed for existing photos

### Option 2: Dual Integration (Recommended)
Keep both systems with toggle in settings:

```swift
// Add to AppSettings model
var photoUploadService: PhotoUploadService = .imgbb // or .companyCam

enum PhotoUploadService: String, Codable {
    case imgbb = "imgbb"
    case companyCam = "CompanyCam"
}
```

**Benefits:**
- Flexibility for users
- Fallback option if one service fails
- Gradual migration path
- Free option still available

## Implementation Plan

### Phase 1: CompanyCam API Manager (2-3 hours)
Create `CompanyCamAPI.swift` following your existing patterns:

```swift
@MainActor
class CompanyCamAPI: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.companycam.com/v2"

    // Similar structure to JobberAPI
    func uploadPhoto(_ image: UIImage, projectId: String) async -> Result<String, Error>
    func createProject(name: String, address: String) async -> Result<String, Error>
    func listProjects() async -> [CompanyCamProject]
}
```

### Phase 2: Data Models (1 hour)
```swift
// Add to DataModels.swift
struct CompanyCamProject: Codable {
    let id: String
    let name: String
    let address: String
    let coordinates: CLLocationCoordinate2D?
    let jobberJobId: String? // Link to Jobber
}

struct CompanyCamPhoto: Codable {
    let id: String
    let projectId: String
    let url: String
    let coordinates: CLLocationCoordinate2D
    let capturedAt: Date
}
```

### Phase 3: Settings UI (1 hour)
Add toggle to `SettingsView.swift`:
```swift
Picker("Photo Upload Service", selection: $settings.photoUploadService) {
    Text("imgbb (Free)").tag(PhotoUploadService.imgbb)
    Text("CompanyCam").tag(PhotoUploadService.companyCam)
}

if settings.photoUploadService == .companyCam {
    SecureField("CompanyCam API Key", text: $companyCamAPIKey)
}
```

### Phase 4: Upload Logic Update (2 hours)
Modify `JobberAPI.swift` photo upload functions:
```swift
func uploadPhoto(_ image: UIImage) async -> Result<String, Error> {
    let service = getCurrentPhotoUploadService()

    switch service {
    case .imgbb:
        return await uploadImageToImgbb(image)
    case .companyCam:
        return await companyCamAPI.uploadPhoto(image, projectId: currentProjectId)
    }
}
```

## Key Benefits of CompanyCam Integration

### 1. **Project Organization**
- Automatic project creation from Jobber jobs
- Photos grouped by project (not scattered in Jobber notes)
- Easy "show all photos for this job" view

### 2. **Better Photo Management**
- Tag photos: "Before", "After", "Damage", "Install Complete"
- Add comments/notes to specific photos
- Timeline view of all project photos

### 3. **Team Collaboration**
- Multiple team members can upload to same project
- Photo comments for crew communication
- Photo approval workflows

### 4. **Native Features**
- Before/After photo pairing
- GPS coordinates stored natively (not just watermark)
- Photo reports and exports
- Mobile app for field crews

### 5. **Integration Ecosystem**
CompanyCam integrates with:
- Jobber (your CRM) - potential two-way sync
- QuickBooks
- Other contractor tools

## Cost Considerations

### imgbb (Current)
- ✅ Free tier: 32 MB/image, unlimited uploads
- ✅ No subscription needed
- ❌ Limited features
- ❌ No organization

### CompanyCam
- ❌ Paid service: ~$50-150/month depending on plan
- ✅ Professional photo management
- ✅ Team features
- ✅ Unlimited storage (plan dependent)
- ✅ Native integrations

## Migration Strategy

### Hybrid Approach (Low Risk)
1. Keep imgbb as default (free, working)
2. Add CompanyCam as opt-in feature
3. Users choose based on needs:
   - Small operations → imgbb
   - Growing teams → CompanyCam
4. Settings toggle allows switching anytime

### Code Changes Required
```
Files to Modify:
- DataModels.swift (add CompanyCam models)
- JobberAPI.swift (add service selection logic)
- SettingsView.swift (add CompanyCam settings)
- AppSettings model (add service preference)

New Files:
- CompanyCamAPI.swift (API integration)
```

**Estimated Development Time:** 6-8 hours
**Testing Time:** 2-3 hours
**Total Implementation:** ~1-2 days

## Recommendation

**Implement Option 2 (Dual Integration):**

### Immediate Benefits:
- ✅ Current imgbb workflow continues working
- ✅ Adds professional photo management option
- ✅ Flexibility for different user needs
- ✅ Future-proofs the app

### Implementation Priority:
1. **High Priority:** Create CompanyCamAPI.swift (core API)
2. **Medium Priority:** Add settings toggle
3. **Medium Priority:** Project sync with Jobber jobs
4. **Low Priority:** Advanced features (tags, comments)

### Why This Works:
- Matches your Jobber integration pattern (OAuth + API)
- Leverages existing photo capture infrastructure
- No breaking changes to current workflow
- Professional growth path for larger contractors

## Next Steps

1. **Create CompanyCam account** to get API key
2. **Test API endpoints** with simple HTTP calls
3. **Build CompanyCamAPI.swift** following JobberAPI patterns
4. **Add settings UI** for service selection
5. **Test photo upload** to both services
6. **Document** in updated instructions

---

**Questions to Consider:**
1. Do you want to support both services long-term?
2. Should CompanyCam projects auto-create from Jobber jobs?
3. Do you need photo sync back to Jobber (like current flow)?
4. Should the app support viewing CompanyCam photos in-app?

Let me know which direction you'd like to go, and I can help implement it! 🚀
