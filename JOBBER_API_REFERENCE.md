# Jobber API Reference

Complete API reference for the JobberAPI class methods and properties.

## Table of Contents
1. [Class Properties](#class-properties)
2. [Authentication Methods](#authentication-methods)
3. [Data Retrieval Methods](#data-retrieval-methods)
4. [Data Creation Methods](#data-creation-methods)
5. [Utility Methods](#utility-methods)
6. [GraphQL Queries](#graphql-queries)
7. [Method Parameters](#method-parameters)

## Class Properties

### Published Properties (Observable)
These properties automatically trigger UI updates when changed:

```swift
@Published var isAuthenticated: Bool = false
@Published var jobs: [JobberJob] = []
@Published var isLoading: Bool = false
@Published var errorMessage: String? = nil
@Published var connectedEmail: String? = nil
```

**Usage in SwiftUI:**
```swift
@EnvironmentObject var jobberAPI: JobberAPI

var body: some View {
    if jobberAPI.isAuthenticated {
        // Show authenticated content
    }
    
    if jobberAPI.isLoading {
        ProgressView()
    }
    
    if let error = jobberAPI.errorMessage {
        Text("Error: \(error)")
    }
}
```

### Private Configuration Properties
```swift
private let clientId: String            // OAuth client ID
private let clientSecret: String        // OAuth client secret  
private let redirectURI: String         // OAuth redirect URI
private let scopes: String              // Required OAuth scopes
private let authURL: String             // OAuth authorization endpoint
private let tokenURL: String            // OAuth token endpoint
private let apiURL: String              // GraphQL API endpoint
```

## Authentication Methods

### `init()`
Initializes the JobberAPI and checks existing authentication status.

```swift
let jobberAPI = JobberAPI()
// Automatically calls checkAuthenticationStatus()
```

### `authenticate()`
Starts the OAuth 2.0 authentication flow.

```swift
func authenticate()
```

**Usage:**
```swift
jobberAPI.authenticate()
// Opens web browser for user to login to Jobber
```

### `signOut()`
Signs out the user and clears all stored tokens.

```swift
func signOut()
```

**Usage:**
```swift
jobberAPI.signOut()
// User will need to authenticate again
```

### `checkAuthenticationStatus()` (Private)
Internal method that verifies stored tokens and refreshes if needed.

### `refreshAccessTokens()` (Private)
Internal method that refreshes expired access tokens using refresh token.

## Data Retrieval Methods

### `fetchScheduledAssessments()`
Fetches scheduled assessments for the current week.

```swift
func fetchScheduledAssessments() async
```

**Usage:**
```swift
Task {
    await jobberAPI.fetchScheduledAssessments()
    // Results available in jobberAPI.jobs array
}
```

**What it fetches:**
- Assessments scheduled for current week
- Client information (name, phone, email)
- Property addresses
- Assessment status and timing
- Assigned users

**GraphQL Query Used:**
```graphql
query GetScheduledItems($start: ISO8601DateTime!, $end: ISO8601DateTime!, $first: Int!)
```

### `fetchAccountInfo()` (Private)
Internal method that fetches user account information after authentication.

## Data Creation Methods

### `createQuoteDraft(quoteDraft:)`
Creates a new quote in Jobber from a QuoteDraft object.

```swift
func createQuoteDraft(quoteDraft: QuoteDraft) async
```

**Parameters:**
- `quoteDraft`: QuoteDraft object containing quote details

**Usage:**
```swift
let quote = QuoteDraft()
quote.clientId = "client_123"
quote.gutterFeet = 100.0
quote.downspoutFeet = 20.0
quote.markupPercent = 0.61

Task {
    await jobberAPI.createQuoteDraft(quoteDraft: quote)
}
```

**Required QuoteDraft Properties:**
- `clientId`: Jobber client ID
- `gutterFeet`: Linear feet of gutter
- `downspoutFeet`: Linear feet of downspout
- `elbowsCount`: Number of elbow pieces
- `endCapPairs`: Number of end cap pairs
- `includeGutterGuard`: Boolean for gutter guard inclusion
- `gutterGuardFeet`: Linear feet of gutter guard (if included)
- `markupPercent`: Markup percentage (e.g., 0.61 for 61%)
- `profitMarginPercent`: Profit margin percentage
- `salesCommissionPercent`: Sales commission percentage
- `notes`: Additional quote notes

## Utility Methods

### `presentationAnchor(for:)`
Required by ASWebAuthenticationPresentationContextProviding protocol.

```swift
func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
```

**Usage:** Automatically called by the authentication system.

### `ensureValidAccessToken()` (Private)
Internal method that ensures access token is valid before API calls.

### `performGraphQLRequest(query:variables:completion:)` (Private)
Generic method for executing GraphQL requests.

```swift
private func performGraphQLRequest<T: Codable>(
    query: String,
    variables: [String: Any],
    completion: @escaping (Result<T, Error>) -> Void
) async
```

## GraphQL Queries

### Scheduled Assessments Query
Retrieves assessments scheduled within a date range:

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
          phones { number, primary }
          emails { address, primary }
        }
        property {
          address { street1, city, province }
        }
        assignedUsers {
          nodes { name { full } }
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

### Quote Creation Mutation
Creates a new quote in Jobber:

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

**Input Variables:**
```swift
let variables: [String: Any] = [
    "input": [
        "clientId": "client_id_string",
        "title": "Quote Title",
        "lineItems": [
            [
                "name": "Item Name",
                "description": "Item Description", 
                "quantity": 1.0,
                "unitCost": 100.0
            ]
        ]
    ]
]
```

## Method Parameters

### Date Parameters
GraphQL queries use ISO8601DateTime format:

```swift
let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let dateString = isoFormatter.string(from: Date())
```

### Error Handling Parameters
All async methods handle errors internally and update `errorMessage` property:

```swift
// Successful operation
jobberAPI.errorMessage = nil

// Error occurred  
jobberAPI.errorMessage = "Descriptive error message"
```

### Loading State Management
Methods automatically manage loading state:

```swift
// Before operation
isLoading = true

// After operation (success or failure)
isLoading = false
```

## Usage Patterns

### Basic Authentication Check
```swift
struct AuthView: View {
    @EnvironmentObject var jobberAPI: JobberAPI
    
    var body: some View {
        Group {
            if jobberAPI.isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }
        }
    }
}
```

### Data Fetching with Error Handling
```swift
func loadJobs() {
    Task {
        await jobberAPI.fetchScheduledAssessments()
        
        if let error = jobberAPI.errorMessage {
            // Handle error
            print("Failed to load jobs: \(error)")
        } else {
            // Success - data is in jobberAPI.jobs
            print("Loaded \(jobberAPI.jobs.count) jobs")
        }
    }
}
```

### Quote Creation with Validation
```swift
func createQuote(for client: String) {
    guard !client.isEmpty else {
        jobberAPI.errorMessage = "Client ID is required"
        return
    }
    
    let quote = QuoteDraft()
    quote.clientId = client
    // ... configure quote properties
    
    Task {
        await jobberAPI.createQuoteDraft(quoteDraft: quote)
        
        if jobberAPI.errorMessage == nil {
            // Quote created successfully
            print("Quote created for client: \(client)")
        }
    }
}
```

## Error Types and Handling

### APIError Enum
```swift
enum APIError: Error {
    case noToken                // No authentication token available
    case invalidURL             // API URL is malformed
    case unauthorized          // Token expired or invalid
    case invalidResponse       // Server response format invalid
    case graphQLError(String)  // GraphQL query/mutation error
}
```

### Error Recovery Patterns
```swift
// Automatic token refresh on unauthorized
if httpResponse.statusCode == 401 {
    await refreshAccessTokens()
    // Retry original request
}

// Sign out on token refresh failure
if refreshFailed {
    await MainActor.run {
        self.signOut()
    }
}
```

## Thread Safety

All UI updates are performed on the main thread:
```swift
await MainActor.run {
    self.isLoading = false
    self.errorMessage = "Error message"
    self.jobs = fetchedJobs
}
```

## Token Storage Security

Tokens are stored securely using iOS Keychain:
```swift
// Save token
_ = Keychain.save(key: "jobber_access_token", data: Data(token.utf8))

// Load token
guard let data = Keychain.load(key: "jobber_access_token") else { return nil }
return String(data: data, encoding: .utf8)

// Delete token
Keychain.delete(key: "jobber_access_token")
```

This reference provides complete coverage of all available methods and their proper usage patterns.