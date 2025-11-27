# Photo Persistence - Quick Start

## What Changed?
Photos now persist across app reinstalls and version updates using iOS App Groups.

## What You Need to Do

### 1. Enable App Groups in Xcode (5 minutes)

1. Open `DTS App/DTS App.xcodeproj` in Xcode
2. Select the **DTS App** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **App Groups**
6. Click **+** in App Groups section
7. Enter: `group.DTS.DTS-App`
8. Check the box next to it ✅

That's it! Build and run.

### 2. Test It Works

```bash
# Build and run
xcodebuild -project "DTS App/DTS App.xcodeproj" -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath build clean build
```

1. Take a test photo
2. Delete the app
3. Rebuild and run
4. Check Photos tab - photo should still be there! ✅

## What Happens Automatically

- ✅ Photos save to shared container (persists across builds)
- ✅ Existing photos migrate automatically on first launch
- ✅ Falls back to Documents if App Groups not configured
- ✅ One-time migration logged to console

## Console Output

Look for these logs on first launch:
```
✅ Created shared photos directory: ...
📦 Found X photos to migrate from Documents
✅ Migration complete: X photos migrated, 0 errors
```

## Files Modified

- **New:** `SharedContainerHelper.swift` - Storage utility
- **Updated:** `PhotoCaptureManager.swift` - Photo saving
- **Updated:** `PhotoLibraryView.swift` - Photo loading
- **Updated:** `QuoteHistoryView.swift` - Cleanup
- **Updated:** `DTSApp.swift` - Auto-migration

## Troubleshooting

**Photos still disappearing?**
- Verify App Groups capability is enabled
- Check identifier is exactly: `group.DTS.DTS-App`
- Look for console error: "❌ Failed to access App Group container"

**Need more details?**
See `PHOTO_PERSISTENCE_SETUP.md` for full documentation.
