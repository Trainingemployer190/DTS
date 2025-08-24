//
//  JobberAPI.swift
//  DTS App
//
//  Jobber API integration with OAuth authentication and GraphQL
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
    private let scopes = "read_clients write_clients read_requests write_requests read_quotes write_quotes read_jobs write_jobs read_scheduled_items write_scheduled_items read_invoices write_invoices read_jobber_payments read_users write_users write_tax_rates read_expenses write_expenses read_custom_field_configurations write_custom_field_configurations read_time_sheets"

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
        // Start fresh OAuth flow
        clearStoredTokens()
        startOAuthFlow()
    }

    private func startOAuthFlow() {
        // Generate random state for security
        storedState = UUID().uuidString

        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: storedState)
        ]

        guard let authURL = urlComponents.url else {
            self.errorMessage = "Invalid authorization URL."
            return
        }

        // Extract scheme from redirect URI
        let callbackScheme: String
        if let url = URL(string: redirectURI) {
            callbackScheme = url.scheme ?? "https"
        } else {
            callbackScheme = "https"
        }

        let authSession = ASWebAuthenticationSession(
            url: authURL,
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
        print("- Auth URL: \(authURL.absoluteString)")
        print("- Redirect URI: \(redirectURI)")

        let started = authSession.start()
        print("Authentication session start result: \(started)")

        if !started {
            Task { @MainActor in
                self.errorMessage = "Failed to start authentication session"
            }
        }
    }

    private func handleOAuthCallback(url: URL) async {
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
                  requestStatus
                  source
                  title
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
                        let jobberJob = JobberJob(
                            jobId: assessment.id,
                            clientName: clientName,
                            clientPhone: clientPhone,
                            address: address,
                            scheduledAt: startAt,
                            status: status
                        )

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
                  requestStatus
                  source
                  title
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

                        let jobberJob = JobberJob(
                            jobId: assessment.id,
                            clientName: clientName,
                            clientPhone: clientPhone,
                            address: address,
                            scheduledAt: startAt,
                            status: status
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
            "input": [
                "clientId": quoteDraft.clientId ?? "",
                "title": "Gutter Installation Quote",
                "lineItems": lineItems
            ]
        ]

        let mutation = """
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
    let requestStatus: String?
    let source: String?
    let title: String?
}

struct ClientNode: Codable {
    let name: String
    let phones: [Phone]?
    let emails: [Email]?
}

struct PropertyNode: Codable {
    let address: PropertyAddress?
}

struct PropertyAddress: Codable {
    let street1: String?
    let city: String?
    let province: String?
}

// MARK: - Missing Response Models
struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int?
}

struct AccountResponse: Codable {
    let data: AccountData
}

struct AccountData: Codable {
    let account: Account
}

struct Account: Codable {
    let id: String
    let name: String
}

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

struct AssignedUsersConnection: Codable {
    let nodes: [AssignedUser]
}

struct AssignedUser: Codable {
    let name: UserName
}

struct UserName: Codable {
    let full: String
}

struct PageInfo: Codable {
    let hasNextPage: Bool
    let endCursor: String?
}

struct QuoteCreateResponse: Codable {
    let data: QuoteCreateData
}

struct QuoteCreateData: Codable {
    let quoteCreate: QuoteCreateResult
}

struct QuoteCreateResult: Codable {
    let quote: Quote?
    let userErrors: [UserError]?
}

struct Quote: Codable {
    let id: String
    let title: String
}

struct UserError: Codable {
    let field: String
    let message: String
}

struct Phone: Codable {
    let number: String
    let primary: Bool
}

struct Email: Codable {
    let address: String
    let primary: Bool
}
