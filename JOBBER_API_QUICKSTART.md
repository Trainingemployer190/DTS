# Jobber API Quick Setup Guide

Fast setup guide for integrating Jobber API into your iOS app using the DTS implementation.

## 🚀 Quick Start (5 minutes)

### 1. Add JobberAPI to Your Project
```swift
import SwiftUI
import AuthenticationServices

// Copy JobberAPI.swift to your project
// Copy DataModels.swift for required models
```

### 2. Initialize in Your App
```swift
@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(JobberAPI()) // Add this line
        }
    }
}
```

### 3. Basic Implementation
```swift
struct ContentView: View {
    @EnvironmentObject var jobberAPI: JobberAPI
    
    var body: some View {
        VStack {
            if jobberAPI.isAuthenticated {
                // Show authenticated UI
                Button("Fetch Jobs") {
                    Task { await jobberAPI.fetchScheduledAssessments() }
                }
                
                List(jobberAPI.jobs, id: \.jobId) { job in
                    VStack(alignment: .leading) {
                        Text(job.clientName).font(.headline)
                        Text(job.address).font(.caption)
                    }
                }
            } else {
                // Show authentication button
                Button("Connect to Jobber") {
                    jobberAPI.authenticate()
                }
            }
            
            if jobberAPI.isLoading {
                ProgressView("Loading...")
            }
            
            if let error = jobberAPI.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}
```

## 🔑 Configuration Required

### OAuth Settings in JobberAPI.swift
```swift
// Replace with your OAuth credentials
private let clientId = "YOUR_CLIENT_ID"
private let clientSecret = "YOUR_CLIENT_SECRET"  
private let redirectURI = "YOUR_REDIRECT_URI"
```

### Redirect URI Setup
1. Register your app in Jobber Developer Portal
2. Set redirect URI (e.g., `https://yourapp.com/oauth/callback`)
3. Handle the callback in your app

## 📱 Core Features Available

### Authentication
- ✅ OAuth 2.0 flow with ASWebAuthenticationSession
- ✅ Automatic token refresh
- ✅ Secure keychain storage

### Data Operations
- ✅ Fetch scheduled assessments/jobs
- ✅ Create quotes with line items  
- ✅ Client and property data
- ✅ SwiftData integration

### Error Handling
- ✅ Network error recovery
- ✅ Token expiration handling
- ✅ GraphQL error parsing
- ✅ User-friendly error messages

## 🛠️ Essential Code Patterns

### Check Authentication Status
```swift
// Automatically happens on init
jobberAPI.checkAuthenticationStatus()

// Manual check
if jobberAPI.isAuthenticated {
    // User is logged in
} else {
    // Show login button
}
```

### Create and Submit Quote
```swift
let quote = QuoteDraft()
quote.clientId = "client_123"
quote.gutterFeet = 100.0
quote.markupPercent = 0.61

Task {
    await jobberAPI.createQuoteDraft(quoteDraft: quote)
}
```

### Handle Loading and Errors
```swift
struct JobberStatusView: View {
    @EnvironmentObject var jobberAPI: JobberAPI
    
    var body: some View {
        Group {
            if jobberAPI.isLoading {
                ProgressView("Syncing with Jobber...")
            }
            
            if let error = jobberAPI.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
```

## 🔧 Required Dependencies

Add to your project:
- `AuthenticationServices` (for OAuth)
- `SwiftData` (for local storage)
- `Foundation` (for networking)

## ⚡ Testing Your Integration

### 1. Test Authentication
```swift
// Should open web browser for Jobber login
jobberAPI.authenticate()
```

### 2. Test Data Fetch
```swift
Task {
    await jobberAPI.fetchScheduledAssessments()
    print("Fetched \(jobberAPI.jobs.count) jobs")
}
```

### 3. Test Quote Creation
```swift
let testQuote = QuoteDraft()
testQuote.clientId = "test_client_id"

Task {
    await jobberAPI.createQuoteDraft(quoteDraft: testQuote)
}
```

## 🚨 Common Setup Issues

### Issue: Authentication fails
**Fix**: Check client ID, secret, and redirect URI match exactly

### Issue: No data returned
**Fix**: Verify user has appropriate permissions in Jobber

### Issue: Network errors
**Fix**: Check internet connection and API endpoint URLs

### Issue: Token refresh fails  
**Fix**: Clear tokens and re-authenticate: `jobberAPI.signOut()`

## 📚 Next Steps

1. Read full documentation: `JOBBER_API_DOCUMENTATION.md`
2. Customize GraphQL queries for your needs
3. Implement offline data sync
4. Add push notifications for new jobs
5. Integrate with your existing data models

## 🔗 Resources

- [Jobber Developer Portal](https://developer.getjobber.com/)
- [GraphQL Explorer](https://api.getjobber.com/graphql)
- Full implementation: `DTS App/Managers/JobberAPI.swift`

---
**Need help?** Check the troubleshooting section in the full documentation!