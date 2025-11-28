# Photo Persistence Setup Guide

## Problem
Photos were being lost every time the app was reinstalled or a new version was tested from Xcode because they were stored in the app's Documents directory, which gets deleted with each new build.

## Solution: App Groups Shared Container
Use iOS App Groups to create a shared storage location that persists across app installations and updates.

---

## Step 1: Enable App Groups in Xcode

### Required Configuration Steps:

1. **Open your Xcode project**
   - Navigate to: `DTS App/DTS App.xcodeproj`
   - Select the "DTS App" target

2. **Add App Groups Capability**
   - Go to the **Signing & Capabilities** tab
   - Click the **+ Capability** button
   - Search for and add **App Groups**

3. **Configure App Group Identifier**
   - In the App Groups section, click the **+** button
   - Enter the identifier: `group.DTS.DTS-App`
   - Make sure the checkbox next to it is checked ✅

4. **Verify Configuration**
   - The identifier should exactly match: `group.DTS.DTS-App`
   - This matches the identifier in `SharedContainerHelper.swift`

### Screenshot Reference:
```
Signing & Capabilities Tab
┌────────────────────────────────────────┐
│ + Capability                           │
│                                        │
│ App Groups                             │
│ ✅ group.DTS.DTS-App                   │
└────────────────────────────────────────┘
```

---

## Step 2: Files Modified

The following files have been updated to use the shared container:

### New Files:
- **`SharedContainerHelper.swift`** - Utility for managing shared photo storage
  - Provides `photosStorageDirectory` for persistent storage
  - Includes migration logic to move existing photos
  - Falls back to Documents if App Groups not configured

### Updated Files:
- **`PhotoCaptureManager.swift`** - Photo capture and storage
  - Line ~308: Changed from Documents to shared container

- **`PhotoLibraryView.swift`** - Photo library and saving
  - Lines ~224, ~703: Changed from Documents to shared container

- **`QuoteHistoryView.swift`** - Orphaned photo cleanup
  - Line ~266: Changed from Documents to shared container

- **`DTSApp.swift`** - App initialization
  - Added automatic photo migration on first launch

---

## Step 3: How It Works

### Storage Location:
- **Before:** `/var/mobile/Containers/Data/Application/{UUID}/Documents/`
  - ❌ Deleted on every reinstall

- **After:** `/var/mobile/Containers/Shared/AppGroup/{GROUP-UUID}/Photos/`
  - ✅ Persists across reinstalls and updates

### Automatic Migration:
On first launch after this update:
1. App checks if migration is needed via `needsMigration()`
2. Copies all existing photos from Documents to shared container
3. Sets `com.dtsapp.photoMigrationCompleted` flag to prevent re-running
4. Logs migration progress to console

### Fallback Behavior:
If App Groups is **not** configured in Xcode:
- App falls back to Documents directory
- Console shows warning: "⚠️ Using Documents directory fallback"
- Photos will still work, but won't persist across reinstalls

---

## Step 4: Testing

### Verify Setup is Working:

1. **Build and run the app:**
   ```bash
   # From workspace root
   xcodebuild -project "DTS App/DTS App.xcodeproj" -scheme "DTS App" \
     -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
     -derivedDataPath build clean build
   ```

2. **Check console logs for confirmation:**
   ```
   ✅ Created shared photos directory: /var/mobile/.../AppGroup/.../Photos
   📦 Found X photos to migrate from Documents
   ✅ Migrated: photo_1234567890.jpg
   ✅ Migration complete: X photos migrated, 0 errors
   ```

3. **Take a test photo:**
   - Capture a photo in the app
   - Note the filename in console logs

4. **Reinstall the app:**
   - Delete the app from simulator/device
   - Build and run again
   - Check Photos tab - your photo should still be there! ✅

### Troubleshooting:

**Photos still disappearing?**
- Check console for: "❌ Failed to access App Group container"
- Verify App Groups capability is enabled in Xcode
- Confirm identifier is exactly: `group.DTS.DTS-App`
- Clean build folder and rebuild

**Migration errors?**
- Check console for specific error messages
- Migration runs only once per install
- To force re-migration, delete app and reinstall

**Storage location verification:**
Add this debug code temporarily:
```swift
print("📂 Photos directory: \(SharedContainerHelper.photosStorageDirectory.path)")
```

---

## Step 5: What Happens Next

### For Existing Users:
- On first launch of updated app, photos automatically migrate
- Migration happens in background (< 1 second for typical photo count)
- Old photos remain in Documents (can be manually cleaned up later)

### For New Installations:
- Photos go directly to shared container
- No migration needed

### For Development:
- Photos now persist across Xcode builds
- Can test without losing photo history
- Easier to debug photo-related features

---

## Technical Details

### App Group Identifier Format:
- Must start with `group.`
- Followed by reverse domain notation
- Example: `group.DTS.DTS-App`

### Shared Container Structure:
```
AppGroup Container/
├── Photos/              ← Our photos directory
│   ├── photo_1234567890.jpg
│   ├── photo_1234567891.jpg
│   └── ...
└── (Other shared data)
```

### Security:
- App Groups are sandboxed per developer team
- Only your apps can access this container
- Photos encrypted at rest by iOS

---

## Benefits

✅ **Photos persist** across app reinstalls
✅ **No data loss** when testing new versions
✅ **Automatic migration** of existing photos
✅ **Fallback safety** if not configured
✅ **Production ready** for App Store builds

---

## Next Steps

After enabling App Groups:
1. Build and run the app
2. Verify migration logs in console
3. Test photo capture and persistence
4. Delete and reinstall to confirm photos persist
5. Commit changes to git (when ready)

---

## References

- Apple Docs: [App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- WWDC: [Sharing Data Between Apps](https://developer.apple.com/videos/play/wwdc2019/244/)
- File System: [FileManager.containerURL](https://developer.apple.com/documentation/foundation/filemanager/1412643-containerurl)
