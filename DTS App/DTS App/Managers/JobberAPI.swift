//
//  JobberAPI.swift
//  DTS App
//
//  Jobber API integration with OAuth authentication and GraphQL
//
//  COPILOT INSTRUCTIONS:
//  When modifying this file, ALWAYS reference the GraphQL documentation:
//  - Schema: DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt (60,218+ lines)
//  - API Reference: DTS App/DTS App/Docs/GraphQL/JOBBER_API_REFERENCE.md
//  - Technical Guide: DTS App/DTS App/Docs/GraphQL/The Jobber GraphQL API_*.pdf
//
//  Key Rules:
//  1. Validate ALL field names against jobber_schema.graphql.txt before suggesting changes
//  2. GraphQL IDs are Base64-encoded (e.g. Z2lkOi8vSm9iYmVyL0NsaWVudC84MDA0NDUzOA==)
//  3. Web URLs require numeric IDs only - use extractNumericId() from DataModels.swift
//  4. Follow existing query patterns and error handling
//  5. Include debug logging for troubleshooting ID transformations
//
//  Schema Validation: Before adding/modifying any GraphQL query, search the schema
//  file to confirm field existence, types, and nested relationships.
//

import Foundation
import SwiftUI
import AuthenticationServices
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

// MARK: - API Error Types

enum APIError: Error {
    case noToken
    case invalidURL
    case unauthorized
    case invalidResponse
    case graphQLError(String)
}

enum JobberAPIError: Error {
    case invalidRequest(String)
    case networkError(String)
    case authenticationRequired
}

extension JobberAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "Please connect to Jobber first"
        }
    }
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

// MARK: - JobberAPI

