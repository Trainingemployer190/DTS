
# DTS App - Gutter Installation & Quote Management

Professional iOS app for DTS Gutters & Restoration, built with SwiftUI and integrated with Jobber CRM.

## Features
- **Jobber Integration**: Sync scheduled jobs and create quotes directly from Jobber CRM
- **Quote Calculator**: Advanced pricing with markup calculations, profit margins, and commission tracking
- **Photo Capture**: Location-watermarked photos with GPS coordinates for job documentation
- **PDF Generation**: Professional quote PDFs with photos and detailed pricing breakdowns
- **SwiftData Storage**: Local data persistence with seamless sync capabilities

## Jobber API Documentation

Complete documentation for Jobber API integration:
- **[📚 Full Documentation](JOBBER_API_DOCUMENTATION.md)** - Complete setup and integration guide
- **[🚀 Quick Start](JOBBER_API_QUICKSTART.md)** - 5-minute setup guide  
- **[📖 API Reference](JOBBER_API_REFERENCE.md)** - Complete method reference

## Tech Stack
- **SwiftUI** (iOS 18+) - Modern declarative UI framework
- **SwiftData** - Core Data replacement for data persistence
- **Jobber GraphQL API** - Real-time integration with Jobber CRM
- **Core Location** - GPS coordinates and location services
- **PDFKit** - Professional quote document generation
- **OAuth 2.0** - Secure authentication with Jobber

## Quick Start

1. **Open in Xcode**:
   ```bash
   open "DTS App.xcodeproj"
   ```

2. **Or Build with VS Code**:
   - Press `Cmd+Shift+B` to build
   - Use Command Palette → "Tasks: Run Task" → "Run on Simulator"
   - Or use status bar buttons: "🛠️ Build iOS" and "▶️ Run iOS App"

## Available Tasks

### Build iOS Simulator
- **Shortcut**: `Cmd+Shift+B` (default build task)
- **Purpose**: Compiles your iOS app for simulator
- **Output**: `build/Build/Products/Debug-iphonesimulator/`

### Run on Simulator
- **Purpose**: Installs and launches app on iOS Simulator
- **Dependencies**: Automatically builds first if needed
- **Features**: Auto-discovers bundle ID from Info.plist

### Discover Project Info
- **Purpose**: Lists available schemes and simulators
- **Use**: When you need to update configuration

### Additional Tasks
- **Clean Build Folder**: Removes build artifacts
- **Open in Xcode**: Quick access to Xcode when needed

## Configuration

The setup uses three configurable variables in `.vscode/tasks.json`:

```json
{
    "projectPath": "DTS App/DTS App.xcodeproj",
    "schemeName": "DTS App",
    "simulatorName": "iPhone 16 Pro"
}
```

To change these:
1. Run "Discover Project Info" task to see available options
2. Modify the `default` values in the `inputs` section of `tasks.json`

## Troubleshooting

### Signing Errors
**Problem**: Code signing fails during build
**Solution**:
1. Run: `./discover-ios-config.sh` to check team configuration
2. If needed, open project in Xcode once: `open "DTS App/DTS App.xcodeproj"`
3. Select project → Signing & Capabilities → Choose your Team

### App Not Found Error
**Problem**: "App not found at expected path"
**Causes**:
- Build failed (check build task output)
- Wrong scheme name (scheme should match your target)
- Derived data path issues

**Solution**:
1. Run "Clean Build Folder" task
2. Verify scheme name with "Discover Project Info" task
3. Run build task and check for errors

### Bundle ID Issues
**Problem**: App fails to launch with bundle ID error
**Solution**: The task auto-discovers bundle ID from Info.plist, but you can manually set it:
- Default: `DTS.DTS-App` (from your project.pbxproj)
- Location: Built app's `Info.plist` file

### Simulator Issues
**Problem**: Simulator won't boot or app won't install
**Solutions**:
1. Check available simulators: `xcrun simctl list devices`
2. Reset simulator: iOS Simulator → Device → Erase All Content and Settings
3. Restart Simulator app
4. Verify simulator name matches exactly (case-sensitive)

### Xcode Command Line Tools
**Problem**: `xcodebuild` command not found
**Solution**:
```bash
# Install command line tools
sudo xcode-select --install

# Set active developer directory
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Verify installation
xcodebuild -version
```

## File Structure

```
DTS APP/
├── .vscode/
│   ├── tasks.json          # Build and run tasks
│   └── settings.json       # VS Code settings
├── DTS App/
│   ├── DTS App/
│   │   ├── ContentView.swift
│   │   └── DTS_AppApp.swift
│   └── DTS App.xcodeproj/
├── build/                  # Build output (created automatically)
├── discover-ios-config.sh  # Discovery script
└── README.md              # This file
```

## Development Workflow

1. **Edit Code**: Use VS Code for all Swift development
2. **Build**: Press `Cmd+Shift+B` or use status bar "Build iOS" button
3. **Run**: Use "Run iOS App" status bar button or run task
4. **Debug**: View build output in VS Code terminal
5. **Xcode**: Only needed for:
   - Signing & Capabilities configuration
   - Storyboard/XIB editing (if used)
   - Advanced debugging with Instruments

## Tips

- **Fast Development**: Keep Simulator open for faster app launches
- **Clean Builds**: Use "Clean Build Folder" task when switching branches
- **Multiple Simulators**: Change `simulatorName` in inputs to test on different devices
- **Keyboard Shortcuts**:
  - `Cmd+Shift+B`: Build
  - `Cmd+Shift+P`: Command Palette → "Tasks: Run Task"

## Extensions

Recommended VS Code extensions for iOS development:

- **Swift** (`sswg.swift-lang`): Syntax highlighting and basic language support
- **iOS Simulator** (`digorydoo.ios-simulator`): Simulator management from VS Code
- **Xcode Theme** (`beareyes.xcode-theme`): Familiar color scheme

```bash
# Install all recommended extensions
code --install-extension sswg.swift-lang
code --install-extension digorydoo.ios-simulator
code --install-extension beareyes.xcode-theme
```

Happy coding! 🎉
