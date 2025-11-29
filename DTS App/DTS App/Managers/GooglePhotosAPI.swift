//
//  GooglePhotosAPI.swift
//  DTS App
//
//  Google Photos API integration for automatic photo uploads
//

import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
class GooglePhotosAPI: ObservableObject {
    static let shared = GooglePhotosAPI()

    // Google OAuth credentials
    private let clientId = "871965263646-e5viush2cefbdtbe7tgmq3t0rr7bbl4g.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.871965263646-e5viush2cefbdtbe7tgmq3t0rr7bbl4g:/oauth2redirect"
    // Updated scope to allow album creation and management
    private let scopes = "https://www.googleapis.com/auth/photoslibrary"

    // PRE-CONFIGURED MODE: Shared company account
    // To enable: Set usePreConfiguredAuth = true and paste your refresh token below
    // To get token: Sign in once manually, check console logs for refresh token
    private let preConfiguredRefreshToken: String? = "1//06IK2CLvA9Q-2CgYIARAAGAYSNwF-L9IrayzbsxQLxV6qtq4K6z3OACKIqcWX2AUz5FXm7gc6eQfw4-NlaTHo6D_2oMZ8rGkXSqY"
    private let usePreConfiguredAuth = true  // Set to true to enable pre-configured mode

    // API endpoints
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let uploadEndpoint = "https://photoslibrary.googleapis.com/v1/uploads"
    private let mediaItemsEndpoint = "https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate"
    private let albumsEndpoint = "https://photoslibrary.googleapis.com/v1/albums"

    // State
    @Published var isAuthenticated = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var autoUploadEnabled = false
    @Published var isPreconfiguredMode = false
    @Published var needsReauth = false  // True when scope upgrade needed

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: GoogleAuthPresentationContextProvider?

    // Album cache: maps address -> albumId
    private var albumCache: [String: String] = [:]
    private let albumCacheKey = "GooglePhotosAlbumCache"

    // UserDefaults keys
    private let autoUploadEnabledKey = "GooglePhotosAutoUploadEnabled"
    private let accessTokenKey = "GooglePhotosAccessToken"
    private let refreshTokenKey = "GooglePhotosRefreshToken"
    private let tokenExpiryKey = "GooglePhotosTokenExpiry"

    init() {
        loadTokens()
        loadAlbumCache()
        autoUploadEnabled = UserDefaults.standard.bool(forKey: autoUploadEnabledKey)

        // Initialize with pre-configured tokens if enabled
        if usePreConfiguredAuth {
            initializePreConfiguredAuth()
        }
    }

    // MARK: - Album Cache

    private func loadAlbumCache() {
        if let data = UserDefaults.standard.data(forKey: albumCacheKey),
           let cache = try? JSONDecoder().decode([String: String].self, from: data) {
            albumCache = cache
            print("📁 Loaded album cache with \(cache.count) albums")
        }
    }

    private func saveAlbumCache() {
        if let data = try? JSONEncoder().encode(albumCache) {
            UserDefaults.standard.set(data, forKey: albumCacheKey)
        }
    }

    // MARK: - Pre-configured Authentication

    private func initializePreConfiguredAuth() {
        guard let preConfiguredToken = preConfiguredRefreshToken,
              !preConfiguredToken.isEmpty,
              preConfiguredToken != "your_token_here" else {
            print("⚠️ Pre-configured mode enabled but no valid refresh token provided")
            print("💡 To get token: Sign in once manually, check console for refresh token")
            return
        }

        // Check if already authenticated from stored tokens
        if isAuthenticated {
            isPreconfiguredMode = true
            print("✅ Already authenticated with stored tokens")
            return
        }

        // Use pre-configured refresh token
        refreshToken = preConfiguredToken
        isPreconfiguredMode = true

        // Get access token automatically
        Task {
            let success = await refreshAccessToken()
            if success {
                isAuthenticated = true
                autoUploadEnabled = true  // Auto-enable uploads
                setAutoUploadEnabled(true)  // Persist setting
                print("✅ Pre-configured authentication successful - auto-upload enabled")

                // Test if we have album permissions
                let hasAlbumAccess = await testAlbumAccess()
                if !hasAlbumAccess {
                    print("⚠️ Token doesn't have album permissions - re-auth required")
                    needsReauth = true
                }
            } else {
                print("❌ Pre-configured authentication failed - token may be expired or invalid")
                print("💡 Sign in manually to get a new refresh token")
                errorMessage = "Pre-configured authentication failed. Token may need renewal."
            }
        }
    }

