//
//  ImagePicker.swift
//  DTS App
//
//  Created by System on 10/4/25.
//

import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
import PhotosUI

// Single image picker (for camera)
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Multiple image picker (for photo library)
struct MultiImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onImagesPicked: ([(image: UIImage, coordinate: CLLocationCoordinate2D?, timestamp: Date?)]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0 // 0 means unlimited
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard !results.isEmpty else { return }

            var photosWithMetadata: [(image: UIImage, coordinate: CLLocationCoordinate2D?, timestamp: Date?)] = []
            let group = DispatchGroup()

            for result in results {
                group.enter()

                // Use loadFileRepresentation to preserve EXIF data
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    defer { group.leave() }

                    guard let url = url, error == nil else {
                        print("❌ Failed to load file representation: \(error?.localizedDescription ?? "unknown error")")
                        return
                    }

                    do {
                        // Read image data
                        let imageData = try Data(contentsOf: url)

                        // Create UIImage
                        guard let image = UIImage(data: imageData) else {
                            print("❌ Failed to create UIImage from data")
                            return
                        }

                        // Extract EXIF metadata
                        let metadata = PhotoCaptureManager.extractEXIFMetadata(from: imageData)

                        // Add to results
                        DispatchQueue.main.async {
                            photosWithMetadata.append((
                                image: image,
                                coordinate: metadata.coordinate,
                                timestamp: metadata.timestamp
                            ))
                        }

                    } catch {
                        print("❌ Error processing image: \(error.localizedDescription)")
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.onImagesPicked(photosWithMetadata)
            }
        }
    }
}
#endif
