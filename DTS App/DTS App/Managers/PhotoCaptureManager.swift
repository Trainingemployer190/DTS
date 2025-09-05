//
//  PhotoCaptureManager.swift
//  DTS App
//
//  Created by Chandler Staton on 8/17/25.
//

import SwiftUI
import CoreLocation
import AVFoundation
import Photos

// Import UIKit for iOS platform
#if os(iOS)
import UIKit
#endif

#if os(iOS)
@MainActor
class PhotoCaptureManager: NSObject, ObservableObject {
    @Published var capturedImages: [CapturedPhoto] = []
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var showingPhotoLibrary = false
    @Published var isLocationAuthorized = false
    @Published var isPhotosAuthorized = false
    @Published var locationError: String?
    @Published var captureCount = 0

    // Enhanced location management
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    private let maxCachedImages = 20 // Limit cached images to prevent memory issues
    private let geocoder = CLGeocoder()

    // Cached authorization status to avoid main thread warnings
    private var cachedAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    private var cachedLocationServicesEnabled: Bool = true // Cache location services status

    // Geocoding throttling and caching
    private var lastGeocodingTime: Date = .distantPast
    private var lastGeocodedLocation: CLLocation?
    private var cachedAddress: String?
    private let geocodingInterval: TimeInterval = 5.0 // Minimum 5 seconds between requests
    private let locationChangeThreshold: CLLocationDistance = 100.0 // Minimum 100 meters change

