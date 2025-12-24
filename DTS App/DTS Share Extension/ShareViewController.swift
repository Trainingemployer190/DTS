//
//  ShareViewController.swift
//  DTS Share Extension
//
//  Created by Chandler Staton on 12/21/25.
//
//  Purpose: Handle shared PDFs from other apps and pass them to the main DTS App
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupIdentifier = "group.DTS.DTS-App"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }
    
    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeWithError("No content to import")
            return
        }
        
        // Look for PDF attachments
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] item, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.completeWithError("Failed to load PDF: \(error.localizedDescription)")
                            return
                        }
                        
                        if let url = item as? URL {
                            self?.savePDFToAppGroup(from: url)
                        } else if let data = item as? Data {
                            self?.savePDFDataToAppGroup(data)
                        } else {
                            self?.completeWithError("Unsupported PDF format")
                        }
                    }
                }
                return  // Only handle first PDF
            }
        }
        
        completeWithError("No PDF file found")
    }
    
    private func savePDFToAppGroup(from sourceURL: URL) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            completeWithError("Cannot access app group container")
            return
        }
        
        // Create roof PDFs directory
        let roofPDFsDir = containerURL.appendingPathComponent("RoofPDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: roofPDFsDir, withIntermediateDirectories: true)
        
        // Generate unique filename
        let uuid = UUID().uuidString
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let filename = "\(uuid)_\(originalName).pdf"
        let destinationURL = roofPDFsDir.appendingPathComponent(filename)
        
        do {
            // Copy PDF to shared container
            if sourceURL.startAccessingSecurityScopedResource() {
                defer { sourceURL.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
            
            // Open main app with deep link
            openMainApp(withPDFId: uuid)
            
        } catch {
            completeWithError("Failed to save PDF: \(error.localizedDescription)")
        }
    }
    
    private func savePDFDataToAppGroup(_ data: Data) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            completeWithError("Cannot access app group container")
            return
        }
        
        // Create roof PDFs directory
        let roofPDFsDir = containerURL.appendingPathComponent("RoofPDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: roofPDFsDir, withIntermediateDirectories: true)
        
        // Generate unique filename
        let uuid = UUID().uuidString
        let filename = "\(uuid)_shared.pdf"
        let destinationURL = roofPDFsDir.appendingPathComponent(filename)
        
        do {
            try data.write(to: destinationURL)
            openMainApp(withPDFId: uuid)
        } catch {
            completeWithError("Failed to save PDF: \(error.localizedDescription)")
        }
    }
    
    private func openMainApp(withPDFId id: String) {
        // Use custom URL scheme to open main app
        let urlString = "dts-app://import-iroof-pdf?id=\(id)"
        guard let url = URL(string: urlString) else {
            completeWithError("Invalid URL")
            return
        }
        
        // Open URL via responder chain (iOS 13+)
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    if success {
                        self?.completeSuccessfully()
                    } else {
                        self?.completeWithError("Could not open DTS App")
                    }
                }
                return
            }
            responder = responder?.next
        }
        
        // Fallback: complete and let user open app manually
        completeSuccessfully()
    }
    
    private func completeSuccessfully() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private func completeWithError(_ message: String) {
        let error = NSError(domain: "DTS.ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        extensionContext?.cancelRequest(withError: error)
    }
}
