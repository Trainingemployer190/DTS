# DTS App - Gutter Installation & Quote Management

Professional iOS app for DTS Gutters & Restoration, built with SwiftUI and integrated with Jobber CRM.

## Features
- **Jobber Integration**: Sync scheduled jobs and create quotes directly from Jobber CRM
- **Quote Calculator**: Advanced pricing with markup calculations, profit margins, and commission tracking
- **Photo Capture**: Location-watermarked photos with GPS coordinates for job documentation
- **PDF Generation**: Professional quote PDFs with photos and detailed pricing breakdowns
- **SwiftData Storage**: Local data persistence with seamless sync capabilities

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

## Jobber API Configuration & Setup

The DTS App integrates with Jobber CRM using OAuth 2.0 authentication and GraphQL API. Here's a complete breakdown of how it's configured:

### 1. OAuth Application Setup in Jobber

Before the app can connect to Jobber, you need to create an OAuth application in your Jobber account:

1. **Login to Jobber Developer Portal**:
   - Go to [Jobber Developer Portal](https://developer.getjobber.com/)
   - Login with your Jobber account credentials

2. **Create New Application**:
   - Navigate to "My Apps" → "Create App"
   - Fill in application details:
     - **App Name**: `DTS Gutter App` (or your preferred name)
     - **Description**: `Mobile app for DTS Gutters & Restoration quote management`
     - **Redirect URI**: `dts-app://oauth/callback`
   - Save the application

3. **Obtain Credentials**:
   - **Client ID**: Copy this from your created app (e.g., `abc123def456`)
   - **Client Secret**: Copy this securely (e.g., `secret789xyz`)
   - **Redirect URI**: Must match exactly: `dts-app://oauth/callback`

### 2. App Configuration Files

#### A. JobberAPI.swift (`DTS App/DTS App/Managers/JobberAPI.swift`)

This is the main integration file containing:

```swift
class JobberAPI: ObservableObject {
    // OAuth Configuration
    private let clientId = "YOUR_CLIENT_ID_HERE"
    private let clientSecret = "YOUR_CLIENT_SECRET_HERE"
    private let redirectUri = "dts-app://oauth/callback"
    private let baseUrl = "https://api.getjobber.com/api/graphql"
    
    // Authentication endpoints
    private let authUrl = "https://api.getjobber.com/api/oauth/authorize"
    private let tokenUrl = "https://api.getjobber.com/api/oauth/token"
}
```

**Key Components**:
- **Authentication State**: `@Published var isAuthenticated = false`
- **Token Management**: Secure storage using Keychain
- **GraphQL Queries**: Job fetching, quote creation
- **OAuth Flow**: ASWebAuthenticationSession handling

#### B. Info.plist URL Scheme

The app must handle the OAuth callback. In `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>DTS App OAuth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>dts-app</string>
        </array>
    </dict>
</array>
```

### 3. Authentication Flow

#### Step-by-Step OAuth Process:

1. **User Taps "Connect to Jobber"**:
   ```swift
   Button("Connect to Jobber") {
       jobberAPI.authenticate()
   }
   ```

2. **App Opens Jobber OAuth**:
   - Constructs authorization URL with scopes
   - Opens ASWebAuthenticationSession
   - User sees Jobber login page

3. **User Authorizes App**:
   - User enters Jobber credentials
   - Jobber shows permission screen
   - User approves app access

4. **Callback Handling**:
   - Jobber redirects to `dts-app://oauth/callback?code=AUTH_CODE`
   - App extracts authorization code
   - Exchanges code for access token

5. **Token Storage**:
   - Access token stored securely in Keychain
   - Refresh token saved for token renewal
   - User email/account info cached

### 4. GraphQL API Integration

#### Required Scopes:
- `jobs:read` - Read job information
- `quotes:write` - Create and modify quotes
- `clients:read` - Access client information

#### Key GraphQL Queries:

**Fetch Jobs**:
```graphql
query GetJobs($first: Int!) {
  jobs(first: $first) {
    edges {
      node {
        id
        title
        scheduledAt
        client {
          name
          email
        }
        property {
          address
        }
      }
    }
  }
}
```

**Create Quote**:
```graphql
mutation CreateQuote($input: QuoteCreateInput!) {
  quoteCreate(input: $input) {
    quote {
      id
      title
      total
    }
    userErrors {
      field
      message
    }
  }
}
```

### 5. Security Implementation

#### Token Security:
- **Keychain Storage**: All tokens stored in iOS Keychain
- **Automatic Refresh**: Handles token expiration
- **Secure Deletion**: Tokens removed on logout

#### Network Security:
- **HTTPS Only**: All API calls use secure connections
- **Certificate Pinning**: Validates Jobber's SSL certificates
- **Request Signing**: OAuth 2.0 Bearer token authentication

### 6. Error Handling & Edge Cases

#### Common Scenarios Handled:
- **Network Failures**: Retry logic with exponential backoff
- **Token Expiration**: Automatic refresh using refresh token
- **Rate Limiting**: Respects Jobber's API rate limits
- **Offline Mode**: Graceful degradation when no internet

#### User Experience:
- **Loading States**: Shows spinner during API calls
- **Error Messages**: User-friendly error descriptions
- **Reconnection**: Easy re-authentication flow

### 7. Testing & Development

#### Development Setup:
1. **Sandbox Environment**: Use Jobber's sandbox API for testing
2. **Test Credentials**: Create separate test OAuth app
3. **Mock Data**: Local test data for offline development

#### Debugging:
- **Console Logging**: Detailed API call logging in debug mode
- **Network Inspector**: Monitor all GraphQL requests/responses
- **Token Validation**: Check token expiration and refresh cycles

### 8. Deployment Checklist

Before releasing updates involving Jobber integration:

- [ ] **Update OAuth Credentials**: Ensure production client ID/secret
- [ ] **Test Authentication Flow**: Full OAuth cycle works
- [ ] **Verify API Scopes**: All required permissions granted
- [ ] **Test Error Scenarios**: Network failures, token expiration
- [ ] **Validate URL Scheme**: Deep linking works correctly
- [ ] **Security Review**: No credentials in source code

### 9. Future Maintenance

#### Regular Tasks:
- **Token Monitoring**: Check for authentication issues
- **API Updates**: Monitor Jobber's GraphQL schema changes
- **Performance**: Review API call efficiency
- **User Feedback**: Address integration pain points

#### Jobber API Updates:
- Subscribe to Jobber developer newsletter
- Review API changelog for breaking changes
- Test new features and endpoints
- Update GraphQL queries as needed

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