    /// Test if current token has album permissions
    private func testAlbumAccess() async -> Bool {
        guard let accessToken = accessToken else { return false }

        var request = URLRequest(url: URL(string: "\(albumsEndpoint)?pageSize=1")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ Album access test failed: \(error)")
        }
        return false
    }

    // MARK: - Authentication

    func startAuthentication() {
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "GooglePhotosOAuthState")

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            errorMessage = "Failed to create authentication URL"
            return
        }

        print("🔐 Starting Google OAuth flow with album permissions...")
        print("   Client ID: \(clientId)")
        print("   Redirect URI: \(redirectURI)")
        print("   Scope: \(scopes)")

        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.googleusercontent.apps.871965263646-e5viush2cefbdtbe7tgmq3t0rr7bbl4g"
        ) { callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    let nsError = error as NSError
                    print("❌ Google OAuth error: \(error.localizedDescription)")
                    print("   Error domain: \(nsError.domain), code: \(nsError.code)")

                    // Error code 2 = user cancelled
                    if nsError.code == 2 {
                        self.errorMessage = "Sign in was cancelled. Please try again."
                    } else {
                        self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    self.errorMessage = "No callback URL received"
                    return
                }

                await self.handleOAuthCallback(url: callbackURL)
                self.needsReauth = false
            }
        }

        // Store strong reference to prevent deallocation
        presentationContextProvider = GoogleAuthPresentationContextProvider()
        authSession?.presentationContextProvider = presentationContextProvider
        authSession?.prefersEphemeralWebBrowserSession = true  // Use private browsing mode

        print("🔐 Starting ASWebAuthenticationSession...")
        let started = authSession?.start() ?? false
        print("🔐 ASWebAuthenticationSession started: \(started)")

        if !started {
            print("❌ Failed to start auth session - checking window availability...")
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                print("   Window scene found: \(windowScene)")
                print("   Windows count: \(windowScene.windows.count)")
                for (index, window) in windowScene.windows.enumerated() {
                    print("   Window \(index): isKeyWindow=\(window.isKeyWindow), isHidden=\(window.isHidden)")
                }
            } else {
                print("   No window scene found!")
            }
        }
    }

    /// Force re-authentication to get new permissions
    func reauthenticate() {
        signOut()
        startAuthentication()
    }

    private func handleOAuthCallback(url: URL) async {
        print("🔗 Google OAuth callback: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            errorMessage = "Invalid callback URL"
            return
        }

        // Verify state
        let storedState = UserDefaults.standard.string(forKey: "GooglePhotosOAuthState")
        guard state == storedState else {
            errorMessage = "State mismatch - possible CSRF attack"
            return
        }

        // Exchange code for tokens
        await exchangeCodeForTokens(code: code)
    }

    private func exchangeCodeForTokens(code: String) async {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                return
            }

            if httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

                accessToken = tokenResponse.access_token
                refreshToken = tokenResponse.refresh_token

                if let expiresIn = tokenResponse.expires_in {
                    tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                }

                saveTokens()
                isAuthenticated = true
                errorMessage = nil

                // Print refresh token for pre-configured mode setup
                if let refreshToken = tokenResponse.refresh_token {
                    print(String(repeating: "=", count: 60))
                    print("🔑 GOOGLE PHOTOS REFRESH TOKEN (for pre-configured mode):")
                    print(refreshToken)
                    print("💡 Copy this token to GooglePhotosAPI.swift preConfiguredRefreshToken")
                    print(String(repeating: "=", count: 60))
                }

                print("✅ Google Photos authentication successful")
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Token exchange failed: \(errorText)"
                print("❌ Token exchange failed: \(errorText)")
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            print("❌ Token exchange error: \(error)")
        }
    }

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else {
            return false
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

            accessToken = tokenResponse.access_token
            if let expiresIn = tokenResponse.expires_in {
                tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            }

            saveTokens()
            return true
        } catch {
            print("❌ Token refresh failed: \(error)")
            return false
        }
    }

    // MARK: - Token Storage

    private func saveTokens() {
        if let accessToken = accessToken {
            UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }
        if let tokenExpiryDate = tokenExpiryDate {
            UserDefaults.standard.set(tokenExpiryDate, forKey: tokenExpiryKey)
        }
    }

    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        tokenExpiryDate = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date

        isAuthenticated = accessToken != nil
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        isAuthenticated = false
        autoUploadEnabled = false
        albumCache = [:]
        needsReauth = false

        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        UserDefaults.standard.removeObject(forKey: albumCacheKey)
        UserDefaults.standard.set(false, forKey: autoUploadEnabledKey)
    }

    private func ensureValidToken() async -> Bool {
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            return await refreshAccessToken()
        }
        return accessToken != nil
    }

    // MARK: - Album Management

    /// Shorten address for album name (e.g., "713 Olive Ave Vista CA" -> "713 Olive Ave")
    func shortenAddress(_ address: String) -> String {
        let components = address.components(separatedBy: " ")
        var result: [String] = []
        var foundStreetType = false

        let streetTypes = ["Ave", "Avenue", "St", "Street", "Rd", "Road", "Dr", "Drive",
                          "Ln", "Lane", "Blvd", "Boulevard", "Ct", "Court", "Pl", "Place",
                          "Way", "Cir", "Circle", "Ter", "Terrace", "Pkwy", "Parkway"]

        for component in components {
            result.append(component)
            let cleanComponent = component.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            if streetTypes.contains(where: { cleanComponent.caseInsensitiveCompare($0) == .orderedSame }) {
                foundStreetType = true
                break
            }
        }

        if foundStreetType {
            return result.joined(separator: " ")
        } else if components.count > 3 {
            return components.prefix(3).joined(separator: " ")
        }

        return address
    }

    /// Get or create album by address, returns albumId
    func getOrCreateAlbum(for address: String) async -> String? {
        let albumTitle = shortenAddress(address)

        // Check cache first
        if let cachedId = albumCache[albumTitle] {
            print("📁 Found cached album: \(albumTitle) -> \(cachedId)")
            return cachedId
        }

        guard await ensureValidToken(), let accessToken = accessToken else {
            errorMessage = "Not authenticated"
            return nil
        }

        // Search existing albums
        if let existingId = await findAlbumByTitle(albumTitle) {
            albumCache[albumTitle] = existingId
            saveAlbumCache()
            print("📁 Found existing album: \(albumTitle)")
            return existingId
        }

        // Create new album
        if let newId = await createAlbum(title: albumTitle) {
            albumCache[albumTitle] = newId
            saveAlbumCache()
            print("📁 Created new album: \(albumTitle)")
            return newId
        }

        return nil
    }

    /// Find album by title
    private func findAlbumByTitle(_ title: String) async -> String? {
        guard let accessToken = accessToken else { return nil }

        var allAlbums: [GoogleAlbum] = []
        var pageToken: String? = nil

        repeat {
            var urlString = "\(albumsEndpoint)?pageSize=50"
            if let token = pageToken {
                urlString += "&pageToken=\(token)"
            }

            var request = URLRequest(url: URL(string: urlString)!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("❌ Failed to list albums")
                    return nil
                }

                let albumsResponse = try JSONDecoder().decode(GoogleAlbumsResponse.self, from: data)
                allAlbums.append(contentsOf: albumsResponse.albums ?? [])
                pageToken = albumsResponse.nextPageToken

            } catch {
                print("❌ Error listing albums: \(error)")
                return nil
            }
        } while pageToken != nil

        return allAlbums.first { $0.title == title }?.id
    }

    /// Create a new album
    private func createAlbum(title: String) async -> String? {
        guard let accessToken = accessToken else { return nil }

        var request = URLRequest(url: URL(string: albumsEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["album": ["title": title]]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
                print("❌ Failed to create album: \(errorText)")
                return nil
            }

            let album = try JSONDecoder().decode(GoogleAlbum.self, from: data)
            return album.id
        } catch {
            print("❌ Error creating album: \(error)")
            return nil
        }
    }

    /// Add media items to album
    func addToAlbum(albumId: String, mediaItemIds: [String]) async -> Bool {
        guard await ensureValidToken(), let accessToken = accessToken else {
            return false
        }

        let url = URL(string: "\(albumsEndpoint)/\(albumId):batchAddMediaItems")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["mediaItemIds": mediaItemIds]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return false }

            if httpResponse.statusCode == 200 {
                print("✅ Added \(mediaItemIds.count) photos to album")
                return true
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
                print("❌ Failed to add to album: \(errorText)")
                return false
            }
        } catch {
            print("❌ Error adding to album: \(error)")
            return false
        }
    }

    // MARK: - Photo Upload

    /// Upload photo and return (success, mediaItemId)
    func uploadPhoto(fileURL: URL, albumName: String? = nil) async -> (success: Bool, mediaItemId: String?) {
        // Check if token needs refresh
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            let refreshed = await refreshAccessToken()
            if !refreshed {
                errorMessage = "Failed to refresh access token"
                return (false, nil)
            }
        }

        guard let accessToken = accessToken else {
            errorMessage = "Not authenticated"
            return (false, nil)
        }

        isUploading = true
        uploadProgress = 0.0

        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        do {
            // Step 1: Upload raw bytes
            let imageData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent

            var uploadRequest = URLRequest(url: URL(string: uploadEndpoint)!)
            uploadRequest.httpMethod = "POST"
            uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            uploadRequest.setValue(fileName, forHTTPHeaderField: "X-Goog-Upload-File-Name")
            uploadRequest.setValue("raw", forHTTPHeaderField: "X-Goog-Upload-Protocol")
            uploadRequest.httpBody = imageData

            uploadProgress = 0.3

            let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)

            guard let httpResponse = uploadResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let uploadToken = String(data: uploadData, encoding: .utf8) else {
                errorMessage = "Failed to upload photo bytes"
                return (false, nil)
            }

            uploadProgress = 0.6

            // Step 2: Create media item
            let mediaItem = GoogleMediaItemRequest(
                description: albumName ?? "DTS App Photo",
                simpleMediaItem: GoogleSimpleMediaItem(uploadToken: uploadToken)
            )

            let batchRequest = GoogleBatchCreateRequest(newMediaItems: [mediaItem])
            let batchData = try JSONEncoder().encode(batchRequest)

            var createRequest = URLRequest(url: URL(string: mediaItemsEndpoint)!)
            createRequest.httpMethod = "POST"
            createRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            createRequest.httpBody = batchData

            let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)

            guard let httpResponse = createResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorText = String(data: createData, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Failed to create media item: \(errorText)"
                return (false, nil)
            }

            // Parse response to get mediaItemId
            let createResult = try JSONDecoder().decode(GoogleBatchCreateResponse.self, from: createData)
            let mediaItemId = createResult.newMediaItemResults?.first?.mediaItem?.id

            uploadProgress = 1.0
            print("✅ Photo uploaded to Google Photos: \(fileName), mediaItemId: \(mediaItemId ?? "unknown")")
            return (true, mediaItemId)

        } catch {
            errorMessage = "Upload error: \(error.localizedDescription)"
            print("❌ Upload error: \(error)")
            return (false, nil)
        }
    }

    /// Upload photo to specific album (full flow)
    func uploadPhotoToAlbum(fileURL: URL, address: String?) async -> (success: Bool, mediaItemId: String?, albumId: String?) {
        // Upload photo first
        let albumName = address.map { shortenAddress($0) }
        let (success, mediaItemId) = await uploadPhoto(fileURL: fileURL, albumName: albumName)

        guard success, let mediaItemId = mediaItemId else {
            return (false, nil, nil)
        }

        // If no address, just return without album
        guard let address = address else {
            return (true, mediaItemId, nil)
        }

        // Get or create album
        guard let albumId = await getOrCreateAlbum(for: address) else {
            print("⚠️ Photo uploaded but couldn't create/find album")
            return (true, mediaItemId, nil)
        }

        // Add to album
        let addedToAlbum = await addToAlbum(albumId: albumId, mediaItemIds: [mediaItemId])

        if addedToAlbum {
            print("✅ Photo added to album: \(shortenAddress(address))")
        }

        return (true, mediaItemId, albumId)
    }

    /// Sync existing photos to albums (for photos already uploaded without album)
    /// Returns a dictionary mapping mediaItemId to albumId for successful syncs
    func syncPhotosToAlbums(photos: [(mediaItemId: String, address: String)]) async -> [String: String] {
        var syncedMediaItems: [String: String] = [:] // mediaItemId -> albumId

        print("🔄 Starting album sync for \(photos.count) photos")

        // Group by address
        let grouped = Dictionary(grouping: photos) { $0.address }

        for (address, items) in grouped {
            print("🔄 Syncing \(items.count) photos to album for: \(address)")

            guard let albumId = await getOrCreateAlbum(for: address) else {
                print("❌ Failed to get/create album for: \(address)")
                continue
            }

            let mediaItemIds = items.map { $0.mediaItemId }
            let success = await addToAlbum(albumId: albumId, mediaItemIds: mediaItemIds)

            if success {
                for item in items {
                    syncedMediaItems[item.mediaItemId] = albumId
                }
                print("✅ Synced \(items.count) photos to album: \(shortenAddress(address))")
            } else {
                print("❌ Failed to add photos to album: \(shortenAddress(address))")
            }
        }

        print("🔄 Album sync complete: \(syncedMediaItems.count) photos synced")
        return syncedMediaItems
    }

    func setAutoUploadEnabled(_ enabled: Bool) {
        autoUploadEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: autoUploadEnabledKey)
    }
}

