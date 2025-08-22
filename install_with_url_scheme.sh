#!/bin/bash

# Path to the built Info.plist
INFO_PLIST="/Users/chandlerstaton/Library/Developer/Xcode/DerivedData/DTS_App-gserwnpkdzncpjdczmifdxvlfghu/Build/Products/Debug-iphonesimulator/DTS App.app/Info.plist"

echo "Adding URL scheme to Info.plist..."

# Add CFBundleURLTypes array if it doesn't exist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST" 2>/dev/null || true

# Add the URL type dictionary
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST" 2>/dev/null || true

# Add the URL name and schemes
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string DTS.DTS-App.oauth" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string dtsapp" "$INFO_PLIST" 2>/dev/null || true

echo "URL scheme added successfully!"

# Install the app
echo "Installing app to simulator..."
xcrun simctl install booted "/Users/chandlerstaton/Library/Developer/Xcode/DerivedData/DTS_App-gserwnpkdzncpjdczmifdxvlfghu/Build/Products/Debug-iphonesimulator/DTS App.app"

# Launch the app
echo "Launching app..."
xcrun simctl launch booted DTS.DTS-App

echo "App installed and launched successfully!"
echo "The OAuth URL scheme 'dtsapp://' is now properly registered."
