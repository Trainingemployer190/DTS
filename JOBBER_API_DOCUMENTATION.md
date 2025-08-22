# Jobber API Integration Documentation

Complete guide for integrating with Jobber CRM using OAuth 2.0 and GraphQL APIs in the DTS Gutter Installation App.

## Table of Contents
1. [Overview](#overview)
2. [OAuth 2.0 Configuration](#oauth-20-configuration)
3. [API Endpoints](#api-endpoints)
4. [Authentication Flow](#authentication-flow)
5. [Data Models](#data-models)
6. [GraphQL Operations](#graphql-operations)
7. [Usage Examples](#usage-examples)
8. [Error Handling](#error-handling)
9. [Token Management](#token-management)
10. [Troubleshooting](#troubleshooting)

## Overview

The JobberAPI class provides a complete integration with Jobber's CRM system, featuring:

- **OAuth 2.0 Authentication**: Secure token-based authentication
- **GraphQL API**: Modern API for flexible data queries
- **Automatic Token Refresh**: Seamless token management
- **SwiftData Integration**: Local data persistence with sync capabilities
- **Comprehensive Error Handling**: Robust error recovery and user feedback

## OAuth 2.0 Configuration

### Client Credentials
```swift
private let clientId = "bc74e0a3-3f65-4373-b758-a512536ded90"
private let clientSecret = "c4cc587785949060e4dd052e598a702d0ed8e91410302ceed2702d30413a6c03"
private let redirectURI = "https://trainingemployer190.github.io/dtsapp-oauth-redirect/"
```

### Required Scopes
```swift
private let scopes = "read_clients write_clients read_requests write_requests read_quotes write_quotes read_jobs write_jobs read_scheduled_items write_scheduled_items read_invoices write_invoices read_jobber_payments read_users write_users write_tax_rates read_expenses write_expenses read_custom_field_configurations write_custom_field_configurations read_time_sheets"
```

### Redirect URI Setup
The redirect URI must be configured in your Jobber OAuth application:
- **Production**: `https://trainingemployer190.github.io/dtsapp-oauth-redirect/`
- **Development**: Use the same URL for consistency

## API Endpoints

```swift
private let authURL = "https://api.getjobber.com/api/oauth/authorize"
private let tokenURL = "https://api.getjobber.com/api/oauth/token"
private let apiURL = "https://api.getjobber.com/api/graphql"
```

### GraphQL Version Header
All GraphQL requests include the API version header:
```swift
request.setValue("2025-01-20", forHTTPHeaderField: "X-JOBBER-GRAPHQL-VERSION")
```

## Authentication Flow

### 1. Initial Authentication
```swift
let jobberAPI = JobberAPI()
jobberAPI.authenticate()
```

### 2. OAuth Authorization Request
```swift
// Automatically constructs authorization URL with required parameters
let authURL = "https://api.getjobber.com/api/oauth/authorize"
    + "?client_id=YOUR_CLIENT_ID"
    + "&redirect_uri=YOUR_REDIRECT_URI"
    + "&response_type=code"
    + "&scope=REQUIRED_SCOPES"
    + "&state=RANDOM_STATE"
```

### 3. Token Exchange
After user authorization, the app exchanges the authorization code for access tokens:
```swift
// POST to token endpoint with authorization code
{
    "grant_type": "authorization_code",
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET", 
    "redirect_uri": "YOUR_REDIRECT_URI",
    "code": "AUTHORIZATION_CODE"
}
```

### 4. Token Response
```swift
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
}
```

## Data Models

### Core JobberJob Model
```swift
@Model
final class JobberJob {
    var jobId: String
    var clientName: String
    var clientPhone: String?
    var address: String
    var scheduledAt: Date
    var status: String

    init(jobId: String, clientName: String, clientPhone: String? = nil, 
         address: String, scheduledAt: Date, status: String) {
        self.jobId = jobId
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.address = address
        self.scheduledAt = scheduledAt
        self.status = status
    }
}
```

### Quote Line Items
```swift
struct JobberLineItem {
    let name: String
    let description: String
    let quantity: Double
    let unitPrice: Double
}

struct QuoteDraftLineItem {
    let name: String
    let description: String
    let quantity: Double
    let unitPrice: Double
    let totalPrice: Double
}
```

### API Response Models
```swift
// Token Response
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
}

// Quote Creation Response
struct QuoteCreateResponse: Codable {
    let data: QuoteCreateData
}

struct QuoteCreateData: Codable {
    let quoteCreate: QuoteCreateResult
}

struct QuoteCreateResult: Codable {
    let quote: JobberQuote?
    let userErrors: [JobberError]?
}

// Visit Response Models
struct VisitsResponse: Codable {
    let data: VisitsData
}

struct VisitsData: Codable {
    let visits: VisitsConnection
}

struct VisitsConnection: Codable {
    let nodes: [VisitWithJobNode]
}

struct VisitWithJobNode: Codable {
    let id: String
    let startAt: String?
    let endAt: String?
    let job: SimpleJobNode
}

struct SimpleJobNode: Codable {
    let id: String
    let title: String?
    let client: ClientNode
    let property: PropertyNode?
}

struct ClientNode: Codable {
    let name: String
}

struct PropertyNode: Codable {
    let address: PropertyAddress?
}

struct PropertyAddress: Codable {
    let street1: String?
    let city: String?
}
```

## GraphQL Operations

### Fetch Scheduled Assessments
```graphql
query GetScheduledItems($start: ISO8601DateTime!, $end: ISO8601DateTime!, $first: Int!) {
  scheduledItems(
    filter: {
      scheduleItemType: ASSESSMENT
      occursWithin: { startAt: $start, endAt: $end }
    }
    first: $first
  ) {
    nodes {
      ... on Assessment {
        id
        startAt
        title
        completedAt
        client {
          id
          name
          phones {
            number
            primary
          }
          emails {
            address
            primary
          }
        }
        property {
          address {
            street1
            city
            province
          }
        }
        assignedUsers {
          nodes {
            name {
              full
            }
          }
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
    totalCount
  }
}
```

### Create Quote Mutation
```graphql
mutation CreateQuote($input: QuoteCreateInput!) {
  quoteCreate(input: $input) {
    quote {
      id
      title
    }
    userErrors {
      field
      message
    }
  }
}
```

### Variables Format for Quote Creation
```swift
let variables: [String: Any] = [
    "input": [
        "clientId": quoteDraft.clientId ?? "",
        "title": "Gutter Installation Quote",
        "lineItems": lineItems.map { item in
            [
                "name": item.name,
                "description": item.description,
                "quantity": item.quantity,
                "unitCost": item.unitPrice
            ]
        }
    ]
]
```

## Usage Examples

### Initialize and Authenticate
```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var jobberAPI = JobberAPI()
    
    var body: some View {
        VStack {
            if jobberAPI.isAuthenticated {
                Text("Connected to Jobber")
                Button("Fetch Jobs") {
                    Task {
                        await jobberAPI.fetchScheduledAssessments()
                    }
                }
            } else {
                Button("Connect to Jobber") {
                    jobberAPI.authenticate()
                }
            }
        }
        .environmentObject(jobberAPI)
    }
}
```

### Create and Submit Quote
```swift
// Create quote draft
let quoteDraft = QuoteDraft()
quoteDraft.clientId = "client_123"
quoteDraft.gutterFeet = 100.0
quoteDraft.downspoutFeet = 20.0
quoteDraft.markupPercent = 0.61

// Submit to Jobber
Task {
    await jobberAPI.createQuoteDraft(quoteDraft: quoteDraft)
}
```

### Fetch Weekly Schedule
```swift
Task {
    await jobberAPI.fetchScheduledAssessments()
    
    // Jobs are automatically updated in the @Published jobs array
    for job in jobberAPI.jobs {
        print("Job: \(job.clientName) at \(job.address)")
    }
}
```

## Error Handling

### API Error Types
```swift
enum APIError: Error {
    case noToken
    case invalidURL
    case unauthorized
    case invalidResponse
    case graphQLError(String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Authentication token not available. Please reconnect to Jobber."
        case .invalidURL:
            return "Invalid API URL configuration."
        case .unauthorized:
            return "Authentication expired. Please reconnect to Jobber."
        case .invalidResponse:
            return "Invalid response from Jobber API."
        case .graphQLError(let message):
            return "Jobber API Error: \(message)"
        }
    }
}
```

### Error Monitoring
```swift
struct JobberErrorView: View {
    @EnvironmentObject private var jobberAPI: JobberAPI
    
    var body: some View {
        VStack {
            if let error = jobberAPI.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}
```

## Token Management

### Automatic Token Refresh
The JobberAPI automatically handles token refresh:
- Tokens are checked before each API request
- Refresh tokens are used automatically when access tokens expire
- Failed refresh attempts trigger re-authentication

### Token Storage
Tokens are securely stored using:
- **Access Token**: Keychain storage (`jobber_access_token`)
- **Refresh Token**: Keychain storage (`jobber_refresh_token`)
- **Token Expiry**: UserDefaults (`jobber_token_expiry`)

### Manual Token Management
```swift
// Check authentication status
jobberAPI.checkAuthenticationStatus()

// Sign out and clear tokens
jobberAPI.signOut()

// Refresh tokens manually
Task {
    await jobberAPI.refreshAccessTokens()
}
```

## Required Headers

### Standard Request Headers
```swift
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Origin")
request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Referer")
request.setValue("2025-01-20", forHTTPHeaderField: "X-JOBBER-GRAPHQL-VERSION")
```

### Token Request Headers
```swift
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
request.setValue("application/json", forHTTPHeaderField: "Accept")
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
**Problem**: User gets "Authentication failed" error
**Solutions**:
- Verify client credentials are correct
- Check redirect URI matches exactly (including trailing slash)
- Ensure all required scopes are included
- Verify the OAuth app is active in Jobber

#### 2. Token Refresh Failures  
**Problem**: "Token refresh failed" error
**Solutions**:
- Clear stored tokens and re-authenticate: `jobberAPI.signOut()`
- Check internet connectivity
- Verify refresh token hasn't been revoked in Jobber admin

#### 3. GraphQL Errors
**Problem**: GraphQL queries return errors
**Solutions**:
- Verify API version header is correct
- Check query syntax and field names
- Ensure user has appropriate permissions in Jobber
- Validate variable types match GraphQL schema

#### 4. Missing Data
**Problem**: API returns empty or incomplete data
**Solutions**:
- Check user permissions for requested data
- Verify date ranges for time-based queries
- Ensure filters are correctly applied
- Check if data exists in Jobber account

### Debug Mode
Enable detailed logging by setting breakpoints at:
- `performGraphQLRequest` method for API calls
- `handleOAuthCallback` for authentication flow
- Error handling blocks for specific error details

### Network Issues
For network-related problems:
- Check device connectivity
- Verify firewall/proxy settings don't block Jobber domains
- Test with different network (cellular vs WiFi)
- Check for Cloudflare protection messages

## Security Considerations

### Client Secret Protection
- Never commit client secrets to version control
- Use environment variables or secure configuration for production
- Consider server-side proxy for additional security

### Token Security
- Tokens are stored in iOS Keychain for maximum security
- Access tokens expire automatically (default 1 hour)
- Refresh tokens should be treated as highly sensitive

### State Parameter Validation
OAuth state parameters are validated to prevent CSRF attacks:
```swift
let receivedState = components.queryItems?.first(where: { $0.name == "state" })?.value
guard receivedState == storedState else {
    // Security issue - reject the request
    return
}
```

## Integration Checklist

- [ ] Configure OAuth application in Jobber
- [ ] Set up redirect URI handling
- [ ] Implement JobberAPI class
- [ ] Set up SwiftData models
- [ ] Configure authentication flow
- [ ] Test token refresh mechanism
- [ ] Implement error handling
- [ ] Test GraphQL operations
- [ ] Validate data synchronization
- [ ] Test offline/online scenarios

This documentation provides a complete reference for implementing Jobber API integration. For additional support, refer to [Jobber's official API documentation](https://developer.getjobber.com/).