    override init() {
        super.init()
        // Initialize with default values - will be updated by delegate callback
        cachedAuthorizationStatus = .notDetermined
        cachedLocationServicesEnabled = true
        setupLocationManager()
        checkLocationPermission()
        checkPhotosPermission()

        #if os(iOS)
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func handleMemoryWarning() {
        // Clear image caches when memory warning is received
        print("Memory warning received - clearing image caches")

        // Reduce the number of cached images more aggressively
        if capturedImages.count > 10 {
            capturedImages.removeFirst(capturedImages.count - 10)
        }

        // Force garbage collection
        autoreleasepool {
            // This forces any autorelease objects to be released immediately
        }
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        // Use a reasonable accuracy that doesn't drain battery
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Don't start updates immediately
    }

    private func checkLocationPermission() {
        // Request authorization which will trigger the delegate callback
        if cachedAuthorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func requestLocationPermission() {
        // Simply request authorization - delegate callback will handle the result
        locationManager.requestWhenInUseAuthorization()
    }

    private func requestCurrentLocation() {
        // Check cached authorization status first
        switch cachedAuthorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Use cached location services status to avoid main thread warnings
            guard cachedLocationServicesEnabled else {
                print("Location services not enabled on device")
                locationError = "Location services are disabled on this device. Enable them in Settings > Privacy & Security > Location Services."
                return
            }

            print("Requesting current location...")
            // Use requestLocation for one-time location request instead of continuous updates
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location not authorized - cannot request location")
            locationError = "Location access not granted"
        case .notDetermined:
            print("Location permission not determined")
            locationError = "Location permission pending"
        @unknown default:
            print("Unknown location authorization status")
            locationError = "Location access status unknown"
        }
    }

    private func checkPhotosPermission() {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            isPhotosAuthorized = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                DispatchQueue.main.async {
                    self?.isPhotosAuthorized = (status == .authorized || status == .limited)
                }
            }
        case .denied, .restricted:
            isPhotosAuthorized = false
        @unknown default:
            isPhotosAuthorized = false
        }
    }

    func capturePhoto(for jobId: String? = nil, quoteDraftId: UUID? = nil) {
        // Clear any previous errors
        locationError = nil

        // Request current location when starting photo capture
        if isLocationAuthorized {
            requestCurrentLocation()
        }

        // First check if camera is available (won't work in simulator)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // For simulator or devices without camera, use photo library instead
            showingPhotoLibrary = true
            return
        }

        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            captureCount = 0 // Reset counter for new session
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.captureCount = 0 // Reset counter for new session
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
        // First compress the image to reduce memory usage
        let compressedImage = compressImage(image)

        autoreleasepool {
            let watermarkedImage = addWatermark(to: compressedImage)

            // Save to Photos app if permission is granted
            if isPhotosAuthorized {
                saveToPhotosApp(watermarkedImage)
            }

            // Save to Documents directory
            guard let imageData = watermarkedImage.jpegData(compressionQuality: 0.7),
                  let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }

            let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
            let fileURL = documentsPath.appendingPathComponent(fileName)

            do {
                try imageData.write(to: fileURL)

                // Convert data to UIImage
                guard let uiImage = UIImage(data: imageData) else {
                    DispatchQueue.main.async {
                        self.locationError = "Failed to convert image data"
                    }
                    return
                }

                // Convert location to string if available
                let locationString: String?
                if let location = currentLocation {
                    locationString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
                } else {
                    locationString = nil
                }

                let capturedPhoto = CapturedPhoto(
                    image: uiImage,
                    location: locationString
                )

                capturedImages.append(capturedPhoto)

                // Limit the number of cached images to prevent memory issues
                if capturedImages.count > maxCachedImages {
                    capturedImages.removeFirst(capturedImages.count - maxCachedImages)
                }

            } catch {
                print("Error saving image: \(error)")
            }
        }
    }

    private func compressImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1920 // Max width or height
        let originalSize = image.size

        // If image is already small enough, return as is
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
        let newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)

        // Use autoreleasepool for memory management
        return autoreleasepool {
            let renderer = UIGraphicsImageRenderer(size: newSize, format: UIGraphicsImageRendererFormat())
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }

    private func saveToPhotosApp(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.creationRequestForAsset(from: image)
            // Add metadata if needed
            creationRequest.location = self.currentLocation
            creationRequest.creationDate = Date()
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("Photo saved to Photos app successfully")
                } else if let error = error {
                    print("Error saving photo to Photos app: \(error)")
                    self?.locationError = "Could not save to Photos app: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addWatermark(to image: UIImage) -> UIImage {
        // Use autoreleasepool to manage memory during rendering
        return autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // Use 1x scale to reduce memory usage
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

            return renderer.image { context in
                // Draw original image
                image.draw(in: CGRect(origin: .zero, size: image.size))

                // Prepare watermark text
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"

                let timestamp = dateFormatter.string(from: Date())
                let locationText = formatLocationText()

                // Simple watermark with just timestamp and location
                let watermarkText = "\(timestamp)\n\(locationText)"

                // Configure text attributes with smaller font to reduce memory
                let textColor = UIColor.white
                let shadowColor = UIColor.black
                let font = UIFont.boldSystemFont(ofSize: max(image.size.width / 30, 16)) // Reduced font size

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor,
                    .strokeColor: shadowColor,
                    .strokeWidth: -2.0 // Reduced stroke width
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

                // Draw semi-transparent background with rounded corners
                let backgroundRect = textRect.insetBy(dx: -10, dy: -8) // Reduced background padding
                context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
                let roundedPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 6)
                context.cgContext.addPath(roundedPath.cgPath)
                context.cgContext.fillPath()

                // Draw text
                attributedString.draw(in: textRect)
            }
        }
    }

    func formatLocationStatus() -> String {
        // Check cached authorization status first to avoid main thread warnings
        switch cachedAuthorizationStatus {
        case .denied, .restricted:
            return "Location access denied"
        case .notDetermined:
            return "Location permission pending"
        case .authorizedWhenInUse, .authorizedAlways:
            // Use cached location services status to avoid main thread warnings
            if !cachedLocationServicesEnabled {
                return "Location services disabled"
            }

            if let error = locationError {
                return error
            } else if let address = currentAddress, !address.isEmpty {
                // Take first 30 characters of address
                return String(address.prefix(30)) + (address.count > 30 ? "..." : "")
            } else if let location = currentLocation {
                let latitude = String(format: "%.4f", location.coordinate.latitude)
                let longitude = String(format: "%.4f", location.coordinate.longitude)
                return "\(latitude), \(longitude)"
            } else {
                return "Getting location..."
            }
        @unknown default:
            return "Location status unknown"
        }
    }

    private func formatLocationText() -> String {
        // Check cached authorization status first to avoid main thread warnings
        switch cachedAuthorizationStatus {
        case .denied, .restricted:
            return "📍 Location access denied. Enable in Settings > Privacy & Security > Location Services"
        case .notDetermined:
            return "📍 Location permission pending"
        case .authorizedWhenInUse, .authorizedAlways:
            // Use cached location services status to avoid main thread warnings
            if !cachedLocationServicesEnabled {
                return "📍 Location services disabled"
            }

            // Show any current location error
            if let error = locationError {
                return "📍 \(error)"
            }

            // Use address if available, otherwise fall back to coordinates
            if let address = currentAddress, !address.isEmpty {
                return "📍 \(address)"
            } else if let location = currentLocation {
                let latitude = String(format: "%.6f", location.coordinate.latitude)
                let longitude = String(format: "%.6f", location.coordinate.longitude)
                return "📍 \(latitude), \(longitude)"
            } else {
                return "📍 Getting location..."
            }
        @unknown default:
            return "📍 Location status unknown"
        }
    }
}

