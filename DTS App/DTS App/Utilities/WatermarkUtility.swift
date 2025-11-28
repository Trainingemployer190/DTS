//
//  WatermarkUtility.swift
//  DTS App
//
//  Utility for regenerating photo watermarks with updated information
//

import Foundation
import CoreLocation

#if canImport(UIKit)
import UIKit
struct WatermarkUtility {
    
    /// Regenerate watermark on existing photo with new address
    /// - Parameters:
    ///   - photo: The PhotoRecord to update
    ///   - newAddress: New address to display in watermark
    ///   - preserveTimestamp: If true, uses original timestamp; if false, uses current time
    /// - Returns: URL of the new watermarked image file
    static func regenerateWatermark(
        photo: PhotoRecord,
        newAddress: String,
        preserveTimestamp: Bool = true
    ) -> URL? {
        // Load original image
        guard let originalImage = loadImage(from: photo.fileURL) else {
            print("❌ Failed to load image from: \(photo.fileURL)")
            return nil
        }
        
        // Determine timestamp to use
        let timestamp = preserveTimestamp ? (photo.originalTimestamp ?? Date()) : Date()
        
        // Get coordinate for watermark
        let coordinate: CLLocationCoordinate2D? = {
            if let lat = photo.latitude, let lon = photo.longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()
        
        // Generate new watermark
        let watermarkedImage = addWatermark(
            to: originalImage,
            timestamp: timestamp,
            coordinate: coordinate,
            address: newAddress
        )
        
        // Save to new file
        guard let imageData = watermarkedImage.jpegData(compressionQuality: 0.9) else {
            print("❌ Failed to generate image data")
            return nil
        }
        
        let storageDirectory = SharedContainerHelper.photosStorageDirectory
        let fileName = "photo_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = storageDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            
            // Delete old file
            let oldURL = URL(fileURLWithPath: photo.fileURL)
            try? FileManager.default.removeItem(at: oldURL)
            
            print("✅ Regenerated watermark: \(fileName)")
            return fileURL
        } catch {
            print("❌ Failed to save watermarked image: \(error)")
            return nil
        }
    }
    
    /// Load image from file path
    private static func loadImage(from path: String) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    /// Add watermark to image
    private static func addWatermark(
        to image: UIImage,
        timestamp: Date,
        coordinate: CLLocationCoordinate2D?,
        address: String?
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            // Draw original image
            image.draw(in: CGRect(origin: .zero, size: image.size))

            // Prepare watermark text
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
            let timestampText = dateFormatter.string(from: timestamp)

            // Location text
            let locationText: String
            if let address = address, !address.isEmpty {
                locationText = "📍 \(address)"
            } else if let coordinate = coordinate {
                let latitude = String(format: "%.6f", coordinate.latitude)
                let longitude = String(format: "%.6f", coordinate.longitude)
                locationText = "📍 \(latitude), \(longitude)"
            } else {
                locationText = "📍 Location not available"
            }

            let watermarkText = "\(timestampText)\n\(locationText)"

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

            // Position watermark in bottom-left corner
            let textRect = CGRect(
                x: 20,
                y: image.size.height - textSize.height - 20,
                width: textSize.width,
                height: textSize.height
            )

            // Draw semi-transparent background
            let backgroundRect = textRect.insetBy(dx: -10, dy: -8)
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            let roundedPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 6)
            context.cgContext.addPath(roundedPath.cgPath)
            context.cgContext.fillPath()

            // Draw text
            attributedString.draw(in: textRect)
        }
    }
}
#endif