// MARK: - Response Models

private struct GoogleTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int?
    let token_type: String
}

private struct GoogleBatchCreateRequest: Codable {
    let newMediaItems: [GoogleMediaItemRequest]
}

private struct GoogleMediaItemRequest: Codable {
    let description: String
    let simpleMediaItem: GoogleSimpleMediaItem
}

private struct GoogleSimpleMediaItem: Codable {
    let uploadToken: String
}

private struct GoogleBatchCreateResponse: Codable {
    let newMediaItemResults: [GoogleNewMediaItemResult]?
}

private struct GoogleNewMediaItemResult: Codable {
    let uploadToken: String?
    let status: GoogleStatus?
    let mediaItem: GoogleMediaItem?
}

private struct GoogleStatus: Codable {
    let message: String?
    let code: Int?
}

private struct GoogleMediaItem: Codable {
    let id: String
    let description: String?
    let productUrl: String?
    let mimeType: String?
    let filename: String?
}

private struct GoogleAlbumsResponse: Codable {
    let albums: [GoogleAlbum]?
    let nextPageToken: String?
}

struct GoogleAlbum: Codable {
    let id: String
    let title: String
    let productUrl: String?
    let mediaItemsCount: String?
    let coverPhotoBaseUrl: String?
    let coverPhotoMediaItemId: String?
}

// MARK: - Presentation Context Provider

class GoogleAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        print("🔐 presentationAnchor called")

        // Try to get key window from active window scene
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.activationState == .foregroundActive {
                for window in windowScene.windows {
                    if window.isKeyWindow {
                        print("🔐 Found key window: \(window)")
                        return window
                    }
                }
                // If no key window, return first window
                if let firstWindow = windowScene.windows.first {
                    print("🔐 Using first window: \(firstWindow)")
                    return firstWindow
                }
            }
        }

        // Fallback: try any window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            print("🔐 Using fallback window: \(window)")
            return window
        }

        print("❌ No window found for presentation anchor!")
        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
