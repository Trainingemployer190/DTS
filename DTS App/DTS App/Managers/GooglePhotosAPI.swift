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
    private let scopes = "https://www.googleapis.com/auth/photoslibrary.appendonly"
    
    // PRE-CONFIGURED MODE: Shared company account
    // To enable: Set usePreConfiguredAuth = true and paste your refresh token below
    // To get token: Sign in once manually, check console logs for refresh token
    private let preConfiguredRefreshToken: String? = "1//06IK2CLvA9Q-2CgYIARAAGAYSNwF-L9IrayzbsxQLxV6qtq4K6z3OACKIqcWX2AUz5FXm7gc6eQfw4-NlaTHo6D_2oMZ8rGkXSqY"
    private let usePreConfiguredAuth = true  // Set to true to enable pre-configured mode
    
    // API endpoints
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let uploadEndpoint = "https://photoslibrary.googleapis.com/v1/uploads"
    private let mediaItemsEndpoint = "https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate"
    
    // State
    @Published var isAuthenticated = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var autoUploadEnabled = false
    @Published var isPreconfiguredMode = false
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: GoogleAuthPresentationContextProvider?
    
    // UserDefaults keys
    private let autoUploadEnabledKey = "GooglePhotosAutoUploadEnabled"
    private let accessTokenKey = "GooglePhotosAccessToken"
    private let refreshTokenKey = "GooglePhotosRefreshToken"
    private let tokenExpiryKey = "GooglePhotosTokenExpiry"
    
    init() {
        loadTokens()
        autoUploadEnabled = UserDefaults.standard.bool(forKey: autoUploadEnabledKey)
        
        // Initialize with pre-configured tokens if enabled
        if usePreConfiguredAuth {
            initializePreConfiguredAuth()
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
            } else {
                print("❌ Pre-configured authentication failed - token may be expired or invalid")
                print("💡 Sign in manually to get a new refresh token")
                errorMessage = "Pre-configured authentication failed. Token may need renewal."
            }
        }
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
        
        print("🔐 Starting Google OAuth flow...")
        print("   Client ID: \(clientId)")
        print("   Redirect URI: \(redirectURI)")
        print("   Callback Scheme: com.googleusercontent.apps.871965263646-e5viush2cefbdtbe7tgmq3t0rr7bbl4g")
        print("   Auth URL: \(authURL.absoluteString)")
        
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
        
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        UserDefaults.standard.set(false, forKey: autoUploadEnabledKey)
    }
    
    // MARK: - Photo Upload
    
    func uploadPhoto(fileURL: URL, albumName: String? = nil) async -> Bool {
        // Check if token needs refresh
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            let refreshed = await refreshAccessToken()
            if !refreshed {
                errorMessage = "Failed to refresh access token"
                return false
            }
        }
        
        guard let accessToken = accessToken else {
            errorMessage = "Not authenticated"
            return false
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
                return false
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
                return false
            }
            
            uploadProgress = 1.0
            print("✅ Photo uploaded to Google Photos: \(fileName)")
            return true
            
        } catch {
            errorMessage = "Upload error: \(error.localizedDescription)"
            print("❌ Upload error: \(error)")
            return false
        }
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
