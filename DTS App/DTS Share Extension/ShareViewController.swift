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
    
    private var statusLabel: UILabel!
    private var activityIndicator: UIActivityIndicatorView!
    private var instructionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        handleSharedContent()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 16
        view.addSubview(containerView)
        
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Importing PDF..."
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        statusLabel.textColor = .label
        statusLabel.numberOfLines = 0
        containerView.addSubview(statusLabel)
        
        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 14)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.numberOfLines = 0
        instructionLabel.isHidden = true
        containerView.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            instructionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            instructionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            instructionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            showError("No content to import")
            return
        }

        // Look for PDF attachments
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] item, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.showError("Failed to load PDF: \(error.localizedDescription)")
                            return
                        }

                        if let url = item as? URL {
                            self?.savePDFToAppGroup(from: url)
                        } else if let data = item as? Data {
                            self?.savePDFDataToAppGroup(data)
                        } else {
                            self?.showError("Unsupported PDF format")
                        }
                    }
                }
                return  // Only handle first PDF
            }
        }

        showError("No PDF file found")
    }
    
    private func getStorageDirectory() -> URL? {
        // Try App Group container first
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            print("✅ Using App Group container: \(containerURL.path)")
            return containerURL.appendingPathComponent("RoofPDFs", isDirectory: true)
        }
        
        // Fallback: Use the extension's own documents directory (limited but works)
        // The main app won't be able to access this, so we'll need to guide the user
        print("⚠️ App Group not available, using fallback")
        return nil
    }

    private func savePDFToAppGroup(from sourceURL: URL) {
        guard let roofPDFsDir = getStorageDirectory() else {
            // App Group not configured - show instructions for manual import
            showManualImportInstructions(filename: sourceURL.lastPathComponent)
            return
        }
        
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

            // Set pending import flag in shared UserDefaults
            let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
            sharedDefaults?.set(uuid, forKey: "pendingRoofPDFImport")
            sharedDefaults?.synchronize()
            
            print("✅ PDF saved to: \(destinationURL.path)")
            print("✅ Set pending import flag: \(uuid)")
            
            showSuccess(filename: originalName)

        } catch {
            showError("Failed to save PDF: \(error.localizedDescription)")
        }
    }

    private func savePDFDataToAppGroup(_ data: Data) {
        guard let roofPDFsDir = getStorageDirectory() else {
            showManualImportInstructions(filename: "Shared PDF")
            return
        }

        try? FileManager.default.createDirectory(at: roofPDFsDir, withIntermediateDirectories: true)

        // Generate unique filename
        let uuid = UUID().uuidString
        let filename = "\(uuid)_shared.pdf"
        let destinationURL = roofPDFsDir.appendingPathComponent(filename)

        do {
            try data.write(to: destinationURL)
            
            // Set pending import flag in shared UserDefaults
            let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
            sharedDefaults?.set(uuid, forKey: "pendingRoofPDFImport")
            sharedDefaults?.synchronize()
            
            print("✅ PDF data saved to: \(destinationURL.path)")
            print("✅ Set pending import flag: \(uuid)")
            
            showSuccess(filename: "Shared PDF")
            
        } catch {
            showError("Failed to save PDF: \(error.localizedDescription)")
        }
    }
    
    private func showSuccess(filename: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = "✓ PDF Ready!"
        statusLabel.textColor = .systemGreen
        
        instructionLabel.text = "Opening DTS App..."
        instructionLabel.isHidden = false
        
        // Open the main app using URL scheme
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.openContainingApp()
        }
    }
    
    private func openContainingApp() {
        // Use the responder chain to find the application and open URL
        let url = URL(string: "dts-app://import-roof-pdf")!
        
        // Method 1: Try using the selector approach (works on some iOS versions)
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
        
        // Method 2: Use the private API via selector (more reliable for extensions)
        // This is the documented way for Action Extensions to open URLs
        let selector = NSSelectorFromString("openURL:")
        var responder2: UIResponder? = self
        while responder2 != nil {
            if responder2!.responds(to: selector) {
                responder2!.perform(selector, with: url)
                break
            }
            responder2 = responder2?.next
        }
        
        // Complete the extension after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showManualImportInstructions(filename: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = "⚠️ Setup Required"
        statusLabel.textColor = .systemOrange
        
        instructionLabel.text = "To use Share to DTS:\n\n1. Open DTS App\n2. Go to Roof Orders\n3. Tap + and select your PDF\n\nApp Group needs configuration in Xcode."
        instructionLabel.isHidden = false
        
        // Auto-close after a longer delay to allow reading
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = "❌ \(message)"
        statusLabel.textColor = .systemRed
        
        // Auto-close after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            let error = NSError(domain: "DTS.ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            self?.extensionContext?.cancelRequest(withError: error)
        }
    }
}
