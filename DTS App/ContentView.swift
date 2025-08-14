//
//  ContentView.swift
//  DTS App
//
//  Created by Chandler Staton on 8/13/25.
//

import SwiftUI
import SwiftData
import Foundation
import AuthenticationServices
import Security
import CommonCrypto
import CoreLocation
import UIKit
import AVFoundation
import PDFKit
import UniformTypeIdentifiers

// MARK: - SwiftData Models

@Model
final class AppSettings {
    var materialCostPerFootGutter: Double = 3.50
    var materialCostPerFootDownspout: Double = 4.00
    var costPerElbow: Double = 8.00
    var costPerHanger: Double = 2.50
    var hangerSpacingFeet: Double = 3.0
    var laborPerFootGutter: Double = 5.00
    var gutterGuardMaterialPerFoot: Double = 6.00
    var gutterGuardLaborPerFoot: Double = 3.00
    var defaultMarginPercent: Double = 0.35
    var defaultSalesCommissionPercent: Double = 0.03
    var gutterGuardMarginPercent: Double = 0.40
    var elbowFootEquivalency: Double = 0.0

    init() {}
}

@Model
final class JobberJob {
    var jobId: String
    var clientName: String
    var address: String
    var scheduledAt: Date
    var status: String

    init(jobId: String, clientName: String, address: String, scheduledAt: Date, status: String) {
        self.jobId = jobId
        self.clientName = clientName
        self.address = address
        self.scheduledAt = scheduledAt
        self.status = status
    }
}

enum SyncState: String, Codable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed
}

@Model
final class QuoteDraft {
    var localId: UUID = UUID()
    var jobId: String?
    var clientId: String?
    var gutterFeet: Double = 0
    var downspoutFeet: Double = 0
    var elbowsCount: Int = 0
    var endCapPairs: Int = 0
    var includeGutterGuard: Bool = false
    var gutterGuardFeet: Double = 0
    var marginPercent: Double = 0.35
    var salesCommissionPercent: Double = 0.03
    var notes: String = ""
    var syncStateRaw: String = SyncState.pending.rawValue
    var createdAt: Date = Date()

    // Computed totals (stored for audit)
    var materialsTotal: Double = 0
    var laborTotal: Double = 0
    var marginAmount: Double = 0
    var commissionAmount: Double = 0
    var finalTotal: Double = 0

    @Relationship(deleteRule: .cascade)
    var additionalLaborItems: [LineItem] = []

    @Relationship(deleteRule: .cascade)
    var photos: [PhotoRecord] = []

    // Computed property to create line items for Jobber API
    var lineItemsForJobber: [JobberLineItem] {
        var items: [JobberLineItem] = []

        // Add gutter line item
        if gutterFeet > 0 {
            items.append(JobberLineItem(
                name: "Gutter Installation",
                description: "\(gutterFeet) feet of gutter",
                quantity: gutterFeet,
                unitPrice: materialsTotal > 0 ? (materialsTotal + laborTotal) / gutterFeet : 0
            ))
        }

        // Add additional labor items
        for item in additionalLaborItems {
            items.append(JobberLineItem(
                name: item.title,
                description: item.title,
                quantity: 1,
                unitPrice: item.amount
            ))
        }

        return items
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    var hangersCount: Int {
        return Int(ceil(gutterFeet / 3.0)) // Default spacing of 3 feet
    }

    init() {}
}

@Model
final class LineItem {
    var title: String
    var amount: Double
    var quoteDraft: QuoteDraft?

    init(title: String, amount: Double) {
        self.title = title
        self.amount = amount
    }
}

@Model
final class PhotoRecord {
    var localId: UUID = UUID()
    var jobId: String?
    var quoteDraftId: UUID?
    var fileURL: String
    var createdAt: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var uploaded: Bool = false

    init(fileURL: String, jobId: String? = nil, quoteDraftId: UUID? = nil) {
        self.fileURL = fileURL
        self.jobId = jobId
        self.quoteDraftId = quoteDraftId
    }
}

@Model
final class OutboxOperation {
    var id: UUID = UUID()
    var operationType: String // "createQuote", "uploadPhoto", etc.
    var payload: Data // JSON encoded operation data
    var retryCount: Int = 0
    var createdAt: Date = Date()
    var lastAttemptAt: Date?
    var errorMessage: String?

    init(operationType: String, payload: Data) {
        self.operationType = operationType
        self.payload = payload
    }
}

// MARK: - Jobber API

// MARK: - Photo Capture Manager

@MainActor
class PhotoCaptureManager: NSObject, ObservableObject {
    @Published var capturedImages: [CapturedPhoto] = []
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var showingPhotoLibrary = false
    @Published var isLocationAuthorized = false
    @Published var locationError: String?

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    override init() {
        super.init()
        setupLocationManager()
        checkLocationPermission()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            startLocationUpdates()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isLocationAuthorized = false
            locationError = "Location access denied. Please enable in Settings."
        @unknown default:
            isLocationAuthorized = false
        }
    }

    private func startLocationUpdates() {
        guard isLocationAuthorized else { return }
        locationManager.startUpdatingLocation()
    }

    func capturePhoto(for jobId: String? = nil, quoteDraftId: UUID? = nil) {
        // Clear any previous errors
        locationError = nil

        // First check if camera is available (won't work in simulator)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // For simulator or devices without camera, use photo library instead
            showingPhotoLibrary = true
            return
        }

        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showingCamera = true
                    } else {
                        self?.locationError = "Camera access denied. Please enable in Settings."
                        self?.showingPhotoLibrary = true
                    }
                }
            }
        case .denied, .restricted:
            locationError = "Camera access denied. Please enable camera access in Settings app under Privacy & Security > Camera."
            showingPhotoLibrary = true
        @unknown default:
            locationError = "Camera access status unknown."
        }
    }

    func processImage(_ image: UIImage, jobId: String? = nil, quoteDraftId: UUID? = nil) {
        let watermarkedImage = addWatermark(to: image)

        // Save to Documents directory
        guard let imageData = watermarkedImage.jpegData(compressionQuality: 0.8),
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)

            let capturedPhoto = CapturedPhoto(
                id: UUID(),
                fileURL: fileURL.path,
                jobId: jobId,
                quoteDraftId: quoteDraftId,
                location: currentLocation,
                capturedAt: Date()
            )

            capturedImages.append(capturedPhoto)

        } catch {
            print("Error saving image: \(error)")
        }
    }

    private func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            // Draw original image
            image.draw(in: CGRect(origin: .zero, size: image.size))

            // Prepare watermark text
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            let timestamp = dateFormatter.string(from: Date())
            let locationText = formatLocationText()

            let watermarkText = "\(timestamp)\n\(locationText)"

            // Configure text attributes
            let textColor = UIColor.white
            let shadowColor = UIColor.black
            let font = UIFont.boldSystemFont(ofSize: max(image.size.width / 30, 16))

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .strokeColor: shadowColor,
                .strokeWidth: -2.0
            ]

            // Calculate text size and position
            let attributedString = NSAttributedString(string: watermarkText, attributes: textAttributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: image.size.width - 40, height: image.size.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size

            // Position watermark in bottom-left corner with padding
            let textRect = CGRect(
                x: 20,
                y: image.size.height - textSize.height - 20,
                width: textSize.width,
                height: textSize.height
            )

            // Draw semi-transparent background
            let backgroundRect = textRect.insetBy(dx: -10, dy: -5)
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            context.cgContext.fillEllipse(in: backgroundRect)

            // Draw text
            attributedString.draw(in: textRect)
        }
    }

    private func formatLocationText() -> String {
        guard let location = currentLocation else {
            return "Location unavailable"
        }

        let latitude = String(format: "%.6f", location.coordinate.latitude)
        let longitude = String(format: "%.6f", location.coordinate.longitude)
        return "📍 \(latitude), \(longitude)"
    }
}

