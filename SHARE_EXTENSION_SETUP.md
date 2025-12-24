# Share Extension Setup Guide

The Share Extension code files have been created at:
- `DTS App/DTS Share Extension/ShareViewController.swift`
- `DTS App/DTS Share Extension/Info.plist`
- `DTS App/DTS Share Extension/DTS Share Extension.entitlements`

## Complete Setup in Xcode

### Step 1: Add Share Extension Target

1. Open `DTS App.xcodeproj` in Xcode
2. File → New → Target
3. Search for "Share Extension"
4. Select **Share Extension** and click Next
5. Configure:
   - **Product Name:** `DTS Share Extension`
   - **Bundle Identifier:** `DTS.DTS-App.ShareExtension`
   - **Language:** Swift
   - **Project:** DTS App
   - **Embed in Application:** DTS App
6. Click Finish
7. If prompted to activate the scheme, click **Cancel** (we'll use existing files)

### Step 2: Replace Generated Files

1. In the Project Navigator, find the newly created `DTS Share Extension` group
2. **Delete** the auto-generated `ShareViewController.swift`
3. Right-click the `DTS Share Extension` group → **Add Files to "DTS App"...**
4. Navigate to `DTS App/DTS Share Extension/` and select:
   - `ShareViewController.swift`
   - Make sure "Add to targets: DTS Share Extension" is checked
5. **Delete** the auto-generated `Info.plist`
6. In Build Settings for DTS Share Extension target:
   - Find "Info.plist File"
   - Set to: `DTS Share Extension/Info.plist`

### Step 3: Configure Entitlements

1. Select the `DTS Share Extension` target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Search and add **App Groups**
5. Enable `group.DTS.DTS-App` (same as main app)
6. In Build Settings, set:
   - "Code Signing Entitlements" to `DTS Share Extension/DTS Share Extension.entitlements`

### Step 4: Verify Main App Entitlements

Ensure the main `DTS App` target also has the App Group configured:
1. Select `DTS App` target
2. Signing & Capabilities → App Groups
3. Verify `group.DTS.DTS-App` is enabled

### Step 5: Build Settings

For `DTS Share Extension` target:
- **Bundle Identifier:** `DTS.DTS-App.ShareExtension`
- **iOS Deployment Target:** Same as main app (iOS 18.0)
- **Swift Language Version:** Same as main app

### Step 6: Test

1. Build and run on a device or simulator
2. Open Files app or Mail with a PDF attachment
3. Tap Share
4. Look for "Import to DTS" in the share sheet
5. Tap it - the PDF should be imported and main app should open

## How It Works

1. **Share Extension receives PDF** → `ShareViewController.swift`
2. **Saves PDF to shared container** → `group.DTS.DTS-App/RoofPDFs/`
3. **Stores pending import ID** → `UserDefaults(suiteName: "group.DTS.DTS-App")`
4. **Opens main app via URL** → `dts-app://import-roof-pdf?id={uuid}`
5. **Main app detects pending import** → `checkForPendingRoofPDFImport()` in DTSApp.swift
6. **Navigates to Roof Orders tab** → Auto-imports the PDF

## Troubleshooting

### Share Extension not appearing
- Verify bundle identifier matches pattern: `{main-app-id}.ShareExtension`
- Check Info.plist `NSExtensionActivationRule` is correct
- Rebuild and restart simulator/device

### PDF not saving
- Verify App Group is enabled on BOTH targets
- Check app group identifier matches exactly: `group.DTS.DTS-App`
- Look for errors in Console.app

### Main app not opening
- Verify URL scheme `dts-app` is registered in main app's Info.plist
- Check `handleIncomingURL` in DTSApp.swift handles `import-roof-pdf` host

### Data not shared between extension and app
- App Groups must be enabled on BOTH targets
- Use same app group identifier everywhere
- Call `synchronize()` on UserDefaults after writing
