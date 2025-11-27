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
import ImageIO
import UniformTypeIdentifiers

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

    // EXIF-based geocoding cache (persistent)
    private let geocodingCacheKey = "com.dtsapp.geocodingCache"
    private let geocodingCacheRadius: CLLocationDistance = 10.0 // 10m precision for exact property matching

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
        locationManager.stopUpdatingLocation()
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
        locationManager.distanceFilter = 50 // Update every 50 meters
        // Start location updates when authorized
        if cachedAuthorizationStatus == .authorizedWhenInUse || cachedAuthorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
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

            print("Starting location updates...")
            // Start continuous location updates for more reliable location data
            locationManager.startUpdatingLocation()
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

    func processImage(
        _ image: UIImage,
        jobId: String? = nil,
        quoteDraftId: UUID? = nil,
        exifTimestamp: Date? = nil,
        exifCoordinate: CLLocationCoordinate2D? = nil,
        preGeocodedAddress: String? = nil
    ) {
        // First compress the image to reduce memory usage
        let compressedImage = compressImage(image)

        autoreleasepool {
            let watermarkedImage = addWatermark(
                to: compressedImage,
                timestamp: exifTimestamp,
                coordinate: exifCoordinate,
                address: preGeocodedAddress
            )

            // Save to Photos app disabled to avoid duplicates
            // Photos are already in the app and can be exported if needed
            // if isPhotosAuthorized {
            //     saveToPhotosApp(watermarkedImage)
            // }

            // Save to shared container (persists across app installations)
            guard let imageData = watermarkedImage.jpegData(compressionQuality: 0.7) else {
                return
            }

            let storageDirectory = SharedContainerHelper.photosStorageDirectory
            let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
            let fileURL = storageDirectory.appendingPathComponent(fileName)

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
                    location: locationString,
                    address: preGeocodedAddress,
                    quoteDraftId: quoteDraftId,
                    jobId: jobId
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

    private func addWatermark(
        to image: UIImage,
        timestamp: Date? = nil,
        coordinate: CLLocationCoordinate2D? = nil,
        address: String? = nil
    ) -> UIImage {
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

                // Use provided timestamp or current time
                let timestampText = dateFormatter.string(from: timestamp ?? Date())

                // Use provided address, or generate location text
                let locationText: String
                if let address = address, !address.isEmpty {
                    locationText = "📍 \(address)"
                } else if let coordinate = coordinate {
                    // Use EXIF coordinates if provided
                    let latitude = String(format: "%.6f", coordinate.latitude)
                    let longitude = String(format: "%.6f", coordinate.longitude)
                    locationText = "📍 \(latitude), \(longitude)"
                } else {
                    // Fall back to current location
                    locationText = formatLocationText()
                }

                // Simple watermark with just timestamp and location
                let watermarkText = "\(timestampText)\n\(locationText)"

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

            if let error = locationError, !error.contains("Getting location") {
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

    // MARK: - EXIF Metadata Extraction

    /// Extract GPS coordinates and timestamp from photo EXIF data
    nonisolated static func extractEXIFMetadata(from imageData: Data) -> (coordinate: CLLocationCoordinate2D?, timestamp: Date?) {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("❌ Failed to read image properties")
            return (nil, nil)
        }

        var coordinate: CLLocationCoordinate2D?
        var timestamp: Date?

        // Extract GPS coordinates
        if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String
            let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String

            if let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
               let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {

                // Convert to signed coordinates based on hemisphere
                let signedLatitude = (latitudeRef == "S") ? -latitude : latitude
                let signedLongitude = (longitudeRef == "W") ? -longitude : longitude

                coordinate = CLLocationCoordinate2D(latitude: signedLatitude, longitude: signedLongitude)
                print("✅ Extracted EXIF GPS: \(signedLatitude), \(signedLongitude)")
            }
        }

        // Extract timestamp from EXIF
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {

            // EXIF date format: "yyyy:MM:dd HH:mm:ss"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone.current

            if let parsedDate = dateFormatter.date(from: dateTimeOriginal) {
                timestamp = parsedDate
                print("✅ Extracted EXIF timestamp: \(parsedDate)")
            }
        }

        // If no EXIF timestamp, try TIFF timestamp
        if timestamp == nil, let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateTime = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String {

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone.current

            if let parsedDate = dateFormatter.date(from: dateTime) {
                timestamp = parsedDate
                print("✅ Extracted TIFF timestamp: \(parsedDate)")
            }
        }

        return (coordinate, timestamp)
    }

    // MARK: - Persistent Geocoding Cache

    /// Save geocoded address to persistent cache
    private func saveToDiskCache(coordinate: CLLocationCoordinate2D, address: String) {
        let key = cacheKey(for: coordinate)
        let cacheEntry: [String: Any] = [
            "address": address,
            "timestamp": Date(),
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]

        var cache = UserDefaults.standard.dictionary(forKey: geocodingCacheKey) ?? [:]
        cache[key] = cacheEntry
        UserDefaults.standard.set(cache, forKey: geocodingCacheKey)

        print("💾 Saved to geocoding cache: \(address) at \(coordinate.latitude), \(coordinate.longitude)")
    }

    /// Load address from cache if within radius
    private func loadFromDiskCache(coordinate: CLLocationCoordinate2D, maxRadius: CLLocationDistance = 30.0) -> String? {
        guard let cache = UserDefaults.standard.dictionary(forKey: geocodingCacheKey) else {
            return nil
        }

        let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Find closest cached location within radius
        var closestMatch: (address: String, distance: CLLocationDistance)?

        for (_, value) in cache {
            guard let entry = value as? [String: Any],
                  let cachedLat = entry["latitude"] as? Double,
                  let cachedLon = entry["longitude"] as? Double,
                  let address = entry["address"] as? String else {
                continue
            }

            let cachedLocation = CLLocation(latitude: cachedLat, longitude: cachedLon)
            let distance = searchLocation.distance(from: cachedLocation)

            if distance <= maxRadius {
                if closestMatch == nil || distance < closestMatch!.distance {
                    closestMatch = (address, distance)
                }
            }
        }

        if let match = closestMatch {
            print("🎯 Cache hit: \(match.address) (distance: \(Int(match.distance))m)")
            return match.address
        }

        print("❌ Cache miss for coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        return nil
    }

    /// Generate cache key for coordinate (rounded to 5 decimal places ~1m precision)
    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.5f", coordinate.latitude)
        let lon = String(format: "%.5f", coordinate.longitude)
        return "geocache_\(lat)_\(lon)"
    }

    // MARK: - Batch Location Selection Logic

    /// Select best location for batch of photos based on priority rules
    /// Returns: (address: String?, coordinateToGeocode: CLLocationCoordinate2D?)
    private func selectBestLocationForBatch(
        photos: [(image: UIImage, coordinate: CLLocationCoordinate2D?, timestamp: Date?)],
        currentLocation: CLLocation?,
        jobAddress: String?
    ) -> (address: String?, coordinateToGeocode: CLLocationCoordinate2D?) {

        // Priority 1: Use job address if available and not empty
        if let jobAddress = jobAddress, !jobAddress.isEmpty {
            print("✅ Using job address: \(jobAddress)")
            return (jobAddress, nil)
        }

        // Extract valid coordinates from photos
        let coordinates = photos.compactMap { $0.coordinate }

        guard !coordinates.isEmpty else {
            print("⚠️ No EXIF coordinates found, will use current location")
            return (nil, nil)
        }

        // Priority 2: For 2 photos with different EXIF locations, choose one >500m from current location
        if coordinates.count == 2, let current = currentLocation {
            let loc1 = CLLocation(latitude: coordinates[0].latitude, longitude: coordinates[0].longitude)
            let loc2 = CLLocation(latitude: coordinates[1].latitude, longitude: coordinates[1].longitude)

            let dist1 = current.distance(from: loc1)
            let dist2 = current.distance(from: loc2)

            // If both are far from current location, use the one taken first (or cluster center)
            if dist1 > 500 && dist2 > 500 {
                print("✅ Both photos >500m from current location, using first EXIF coordinate")
                return (nil, coordinates[0])
            }

            // Choose the one farther from current location
            let chosenCoordinate = dist1 > dist2 ? coordinates[0] : coordinates[1]
            print("✅ Selected EXIF coordinate \(Int(max(dist1, dist2)))m from current location")
            return (nil, chosenCoordinate)
        }

        // Priority 3: For 3+ photos, cluster by 100m radius and use largest cluster
        if coordinates.count >= 3 {
            let clusters = clusterCoordinates(coordinates, threshold: 100.0)

            // Find largest cluster
            if let largestCluster = clusters.max(by: { $0.count < $1.count }) {
                let centroid = calculateCentroid(largestCluster)
                print("✅ Using centroid of largest cluster (\(largestCluster.count) photos)")
                return (nil, centroid)
            }
        }

        // Priority 4: Single photo or fallback - use first EXIF coordinate
        if let firstCoordinate = coordinates.first {
            print("✅ Using EXIF coordinate from photo")
            return (nil, firstCoordinate)
        }

        print("⚠️ No valid location found, will use current location")
        return (nil, nil)
    }

    /// Cluster coordinates within threshold distance
    private func clusterCoordinates(_ coordinates: [CLLocationCoordinate2D], threshold: CLLocationDistance) -> [[CLLocationCoordinate2D]] {
        var clusters: [[CLLocationCoordinate2D]] = []
        var remaining = coordinates

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var cluster = [seed]

            let seedLocation = CLLocation(latitude: seed.latitude, longitude: seed.longitude)

            remaining.removeAll { coordinate in
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = seedLocation.distance(from: location)

                if distance <= threshold {
                    cluster.append(coordinate)
                    return true
                }
                return false
            }

            clusters.append(cluster)
        }

        return clusters
    }

    /// Calculate centroid (average) of coordinates
    private func calculateCentroid(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let avgLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
        let avgLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }

    // MARK: - Batch Image Processing

    /// Process multiple images with EXIF metadata extraction and smart location selection
    func processBatchImages(
        _ photosWithMetadata: [(image: UIImage, coordinate: CLLocationCoordinate2D?, timestamp: Date?)],
        quoteDraftId: UUID? = nil,
        jobId: String? = nil,
        jobAddress: String? = nil
    ) async {
        print("📸 Processing batch of \(photosWithMetadata.count) photos...")

        // Select best location using priority rules
        let (preGeocodedAddress, coordinateToGeocode) = selectBestLocationForBatch(
            photos: photosWithMetadata,
            currentLocation: currentLocation,
            jobAddress: jobAddress
        )

        var finalAddress: String? = preGeocodedAddress

        // If we have a coordinate to geocode and no pre-geocoded address
        if let coordinate = coordinateToGeocode, finalAddress == nil {
            // Check cache first (30m radius for exact property matching)
            if let cachedAddress = loadFromDiskCache(coordinate: coordinate, maxRadius: geocodingCacheRadius) {
                finalAddress = cachedAddress
                print("✅ Using cached address: \(cachedAddress)")
            } else {
                // Perform geocoding with timeout
                print("🌐 Geocoding coordinate: \(coordinate.latitude), \(coordinate.longitude)")

                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                do {
                    let address = try await withTimeout(seconds: 5.0) {
                        try await self.reverseGeocode(location: location)
                    }

                    finalAddress = address
                    saveToDiskCache(coordinate: coordinate, address: address)
                    print("✅ Geocoded address: \(address)")

                } catch {
                    print("⚠️ Geocoding failed or timed out: \(error.localizedDescription)")
                    // Will fall back to coordinates in watermark
                }
            }
        }

        // Process all photos with the determined address
        await MainActor.run {
            for (index, photo) in photosWithMetadata.enumerated() {
                print("📸 Processing photo \(index + 1)/\(photosWithMetadata.count)")
                processImage(
                    photo.image,
                    jobId: jobId,
                    quoteDraftId: quoteDraftId,
                    exifTimestamp: photo.timestamp,
                    exifCoordinate: photo.coordinate,
                    preGeocodedAddress: finalAddress
                )
            }
        }

        print("✅ Batch processing complete")
    }

    /// Reverse geocode a location with CLGeocoder
    private func reverseGeocode(location: CLLocation) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
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
                    continuation.resume(returning: address)
                } else {
                    continuation.resume(throwing: NSError(domain: "Geocoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No address found"]))
                }
            }
        }
    }

    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
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
                // Start continuous location updates for immediate location availability
                locationManager.startUpdatingLocation()
            case .denied, .restricted:
                isLocationAuthorized = false
                locationError = "Location access denied. Go to Settings > Privacy & Security > Location Services to enable location access for this app."
                locationManager.stopUpdatingLocation()
            case .notDetermined:
                // Wait for user response
                break
            @unknown default:
                isLocationAuthorized = false
                locationError = "Location access status unknown."
                locationManager.stopUpdatingLocation()
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