@MainActor
class JobberAPI: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var jobs: [JobberJob] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var connectedEmail: String?

    // OAuth Configuration
    private let clientId = "bc74e0a3-3f65-4373-b758-a512536ded90"
    private let clientSecret = "c4cc587785949060e4dd052e598a702d0ed8e91410302ceed2702d30413a6c03"
    private let redirectURI = "https://trainingemployer190.github.io/dtsapp-oauth-redirect/"
    private let scopes = "read_clients write_clients read_requests write_requests read_quotes write_quotes read_jobs write_jobs read_scheduled_items write_scheduled_items"

    // API Endpoints
    private let authURL = "https://api.getjobber.com/api/oauth/authorize"
    private let tokenURL = "https://api.getjobber.com/api/oauth/token"
    private let apiURL = "https://api.getjobber.com/api/graphql"

    private var authSession: ASWebAuthenticationSession?
    private var storedState: String?

    // Token storage with automatic expiry tracking
    private var accessToken: String? {
        get {
            guard let data = Keychain.load(key: "jobber_access_token") else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let token = newValue {
                _ = Keychain.save(key: "jobber_access_token", data: Data(token.utf8))
            } else {
                Keychain.delete(key: "jobber_access_token")
            }
        }
    }

    private var refreshToken: String? {
        get {
            guard let data = Keychain.load(key: "jobber_refresh_token") else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let token = newValue {
                _ = Keychain.save(key: "jobber_refresh_token", data: Data(token.utf8))
            } else {
                Keychain.delete(key: "jobber_refresh_token")
            }
        }
    }

    private var tokenExpiry: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: "jobber_token_expiry")
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "jobber_token_expiry")
            } else {
                UserDefaults.standard.removeObject(forKey: "jobber_token_expiry")
            }
        }
    }

    override init() {
        super.init()
        checkAuthenticationStatus()
    }

    private func checkAuthenticationStatus() {
        // Check if we have stored tokens
        if let _ = accessToken, let _ = refreshToken {
            // We have tokens, check if they're still valid
            if let expiry = tokenExpiry, Date() < expiry {
                // Access token is still valid
                isAuthenticated = true
                Task {
                    await fetchAccountInfo()
                }
            } else {
                // Access token expired, try to refresh
                Task {
                    await refreshAccessTokens()
                }
            }
        } else {
            // No tokens stored
            isAuthenticated = false
        }
    }

    func authenticate() {
        print("🔐 Starting fresh OAuth authentication flow")
        // Start fresh OAuth flow
        clearStoredTokens()

        // Reset authentication state
        Task { @MainActor in
            self.isAuthenticated = false
            self.errorMessage = nil
            self.isLoading = false
            self.connectedEmail = nil
        }

        startOAuthFlow()
    }

    private func startOAuthFlow() {
        print("🚀 Starting OAuth flow")

        // Generate random state for security
        storedState = UUID().uuidString
        print("📝 Generated state: \(storedState ?? "nil")")

        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: storedState)
        ]

        guard let finalAuthURL = urlComponents.url else {
            print("❌ Failed to create authorization URL")
            print("❌ Base URL: \(authURL)")
            print("❌ Client ID: \(clientId)")
            print("❌ Redirect URI: \(redirectURI)")
            print("❌ Scopes: \(scopes)")
            print("❌ State: \(storedState ?? "nil")")
            self.errorMessage = "Invalid authorization URL."
            return
        }

        print("🔗 Final Authorization URL: \(finalAuthURL.absoluteString)")
        print("🔗 URL Length: \(finalAuthURL.absoluteString.count)")

        // Validate URL before proceeding
        if finalAuthURL.absoluteString.count > 2048 {
            print("⚠️ Warning: URL is very long (\(finalAuthURL.absoluteString.count) characters)")
        }

        // Use custom URL scheme for OAuth callbacks
        let callbackScheme = "dtsapp"

        let authSession = ASWebAuthenticationSession(
            url: finalAuthURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            print("ASWebAuthenticationSession callback received")
            print("Callback URL: \(String(describing: callbackURL))")
            print("Error: \(String(describing: error))")

            if let error = error {
                if case ASWebAuthenticationSessionError.canceledLogin = error {
                    print("User cancelled authentication")
                    return
                }
                Task { @MainActor in
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                }
                return
            }

            guard let callbackURL = callbackURL else {
                Task { @MainActor in
                    self.errorMessage = "Authentication completed but no callback URL was received. Please try again."
                }
                return
            }

            print("Processing callback URL: \(callbackURL.absoluteString)")
            Task {
                await self.handleOAuthCallback(url: callbackURL)
            }
        }

        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = false
        self.authSession = authSession

        print("Starting authentication session with:")
        print("- Auth URL: \(finalAuthURL.absoluteString)")
        print("- Redirect URI: \(redirectURI)")

        let started = authSession.start()
        print("Authentication session start result: \(started)")

        if !started {
            Task { @MainActor in
                self.errorMessage = "Failed to start authentication session"
            }
        }
    }

    func handleOAuthCallback(url: URL) async {
        print("=== handleOAuthCallback ===")
        print("Full callback URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Failed to parse URL components")
            await MainActor.run {
                self.errorMessage = "Invalid callback URL format"
            }
            return
        }

        // Validate state
        let receivedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard receivedState == storedState else {
            print("State validation failed!")
            await MainActor.run {
                self.errorMessage = "Invalid state parameter - possible security issue"
            }
            return
        }

        // Check for error
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            await MainActor.run {
                self.errorMessage = "Authorization failed: \(error)"
            }
            return
        }

        // Extract authorization code
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            await MainActor.run {
                self.errorMessage = "No authorization code received"
            }
            return
        }

        // Exchange code for tokens
        await exchangeCodeForTokens(code: code)
    }

    private func exchangeCodeForTokens(code: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let url = URL(string: tokenURL) else {
            await MainActor.run {
                self.errorMessage = "Invalid token URL"
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Origin")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Referer")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code", value: code)
        ]

        request.httpBody = components.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    await MainActor.run {
                        self.errorMessage = "Token exchange failed (Status \(httpResponse.statusCode)): \(errorText)"
                        self.isLoading = false
                    }
                    return
                }
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"

            // Check if we got an HTML response (Cloudflare protection)
            if responseString.lowercased().contains("<html") || responseString.lowercased().contains("<!doctype") {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Cloudflare protection detected. Please try again."
                }
                return
            }

            // Check if data is empty
            if data.isEmpty {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Empty response from server"
                }
                return
            }

            // Try to detect if this is a JSON error response from Jobber
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = jsonObject["error"] as? String {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "OAuth Error: \(error)"
                        if let description = jsonObject["error_description"] as? String {
                            self.errorMessage = "OAuth Error: \(error) - \(description)"
                        }
                    }
                    return
                }
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            await MainActor.run {
                self.storeTokens(tokenResponse)
                self.isAuthenticated = true
                self.errorMessage = nil
                self.isLoading = false
                self.storedState = nil

                // Fetch account info to verify connection
                Task {
                    await self.fetchAccountInfo()
                    // After fetching account info, also fetch jobs
                    await self.fetchScheduledAssessments()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to exchange code for tokens: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func storeTokens(_ tokenResponse: TokenResponse) {
        self.accessToken = tokenResponse.access_token
        self.refreshToken = tokenResponse.refresh_token

        // Set expiry with 60 second buffer - default to 1 hour if not provided
        let expiresIn = tokenResponse.expires_in ?? 3600
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        self.tokenExpiry = expiryDate

        print("Tokens stored successfully. Access token expires at: \(expiryDate)")
    }

    private func refreshAccessTokens() async {
        guard let refreshToken = self.refreshToken else {
            await MainActor.run {
                self.signOut()
            }
            return
        }

        guard let url = URL(string: tokenURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Origin")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Referer")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        request.httpBody = components.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                    await MainActor.run {
                        self.errorMessage = "Session expired. Please reconnect your Jobber account."
                        self.signOut()
                    }
                    return
                } else if httpResponse.statusCode != 200 {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    await MainActor.run {
                        self.errorMessage = "Token refresh failed: \(errorText)"
                        self.signOut()
                    }
                    return
                }
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            await MainActor.run {
                self.storeTokens(tokenResponse)
                self.isAuthenticated = true
                self.errorMessage = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh tokens. Please reconnect your account."
                self.signOut()
            }
        }
    }

    func ensureValidAccessToken() async -> Bool {
        guard accessToken != nil else {
            print("No access token available")
            return false
        }

        // Check if access token is expired or will expire in the next 5 minutes
        if let expiry = tokenExpiry {
            let bufferTime: TimeInterval = 300 // 5 minutes
            if Date().addingTimeInterval(bufferTime) >= expiry {
                print("Token expired or expiring soon, attempting refresh...")
                await refreshAccessTokens()
            }
        }

        return isAuthenticated && accessToken != nil
    }

    private func fetchAccountInfo() async {
        guard await ensureValidAccessToken(), let _ = accessToken else { return }

        let query = """
        query GetAccountInfo {
          account {
            id
            name
          }
        }
        """

        await performGraphQLRequest(query: query, variables: [:]) { [weak self] (result: Result<AccountResponse, Error>) in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    self?.connectedEmail = response.data.account.name
                    print("Successfully connected as: \(response.data.account.name)")
                case .failure(let error):
                    print("Failed to fetch account info: \(error)")
                }
            }
        }
    }

    // Add rate limiting protection
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 2.0 // 2 seconds between requests

    private func shouldAllowRequest() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastRequestTime) < minimumRequestInterval {
            print("Rate limiting: Request blocked, too soon since last request")
            return false
        }
        lastRequestTime = now
        return true
    }

    func fetchScheduledAssessments() async {
        guard shouldAllowRequest() else {
            print("Skipping request due to rate limiting")
            return
        }

        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let today = Date()
        let calendar = Calendar.current

        // Get current date at start of day
        let startOfDay = calendar.startOfDay(for: today)
        // Get date 7 days from now
        let endDate = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? today
        let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        // Use ISO format for GraphQL variables
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let weekStart = isoFormatter.string(from: startOfDay)
        let weekEnd = isoFormatter.string(from: endOfWeek)

        print("Fetching scheduled assessments for next 7 days")
        print("Date range: \(weekStart) to \(weekEnd)")

        // Use the working GraphQL query from GraphiQL
        let query = """
        query getScheduledAssessments($start: ISO8601DateTime!, $end: ISO8601DateTime!, $first: Int!) {
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
                title
                startAt
                endAt
                completedAt
                instructions
                client {
                  id
                  name
                  firstName
                  lastName
                  companyName
                  emails {
                    address
                    description
                    primary
                  }
                  phones {
                    number
                    description
                    primary
                  }
                  billingAddress {
                    street1
                    city
                    province
                    postalCode
                  }
                }
                property {
                  id
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
                request {
                  id
                  requestStatus
                  source
                  title
                  notes {
                    nodes {
                      ... on RequestNote {
                        message
                      }
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
        """

        let variables: [String: Any] = [
            "start": weekStart,
            "end": weekEnd,
            "first": 20
        ]

        print("About to make GraphQL request with variables: \(variables)")

        await performGraphQLRequest(query: query, variables: variables) { [weak self] (result: Result<ScheduledAssessmentsResponse, Error>) in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                print("GraphQL request completed")

                switch result {
                case .success(let response):
                    var fetchedJobs: [JobberJob] = []

                    print("SUCCESS: Found \(response.data.scheduledItems.nodes.count) scheduled assessments")

                    for assessment in response.data.scheduledItems.nodes {
                        print("Processing assessment: \(assessment.id)")
                        print("Assessment title: \(assessment.title ?? "No title")")
                        print("Assessment startAt: \(assessment.startAt)")
                        print("Assessment request: \(String(describing: assessment.request))")
                        print("Assessment request ID: \(String(describing: assessment.request?.id))")

                        guard let startAt = self.parseDate(assessment.startAt) else {
                            print("Could not parse start date: \(assessment.startAt)")
                            continue
                        }

                        let clientName = assessment.client.name

                        // Extract primary phone number from enhanced phone structure
                        let clientPhone: String? = assessment.client.phones?.first(where: { $0.primary })?.number ?? assessment.client.phones?.first?.number

                        // Build address from property
                        let address: String
                        if let property = assessment.property?.address {
                            var addressComponents: [String] = []
                            if let street = property.street1, !street.isEmpty {
                                addressComponents.append(street)
                            }
                            if let city = property.city, !city.isEmpty {
                                addressComponents.append(city)
                            }
                            if let province = property.province, !province.isEmpty {
                                addressComponents.append(province)
                            }
                            address = addressComponents.joined(separator: ", ")
                        } else {
                            address = "Address not available"
                        }

                        // Determine status
                        let status: String
                        if assessment.completedAt != nil {
                            status = "completed"
                        } else if startAt <= Date() {
                            status = "in_progress"
                        } else {
                            status = "scheduled"
                        }

                        // Create JobberJob
                        // This correctly retrieves the service information from the notes
                        let serviceInformation = assessment.request?.notes?.nodes?
                            .compactMap { $0.message }
                            .joined(separator: "\n") ?? ""

                        print("🔍 Debug - Service Information from notes: '\(serviceInformation)'")
                        print("🔍 Debug - Request title: '\(assessment.request?.title ?? "nil")'")
                        print("🔍 Debug - Instructions: '\(assessment.instructions ?? "nil")'")

                        let jobberJob = JobberJob(
                            jobId: assessment.id,
                            requestId: assessment.request?.id,
                            clientId: assessment.client.id,
                            propertyId: assessment.property?.id,
                            clientName: clientName,
                            clientPhone: clientPhone,
                            address: address,
                            scheduledAt: startAt,
                            status: status,
                            serviceTitle: assessment.request?.title,
                            instructions: assessment.instructions,
                            serviceInformation: serviceInformation,
                            serviceSpecifications: serviceInformation  // Use serviceInformation for both
                        )

                        print("Created JobberJob with requestId: \(String(describing: jobberJob.requestId))")
                        fetchedJobs.append(jobberJob)
                        print("Added assessment: \(clientName) at \(startAt) (\(status))")
                    }

                    self.jobs = fetchedJobs
                    print("Successfully fetched \(fetchedJobs.count) scheduled assessments")

                case .failure(let error):
                    print("FAILED to fetch scheduled assessments: \(error)")

                    if let apiError = error as? APIError {
                        switch apiError {
                        case .graphQLError(let message):
                            if message.contains("Throttled") {
                                self.errorMessage = "API rate limit reached. Please wait a moment and try again."
                                print("API throttled - waiting before retry")
                            } else {
                                print("GraphQL Error: \(message)")
                                self.errorMessage = "Jobber API Error: \(message)"
                            }
                        default:
                            self.errorMessage = error.localizedDescription
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func fetchAllScheduledItems() async {
        guard shouldAllowRequest() else {
            print("Skipping fetchAllScheduledItems due to rate limiting")
            return
        }

        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            return
        }

        print("Fetching recent scheduled items...")

        // Use the same dynamic date logic as fetchScheduledAssessments
        let today = Date()
        let calendar = Calendar.current

        // Get current date at start of day
        let startOfDay = calendar.startOfDay(for: today)
        // Get date 7 days from now
        let endDate = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? today
        let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        // Use ISO format for GraphQL variables
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startDate = isoFormatter.string(from: startOfDay)
        let endDateFormatted = isoFormatter.string(from: endOfWeek)

        let query = """
        query getAllScheduledItems($start: ISO8601DateTime!, $end: ISO8601DateTime!, $first: Int!) {
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
                title
                startAt
                endAt
                completedAt
                instructions
                client {
                  id
                  name
                  firstName
                  lastName
                  companyName
                  emails {
                    address
                    description
                    primary
                  }
                  phones {
                    number
                    description
                    primary
                  }
                  billingAddress {
                    street1
                    city
                    province
                    postalCode
                  }
                }
                property {
                  id
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
                request {
                  id
                  requestStatus
                  source
                  title
                  notes {
                    nodes {
                      ... on RequestNote {
                        message
                      }
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
        """

        let variables: [String: Any] = [
            "start": startDate,
            "end": endDateFormatted,
            "first": 10  // Reduced to 10 most recent items
        ]

        print("About to make GraphQL request for recent scheduled items")
        print("Dynamic date range: \(startDate) to \(endDateFormatted)")

        await performGraphQLRequest(query: query, variables: variables) { [weak self] (result: Result<ScheduledAssessmentsResponse, Error>) in
            Task { @MainActor in
                guard let self = self else { return }

                print("GraphQL request for recent items completed")

                switch result {
                case .success(let response):
                    var fetchedJobs: [JobberJob] = []

                    print("SUCCESS: Found \(response.data.scheduledItems.nodes.count) scheduled items in next 7 days")

                    for assessment in response.data.scheduledItems.nodes {
                        guard let startAt = self.parseDate(assessment.startAt) else {
                            continue
                        }

                        let clientName = assessment.client.name
                        let clientPhone: String? = assessment.client.phones?.first(where: { $0.primary })?.number ?? assessment.client.phones?.first?.number

                        // Build address from property
                        let address: String
                        if let property = assessment.property?.address {
                            var addressComponents: [String] = []
                            if let street = property.street1, !street.isEmpty {
                                addressComponents.append(street)
                            }
                            if let city = property.city, !city.isEmpty {
                                addressComponents.append(city)
                            }
                            if let province = property.province, !province.isEmpty {
                                addressComponents.append(province)
                            }
                            address = addressComponents.joined(separator: ", ")
                        } else {
                            address = "Address not available"
                        }

                        let status: String
                        if assessment.completedAt != nil {
                            status = "completed"
                        } else if startAt <= Date() {
                            status = "in_progress"
                        } else {
                            status = "scheduled"
                        }

                        // This correctly retrieves the service information from the notes
                        let serviceInformation = assessment.request?.notes?.nodes?
                            .compactMap { $0.message }
                            .joined(separator: "\n") ?? ""

                        // Debug logging to confirm the data is being parsed correctly
                        print("🔍 Debug - Service Information from notes: '\(serviceInformation)'")

                        let jobberJob = JobberJob(
                            jobId: assessment.id,
                            requestId: assessment.request?.id,
                            clientId: assessment.client.id,
                            propertyId: assessment.property?.id,
                            clientName: clientName,
                            clientPhone: clientPhone,
                            address: address,
                            scheduledAt: startAt,
                            status: status,
                            serviceTitle: assessment.request?.title,
                            instructions: assessment.instructions,
                            serviceInformation: serviceInformation,
                            serviceSpecifications: serviceInformation  // Use serviceInformation for both
                        )

                        fetchedJobs.append(jobberJob)
                        print("Added item: \(clientName) at \(startAt) (\(status))")
                    }

                    self.jobs = fetchedJobs
                    print("Successfully fetched \(fetchedJobs.count) scheduled items for next 7 days")

                case .failure(let error):
                    print("FAILED to fetch scheduled items: \(error)")
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .graphQLError(let message):
                            if message.contains("Throttled") {
                                self.errorMessage = "API rate limit reached. Please wait a moment before refreshing."
                            } else {
                                self.errorMessage = "Jobber API Error: \(message)"
                            }
                        default:
                            self.errorMessage = error.localizedDescription
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// Fetches product details including description for use in quotes
    private func fetchProductDetails(productId: String) async -> Result<(name: String, description: String), Error> {
        guard await ensureValidAccessToken() else {
            return .failure(APIError.noToken)
        }

        let query = """
        query getProductDetails($productId: EncodedId!) {
          product(id: $productId) {
            id
            name
            description
          }
        }
        """

        let variables: [String: Any] = ["productId": productId]

        return await withCheckedContinuation { continuation in
            Task {
                await performGraphQLRequest(query: query, variables: variables) { [weak self] (result: Result<ProductDetailsResponse, Error>) in
                    Task { @MainActor in
                        guard self != nil else {
                            continuation.resume(returning: .failure(APIError.invalidResponse))
                            return
                        }

                        switch result {
                        case .success(let response):
                            if let product = response.data.product {
                                let name = product.name ?? ""
                                let description = product.description ?? ""
                                continuation.resume(returning: .success((name: name, description: description)))
                            } else {
                                continuation.resume(returning: .failure(APIError.invalidResponse))
                            }
                        case .failure(let error):
                            continuation.resume(returning: .failure(error))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Product Details Response Models
    struct ProductDetailsResponse: Codable {
        let data: ProductDetailsData
    }

    struct ProductDetailsData: Codable {
        let product: ProductDetailsNode?
    }

    struct ProductDetailsNode: Codable {
        let id: String
        let name: String?
        let description: String?
    }

    func createQuoteDraft(quoteDraft: QuoteDraft) async {
        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let lineItems = quoteDraft.lineItemsForJobber.map { item in
            [
                "name": item.name,
                "description": item.description,
                "quantity": item.quantity,
                "unitCost": item.unitPrice
            ]
        }

        let variables: [String: Any] = [
            "attributes": [
                "clientId": quoteDraft.clientId ?? "",
                "title": "Gutter Installation Quote",
                "lineItems": lineItems
            ]
        ]

        let mutation = """
        mutation CreateQuote($attributes: QuoteCreateAttributes!) {
          quoteCreate(attributes: $attributes) {
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
        """

        await performGraphQLRequest(query: mutation, variables: variables) { [weak self] (result: Result<QuoteCreateResponse, Error>) in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let response):
                    if let userErrors = response.data.quoteCreate.userErrors, !userErrors.isEmpty {
                        let errors = userErrors.map { $0.message }.joined(separator: ", ")
                        self.errorMessage = "Quote creation failed: \(errors)"
                    } else {
                        self.errorMessage = nil
                        print("Quote created successfully")
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to create quote: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Creates a simple Jobber quote from a JobberJob (assessment)
    func createQuoteFromJob(
        job: JobberJob,
        quoteDraft: QuoteDraft,
        completion: @escaping (Result<String, Error>) -> Void
    ) async {
        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            completion(.failure(APIError.noToken))
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        print("Creating quote from JobberJob: \(job.jobId)")
        print("Client: \(job.clientName)")
        print("Request ID: \(String(describing: job.requestId))")

        // Debug the job data first
        print("DEBUG: JobberJob data:")
        print("  - jobId: \(job.jobId)")
        print("  - clientId: '\(job.clientId)'")
        print("  - propertyId: \(String(describing: job.propertyId))")
        print("  - requestId: \(String(describing: job.requestId))")

        // Convert QuoteDraft line items to Jobber format
        let lineItems = quoteDraft.lineItemsForJobber.map { item in
            [
                "name": item.name,
                "description": item.description,
                "quantity": item.quantity,
                "unitCost": item.unitPrice
            ]
        }

        // Build input dictionary with proper client and property references
        var inputDict: [String: Any] = [
            "title": "Gutter Installation Quote - \(job.clientName)",
            "lineItems": lineItems
        ]

        // Use request ID first, otherwise use clientId and propertyId
        // But based on the error, it seems like we need to provide clientId and propertyId even when we have requestId
        if let requestId = job.requestId {
            inputDict["requestId"] = requestId
            print("Linking quote to request ID: \(requestId)")

            // Also provide clientId and propertyId if available (seems to be required by the API)
            if !job.clientId.isEmpty && job.clientId != "unknown" {
                inputDict["clientId"] = job.clientId
                print("Also including clientId: \(job.clientId)")
            }
            if let propertyId = job.propertyId, !propertyId.isEmpty {
                inputDict["propertyId"] = propertyId
                print("Also including propertyId: \(propertyId)")
            }
        } else if !job.clientId.isEmpty && job.clientId != "unknown", let propertyId = job.propertyId, !propertyId.isEmpty {
            inputDict["clientId"] = job.clientId
            inputDict["propertyId"] = propertyId
            print("Using clientId: \(job.clientId) and propertyId: \(propertyId)")
        } else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Cannot create quote: Missing client ID ('\(job.clientId)') or property ID ('\(String(describing: job.propertyId))')"
            }
            completion(.failure(APIError.invalidResponse))
            return
        }

        let variables: [String: Any] = ["attributes": inputDict]

        let mutation = """
        mutation CreateQuote($attributes: QuoteCreateAttributes!) {
          quoteCreate(attributes: $attributes) {
            quote {
              id
              title
              createdAt
              client {
                id
                name
              }
            }
            userErrors {
              field
              message
              path
            }
          }
        }
        """

        await performGraphQLRequest(query: mutation, variables: variables) { [weak self] (result: Result<QuoteCreateResponse, Error>) in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let response):
                    if let userErrors = response.data.quoteCreate.userErrors, !userErrors.isEmpty {
                        let errors = userErrors.map { $0.message }.joined(separator: ", ")
                        let errorMessage = "Quote creation failed: \(errors)"
                        self.errorMessage = errorMessage
                        print("❌ Quote creation failed: \(errors)")
                        completion(.failure(APIError.graphQLError(errorMessage)))
                    } else if let quote = response.data.quoteCreate.quote {
                        self.errorMessage = nil
                        let successMessage = "Quote '\(quote.title)' created successfully with ID: \(quote.id)"
                        print("✅ \(successMessage)")
                        completion(.success(quote.id))
                    } else {
                        let errorMessage = "Quote creation succeeded but no quote data returned"
                        self.errorMessage = errorMessage
                        print("❌ \(errorMessage)")
                        completion(.failure(APIError.invalidResponse))
                    }
                case .failure(let error):
                    let errorMessage = "Failed to create quote: \(error.localizedDescription)"
                    self.errorMessage = errorMessage
                    print("❌ \(errorMessage)")
                    completion(.failure(error))
                }
            }
        }
    }

    /// Creates a Jobber quote draft from an assessment with pre-filled line items
    func createQuoteFromAssessment(
        assessment: AssessmentNode,
        quoteDraft: QuoteDraft,
        completion: @escaping (Result<String, Error>) -> Void
    ) async {
        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            completion(.failure(APIError.noToken))
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        print("Creating quote from assessment: \(assessment.id)")
        print("Assessment title: \(assessment.title ?? "No title")")
        print("Client ID: \(assessment.client.id)")
        print("Request ID: \(String(describing: assessment.request?.id))")

        // Convert QuoteDraft line items to Jobber format
        let lineItems = quoteDraft.lineItemsForJobber.map { item in
            [
                "name": item.name,
                "description": item.description,
                "quantity": item.quantity,
                "unitCost": item.unitPrice
            ]
        }

        var inputDict: [String: Any] = [
            "clientId": assessment.client.id,
            "title": assessment.title ?? "Gutter Installation Quote",
            "lineItems": lineItems
        ]

        // Link to original request if available
        if let requestId = assessment.request?.id {
            inputDict["requestId"] = requestId
            print("Linking quote to request ID: \(requestId)")
        }

        let variables: [String: Any] = ["attributes": inputDict]

        let mutation = """
        mutation CreateQuote($attributes: QuoteCreateAttributes!) {
          quoteCreate(attributes: $attributes) {
            quote {
              id
              title
              createdAt
              client {
                id
                name
              }
            }
            userErrors {
              field
              message
              path
            }
          }
        }
        """

        await performGraphQLRequest(query: mutation, variables: variables) { [weak self] (result: Result<QuoteCreateResponse, Error>) in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let response):
                    if let userErrors = response.data.quoteCreate.userErrors, !userErrors.isEmpty {
                        let errors = userErrors.map { $0.message }.joined(separator: ", ")
                        let errorMessage = "Quote creation failed: \(errors)"
                        self.errorMessage = errorMessage
                        print("❌ Quote creation failed: \(errors)")
                        completion(.failure(APIError.graphQLError(errorMessage)))
                    } else if let quote = response.data.quoteCreate.quote {
                        self.errorMessage = nil
                        let successMessage = "Quote '\(quote.title)' created successfully with ID: \(quote.id)"
                        print("✅ \(successMessage)")
                        completion(.success(quote.id))
                    } else {
                        let errorMessage = "Quote creation succeeded but no quote data returned"
                        self.errorMessage = errorMessage
                        print("❌ \(errorMessage)")
                        completion(.failure(APIError.invalidResponse))
                    }
                case .failure(let error):
                    let errorMessage = "Failed to create quote: \(error.localizedDescription)"
                    self.errorMessage = errorMessage
                    print("❌ \(errorMessage)")
                    completion(.failure(error))
                }
            }
        }
    }

    /// Creates a Jobber quote from measurements with proper line item structure
    ///
    /// IMPORTANT: This function ensures that the line item prices sent to Jobber include
    /// the full calculated price (materials + labor + markup + commission + tax).
    /// Previously, only base costs were being sent, causing a mismatch between the
    /// app's total ($624.02) and Jobber's quote total ($424.00).
    ///
    /// The fix distributes the final marked-up price proportionally across line items
    /// based on their base cost ratios, ensuring the Jobber quote total matches
    /// the app's calculated total exactly.
    func createQuoteFromJobWithMeasurements(
        job: JobberJob,
        quoteDraft: QuoteDraft,
        breakdown: PricingEngine.PriceBreakdown,
        settings: AppSettings
    ) async -> Result<String, Error> {
        guard await ensureValidAccessToken() else {
            await MainActor.run {
                self.errorMessage = "Please connect your Jobber account first"
            }
            return .failure(APIError.noToken)
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        print("Creating measurement-based quote for JobberJob: \(job.jobId)")
        print("Client: \(job.clientName)")
        print("Gutter Feet: \(quoteDraft.gutterFeet)")
        print("Downspout Feet: \(quoteDraft.downspoutFeet)")
        print("Include Gutter Guard: \(quoteDraft.includeGutterGuard)")
        print("Gutter Guard Feet: \(quoteDraft.gutterGuardFeet)")

        // The Correct IDs You Found
        let gutterProductId = "Z2lkOi8vSm9iYmVyL1Byb2R1Y3RPclNlcnZpY2UvNzE0MDU3Mg=="
        let gutterGuardProductId = "Z2lkOi8vSm9iYmVyL1Byb2R1Y3RPclNlcnZpY2UvODg4Nzk3OQ=="

        // Step 1: Fetch product details to get descriptions
        print("Fetching product details...")

        let gutterDetailsResult = await fetchProductDetails(productId: gutterProductId)
        guard case .success(let gutterDetails) = gutterDetailsResult else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to fetch gutter product details"
            }
            return .failure(APIError.invalidResponse)
        }

        var gutterGuardDetails: (name: String, description: String)?
        if quoteDraft.includeGutterGuard && quoteDraft.gutterGuardFeet > 0 {
            let gutterGuardDetailsResult = await fetchProductDetails(productId: gutterGuardProductId)
            guard case .success(let details) = gutterGuardDetailsResult else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch gutter guard product details"
                }
                return .failure(APIError.invalidResponse)
            }
            gutterGuardDetails = details
        }

        // Step 2: Create line items with proper pricing that includes markup and commission
        var lineItems: [[String: Any]] = []

        // Calculate the total price for the main work (gutters + guard), excluding additional items
        let additionalItemsTotal = quoteDraft.additionalLaborItems.reduce(0, { $0 + $1.amount })

        print("📊 PRICING DEBUG:")
        print("  App's final total (breakdown.totalPrice): $\(String(format: "%.2f", breakdown.totalPrice))")
        print("  Additional items total: $\(String(format: "%.2f", additionalItemsTotal))")

        if quoteDraft.includeGutterGuard && quoteDraft.gutterGuardFeet > 0, let guardDetails = gutterGuardDetails {
            // SCENARIO 1: WITH Gutter Guard - Distribute final price proportionally

            // Calculate the base cost of each component to find their proportion of the total
            // Use the exact same calculation as the app's JobViews.swift
            let totalElbows = quoteDraft.aElbows + quoteDraft.bElbows + quoteDraft.twoCrimp + quoteDraft.fourCrimp
            let elbowUnitCost = quoteDraft.isRoundDownspout ? settings.costPerRoundElbow : settings.costPerElbow
            let elbowsCost = Double(totalElbows) * elbowUnitCost
            let hangersCost = Double(quoteDraft.hangersCount) * settings.costPerHanger

            let gutterMaterialsCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost + elbowsCost + hangersCost
            let guardMaterialsCost = breakdown.gutterGuardCost

            // Use breakdown's accurate labor calculations instead of estimated rates
            let gutterLaborCost = breakdown.gutterLaborCost
            let guardLaborCost = breakdown.gutterGuardLaborCost

            let gutterBaseCost = gutterMaterialsCost + gutterLaborCost
            let guardBaseCost = guardMaterialsCost + guardLaborCost
            let totalBaseCost = gutterBaseCost + guardBaseCost

            print("  Gutter materials: $\(String(format: "%.2f", gutterMaterialsCost))")
            print("  Gutter labor: $\(String(format: "%.2f", gutterLaborCost))")
            print("  Gutter base cost: $\(String(format: "%.2f", gutterBaseCost))")
            print("  Guard materials: $\(String(format: "%.2f", guardMaterialsCost))")
            print("  Guard labor: $\(String(format: "%.2f", guardLaborCost))")
            print("  Guard base cost: $\(String(format: "%.2f", guardBaseCost))")
            print("  Total base cost: $\(String(format: "%.2f", totalBaseCost))")

            // Calculate proportions for distributing the EXACT app total
            var gutterProportionValue = 0.5
            var guardProportionValue = 0.5

            if totalBaseCost > 0.0 {
                gutterProportionValue = gutterBaseCost.magnitude / totalBaseCost.magnitude
                guardProportionValue = 1.0 - gutterProportionValue
            }

            print("  Gutter proportion: \(String(format: "%.4f", gutterProportionValue))")
            print("  Guard proportion: \(String(format: "%.4f", guardProportionValue))")

            // Distribute the app's exact total amount (including all additional labor items)
            let appTotal = breakdown.totalPrice
            let gutterFinalPrice = appTotal * gutterProportionValue
            let guardFinalPrice = appTotal * guardProportionValue

            print("  Gutter final price (proportional): $\(String(format: "%.2f", gutterFinalPrice))")
            print("  Guard final price (proportional): $\(String(format: "%.2f", guardFinalPrice))")
            print("  Verification total: $\(String(format: "%.2f", gutterFinalPrice + guardFinalPrice))")
            print("  🔍 App's breakdown.totalPrice: $\(String(format: "%.2f", breakdown.totalPrice))")

            let jobberTotal = gutterFinalPrice + guardFinalPrice
            let difference = jobberTotal - appTotal
            print("  ✅ Jobber total: $\(String(format: "%.2f", jobberTotal))")
            print("  ✅ Difference (should be ~0): $\(String(format: "%.2f", difference))")

            // 1. Gutter line item with final calculated price (includes markup/commission)
            lineItems.append([
                "productOrServiceId": gutterProductId,
                "name": gutterDetails.name,
                "description": gutterDetails.description,
                "quantity": 1,
                "unitPrice": gutterFinalPrice,
                "saveToProductsAndServices": false
            ])
            print("✅ Gutter line item (with markup): $\(String(format: "%.2f", gutterFinalPrice))")

            // 2. Gutter Guard line item with final calculated price (includes markup/commission)
            lineItems.append([
                "productOrServiceId": gutterGuardProductId,
                "name": guardDetails.name,
                "description": guardDetails.description,
                "quantity": 1,
                "unitPrice": guardFinalPrice,
                "saveToProductsAndServices": false
            ])
            print("✅ Gutter guard line item (with markup): $\(String(format: "%.2f", guardFinalPrice))")

        } else {
            // SCENARIO 2: WITHOUT Gutter Guard - All final price goes to gutter
            let appTotal = breakdown.totalPrice

            print("  Single gutter line item gets full price: $\(String(format: "%.2f", appTotal))")

            lineItems.append([
                "productOrServiceId": gutterProductId,
                "name": gutterDetails.name,
                "description": gutterDetails.description,
                "quantity": 1,
                "unitPrice": appTotal,
                "saveToProductsAndServices": false
            ])
            print("✅ Complete gutter line item (with markup): $\(String(format: "%.2f", appTotal))")
        }

        // Additional labor items are already included in the proportional distribution above
        // Do NOT add them separately to avoid double-counting

        // Debug: Print constructed line items
        print("📋 Constructed Line Items:")
        for (index, item) in lineItems.enumerated() {
            if let name = item["name"] as? String, let price = item["unitPrice"] as? Double {
                print("  \(index + 1). \(name): $\(String(format: "%.2f", price))")
            }
        }

        let totalLineItems = lineItems.compactMap { $0["unitPrice"] as? Double }.reduce(0, +)
        print("📊 Total line items: $\(String(format: "%.2f", totalLineItems))")
        print("📊 Should match app total: $\(String(format: "%.2f", breakdown.totalPrice))")

        // Build custom fields based on the quote data
        var customFields: [[String: Any]] = []

        // Add Color custom field (Text Type)
        customFields.append([
            "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvblRleHQvMTA1ODc1Ng==",
            "valueText": quoteDraft.gutterColor
        ])

        // Add Gutter footage custom field (Numeric Type)
        if quoteDraft.gutterFeet > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc2NQ==",
                "valueNumeric": quoteDraft.gutterFeet
            ])
        }

        // Add Down Spout footage custom field (Numeric Type)
        if quoteDraft.downspoutFeet > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc3NA==",
                "valueNumeric": quoteDraft.downspoutFeet
            ])
        }

        // Add A Elbows custom field (Numeric Type)
        if quoteDraft.aElbows > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc3OA==",
                "valueNumeric": quoteDraft.aElbows
            ])
        }

        // Add B Elbows custom field (Numeric Type)
        if quoteDraft.bElbows > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc4Mg==",
                "valueNumeric": quoteDraft.bElbows
            ])
        }

        // Add 2 Crimp custom field (Numeric Type)
        if quoteDraft.twoCrimp > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc4Ng==",
                "valueNumeric": quoteDraft.twoCrimp
            ])
        }

        // Add 4 Crimp custom field (Numeric Type)
        if quoteDraft.fourCrimp > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc5MA==",
                "valueNumeric": quoteDraft.fourCrimp
            ])
        }

        // Add End Caps custom field (Numeric Type)
        if quoteDraft.endCapPairs > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc5NA==",
                "valueNumeric": quoteDraft.endCapPairs
            ])
        }

        // Add Gutter Guard (Rigid Flow) custom field (Numeric Type)
        if quoteDraft.includeGutterGuard && quoteDraft.gutterGuardFeet > 0 {
            customFields.append([
                "customFieldConfigurationId": "Z2lkOi8vSm9iYmVyL0N1c3RvbUZpZWxkQ29uZmlndXJhdGlvbk51bWVyaWMvMTA1ODc2OQ==",
                "valueNumeric": quoteDraft.gutterGuardFeet
            ])
        }

        // Build the input dictionary
        var inputDict: [String: Any] = [
            "title": "Gutter Installation Quote - \(job.clientName)",
            "lineItems": lineItems,
            "customFields": customFields
        ]

        // Debug the job data first
        print("DEBUG: JobberJob data:")
        print("  - jobId: \(job.jobId)")
        print("  - clientId: '\(job.clientId)'")
        print("  - propertyId: \(String(describing: job.propertyId))")
        print("  - requestId: \(String(describing: job.requestId))")

        // Link to request - API requires either requestId OR both clientId and propertyId
        // But based on the error, it seems like we need to provide clientId and propertyId even when we have requestId
        if let requestId = job.requestId {
            inputDict["requestId"] = requestId
            print("Linking quote to request ID: \(requestId)")

            // Also provide clientId and propertyId if available (seems to be required by the API)
            if !job.clientId.isEmpty && job.clientId != "unknown" {
                inputDict["clientId"] = job.clientId
                print("Also including clientId: \(job.clientId)")
            }
            if let propertyId = job.propertyId, !propertyId.isEmpty {
                inputDict["propertyId"] = propertyId
                print("Also including propertyId: \(propertyId)")
            }
        } else if !job.clientId.isEmpty && job.clientId != "unknown", let propertyId = job.propertyId, !propertyId.isEmpty {
            // Use clientId and propertyId if available
            inputDict["clientId"] = job.clientId
            inputDict["propertyId"] = propertyId
            print("Using clientId: \(job.clientId) and propertyId: \(propertyId)")
        } else {
            // For now, we can't create quotes without proper client/property linkage
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Cannot create quote: Missing client ID ('\(job.clientId)') or property ID ('\(String(describing: job.propertyId))')"
            }
            return .failure(APIError.invalidResponse)
        }

        let variables: [String: Any] = ["attributes": inputDict]

        let mutation = """
        mutation CreateQuote($attributes: QuoteCreateAttributes!) {
          quoteCreate(attributes: $attributes) {
            quote {
              id
              title
              createdAt
              client {
                id
                name
              }
              customFields {
                ... on CustomFieldText {
                  id
                  valueText
                  customFieldConfiguration {
                    id
                    name
                  }
                }
                ... on CustomFieldNumeric {
                  id
                  valueNumeric
                  customFieldConfiguration {
                    id
                    name
                  }
                }
              }
            }
            userErrors {
              message
              path
            }
          }
        }
        """

        return await withCheckedContinuation { continuation in
            Task {
                await performGraphQLRequest(query: mutation, variables: variables) { [weak self] (result: Result<QuoteCreateResponse, Error>) in
                    Task { @MainActor in
                        guard let self = self else {
                            continuation.resume(returning: .failure(APIError.invalidResponse))
                            return
                        }
                        self.isLoading = false

                        switch result {
                        case .success(let response):
                            if let userErrors = response.data.quoteCreate.userErrors, !userErrors.isEmpty {
                                let errors = userErrors.map { $0.message }.joined(separator: ", ")
                                let errorMessage = "Quote creation failed: \(errors)"
                                self.errorMessage = errorMessage
                                print("❌ Quote creation failed: \(errors)")
                                continuation.resume(returning: .failure(APIError.graphQLError(errorMessage)))
                            } else if let quote = response.data.quoteCreate.quote {
                                self.errorMessage = nil
                                let successMessage = "Quote '\(quote.title)' created successfully with ID: \(quote.id)"
                                print("✅ \(successMessage)")
                                continuation.resume(returning: .success(quote.id))
                            } else {
                                let errorMessage = "Quote creation succeeded but no quote data returned"
                                self.errorMessage = errorMessage
                                print("❌ \(errorMessage)")
                                continuation.resume(returning: .failure(APIError.invalidResponse))
                            }
                        case .failure(let error):
                            let errorMessage = "Failed to create quote: \(error.localizedDescription)"
                            self.errorMessage = errorMessage
                            print("❌ \(errorMessage)")
                            continuation.resume(returning: .failure(error))
                        }
                    }
                }
            }
        }
    }

    /// Creates a pre-filled QuoteDraft from an AssessmentNode
    func createQuoteDraftFromAssessment(_ assessment: AssessmentNode, settings: AppSettings) -> QuoteDraft {
        let quoteDraft = QuoteDraft()

        // Pre-fill basic information
        quoteDraft.clientId = assessment.client.id
        quoteDraft.clientName = assessment.client.name

        // Apply default settings for markup and commission percentages
        quoteDraft.applyDefaultSettings(settings)

        // Use assessment title as quote notes
        if let title = assessment.title {
            quoteDraft.notes = "Assessment: \(title)"
        }

        // Add assessment instructions to notes if available
        if let instructions = assessment.instructions, !instructions.isEmpty {
            if !quoteDraft.notes.isEmpty {
                quoteDraft.notes += "\n\nInstructions: \(instructions)"
            } else {
                quoteDraft.notes = "Instructions: \(instructions)"
            }
        }

        // Add address information if available
        if let property = assessment.property?.address {
            var addressComponents: [String] = []
            if let street = property.street1, !street.isEmpty {
                addressComponents.append(street)
            }
            if let city = property.city, !city.isEmpty {
                addressComponents.append(city)
            }
            if let province = property.province, !province.isEmpty {
                addressComponents.append(province)
            }

            if !addressComponents.isEmpty {
                let address = addressComponents.joined(separator: ", ")
                if !quoteDraft.notes.isEmpty {
                    quoteDraft.notes += "\n\nProperty: \(address)"
                } else {
                    quoteDraft.notes = "Property: \(address)"
                }
            }
        }

        print("Created QuoteDraft from assessment:")
        print("- Client: \(quoteDraft.clientName)")
        print("- Client ID: \(quoteDraft.clientId ?? "nil")")
        print("- Notes: \(quoteDraft.notes)")

        return quoteDraft
    }

    // MARK: - Quote to Note Conversion

    /// Creates a formatted note message from quote data
    func formatQuoteForNote(quote: QuoteDraft, breakdown: PricingEngine.PriceBreakdown, photoCount: Int = 0) -> String {
        var message = "DTS APP QUOTE SUMMARY\n\n"

        // Photo note if photos exist
        if photoCount > 0 {
            message += "📸 \(photoCount) photo\(photoCount == 1 ? "" : "s") saved in DTS App\n\n"
        }

        // Notes section if available
        if !quote.notes.isEmpty {
            message += "NOTES\n"
            message += "\(quote.notes)\n\n"
        }

        // Materials
        message += "MATERIAL\n"
        message += "Gutter: \(String(format: "%.0f", quote.gutterFeet))ft\n"
        message += "Downspout: \(String(format: "%.0f", quote.downspoutFeet))ft \(quote.isRoundDownspout ? "(Round)" : "(Standard)")\n"

        message += "Gutter Guard: \(String(format: "%.0f", quote.gutterGuardFeet))ft\n"
        message += "A Elbows: \(quote.aElbows)\n"
        message += "B Elbows: \(quote.bElbows)\n"
        message += "2\" Crimp: \(quote.twoCrimp)\n"
        message += "4\" Crimp: \(quote.fourCrimp)\n"
        message += "End Caps: \(quote.endCapPairs) Pair\n"
        message += "Color: \(quote.gutterColor)\n\n"

        // Additional Labor Items
        if !quote.additionalLaborItems.isEmpty {
            message += "ADDITIONAL LABOR ITEMS\n"
            for item in quote.additionalLaborItems {
                message += "\(item.title): \(item.amount.toCurrency())\n"
            }
            message += "\n"
        }

        // Pricing Breakdown
        let totalMaterialCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost + breakdown.gutterGuardCost

        message += "PRICING BREAKDOWN\n"
        message += "Material: \(totalMaterialCost.toCurrency())\n"
        message += "Labor: \(breakdown.laborCost.toCurrency())\n"
        message += "Profit: \(breakdown.markupAmount.toCurrency())\n"
        message += "Commission: \(breakdown.commissionAmount.toCurrency())\n\n"

        // Calculate component totals (matching the PDF and UI display)
        let gutterBaseCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost + breakdown.gutterLaborCost
        let guardBaseCost = breakdown.gutterGuardCost + breakdown.gutterGuardLaborCost

        let gutterTotalBeforeAddOns = gutterBaseCost + breakdown.gutterMarkupAmount
        let guardTotalBeforeAddOns = guardBaseCost + breakdown.guardMarkupAmount

        let additionalCosts = breakdown.commissionAmount + breakdown.taxAmount
        let totalBeforeAddOns = gutterTotalBeforeAddOns + guardTotalBeforeAddOns
        let gutterShare = totalBeforeAddOns > 0 ? gutterTotalBeforeAddOns / totalBeforeAddOns : 0.5
        let guardShare = 1.0 - gutterShare

        let gutterTotalCost = gutterTotalBeforeAddOns + additionalCosts * gutterShare
        let guardTotalCost = guardTotalBeforeAddOns + additionalCosts * guardShare

        // Calculate price per foot using component totals
        if quote.gutterFeet > 0 {
            let gutterPricePerFoot = gutterTotalCost / (quote.gutterFeet + quote.downspoutFeet)
            message += "Gutter Price/ft: \(gutterPricePerFoot.toCurrency())\n"
        }

        if quote.includeGutterGuard && quote.gutterGuardFeet > 0 {
            let guardPricePerFoot = guardTotalCost / quote.gutterGuardFeet
            message += "Guard Price/ft: \(guardPricePerFoot.toCurrency())\n"
        }

        message += "Total Price: \(breakdown.totalPrice.toCurrency())\n\n"

        // App signature
        message += "Generated by DTS App\n"
        message += "Date: \(Date().formatted(date: .abbreviated, time: .shortened))"

        return message
    }

    /// Creates note attachments from captured photos (Legacy function - not used with imgbb)
    func createNoteAttachments(from photos: [UIImage]) -> [NoteAttachmentAttributes] {
        // This function is no longer used - photos are uploaded to imgbb first
        // Keeping for backwards compatibility
        return []
    }

    // MARK: - Image Upload (imgbb)

    /// Uploads image to imgbb and returns the direct URL with retry logic
    func uploadImageToImgbb(_ image: UIImage, maxRetries: Int = 3) async -> Result<String, Error> {
        let apiKey = "5e439e5a4e3c937ef15899d5efd99b30"
        let uploadURL = "https://api.imgbb.com/1/upload?key=\(apiKey)"

        // Convert image to JPEG with reduced quality for faster uploads
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to JPEG")
            return .failure(APIError.invalidResponse)
        }

        // Create request
        guard let url = URL(string: uploadURL) else {
            return .failure(APIError.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Retry loop with exponential backoff
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                if attempt > 0 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000) // 1s, 2s, 4s
                    print("⏱ Waiting \(Int(pow(2.0, Double(attempt))))s before retry...")
                    try await Task.sleep(nanoseconds: delay)
                }

                print("📤 Upload attempt \(attempt + 1) of \(maxRetries)...")
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Retry on 5xx server errors, but not 4xx client errors
                if httpResponse.statusCode >= 500 {
                    print("❌ Server error (\(httpResponse.statusCode)), will retry...")
                    lastError = APIError.graphQLError("Server error \(httpResponse.statusCode)")
                    continue
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ imgbb upload failed with status: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ imgbb error: \(errorString)")
                    }
                    return .failure(APIError.graphQLError("Upload failed with status \(httpResponse.statusCode)"))
                }

                // Parse response
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let dataDict = json?["data"] as? [String: Any],
                      let imageURL = dataDict["url"] as? String else {
                    print("❌ Failed to parse imgbb response")
                    throw APIError.invalidResponse
                }

                print("✅ Image uploaded to imgbb: \(imageURL)")
                return .success(imageURL)

            } catch {
                print("❌ Upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                lastError = error

                // Don't retry on certain errors
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .badURL, .unsupportedURL:
                        return .failure(error) // Don't retry on permanent errors
                    default:
                        break // Retry on network errors
                    }
                }
            }
        }

        print("❌ All \(maxRetries) upload attempts failed")
        return .failure(lastError ?? APIError.graphQLError("Upload failed after \(maxRetries) attempts"))
    }

    /// Uploads multiple images to imgbb in parallel with retry logic
    func uploadImagesToImgbb(_ images: [UIImage], progressCallback: ((Int, Int) -> Void)? = nil) async throws -> [String] {
        guard !images.isEmpty else { return [] }

        print("📸 Starting parallel upload of \(images.count) photo(s) to imgbb...")

        // Upload with limited parallelism (max 3 concurrent uploads)
        let imageURLs = await withTaskGroup(of: (index: Int, result: Result<String, Error>).self, returning: [String].self) { group in
            var activeUploads = 0
            let maxConcurrent = 3
            var pendingIndices = Array(images.indices)
            var results: [(Int, Result<String, Error>)] = []

            // Start initial batch
            while activeUploads < maxConcurrent && !pendingIndices.isEmpty {
                let index = pendingIndices.removeFirst()
                let image = images[index]
                activeUploads += 1

                group.addTask {
                    print("📤 Starting upload \(index + 1) of \(images.count)...")
                    let result = await self.uploadImageToImgbb(image)
                    return (index, result)
                }
            }

            // Process results and start new uploads
            for await (index, result) in group {
                activeUploads -= 1
                results.append((index, result))

                switch result {
                case .success(_):
                    print("✅ Photo \(index + 1) uploaded successfully")
                    // Notify progress callback on main actor
                    Task { @MainActor in
                        progressCallback?(results.count, images.count)
                    }
                case .failure(let error):
                    print("❌ Photo \(index + 1) failed: \(error.localizedDescription)")
                }

                // Start next upload if available
                if !pendingIndices.isEmpty {
                    let nextIndex = pendingIndices.removeFirst()
                    let nextImage = images[nextIndex]
                    activeUploads += 1

                    group.addTask {
                        print("📤 Starting upload \(nextIndex + 1) of \(images.count)...")
                        let result = await self.uploadImageToImgbb(nextImage)
                        return (nextIndex, result)
                    }
                }
            }

            // Sort by index and extract successful URLs
            results.sort { $0.0 < $1.0 }
            let successfulURLs = results.compactMap { index, result -> String? in
                if case .success(let url) = result {
                    return url
                }
                return nil
            }

            return successfulURLs
        }

        print("📸 Upload complete: \(imageURLs.count) of \(images.count) photos succeeded")

        // Validate all photos uploaded successfully
        guard imageURLs.count == images.count else {
            let failedCount = images.count - imageURLs.count
            throw APIError.graphQLError("Failed to upload \(failedCount) of \(images.count) photos. Please check your internet connection and try again.")
        }

        return imageURLs
    }

    /// Submits quote as a note to Jobber request
    func submitQuoteAsNote(
        requestId: String,
        quote: QuoteDraft,
        breakdown: PricingEngine.PriceBreakdown,
        photos: [UIImage] = [],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async -> Result<RequestNote, APIError> {

        print("📝 submitQuoteAsNote called with requestId: \(requestId)")
        print("📸 Uploading \(photos.count) photo(s) to imgbb...")

        // Step 1: Upload photos to imgbb and get URLs
        var photoURLs: [String] = []
        if !photos.isEmpty {
            do {
                photoURLs = try await uploadImagesToImgbb(photos, progressCallback: progressCallback)
                print("✅ Uploaded \(photoURLs.count) photos successfully")

                // Add delay to ensure imgbb URLs are propagated
                print("⏱ Waiting 1.5s for URL propagation...")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                print("❌ Photo upload failed: \(error.localizedDescription)")
                return .failure(.graphQLError(error.localizedDescription))
            }
        }

        // Step 2: Create note with attachments
        let message = formatQuoteForNote(quote: quote, breakdown: breakdown, photoCount: photoURLs.count)

        // Convert URLs to NoteAttachmentAttributes
        let attachments = photoURLs.isEmpty ? nil : photoURLs.map { NoteAttachmentAttributes(url: $0) }

        let input = RequestCreateNoteInput(
            message: message,
            attachments: attachments,
            pinned: true, // Pin important quotes
            linkedTo: nil // Could link to related jobs if needed
        )

        return await withCheckedContinuation { continuation in
            Task {
                await createRequestNote(requestId: requestId, input: input) { result in
                    switch result {
                    case .success(let response):
                        if !response.userErrors.isEmpty {
                            let errorMessage = response.userErrors.map { $0.message }.joined(separator: ", ")
                            print("❌ Request note creation failed with user errors: \(errorMessage)")
                            continuation.resume(returning: .failure(.graphQLError(errorMessage)))
                        } else {
                            if let noteData = response.requestNote {
                                print("✅ Request note created successfully with ID: \(noteData.id)")
                                continuation.resume(returning: .success(noteData))
                            } else {
                                print("❌ Request note creation succeeded but no note data returned")
                                continuation.resume(returning: .failure(.invalidResponse))
                            }
                        }
                    case .failure(let error):
                        print("❌ Request note creation failed with error: \(error)")
                        if let apiError = error as? APIError {
                            continuation.resume(returning: .failure(apiError))
                        } else {
                            continuation.resume(returning: .failure(.graphQLError(error.localizedDescription)))
                        }
                    }
                }
            }
        }
    }

    /// GraphQL mutation to create a request note
    private func createRequestNote(
        requestId: String,
        input: RequestCreateNoteInput,
        completion: @escaping (Result<RequestCreateNoteResponse, Error>) -> Void
    ) async {

        let mutation = """
        mutation RequestCreateNote($requestId: EncodedId!, $input: RequestCreateNoteInput!) {
          requestCreateNote(requestId: $requestId, input: $input) {
            requestNote {
              id
              message
              createdAt
              createdBy {
                ... on User {
                  name {
                    first
                    last
                  }
                }
              }
            }
            userErrors {
              message
              path
            }
          }
        }
        """

        var variables: [String: Any] = [
            "requestId": requestId,
            "input": [
                "message": input.message,
                "pinned": input.pinned
            ]
        ]

        // Add attachments if present
        if let attachments = input.attachments {
            var attachmentData: [[String: Any]] = []
            for attachment in attachments {
                attachmentData.append([
                    "url": attachment.url
                ])
            }
            var inputDict = variables["input"] as! [String: Any]
            inputDict["attachments"] = attachmentData
            variables["input"] = inputDict
        }

        // Add linked items if present
        if let linkedTo = input.linkedTo {
            var linkData: [String: Any] = [:]
            if let jobIds = linkedTo.jobIds {
                linkData["jobIds"] = jobIds
            }
            if let quoteIds = linkedTo.quoteIds {
                linkData["quoteIds"] = quoteIds
            }
            if let invoiceIds = linkedTo.invoiceIds {
                linkData["invoiceIds"] = invoiceIds
            }
            if !linkData.isEmpty {
                var inputDict = variables["input"] as! [String: Any]
                inputDict["linkedTo"] = linkData
                variables["input"] = inputDict
            }
        }

        await performGraphQLRequest(query: mutation, variables: variables) { (result: Result<RequestCreateNoteRawResponse, Error>) in
            switch result {
            case .success(let rawResponse):
                let response = RequestCreateNoteResponse(
                    requestNote: rawResponse.data.requestCreateNote.requestNote,
                    userErrors: rawResponse.data.requestCreateNote.userErrors?.map {
                        GraphQLError(message: $0.message, path: $0.path ?? [])
                    } ?? []
                )
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Submit photos as a note to a Job
    func submitPhotosAsJobNote(
        jobId: String,
        photos: [UIImage],
        message: String = "Photos uploaded from DTS App"
    ) async -> Result<JobNote, APIError> {

        print("📝 submitPhotosAsJobNote called with jobId: \(jobId)")
        print("📸 Uploading \(photos.count) photo(s) to imgbb...")

        // Step 1: Upload photos to imgbb and get URLs
        var photoURLs: [String] = []
        if !photos.isEmpty {
            do {
                photoURLs = try await uploadImagesToImgbb(photos)
                print("📸 Got \(photoURLs.count) photo URLs from imgbb")
            } catch {
                print("❌ Failed to upload images to imgbb: \(error.localizedDescription)")
                return .failure(.invalidResponse)
            }
        }

        // Step 2: Create note with attachments
        let attachments = photoURLs.isEmpty ? nil : photoURLs.map { NoteAttachmentAttributes(url: $0) }

        let input = JobCreateNoteInput(
            message: message,
            attachments: attachments
        )

        return await withCheckedContinuation { continuation in
            Task {
                await createJobNote(jobId: jobId, input: input) { result in
                    switch result {
                    case .success(let response):
                        if !response.userErrors.isEmpty {
                            let errorMessage = response.userErrors.map { $0.message }.joined(separator: ", ")
                            print("❌ Job note creation failed with user errors: \(errorMessage)")
                            continuation.resume(returning: .failure(.graphQLError(errorMessage)))
                        } else {
                            if let noteData = response.jobNote {
                                print("✅ Job note created successfully with ID: \(noteData.id)")
                                continuation.resume(returning: .success(noteData))
                            } else {
                                print("❌ Job note creation succeeded but no note data returned")
                                continuation.resume(returning: .failure(.invalidResponse))
                            }
                        }
                    case .failure(let error):
                        print("❌ Job note creation failed with error: \(error)")
                        if let apiError = error as? APIError {
                            continuation.resume(returning: .failure(apiError))
                        } else {
                            continuation.resume(returning: .failure(.graphQLError(error.localizedDescription)))
                        }
                    }
                }
            }
        }
    }

    /// GraphQL mutation to create a job note
    private func createJobNote(
        jobId: String,
        input: JobCreateNoteInput,
        completion: @escaping (Result<JobCreateNoteResponse, Error>) -> Void
    ) async {
        let mutation = """
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
        """

        var variables: [String: Any] = [
            "jobId": jobId,
            "input": [
                "message": input.message
            ]
        ]

        // Add attachments if present
        if let attachments = input.attachments {
            var inputDict = variables["input"] as! [String: Any]
            inputDict["attachments"] = attachments.map { $0.toDictionary() }
            variables["input"] = inputDict
        }

        await performGraphQLRequest(query: mutation, variables: variables) { (result: Result<JobCreateNoteRawResponse, Error>) in
            switch result {
            case .success(let rawResponse):
                let response = JobCreateNoteResponse(
                    jobNote: rawResponse.data.jobCreateNote.jobNote,
                    userErrors: rawResponse.data.jobCreateNote.userErrors?.map {
                        GraphQLError(message: $0.message, path: $0.path ?? [])
                    } ?? []
                )
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func performGraphQLRequest<T: Codable>(
        query: String,
        variables: [String: Any],
        completion: @escaping (Result<T, Error>) -> Void
    ) async {
        guard let token = accessToken else {
            completion(.failure(APIError.noToken))
            return
        }

        guard let url = URL(string: apiURL) else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Origin")
        request.setValue("https://api.getjobber.com", forHTTPHeaderField: "Referer")
        request.setValue("2025-01-20", forHTTPHeaderField: "X-JOBBER-GRAPHQL-VERSION")

        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            // Check for GraphQL errors in response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errors = jsonObject["errors"] as? [[String: Any]] {
                    let errorMessages = errors.compactMap { $0["message"] as? String }
                    completion(.failure(APIError.graphQLError(errorMessages.joined(separator: ", "))))
                    return
                }

                if jsonObject["data"] == nil {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh and retry once
                await refreshAccessTokens()

                if isAuthenticated, let newToken = accessToken {
                    // Retry with new token
                    request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    let result = try JSONDecoder().decode(T.self, from: retryData)
                    completion(.success(result))
                } else {
                    completion(.failure(APIError.unauthorized))
                }
                return
            }

            let result = try JSONDecoder().decode(T.self, from: data)
            completion(.success(result))
        } catch {
            print("performGraphQLRequest error: \(error)")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    private func clearStoredTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        connectedEmail = nil
    }

    func signOut() {
        clearStoredTokens()
        isAuthenticated = false
        jobs = []
        errorMessage = nil
    }

    private func createJobberJobFromVisit(visit: VisitWithJobNode, scheduledAt: Date, status: String) -> JobberJob {
        let clientName = visit.job.client.name
        let address = formatVisitAddress(visit)

        let jobberJob = JobberJob(
            jobId: visit.job.id,
            requestId: nil, // Visit-based jobs don't have request info in current schema
            clientId: "unknown", // Visit-based jobs don't have client ID in current schema
            propertyId: visit.job.property?.id,
            clientName: clientName,
            clientPhone: nil as String?, // No phone data available in visit structure
            address: address,
            scheduledAt: scheduledAt,
            status: status
        )

        return jobberJob
    }

    private func formatVisitAddress(_ visit: VisitWithJobNode) -> String {
        if let propertyAddress = visit.job.property?.address {
            var addressParts: [String] = []
            if let street1 = propertyAddress.street1, !street1.isEmpty {
                addressParts.append(street1)
            }
            if let city = propertyAddress.city, !city.isEmpty {
                addressParts.append(city)
            }
            return addressParts.isEmpty ? "No address available" : addressParts.joined(separator: ", ")
        }
        return "No address available"
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for presenting the authentication session
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Response Models for Visits
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

struct EnhancedClientNode: Codable {
    let id: String
    let name: String
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let phones: [EnhancedPhone]?
    let emails: [EnhancedEmail]?
    let billingAddress: BillingAddress?
}

struct EnhancedPhone: Codable {
    let number: String
    let description: String?
    let primary: Bool
}

struct EnhancedEmail: Codable {
    let address: String
    let description: String?
    let primary: Bool
}

struct BillingAddress: Codable {
    let street1: String?
    let city: String?
    let province: String?
    let postalCode: String?
}

struct RequestNode: Codable {
    let id: String?
    let requestStatus: String?
    let source: String?
    let title: String?
    let notes: NotesConnection?
}



struct NotesConnection: Codable {
    let nodes: [RequestNoteUnion]?
}

struct RequestNoteUnion: Codable {
    let message: String?
}

struct NoteNode: Codable {
    let body: String?
}

struct ClientNode: Codable {
    let name: String
    let phones: [Phone]?
    let emails: [Email]?
}

struct PropertyNode: Codable {
    let id: String?
    let address: PropertyAddress?
}

struct PropertyAddress: Codable {
    let street1: String?
    let city: String?
    let province: String?
}

// MARK: - Missing Response Models (fixed)
struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int?
}

struct AccountResponse: Codable { let data: AccountData }
struct AccountData: Codable { let account: Account }
struct Account: Codable { let id: String; let name: String }

// Scheduled Assessments (query) models
struct ScheduledAssessmentsResponse: Codable {
    let data: ScheduledAssessmentsData
}

struct ScheduledAssessmentsData: Codable {
    let scheduledItems: ScheduledItemsConnection
}

struct ScheduledItemsConnection: Codable {
    let nodes: [AssessmentNode]
    let pageInfo: PageInfo
    let totalCount: Int
}

struct AssessmentNode: Codable {
    let id: String
    let title: String?

    let startAt: String
    let endAt: String?
    let completedAt: String?
    let instructions: String?
    let client: EnhancedClientNode
    let property: PropertyNode?
    let assignedUsers: AssignedUsersConnection
    let request: RequestNode?
}

struct AssignedUsersConnection: Codable { let nodes: [AssignedUser] }
struct AssignedUser: Codable { let name: UserName }
struct UserName: Codable { let full: String }
struct PageInfo: Codable { let hasNextPage: Bool; let endCursor: String? }

// Quote creation (mutations)
struct QuoteCreateResponse: Codable { let data: QuoteCreateData }
struct QuoteCreateData: Codable { let quoteCreate: QuoteCreateResult }
struct QuoteCreateResult: Codable { let quote: Quote?; let userErrors: [UserError]? }
struct Quote: Codable { let id: String; let title: String; let createdAt: String?; let client: QuoteClient? }
struct QuoteClient: Codable { let id: String; let name: String }
struct UserError: Codable { let message: String; let path: [String]? }

// Basic contact info used in some nodes
struct Phone: Codable { let number: String; let primary: Bool }
struct Email: Codable { let address: String; let primary: Bool }

// MARK: - Note Creation Types
struct RequestCreateNoteInput {
    let message: String
    let attachments: [NoteAttachmentAttributes]?
    let pinned: Bool
    let linkedTo: RequestNoteLinkInput?
}

struct NoteAttachmentAttributes: Codable {
    let url: String

    func toDictionary() -> [String: Any] {
        return ["url": url]
    }
}

struct RequestNoteLinkInput { let jobIds: [String]?; let quoteIds: [String]?; let invoiceIds: [String]? }

struct RequestNote: Codable {
    let id: String
    let message: String
    let createdAt: String
    let createdBy: RequestNoteCreator?
}

struct RequestNoteCreator: Codable { let first: String?; let last: String? }

struct RequestCreateNoteResponse { // mapped from raw GraphQL response
    let requestNote: RequestNote?
    let userErrors: [GraphQLError]
}

struct GraphQLError { let message: String; let path: [String] }

// Raw GraphQL response types for note creation
struct RequestCreateNoteRawResponse: Codable { let data: RequestCreateNoteDataResponse }
struct RequestCreateNoteDataResponse: Codable { let requestCreateNote: RequestCreateNotePayload }
struct RequestCreateNotePayload: Codable { let requestNote: RequestNote?; let userErrors: [RequestNoteUserError]? }
struct RequestNoteUserError: Codable { let message: String; let path: [String]? }

// MARK: - Job Note Creation Types
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

struct JobCreateNoteRawResponse: Codable { let data: JobCreateNoteDataResponse }
struct JobCreateNoteDataResponse: Codable { let jobCreateNote: JobCreateNotePayload }
struct JobCreateNotePayload: Codable { let jobNote: JobNote?; let userErrors: [RequestNoteUserError]? }