extension PhotoCaptureManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = "Location error: \(error.localizedDescription)"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            checkLocationPermission()
        }
    }
}

// MARK: - Captured Photo Model

struct CapturedPhoto: Identifiable {
    let id: UUID
    let fileURL: String
    let jobId: String?
    let quoteDraftId: UUID?
    let location: CLLocation?
    let capturedAt: Date

    var image: UIImage? {
        return UIImage(contentsOfFile: fileURL)
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Check if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear

            // Important: Set these for proper camera functionality
            picker.showsCameraControls = true
            picker.allowsEditing = false
            picker.modalPresentationStyle = .fullScreen
        } else {
            // Fallback to photo library if camera not available (simulator)
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Photo Library Picker (Alternative to Camera)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Photo Gallery View

struct PhotoGalleryView: View {
    let photos: [CapturedPhoto]
    @State private var selectedPhoto: CapturedPhoto?

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(photos) { photo in
                        Button(action: {
                            selectedPhoto = photo
                        }) {
                            AsyncImage(url: URL(string: "file://" + photo.fileURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Photos")
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }
}

struct PhotoDetailView: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Image not found")
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Captured: \(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))")

                    if let location = photo.location {
                        Text("Location: \(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                    }

                    if let jobId = photo.jobId {
                        Text("Job ID: \(jobId)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class JobberAPI: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var jobs: [JobberJob] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingManualAuth = false

    private let clientId = "bc74e0a3-3f65-4373-b758-a512536ded90"
    private let redirectURI = "dtsapp://oauth/callback" // Using custom URL scheme for native app
    private let baseURL = "https://api.getjobber.com/api/graphql"

    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String?

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

    override init() {
        super.init()
        isAuthenticated = accessToken != nil
    }

    func authenticate() {
        // Temporarily disabled - uncomment when Jobber API details are clarified
        /*
        guard let (codeVerifier, codeChallenge) = generatePkceChallenge() else {
            self.errorMessage = "Could not generate PKCE challenge."
            return
        }

        self.codeVerifier = codeVerifier

        var urlComponents = URLComponents(string: "https://api.getjobber.com/oauth/authorize")!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read_jobs read_clients write_quotes"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = urlComponents.url else {
            self.errorMessage = "Invalid authorization URL."
            return
        }

        let authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "dtsapp" // Just the scheme part
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                return
            }

            guard let callbackURL = callbackURL else {
                self.errorMessage = "Authentication failed: No callback URL received."
                return
            }

            // Extract the authorization code from the callbackURL
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                self.errorMessage = "Could not extract authorization code from callback."
                return
            }

            self.exchangeCodeForToken(code: code)
        }

        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = true

        self.authSession = authSession
        authSession.start()
        */

        // Temporary message while API integration is being clarified
        self.errorMessage = "Jobber integration temporarily disabled. Contact support for API configuration details."
    }

    private func exchangeCodeForToken(code: String) {
        guard let codeVerifier = self.codeVerifier else {
            self.errorMessage = "Code verifier not found."
            return
        }

        guard let url = URL(string: "https://api.getjobber.com/oauth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_verifier", value: codeVerifier) // The secret proof!
        ]

        request.httpBody = components.query?.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Token exchange failed: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received from token exchange"
                    return
                }

                do {
                    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                    self?.accessToken = tokenResponse.access_token
                    self?.isAuthenticated = true
                    self?.errorMessage = nil
                    self?.codeVerifier = nil // Clear the verifier
                } catch {
                    self?.errorMessage = "Failed to decode token response: \(error.localizedDescription)"
                    print("Token response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                }
            }
        }.resume()
    }

    // MARK: - PKCE Helper Methods

    private func generatePkceChallenge() -> (verifier: String, challenge: String)? {
        let verifier = generateCodeVerifier()

        guard let challenge = generateCodeChallenge(from: verifier) else {
            return nil
        }
        return (verifier, challenge)
    }

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }
        let hash = Data(buffer)

        return hash.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }

    func fetchTodayJobs() async {
        // Temporarily disabled
        /*
        guard accessToken != nil else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)

        let query = """
        query GetTodayJobs {
          jobs(
            filter: {
              scheduledStart: { greaterThanOrEqualTo: "\(todayString)T00:00:00Z" }
              scheduledStart: { lessThan: "\(todayString)T23:59:59Z" }
            }
          ) {
            nodes {
              id
              title
              scheduledStart
              client {
                name
                billingAddress {
                  street1
                  city
                  province
                  postalCode
                }
              }
            }
          }
        }
        """

        await performGraphQLRequest(query: query) { [weak self] (result: Result<JobsResponse, Error>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.jobs = response.data.jobs.nodes.map { jobNode in
                        JobberJob(
                            jobId: jobNode.id,
                            clientName: jobNode.client.name,
                            address: jobNode.client.billingAddress != nil ? self?.formatAddress(jobNode.client.billingAddress!) ?? "" : "",
                            scheduledAt: self?.parseDate(jobNode.scheduledStart) ?? Date(),
                            status: "active"
                        )
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch jobs: \(error.localizedDescription)"
                }
            }
        }
        */

        // Temporary message
        await MainActor.run {
            self.errorMessage = "Jobber sync temporarily disabled. Using local data only."
        }
    }

    func createQuoteDraft(quoteDraft: QuoteDraft) async {
        // Temporarily disabled
        /*
        guard accessToken != nil else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        let lineItems = quoteDraft.lineItemsForJobber.map { item in
            """
            {
              name: "\(item.name)"
              description: "\(item.description)"
              quantity: \(item.quantity)
              unitCost: \(item.unitPrice)
            }
            """
        }.joined(separator: ", ")

        let mutation = """
        mutation CreateQuote {
          quoteCreate(
            input: {
              clientId: "\(quoteDraft.clientId ?? "")"
              title: "Gutter Installation Quote"
              lineItems: [\(lineItems)]
            }
          ) {
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

        await performGraphQLRequest(query: mutation) { [weak self] (result: Result<QuoteCreateResponse, Error>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    if response.data.quoteCreate.userErrors.isEmpty {
                        // Success - quote created
                        self?.errorMessage = nil
                    } else {
                        let errors = response.data.quoteCreate.userErrors.map { $0.message }.joined(separator: ", ")
                        self?.errorMessage = "Quote creation failed: \(errors)"
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to create quote: \(error.localizedDescription)"
                }
            }
        }
        */

        // Temporary message
        await MainActor.run {
            self.errorMessage = "Jobber quote creation temporarily disabled. Saving locally only."
        }
    }

    private func performGraphQLRequest<T: Codable>(query: String, completion: @escaping (Result<T, Error>) -> Void) async {
        guard let url = URL(string: baseURL),
              let token = accessToken else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["query": query]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                let result = try JSONDecoder().decode(T.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func formatAddress(_ address: BillingAddress) -> String {
        let components = [address.street1, address.city, address.province, address.postalCode].compactMap { $0?.isEmpty == false ? $0 : nil }
        return components.joined(separator: ", ")
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    func signOut() {
        accessToken = nil
        isAuthenticated = false
        jobs = []
        errorMessage = nil
    }
}

// MARK: - Jobber API Models

struct CommonLaborItem: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
}

struct JobberLineItem {
    let name: String
    let description: String
    let quantity: Double
    let unitPrice: Double
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct JobsResponse: Codable {
    let data: JobsData
}

struct JobsData: Codable {
    let jobs: JobsConnection
}

struct JobsConnection: Codable {
    let nodes: [JobNode]
}

struct JobNode: Codable {
    let id: String
    let title: String
    let scheduledStart: String
    let client: ClientNode
}

struct ClientNode: Codable {
    let name: String
    let billingAddress: BillingAddress?
}

struct BillingAddress: Codable {
    let street1: String?
    let city: String?
    let province: String?
    let postalCode: String?
}

struct QuoteCreateResponse: Codable {
    let data: QuoteCreateData
}

struct QuoteCreateData: Codable {
    let quoteCreate: QuoteCreateResult
}

struct QuoteCreateResult: Codable {
    let quote: QuoteResult?
    let userErrors: [UserError]
}

struct QuoteResult: Codable {
    let id: String
    let title: String
}

struct UserError: Codable {
    let field: String
    let message: String
}

enum APIError: Error {
    case invalidURL
    case noData
}

// MARK: - Keychain Helper

struct Keychain {
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
            return item as? Data
        }
        return nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Pricing Engine

struct PriceBreakdown {
    let materialsTotal: Double
    let laborTotal: Double
    let subtotal: Double
    let marginAmount: Double
    let priceBeforeCommission: Double
    let commissionAmount: Double
    let finalTotal: Double
    let compositeFeet: Double
    let pricePerFoot: Double
}

struct PricingEngine {
    static func calculatePrice(
        quote: QuoteDraft,
        settings: AppSettings
    ) -> PriceBreakdown {

        // Calculate hangers count
        let hangersCount = Int(ceil(quote.gutterFeet / settings.hangerSpacingFeet))

        // Materials calculation
        let gutterMaterialCost = quote.gutterFeet * settings.materialCostPerFootGutter
        let downspoutMaterialCost = quote.downspoutFeet * settings.materialCostPerFootDownspout
        let elbowsCost = Double(quote.elbowsCount) * settings.costPerElbow
        let hangersCost = Double(hangersCount) * settings.costPerHanger
        let gutterGuardMaterialCost = quote.includeGutterGuard ?
            quote.gutterGuardFeet * settings.gutterGuardMaterialPerFoot : 0

        let materialsTotal = gutterMaterialCost + downspoutMaterialCost +
                           elbowsCost + hangersCost + gutterGuardMaterialCost

        // Labor calculation - now based on total footage including downspouts and elbows
        let totalInstallationFeet = quote.gutterFeet + quote.downspoutFeet + Double(quote.elbowsCount) // Each elbow = 1ft
        let gutterLaborCost = totalInstallationFeet * settings.laborPerFootGutter
        let gutterGuardLaborCost = quote.includeGutterGuard ?
            quote.gutterGuardFeet * settings.gutterGuardLaborPerFoot : 0
        let additionalLaborCost = quote.additionalLaborItems.reduce(0) { $0 + $1.amount }

        let laborTotal = gutterLaborCost + gutterGuardLaborCost + additionalLaborCost

        // Subtotal before margin
        let subtotal = materialsTotal + laborTotal

        // Apply margin (use gutter guard margin if gutter guard is included, otherwise default)
        let marginPercent = quote.includeGutterGuard ? settings.gutterGuardMarginPercent : quote.marginPercent
        let marginAmount = subtotal * marginPercent
        let priceBeforeCommission = subtotal + marginAmount

        // Sales commission
        let commissionAmount = priceBeforeCommission * quote.salesCommissionPercent
        let finalTotal = priceBeforeCommission + commissionAmount

        // Composite footage for price per foot calculation - includes all installation footage
        let compositeFeet = quote.gutterFeet + quote.downspoutFeet + Double(quote.elbowsCount) // Each elbow = 1ft

        let pricePerFoot = compositeFeet > 0 ? finalTotal / compositeFeet : 0

        return PriceBreakdown(
            materialsTotal: materialsTotal,
            laborTotal: laborTotal,
            subtotal: subtotal,
            marginAmount: marginAmount,
            priceBeforeCommission: priceBeforeCommission,
            commissionAmount: commissionAmount,
            finalTotal: finalTotal,
            compositeFeet: compositeFeet,
            pricePerFoot: pricePerFoot
        )
    }

    static func updateQuoteWithCalculatedTotals(quote: QuoteDraft, breakdown: PriceBreakdown) {
        quote.materialsTotal = breakdown.materialsTotal
        quote.laborTotal = breakdown.laborTotal
        quote.marginAmount = breakdown.marginAmount
        quote.commissionAmount = breakdown.commissionAmount
        quote.finalTotal = breakdown.finalTotal
    }
}

// MARK: - PDF Generator

@MainActor
class PDFGenerator: ObservableObject {
    static func generateQuotePDF(
        quote: QuoteDraft,
        breakdown: PriceBreakdown,
        settings: AppSettings,
        photos: [CapturedPhoto],
        jobInfo: JobberJob? = nil
    ) -> URL? {

        let pageSize = CGSize(width: 612, height: 792) // Standard US Letter size
        let margin: CGFloat = 50

        // Create PDF using UIGraphicsPDFRenderer
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "Quote_\(Date().timeIntervalSince1970).pdf"
        let pdfURL = documentsPath.appendingPathComponent(fileName)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        do {
            let pdfData = pdfRenderer.pdfData { context in
                context.beginPage()

                var currentY: CGFloat = margin

                // Helper function to draw text
                func drawText(_ text: String, fontSize: CGFloat, bold: Bool = false, at point: CGPoint) -> CGFloat {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize),
                        .foregroundColor: UIColor.black
                    ]

                    let attributedString = NSAttributedString(string: text, attributes: attributes)
                    let textSize = attributedString.size()

                    attributedString.draw(at: point)

                    return textSize.height + 5
                }

                // Helper function to draw a line
                func drawLine(from startPoint: CGPoint, to endPoint: CGPoint) {
                    let path = UIBezierPath()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                    path.stroke()
                }

                // Header
                currentY += drawText("GUTTER QUOTE", fontSize: 24, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 20

                // Company info
                currentY += drawText("DTS Gutters & Restoration", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("Professional Gutter Installation & Repair", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("Date: \(Date().formatted(date: .abbreviated, time: .omitted))", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                currentY += 20

                // Job information if available
                if let job = jobInfo {
                    currentY += drawText("JOB DETAILS", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                    currentY += 10

                    currentY += drawText("Client: \(job.clientName)", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += drawText("Address: \(job.address)", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += drawText("Scheduled: \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += 20
                }

                // Quote details
                currentY += drawText("QUOTE DETAILS", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 10

                // Measurements
                currentY += drawText("Measurements:", fontSize: 14, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("• Gutter Feet: \(quote.gutterFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Downspout Feet: \(quote.downspoutFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Elbows: \(quote.elbowsCount)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• End Cap Pairs: \(quote.endCapPairs)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Hangers: \(quote.hangersCount)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))

                if quote.includeGutterGuard {
                    currentY += drawText("• Gutter Guard Feet: \(quote.gutterGuardFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                }

                // Add composite feet for price calculation clarity
                if breakdown.compositeFeet > 0 {
                    currentY += drawText("• Total Composite Feet: \(breakdown.compositeFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                }
                currentY += 15

                // Additional labor items
                if !quote.additionalLaborItems.isEmpty {
                    currentY += drawText("Additional Labor:", fontSize: 14, bold: true, at: CGPoint(x: margin, y: currentY))
                    for item in quote.additionalLaborItems {
                        currentY += drawText("• \(item.title): \(item.amount.currencyFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                    }
                    currentY += 15
                }

                // Pricing breakdown
                currentY += drawText("PRICING BREAKDOWN", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 10

                let pricingItems = [
                    ("Materials Total:", breakdown.materialsTotal.currencyFormatted),
                    ("Labor Total:", breakdown.laborTotal.currencyFormatted),
                    ("Subtotal:", breakdown.subtotal.currencyFormatted),
                    ("Margin (\(Int(quote.marginPercent * 100))%):", breakdown.marginAmount.currencyFormatted),
                    ("Commission (\(Int(quote.salesCommissionPercent * 100))%):", breakdown.commissionAmount.currencyFormatted)
                ]

                for (label, value) in pricingItems {
                    let labelY = currentY
                    currentY += drawText(label, fontSize: 12, at: CGPoint(x: margin, y: labelY))
                    _ = drawText(value, fontSize: 12, at: CGPoint(x: pageSize.width - margin - 100, y: labelY))
                }

                // Draw line before total
                currentY += 10
                drawLine(from: CGPoint(x: margin, y: currentY), to: CGPoint(x: pageSize.width - margin, y: currentY))
                currentY += 15

                // Final total
                let totalY = currentY
                currentY += drawText("TOTAL:", fontSize: 16, bold: true, at: CGPoint(x: margin, y: totalY))
                _ = drawText(breakdown.finalTotal.currencyFormatted, fontSize: 16, bold: true, at: CGPoint(x: pageSize.width - margin - 120, y: totalY))

                if breakdown.compositeFeet > 0 {
                    currentY += 15
                    let pricePerFootY = currentY
                    currentY += drawText("Price per Foot:", fontSize: 14, bold: true, at: CGPoint(x: margin, y: pricePerFootY))
                    _ = drawText(breakdown.pricePerFoot.currencyFormatted, fontSize: 14, bold: true, at: CGPoint(x: pageSize.width - margin - 120, y: pricePerFootY))
                    currentY += 5
                    _ = drawText("(Based on \(breakdown.compositeFeet.twoDecimalFormatted) composite feet)", fontSize: 10, at: CGPoint(x: margin, y: currentY))
                }

                currentY += 30

                // Notes if any
                if !quote.notes.isEmpty {
                    currentY += drawText("NOTES", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                    currentY += 10
                    currentY += drawText(quote.notes, fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += 20
                }

                // Photos section
                if !photos.isEmpty {
                    // Check if we need a new page for photos
                    let photosNeededHeight: CGFloat = 300 * CGFloat((photos.count + 1) / 2) // Estimate
                    if currentY + photosNeededHeight > pageSize.height - margin {
                        context.beginPage()
                        currentY = margin
                    }

                    currentY += drawText("PHOTOS", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                    currentY += 20

                    let contentWidth = pageSize.width - (margin * 2)
                    let photoWidth: CGFloat = (contentWidth - 20) / 2 // Two photos per row
                    let photoHeight: CGFloat = photoWidth * 0.75 // 4:3 aspect ratio

                    var photoX: CGFloat = margin
                    var photosInRow = 0

                    for photo in photos {
                        if let image = photo.image {
                            // Draw photo
                            let photoRect = CGRect(x: photoX, y: currentY, width: photoWidth, height: photoHeight)
                            image.draw(in: photoRect)

                            // Add photo info below image
                            let infoY = currentY + photoHeight + 5
                            _ = drawText("Captured: \(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))", fontSize: 10, at: CGPoint(x: photoX, y: infoY))

                            if let location = photo.location {
                                let coordinates = String(format: "GPS: %.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
                                _ = drawText(coordinates, fontSize: 10, at: CGPoint(x: photoX, y: infoY + 12))
                            }

                            photosInRow += 1

                            if photosInRow == 2 {
                                // Move to next row
                                currentY += photoHeight + 40
                                photoX = margin
                                photosInRow = 0

                                // Check if we need a new page
                                if currentY + photoHeight > pageSize.height - margin {
                                    context.beginPage()
                                    currentY = margin
                                }
                            } else {
                                // Move to next column
                                photoX += photoWidth + 20
                            }
                        }
                    }

                    // If we ended with an odd number of photos, move to next row
                    if photosInRow == 1 {
                        currentY += photoHeight + 40
                    }
                }

                // Footer
                let footerY = pageSize.height - margin - 40
                drawLine(from: CGPoint(x: margin, y: footerY), to: CGPoint(x: pageSize.width - margin, y: footerY))
                _ = drawText("This quote is valid for 30 days from the date above.", fontSize: 10, at: CGPoint(x: margin, y: footerY + 10))
                _ = drawText("Generated by DTS App", fontSize: 10, at: CGPoint(x: pageSize.width - margin - 120, y: footerY + 10))
            }

            try pdfData.write(to: pdfURL)
            return pdfURL

        } catch {
            print("Error generating PDF: \(error)")
            return nil
        }
    }
}

// MARK: - Formatting Extensions
extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var twoDecimalFormatted: String {
        return String(format: "%.2f", self)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var jobs: [JobberJob]

    var todayJobs: [JobberJob] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Combine local jobs with Jobber jobs
        let allJobs = jobs + jobberAPI.jobs

        return allJobs.filter { job in
            job.scheduledAt >= today && job.scheduledAt < tomorrow
        }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Jobber Authentication Section
                if !jobberAPI.isAuthenticated {
                    VStack(spacing: 16) {
                        Text("Connect to Jobber")
                            .font(.headline)

                        Text("Connect your Jobber account to sync today's jobs automatically.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Connect Jobber Account") {
                            jobberAPI.authenticate()
                        }
                        .buttonStyle(.borderedProminent)

                        if let errorMessage = jobberAPI.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .sheet(isPresented: $jobberAPI.showingManualAuth) {
                        // This view is no longer used with ASWebAuthenticationSession
                        // ManualAuthView()
                        //     .environmentObject(jobberAPI)
                    }
                }

                if jobberAPI.isLoading {
                    ProgressView("Loading today's jobs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todayJobs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Jobs Today")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("No jobs scheduled for today. Check back later or create a new quote.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        if !jobberAPI.isAuthenticated {
                            Button("Add Sample Jobs") {
                                addSampleJobs()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                } else {
                    List(todayJobs, id: \.jobId) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            JobRowView(job: job)
                        }
                    }
                }

                if let errorMessage = jobberAPI.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Today's Jobs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if jobberAPI.isAuthenticated {
                        Button("Refresh") {
                            Task {
                                await jobberAPI.fetchTodayJobs()
                            }
                        }
                    }
                }
            }
            .refreshable {
                if jobberAPI.isAuthenticated {
                    await jobberAPI.fetchTodayJobs()
                } else {
                    await fetchTodayJobs()
                }
            }
            .task {
                if jobberAPI.isAuthenticated {
                    await jobberAPI.fetchTodayJobs()
                } else {
                    await fetchTodayJobs()
                }
            }
        }
    }

    private func fetchTodayJobs() async {
        // For local sample data when not authenticated with Jobber
        if jobs.isEmpty {
            addSampleJobs()
        }
    }

    private func addSampleJobs() {
        let sampleJobs = [
            JobberJob(
                jobId: "job_001",
                clientName: "John Smith",
                address: "123 Main St, Anytown, ST 12345",
                scheduledAt: Date(),
                status: "scheduled"
            ),
            JobberJob(
                jobId: "job_002",
                clientName: "Sarah Johnson",
                address: "456 Oak Ave, Somewhere, ST 67890",
                scheduledAt: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                status: "in_progress"
            ),
            JobberJob(
                jobId: "job_003",
                clientName: "Mike Wilson",
                address: "789 Pine St, Downtown, ST 11111",
                scheduledAt: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date(),
                status: "scheduled"
            )
        ]

        for job in sampleJobs {
            modelContext.insert(job)
        }

        try? modelContext.save()
    }
}

struct JobRowView: View {
    let job: JobberJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(job.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(job.scheduledAt, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    StatusBadge(status: job.status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct JobDetailView: View {
    let job: JobberJob
    @Environment(\.modelContext) private var modelContext
    @StateObject private var photoCaptureManager = PhotoCaptureManager()
    @State private var showingPhotoGallery = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Job Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Job Details")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(job.clientName, systemImage: "person.fill")
                        Label(job.address, systemImage: "location.fill")
                        Label(job.scheduledAt.formatted(date: .abbreviated, time: .shortened),
                              systemImage: "calendar")
                        Label(job.status.capitalized, systemImage: "info.circle")
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Photos Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Photos")
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        if !photoCaptureManager.capturedImages.isEmpty {
                            Button("View All") {
                                showingPhotoGallery = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }

                    if photoCaptureManager.capturedImages.isEmpty {
                        Text("No photos captured yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoCaptureManager.capturedImages.prefix(5)) { photo in
                                    AsyncImage(url: URL(string: "file://" + photo.fileURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Action Buttons
                VStack(spacing: 12) {
                    NavigationLink(destination: QuoteFormView(jobId: job.jobId)) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Create Quote")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: {
                        photoCaptureManager.capturePhoto(for: job.jobId)
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let locationError = photoCaptureManager.locationError {
                        Text(locationError)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Job Details")
        .sheet(isPresented: $photoCaptureManager.showingCamera) {
            CameraView(isPresented: $photoCaptureManager.showingCamera) { image in
                photoCaptureManager.processImage(image, jobId: job.jobId)
            }
        }
        .sheet(isPresented: $photoCaptureManager.showingImagePicker) {
            PhotoLibraryPicker(isPresented: $photoCaptureManager.showingImagePicker) { image in
                photoCaptureManager.processImage(image, jobId: job.jobId)
            }
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PhotoGalleryView(photos: photoCaptureManager.capturedImages.filter { $0.jobId == job.jobId })
        }
    }
}

struct QuoteFormView: View {
    let jobId: String?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]
    @State private var quoteDraft = QuoteDraft()
    @State private var showingPreview = false
    @State private var showingLineItemEditor = false
    @State private var newLineItemTitle = ""
    @State private var newLineItemAmount: Double = 0
    @State private var showingSaveToJobberAlert = false
    @State private var isSavingToJobber = false
    @StateObject private var photoCaptureManager = PhotoCaptureManager()
    @State private var showingPhotoGallery = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var showingPDFAlert = false

    // Common labor items for quick selection
    private let commonLaborItems = [
        CommonLaborItem(title: "TV Dish Removal", amount: 75.0),
        CommonLaborItem(title: "Debris Cleanup", amount: 50.0),
        CommonLaborItem(title: "Gutter Cleaning", amount: 150.0),
        CommonLaborItem(title: "Fascia Repair", amount: 100.0),
        CommonLaborItem(title: "Soffit Repair", amount: 125.0),
        CommonLaborItem(title: "Ladder Setup", amount: 25.0)
    ]

    private var settings: AppSettings {
        settingsArray.first ?? AppSettings()
    }

    // Computed properties to simplify complex bindings
    private var marginPercentBinding: Binding<Double> {
        Binding(
            get: { quoteDraft.marginPercent * 100 },
            set: { quoteDraft.marginPercent = $0 / 100 }
        )
    }

    private var commissionPercentBinding: Binding<Double> {
        Binding(
            get: { quoteDraft.salesCommissionPercent * 100 },
            set: { quoteDraft.salesCommissionPercent = $0 / 100 }
        )
    }

    init(jobId: String? = nil) {
        self.jobId = jobId
    }

    // Helper function to create a binding that clears zero values
    private func clearableNumberBinding(for value: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                if value.wrappedValue == 0 {
                    return ""
                } else {
                    return String(value.wrappedValue)
                }
            },
            set: { newValue in
                if let doubleValue = Double(newValue) {
                    value.wrappedValue = doubleValue
                } else if newValue.isEmpty {
                    value.wrappedValue = 0
                }
            }
        )
    }

    // Helper function for integer fields
    private func clearableIntBinding(for value: Binding<Int>) -> Binding<String> {
        Binding<String>(
            get: {
                if value.wrappedValue == 0 {
                    return ""
                } else {
                    return String(value.wrappedValue)
                }
            },
            set: { newValue in
                if let intValue = Int(newValue) {
                    value.wrappedValue = intValue
                } else if newValue.isEmpty {
                    value.wrappedValue = 0
                }
            }
        )
    }

    @ViewBuilder
    private var measurementsSection: some View {
        Section("Measurements") {
            HStack {
                Text("Gutter Feet")
                Spacer()
                TextField("0", text: clearableNumberBinding(for: $quoteDraft.gutterFeet))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.decimalPad)
            }

            HStack {
                Text("Downspout Feet")
                Spacer()
                TextField("0", text: clearableNumberBinding(for: $quoteDraft.downspoutFeet))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.decimalPad)
            }

            HStack {
                Text("Elbows Count")
                Spacer()
                TextField("0", text: clearableIntBinding(for: $quoteDraft.elbowsCount))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.numberPad)
            }

            HStack {
                Text("End Cap Pairs")
                Spacer()
                TextField("0", text: clearableIntBinding(for: $quoteDraft.endCapPairs))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.numberPad)
            }

            HStack {
                Text("Hangers (auto-calculated)")
                Spacer()
                Text("\(quoteDraft.hangersCount)")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var gutterGuardSection: some View {
        Section("Gutter Guard") {
            Toggle("Include Gutter Guard", isOn: $quoteDraft.includeGutterGuard)

            if quoteDraft.includeGutterGuard {
                HStack {
                    Text("Gutter Guard Feet")
                    Spacer()
                    TextField("0", text: clearableNumberBinding(for: $quoteDraft.gutterGuardFeet))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .onChange(of: quoteDraft.includeGutterGuard) { _, newValue in
            if newValue && quoteDraft.gutterGuardFeet == 0 {
                quoteDraft.gutterGuardFeet = quoteDraft.gutterFeet
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Form {
                    measurementsSection
                    gutterGuardSection

                    Section("Additional Labor") {
                        ForEach(quoteDraft.additionalLaborItems, id: \.title) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline)
                                    Text(item.amount.currencyFormatted)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    removeLineItem(item)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Add Labor Item Button with improved tap handling
                        Button(action: addNewLineItem) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.white)
                                Text("Add Labor Item")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    if showingLineItemEditor {
                        Section("New Labor Item") {
                            HStack {
                                Text("Description")
                                Spacer()
                                TextField("e.g., TV Dish Removal", text: $newLineItemTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180)
                            }

                            // Quick preset buttons for common labor items
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Common Items:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(commonLaborItems) { preset in
                                        VStack(spacing: 2) {
                                            Text(preset.title)
                                                .font(.caption)
                                                .multilineTextAlignment(.center)
                                            Text(preset.amount.currencyFormatted)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .frame(minHeight: 40)
                                        .frame(maxWidth: .infinity)
                                        .background(.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            newLineItemTitle = preset.title
                                            newLineItemAmount = preset.amount
                                        }
                                    }
                                }
                            }

                            HStack {
                                Text("Amount")
                                Spacer()
                                TextField("0", value: $newLineItemAmount, format: .currency(code: "USD"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .keyboardType(.decimalPad)
                            }

                            HStack(spacing: 20) {
                                Text("Cancel")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        cancelLineItemEdit()
                                    }

                                Spacer()

                                Text("Add Item")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(newLineItemTitle.isEmpty || newLineItemAmount <= 0 ? .gray : .blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !newLineItemTitle.isEmpty && newLineItemAmount > 0 {
                                            saveNewLineItem()
                                        }
                                    }
                                    .disabled(newLineItemTitle.isEmpty || newLineItemAmount <= 0)
                            }
                        }
                    }

                    Section("Pricing") {
                        HStack {
                            Text("Margin %")
                            Spacer()
                            TextField("35", value: marginPercentBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                            Text("%")
                        }

                        HStack {
                            Text("Sales Commission %")
                            Spacer()
                            TextField("3", value: commissionPercentBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                            Text("%")
                        }
                    }

                    Section("Preview") {
                        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Materials Total")
                                Spacer()
                                Text(breakdown.materialsTotal.currencyFormatted)
                            }

                            HStack {
                                Text("Labor Total")
                                Spacer()
                                Text(breakdown.laborTotal.currencyFormatted)
                            }

                            // Show additional labor breakdown if any exist
                            if !quoteDraft.additionalLaborItems.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Additional Labor:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }

                                    ForEach(quoteDraft.additionalLaborItems, id: \.title) { item in
                                        HStack {
                                            Text("• \(item.title)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(item.amount.currencyFormatted)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }

                            HStack {
                                Text("Margin")
                                Spacer()
                                Text(breakdown.marginAmount.currencyFormatted)
                            }

                            HStack {
                                Text("Commission")
                                Spacer()
                                Text(breakdown.commissionAmount.currencyFormatted)
                            }

                            Divider()

                            HStack {
                                Text("Final Total")
                                    .fontWeight(.bold)
                                Spacer()
                                Text(breakdown.finalTotal.currencyFormatted)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }

                            if breakdown.compositeFeet > 0 {
                                HStack {
                                    Text("Price per Foot")
                                    Spacer()
                                    Text(breakdown.pricePerFoot.currencyFormatted)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Section("Photos") {
                        HStack {
                            Button(action: {
                                photoCaptureManager.capturePhoto(quoteDraftId: quoteDraft.localId)
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Capture Photo")
                                }
                                .foregroundColor(.blue)
                            }

                            Spacer()

                            if !photoCaptureManager.capturedImages.filter({ $0.quoteDraftId == quoteDraft.localId }).isEmpty {
                                Button("View Photos (\(photoCaptureManager.capturedImages.filter { $0.quoteDraftId == quoteDraft.localId }.count))") {
                                    showingPhotoGallery = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }

                        if !photoCaptureManager.capturedImages.filter({ $0.quoteDraftId == quoteDraft.localId }).isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photoCaptureManager.capturedImages.filter { $0.quoteDraftId == quoteDraft.localId }.prefix(3)) { photo in
                                        AsyncImage(url: URL(string: "file://" + photo.fileURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        if let locationError = photoCaptureManager.locationError {
                            Text(locationError)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping anywhere on the form
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Dismiss keyboard when swiping down
                            if value.translation.height > 50 {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                )
                
                Text("V3")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding()
            }
            .navigationTitle(jobId != nil ? "Create Quote" : "Standalone Quote")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if jobberAPI.isAuthenticated && jobId != nil {
                            Button("Save to Jobber") {
                                showingSaveToJobberAlert = true
                            }
                            .disabled(quoteDraft.gutterFeet == 0 || isSavingToJobber)
                        }

                        Button("Save Quote") {
                            saveQuote()
                        }
                        .disabled(false)
                    }
                }
            }
            .alert("Save to Jobber", isPresented: $showingSaveToJobberAlert) {
                Button("Save Local Only") {
                    saveQuote()
                }

                Button("Save to Jobber") {
                    saveQuoteToJobber()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Would you like to save this quote locally only or create a quote draft in Jobber?")
            }
            .sheet(isPresented: $photoCaptureManager.showingCamera) {
                CameraView(isPresented: $photoCaptureManager.showingCamera) { image in
                    photoCaptureManager.processImage(image, quoteDraftId: quoteDraft.localId)
                }
            }
            .sheet(isPresented: $photoCaptureManager.showingPhotoLibrary) {
                PhotoLibraryPicker(isPresented: $photoCaptureManager.showingPhotoLibrary) { image in
                    photoCaptureManager.processImage(image, quoteDraftId: quoteDraft.localId)
                }
            }
            .sheet(isPresented: $showingPhotoGallery) {
                PhotoGalleryView(photos: photoCaptureManager.capturedImages.filter { $0.quoteDraftId == quoteDraft.localId })
            }
            .alert("PDF Generated", isPresented: $showingPDFAlert) {
                Button("View & Share PDF") {
                    if generatedPDFURL != nil {
                        showingShareSheet = true
                    }
                }
                Button("OK") { }
            } message: {
                Text("Quote PDF has been generated successfully. You can view and share it with your client.")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = generatedPDFURL {
                    ShareSheet(items: [pdfURL])
                }
            }
        }
        .onAppear {
            // Initialize with default values from settings
            quoteDraft.marginPercent = settings.defaultMarginPercent
            quoteDraft.salesCommissionPercent = settings.defaultSalesCommissionPercent
            quoteDraft.jobId = jobId
        }
    }

    private func saveQuote() {
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Save quote to database
        modelContext.insert(quoteDraft)
        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)
    }

    private func saveQuoteToJobber() {
        isSavingToJobber = true

        // First save locally
        saveQuote()

        // Then sync to Jobber
        Task {
            await jobberAPI.createQuoteDraft(quoteDraft: quoteDraft)

            DispatchQueue.main.async {
                self.isSavingToJobber = false
            }
        }
    }

    private func generateQuotePDF(breakdown: PriceBreakdown) {
        // Get photos for this quote
        let quotePhotos = photoCaptureManager.capturedImages.filter { $0.quoteDraftId == quoteDraft.localId }

        // Get job info if available
        let jobInfo: JobberJob? = nil // We could enhance this to fetch job details if needed

        // Generate PDF
        if let pdfURL = PDFGenerator.generateQuotePDF(
            quote: quoteDraft,
            breakdown: breakdown,
            settings: settings,
            photos: quotePhotos,
            jobInfo: jobInfo
        ) {
            generatedPDFURL = pdfURL
            showingPDFAlert = true
        }
    }

    // MARK: - Additional Labor Item Management

    private func addNewLineItem() {
        showingLineItemEditor = true
        newLineItemTitle = ""
        newLineItemAmount = 0
    }

    private func saveNewLineItem() {
        let newItem = LineItem(title: newLineItemTitle, amount: newLineItemAmount)
        newItem.quoteDraft = quoteDraft
        quoteDraft.additionalLaborItems.append(newItem)

        cancelLineItemEdit()
    }

    private func removeLineItem(_ item: LineItem) {
        if let index = quoteDraft.additionalLaborItems.firstIndex(where: { $0.title == item.title && $0.amount == item.amount }) {
            quoteDraft.additionalLaborItems.remove(at: index)
        }
    }

    private func cancelLineItemEdit() {
        showingLineItemEditor = false
        newLineItemTitle = ""
        newLineItemAmount = 0
    }
}

struct StatusBadge: View {
    let status: String

    var statusColor: Color {
        switch status.lowercased() {
        case "scheduled":
            return .blue
        case "in_progress":
            return .orange
        case "completed":
            return .green
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
}

struct CreateQuoteView: View {
    @EnvironmentObject private var jobberAPI: JobberAPI

    var body: some View {
        QuoteFormView()
            .environmentObject(jobberAPI)
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]

    private var settings: AppSettings {
        if let existingSettings = settingsArray.first {
            return existingSettings
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            return newSettings
        }
    }

    // Helper function to create a binding that clears zero values for Double
    private func clearableNumberBinding(for value: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                if value.wrappedValue == 0 {
                    return ""
                } else {
                    return String(value.wrappedValue)
                }
            },
            set: { newValue in
                if let doubleValue = Double(newValue) {
                    value.wrappedValue = doubleValue
                } else if newValue.isEmpty {
                    value.wrappedValue = 0
                }
            }
        )
    }

    // Helper function for percentage fields that are stored as decimals
    private func clearablePercentBinding(get: @escaping () -> Double, set: @escaping (Double) -> Void) -> Binding<String> {
        Binding<String>(
            get: {
                let percentValue = get() * 100
                if percentValue == 0 {
                    return ""
                } else {
                    return String(percentValue)
                }
            },
            set: { newValue in
                if let doubleValue = Double(newValue) {
                    set(doubleValue / 100)
                } else if newValue.isEmpty {
                    set(0)
                }
            }
        )
    }

    private func saveSettings() {
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Materials Cost per Foot") {
                    HStack {
                        Text("Gutter")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.materialCostPerFootGutter },
                            set: { settings.materialCostPerFootGutter = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }

                    HStack {
                        Text("Downspout")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.materialCostPerFootDownspout },
                            set: { settings.materialCostPerFootDownspout = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }

                    HStack {
                        Text("Gutter Guard")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.gutterGuardMaterialPerFoot },
                            set: { settings.gutterGuardMaterialPerFoot = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }
                }

                Section("Component Costs") {
                    HStack {
                        Text("Elbow")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.costPerElbow },
                            set: { settings.costPerElbow = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }

                    HStack {
                        Text("Hanger")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.costPerHanger },
                            set: { settings.costPerHanger = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }

                    HStack {
                        Text("Hanger Spacing (feet)")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.hangerSpacingFeet },
                            set: { settings.hangerSpacingFeet = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }
                }

                Section("Labor Cost per Foot") {
                    HStack {
                        Text("Gutter Installation")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.laborPerFootGutter },
                            set: { settings.laborPerFootGutter = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }

                    HStack {
                        Text("Gutter Guard Installation")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.gutterGuardLaborPerFoot },
                            set: { settings.gutterGuardLaborPerFoot = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }
                }

                Section("Margins & Commission") {
                    HStack {
                        Text("Default Margin %")
                        Spacer()
                        TextField("0", text: clearablePercentBinding(
                            get: { settings.defaultMarginPercent },
                            set: { settings.defaultMarginPercent = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                        Text("%")
                    }

                    HStack {
                        Text("Gutter Guard Margin %")
                        Spacer()
                        TextField("0", text: clearablePercentBinding(
                            get: { settings.gutterGuardMarginPercent },
                            set: { settings.gutterGuardMarginPercent = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                        Text("%")
                    }

                    HStack {
                        Text("Sales Commission %")
                        Spacer()
                        TextField("0", text: clearablePercentBinding(
                            get: { settings.defaultSalesCommissionPercent },
                            set: { settings.defaultSalesCommissionPercent = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                        Text("%")
                    }
                }

                Section("Calculation Settings") {
                    HStack {
                        Text("Elbow Foot Equivalency")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: Binding(
                            get: { settings.elbowFootEquivalency },
                            set: { settings.elbowFootEquivalency = $0 }
                        )))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .onSubmit { saveSettings() }
                    }
                }

                Section("Jobber Integration") {
                    if jobberAPI.isAuthenticated {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Connected to Jobber")
                                    .foregroundColor(.green)
                                Text("Your jobs will sync automatically")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Disconnect") {
                                jobberAPI.signOut()
                            }
                            .foregroundColor(.red)
                        }

                        Button("Sync Jobs Now") {
                            Task {
                                await jobberAPI.fetchTodayJobs()
                            }
                        }
                        .disabled(jobberAPI.isLoading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connect to Jobber")
                                .font(.headline)

                            Text("Connect your Jobber account to automatically sync jobs and create quotes.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Connect Jobber Account") {
                                jobberAPI.authenticate()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let errorMessage = jobberAPI.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere on the form
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Dismiss keyboard when swiping down
                        if value.translation.height > 50 {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
            )
            .onDisappear {
                // Save settings when leaving the view
                saveSettings()
            }
            .navigationTitle("Settings")
        }
    }
}

// This view is no longer used with ASWebAuthenticationSession
// struct ManualAuthView: View {
//     @EnvironmentObject private var jobberAPI: JobberAPI
//     @Environment(\.dismiss) private var dismiss
//     @State private var authCode = ""
//     @State private var showingURL = false
//
//     var body: some View {
//         NavigationStack {
//             VStack(spacing: 20) {
//                 Text("Jobber Authentication")
//
//                 Text("Follow these steps to connect your Jobber account:")
//                     .multilineTextAlignment(.center)
//
//                 VStack(alignment: .leading, spacing: 12) {
//                     Label("1. Copy the URL below", systemImage: "1.circle.fill")
//                     Label("2. Open it in Safari", systemImage: "2.circle.fill")
//                     Label("3. If already logged in, log out first", systemImage: "3.circle.fill")
//                         .foregroundColor(.orange)
//                     Label("4. Sign in and authorize the app", systemImage: "4.circle.fill")
//                     Label("5. Look for authorization code in URL", systemImage: "5.circle.fill")
//                     Label("6. Paste the code below and tap Connect", systemImage: "6.circle.fill")
//
//                     Text("⚠️ Troubleshooting: If you don't see an authorization screen, try logging out of Jobber first, then use the URL again.")
//                         .font(.caption)
//                         .foregroundColor(.orange)
//                         .padding(.top, 8)
//                 }
//                 .font(.subheadline)
//
//                 VStack(spacing: 12) {
//                     Text("Authorization URL:")
//                         .font(.headline)
//
//                     ScrollView(.horizontal, showsIndicators: false) {
//                         Text(jobberAPI.getAuthURL())
//                             .font(.caption)
//                             .foregroundColor(.blue)
//                             .padding(.horizontal, 8)
//                             .padding(.vertical, 4)
//                             .background(.blue.opacity(0.1))
//                             .cornerRadius(4)
//                     }
//
//                     HStack {
//                         Button("Copy URL") {
//                             UIPasteboard.general.string = jobberAPI.getAuthURL()
//                         }
//                         .buttonStyle(.bordered)
//
//                         Button("Open in Safari") {
//                             if let url = URL(string: jobberAPI.getAuthURL()) {
//                                 UIApplication.shared.open(url)
//                             }
//                         }
//                         .buttonStyle(.borderedProminent)
//                     }
//
//                     Button("Force Authorization Screen") {
//                         let forceAuthURL = jobberAPI.getAuthURL() + "&prompt=consent"
//                         if let url = URL(string: forceAuthURL) {
//                             UIApplication.shared.open(url)
//                         }
//                     }
//                     .buttonStyle(.bordered)
//                     .foregroundColor(.orange)
//                 }
//                 .padding()
//                 .background(.ultraThinMaterial)
//                 .cornerRadius(12)
//
//                 VStack(spacing: 12) {
//                     Text("After authorizing, paste the code here:")
//                         .font(.subheadline)
//                         .foregroundColor(.secondary)
//
//                     TextField("Authorization Code", text: $authCode)
//                         .textFieldStyle(.roundedBorder)
//                         .autocapitalization(.none)
//                         .autocorrectionDisabled()
//
//                     Button("Connect") {
//                         jobberAPI.authenticateWithCode(authCode)
//                         dismiss()
//                     }
//                     .buttonStyle(.borderedProminent)
//                     .disabled(authCode.isEmpty)
//                 }
//                 .padding()
//                 .background(.ultraThinMaterial)
//                 .cornerRadius(12)
//
//                 Spacer()
//             }
//             .padding()
//             .navigationBarTitleDisplayMode(.inline)
//             .toolbar {
//                 ToolbarItem(placement: .navigationBarTrailing) {
//                     Button("Cancel") {
//                         dismiss()
//                     }
//                 }
//             }
//         }
//     }
// }

struct ContentView: View {
    @StateObject private var jobberAPI = JobberAPI()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .environmentObject(jobberAPI)

            CreateQuoteView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Create Quote")
                }
                .environmentObject(jobberAPI)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .environmentObject(jobberAPI)
        }

            // Version label in the corner
            Text("v2")
                .font(.system(size: 16, weight: .bold))
                .padding(8)
                .background(Color.black.opacity(0.85))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding([.top, .trailing], 10)
                .shadow(color: .black, radius: 3, x: 1, y: 1)
        }
    }
}

#Preview {
    ContentView()
}