extension PhotoCaptureManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            currentLocation = location

            // Clear any previous location errors since we got a location
            if locationError?.contains("Getting location") == true || locationError?.contains("unavailable") == true {
                locationError = nil
            }

            // Get address from coordinates with throttling and caching
            performThrottledReverseGeocoding(for: location)
        }
    }

    // MARK: - Throttled Reverse Geocoding

    private func performThrottledReverseGeocoding(for location: CLLocation) {
        let now = Date()

        // Check if we should skip based on time throttling
        guard now.timeIntervalSince(lastGeocodingTime) >= geocodingInterval else {
            // Use cached address if available
            if let cached = cachedAddress {
                currentAddress = cached
            }
            return
        }

        // Check if we should skip based on location change threshold
        if let lastLocation = lastGeocodedLocation,
           location.distance(from: lastLocation) < locationChangeThreshold {
            // Use cached address if available
            if let cached = cachedAddress {
                currentAddress = cached
            }
            return
        }

        // Cancel any pending geocoding requests to avoid queue buildup
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }

        // Perform the geocoding request
        lastGeocodingTime = now
        lastGeocodedLocation = location

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    // Don't update lastGeocodingTime on error to allow retry sooner
                    self.lastGeocodingTime = .distantPast
                    return
                }

                if let placemark = placemarks?.first {
                    var addressComponents: [String] = []

                    if let streetNumber = placemark.subThoroughfare {
                        addressComponents.append(streetNumber)
                    }
                    if let streetName = placemark.thoroughfare {
                        addressComponents.append(streetName)
                    }
                    if let city = placemark.locality {
                        addressComponents.append(city)
                    }
                    if let state = placemark.administrativeArea {
                        addressComponents.append(state)
                    }

                    let address = addressComponents.joined(separator: " ")
                    self.currentAddress = address
                    self.cachedAddress = address
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = "Location error: \(error.localizedDescription)"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            cachedAuthorizationStatus = status
            // Update location services status in background thread to avoid UI blocking
            Task.detached {
                let servicesEnabled = CLLocationManager.locationServicesEnabled()
                await MainActor.run {
                    self.cachedLocationServicesEnabled = servicesEnabled
                }
            }

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                isLocationAuthorized = true
                locationError = nil
                // Don't start continuous updates - only request when needed
            case .denied, .restricted:
                isLocationAuthorized = false
                locationError = "Location access denied. Go to Settings > Privacy & Security > Location Services to enable location access for this app."
            case .notDetermined:
                // Wait for user response
                break
            @unknown default:
                isLocationAuthorized = false
                locationError = "Location access status unknown."
            }
        }
    }
}
#else
@MainActor
class PhotoCaptureManager: ObservableObject {
    @Published var capturedImages: [CapturedPhoto] = []
    // Stub methods for non-iOS platforms
    func capturePhoto(for jobId: String? = nil, quoteDraftId: UUID? = nil) {}
}

struct CapturedPhoto: Identifiable { // non-iOS stub
    let id = UUID()
    let timestamp = Date()
    let location: String? = nil
}
#endif
