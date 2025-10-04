# Job Photo Upload Feature - Implementation Summary

## Overview
Updated the job details section to provide two options for photo capture ("Take Photo" and "Choose from Library"), with automatic upload to Jobber as notes - matching the functionality in the quotes section.

## Changes Made

### 1. JobberAPI.swift - Added Job Note Creation
**Location**: `/DTS App/DTS App/Managers/JobberAPI.swift`

#### New Types Added:
```swift
// Job Note Creation Types
struct JobCreateNoteInput {
    let message: String
    let attachments: [NoteAttachmentAttributes]?
}

struct JobNote: Codable {
    let id: String
    let message: String
    let createdAt: String
}

struct JobCreateNoteResponse {
    let jobNote: JobNote?
    let userErrors: [GraphQLError]
}
```

#### New Functions:
- `submitPhotosAsJobNote()` - Main function to upload photos as a job note
  - Uploads photos to imgbb
  - Creates a job note with photo attachments
  - Returns success/failure result

- `createJobNote()` - GraphQL mutation wrapper
  - Calls Jobber's `jobCreateNote` mutation
  - Handles response and errors

### 2. JobViews.swift - Updated Job Detail UI
**Location**: `/DTS App/DTS App/Views/JobViews.swift`

#### JobDetailView Updates:
- Added `@EnvironmentObject var jobberAPI: JobberAPI` for API access
- Added state variables for upload tracking:
  - `isUploadingToJobber` - Shows upload progress
  - `uploadError` - Stores error messages
  - `showingUploadSuccess` - Shows success alert
  - `showingPhotoMenu` - Controls photo menu display

- Added `uploadPhotosToJobber()` function:
  - Filters photos for the current job
  - Calls `submitPhotosAsJobNote()` API
  - Shows success/error alerts with haptic feedback

- Auto-upload integration:
  - Photos automatically upload after capture from camera
  - Photos automatically upload after selection from library

#### New Component: PhotoMenuButton
Replaced the old `CameraButton` with a new menu-based button:
- **Menu Options**:
  - "Take Photo" - Opens camera
  - "Choose from Library" - Opens photo picker
- **Visual Features**:
  - Shows progress indicator during upload
  - Changes text to "Uploading Photos..." during upload
  - Disabled state during upload
  - Gradient background with blue theme
  - Dropdown chevron icon

#### ActionButtonsSection Updates:
- Added `showingPhotoMenu` binding
- Added `isUploadingToJobber` parameter
- Replaced `CameraButton` with `PhotoMenuButton`

### 3. DataModels.swift - Updated CapturedPhoto Model
**Location**: `/DTS App/DTS App/Models/DataModels.swift`

```swift
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    let location: String?
    let quoteDraftId: UUID?
    let jobId: String?  // ← NEW: Track which job the photo belongs to

    init(image: UIImage, location: String? = nil, quoteDraftId: UUID? = nil, jobId: String? = nil)
}
```

### 4. PhotoCaptureManager.swift - Updated Image Processing
**Location**: `/DTS App/DTS App/Managers/PhotoCaptureManager.swift`

Updated `processImage()` to include jobId when creating CapturedPhoto:
```swift
let capturedPhoto = CapturedPhoto(
    image: uiImage,
    location: locationString,
    quoteDraftId: quoteDraftId,
    jobId: jobId  // ← NEW: Pass jobId to track photos
)
```

## How It Works

### User Flow:
1. **Navigate to Job Details** - User clicks on a job from the home tab
2. **Open Photo Menu** - User taps the "Capture Photo" button (now a menu)
3. **Choose Option**:
   - **Take Photo**: Opens camera to capture new photo
   - **Choose from Library**: Opens photo picker to select existing photo
4. **Photo Processing**:
   - Photo is watermarked with timestamp and location
   - Photo is saved locally
   - Photo is tracked with jobId
5. **Auto-Upload**:
   - After photo capture/selection, upload automatically starts
   - Upload indicator shows "Uploading Photos..."
   - Photos are uploaded to imgbb
   - Job note is created in Jobber with photo attachments
6. **Confirmation**:
   - Success: Shows alert "Photos have been uploaded to Jobber as a note"
   - Error: Shows alert with error message
   - Haptic feedback provides tactile confirmation

### Technical Flow:
```
User taps menu → Select option → Capture/Select photo
    ↓
PhotoCaptureManager.processImage()
    ↓
Photo saved with jobId
    ↓
JobDetailView.uploadPhotosToJobber()
    ↓
Filter photos by jobId
    ↓
JobberAPI.submitPhotosAsJobNote()
    ↓
Upload to imgbb → Create job note → Return result
    ↓
Show success/error alert
```

## Features

### ✅ Implemented:
- Menu-based photo capture with two options
- Camera capture integration
- Photo library picker integration
- Automatic upload to Jobber after photo selection
- Photo watermarking with location and timestamp
- Upload progress indicator
- Success/error alerts
- Haptic feedback
- Photos tracked by jobId
- Same workflow as quote photos

### 🎨 UI/UX Improvements:
- Modern menu interface instead of single button
- Visual feedback during upload (progress spinner)
- Clear status messages
- Disabled state during upload to prevent duplicate submissions
- Success confirmation with haptic feedback

## API Integration

### Jobber GraphQL Mutation Used:
```graphql
mutation JobCreateNote($jobId: EncodedId!, $input: JobCreateNoteInput!) {
  jobCreateNote(jobId: $jobId, input: $input) {
    jobNote {
      id
      message
      createdAt
    }
    userErrors {
      message
      path
    }
  }
}
```

### Note Message Format:
```
"Photos uploaded from DTS App on Oct 4, 2025 at 3:23 PM"
```

## Testing Checklist

- [ ] Take photo from camera → Auto-uploads to Jobber
- [ ] Select photo from library → Auto-uploads to Jobber
- [ ] Verify photos appear in Jobber as notes
- [ ] Check location tagging on photos
- [ ] Test error handling (no internet, API errors)
- [ ] Verify upload indicator works correctly
- [ ] Test on real device (camera only works on device)
- [ ] Verify haptic feedback on success
- [ ] Check that menu displays both options
- [ ] Test with multiple photos

## Notes

- Photos are uploaded immediately after capture/selection
- Same imgbb upload service used as in quotes
- Photos are watermarked before upload
- Location services must be enabled for location tagging
- Camera permission required for "Take Photo" option
- Photo library permission required for "Choose from Library" option

## Future Enhancements

Potential improvements:
- Batch photo upload (select multiple from library)
- Offline queue for failed uploads
- Photo preview before upload
- Custom note messages
- Photo compression options
- Delete photos from note
- View uploaded photos in app
