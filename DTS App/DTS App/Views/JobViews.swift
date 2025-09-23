//
//  JobViews.swift
//  DTS App
//
//  Job-related views for Jobber integration
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct JobRowView: View {
    let job: JobberJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Add service information if available
                    if let serviceTitle = job.serviceTitle, !serviceTitle.isEmpty {
                        Text(serviceTitle)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }

                    Button(action: {
                        let addressForURL = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let mapURL = URL(string: "http://maps.apple.com/?q=\(addressForURL)")
                        if let mapURL = mapURL, UIApplication.shared.canOpenURL(mapURL) {
                            UIApplication.shared.open(mapURL)
                        }
                    }) {
                        Text(job.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let clientPhone = job.clientPhone, !clientPhone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(clientPhone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                JobInfoSection(job: job)
                ServiceInfoSection(job: job)
                PhotosSection(photoCaptureManager: photoCaptureManager, showingPhotoGallery: $showingPhotoGallery)
                ActionButtonsSection(job: job, photoCaptureManager: photoCaptureManager)
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Job Details")
        .fullScreenCover(isPresented: $photoCaptureManager.showingCamera) {
            CameraView(
                isPresented: $photoCaptureManager.showingCamera,
                captureCount: $photoCaptureManager.captureCount
            ) { image in
                photoCaptureManager.processImage(image, jobId: job.jobId, quoteDraftId: nil as UUID?)
            }
        }
        .sheet(isPresented: $photoCaptureManager.showingPhotoLibrary) {
            PhotoLibraryPicker(isPresented: $photoCaptureManager.showingPhotoLibrary) { image in
                photoCaptureManager.processImage(image, jobId: job.jobId, quoteDraftId: nil as UUID?)
            }
        }
        .sheet(isPresented: $showingPhotoGallery) {
            NavigationView {
                PhotoGalleryView(photos: photoCaptureManager.capturedImages)
                    .navigationTitle("Photos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingPhotoGallery = false }
                        }
                    }
            }
        }
    }
}

// Custom button view that's more responsive
struct ResponsiveButton: View {
    let title: String
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    let isDisabled: Bool

    init(title: String, action: @escaping () -> Void, backgroundColor: Color = .blue, foregroundColor: Color = .white, isDisabled: Bool = false) {
        self.title = title
        self.action = action
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.isDisabled = isDisabled
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(isDisabled ? .secondary : foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray.opacity(0.3) : backgroundColor.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                if !isDisabled {
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    action()
                }
            }
            .scaleEffect(isDisabled ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDisabled)
    }
}

struct NewLaborItemView: View {
    @Binding var title: String
    @Binding var amount: Double
    let commonLaborItems: [CommonLaborItem]
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSelectItem: (CommonLaborItem) -> Void

    // Helper to bind the amount text field
    private func amountBinding() -> Binding<String> {
        Binding<String>(
            get: {
                if amount == 0 {
                    return ""
                } else {
                    // Format to 2 decimal places, but remove them if they are .00
                    return String(format: "%.2f", amount).replacingOccurrences(of: ".00", with: "")
                }
            },
            set: {
                if let value = Double($0) {
                    amount = value
                } else if $0.isEmpty {
                    amount = 0
                }
            }
        )
    }

    var body: some View {
        // Using a GroupBox to give it a distinct, contained look
        GroupBox("New Labor Item") {
            VStack(spacing: 16) {
                TextField("Item Description (e.g., Fascia Repair)", text: $title)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("$0.00", text: amountBinding())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                }

                // Quick-add common items with more responsive buttons
                if !commonLaborItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Items")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                            ForEach(commonLaborItems) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.leading)
                                    Text(item.amount.toCurrency())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onTapGesture {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    onSelectItem(item)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                    )

                    Button(action: onSave) {
                        Text("Add Item")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty || amount <= 0 ? Color.gray.opacity(0.3) : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(title.isEmpty || amount <= 0)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                if !(title.isEmpty || amount <= 0) {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            }
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // This ensures the new view appears over the form, avoiding gesture conflicts
        .background(Color(.systemBackground))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct PreviewSection: View {
    @ObservedObject var quoteDraft: QuoteDraft
    let breakdown: PricingEngine.PriceBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quote Preview")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.bottom, 8)

            // Measurements summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Measurements")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Gutter:")
                    Spacer()
                    Text("\(quoteDraft.gutterFeet.twoDecimalFormatted) ft")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Downspout:")
                    Spacer()
                    Text("\(quoteDraft.downspoutFeet.twoDecimalFormatted) ft \(quoteDraft.isRoundDownspout ? "(Round)" : "(Standard)")")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("A Elbows:")
                    Spacer()
                    Text("\(quoteDraft.aElbows)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("B Elbows:")
                    Spacer()
                    Text("\(quoteDraft.bElbows)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("2\" Crimp:")
                    Spacer()
                    Text("\(quoteDraft.twoCrimp)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("4\" Crimp:")
                    Spacer()
                    Text("\(quoteDraft.fourCrimp)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Color:")
                    Spacer()
                    Text(quoteDraft.gutterColor)
                        .fontWeight(.medium)
                }

                if quoteDraft.includeGutterGuard {
                    HStack {
                        Text("Gutter Guard:")
                        Spacer()
                        Text("\(quoteDraft.gutterGuardFeet.twoDecimalFormatted) ft")
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("Total Composite Feet:")
                    Spacer()
                    Text("\(breakdown.compositeFeet.twoDecimalFormatted) ft")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }

            Divider()

            // Price per foot information
            VStack(alignment: .leading, spacing: 4) {
                Text("Price Analysis")
                    .font(.headline)
                    .foregroundColor(.secondary)

                if quoteDraft.includeGutterGuard && quoteDraft.gutterGuardFeet > 0 {
                    // Show separate price per foot for gutters and gutter guard
                    let gutterFeet = quoteDraft.gutterFeet + quoteDraft.downspoutFeet
                    let guardFeet = quoteDraft.gutterGuardFeet

                    // Material costs (already available in breakdown)
                    let gutterMaterialsCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost
                    let guardMaterialsCost = breakdown.gutterGuardCost

                    // Estimate labor costs based on standard rates
                    // Note: breakdown.laborCost includes both gutter and guard labor
                    // We'll estimate the proportions based on typical rates
                    let gutterLaborCost = breakdown.compositeFeet * 2.25 // typical gutter labor rate
                    let guardLaborCost = guardFeet * 2.25 // typical guard labor rate
                    let totalEstimatedLabor = gutterLaborCost + guardLaborCost

                    // Use the actual total labor cost from breakdown and distribute proportionally
                    let actualGutterLabor = totalEstimatedLabor > 0 ? breakdown.laborCost * (gutterLaborCost / totalEstimatedLabor) : 0
                    let actualGuardLabor = breakdown.laborCost - actualGutterLabor

                    // Calculate base costs (materials + labor) for each component
                    let gutterBaseCost = gutterMaterialsCost + actualGutterLabor
                    let guardBaseCost = guardMaterialsCost + actualGuardLabor
                    let totalBaseCost = gutterBaseCost + guardBaseCost

                    // Calculate proportional share of additional items (excluding additional labor items)
                    let additionalCosts = breakdown.markupAmount + breakdown.commissionAmount + breakdown.taxAmount
                    let gutterProportion = totalBaseCost > 0 ? gutterBaseCost / totalBaseCost : 0.5
                    let guardProportion = 1.0 - gutterProportion

                    let gutterTotalCost = gutterBaseCost + (additionalCosts * gutterProportion)
                    let guardTotalCost = guardBaseCost + (additionalCosts * guardProportion)

                    let gutterPricePerFoot = gutterFeet > 0 ? gutterTotalCost / gutterFeet : 0
                    let guardPricePerFoot = guardFeet > 0 ? guardTotalCost / guardFeet : 0

                    HStack {
                        Text("Gutters Price/ft:")
                        Spacer()
                        Text(gutterPricePerFoot.toCurrency() + "/ft")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .font(.title3)
                    }

                    HStack {
                        Text("Guard Price/ft:")
                        Spacer()
                        Text(guardPricePerFoot.toCurrency() + "/ft")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .font(.title3)
                    }

                    Text("Based on \(gutterFeet.twoDecimalFormatted) ft gutters and \(guardFeet.twoDecimalFormatted) ft guard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                } else {
                    // Show single price per foot (original behavior)
                    HStack {
                        Text("Price per Foot:")
                        Spacer()
                        Text(breakdown.pricePerFoot.toCurrency() + "/ft")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .font(.title3)
                    }

                    Text("Based on \(breakdown.compositeFeet.twoDecimalFormatted) composite feet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }

            Divider()

            // Pricing summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Pricing")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Materials:")
                    Spacer()
                    Text(breakdown.materialsTotal.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Labor:")
                    Spacer()
                    Text(breakdown.laborTotal.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Markup:")
                    Spacer()
                    Text(breakdown.markupAmount.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Commission:")
                    Spacer()
                    Text(breakdown.commissionAmount.toCurrency())
                        .fontWeight(.medium)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Total:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(breakdown.finalTotal.toCurrency())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - StatusBadge View

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
            .cornerRadius(6)
    }
}

// MARK: - JobDetailView Sub-Components

struct JobInfoSection: View {
    let job: JobberJob

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Job Details")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Label(job.clientName, systemImage: "person.fill")

                if let clientPhone = job.clientPhone, !clientPhone.isEmpty {
                    Button(action: {
                        let phoneURL = URL(string: "tel:\(clientPhone)")
                        if let phoneURL = phoneURL, UIApplication.shared.canOpenURL(phoneURL) {
                            UIApplication.shared.open(phoneURL)
                        }
                    }) {
                        Label(clientPhone, systemImage: "phone.fill")
                            .foregroundColor(.blue)
                    }
                }

                Button(action: {
                    let addressForURL = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let mapURL = URL(string: "http://maps.apple.com/?q=\(addressForURL)")
                    if let mapURL = mapURL, UIApplication.shared.canOpenURL(mapURL) {
                        UIApplication.shared.open(mapURL)
                    }
                }) {
                    Label(job.address, systemImage: "location.fill")
                        .foregroundColor(.blue)
                }

                // Add Jobber link - using computed URL with ID extraction
                Button(action: {
                    print("🔗 Attempting to open Jobber")
                    print("🔗 Raw Client ID: '\(job.clientId)'")
                    print("🔗 Raw Request ID: '\(job.requestId ?? "none")'")

                    // Try to decode the IDs to show the extracted numeric values
                    if let requestId = job.requestId,
                       let data = Data(base64Encoded: requestId),
                       let decoded = String(data: data, encoding: .utf8) {
                        print("🔗 Decoded Request ID: '\(decoded)'")
                    }

                    if let data = Data(base64Encoded: job.clientId),
                       let decoded = String(data: data, encoding: .utf8) {
                        print("🔗 Decoded Client ID: '\(decoded)'")
                    }

                    guard let jobberURL = job.assessmentURL else {
                        print("❌ No valid Jobber URL available")
                        return
                    }

                    print("✅ Opening Jobber URL: \(jobberURL)")

                    if let url = URL(string: jobberURL) {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    } else {
                        print("❌ Failed to create URL from string: \(jobberURL)")
                    }
                }) {
                    Label("View in Jobber", systemImage: "link")
                        .foregroundColor(.blue)
                }

                // Debug info for development
                if job.requestId != nil {
                    Text("Request ID: \(job.requestId!)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text("Client ID: \(job.clientId)")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Label(job.scheduledAt.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                Label(job.status.capitalized, systemImage: "info.circle")
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ServiceInfoSection: View {
    let job: JobberJob

    var body: some View {
        if let serviceTitle = job.serviceTitle, !serviceTitle.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Job Instructions")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Label(serviceTitle, systemImage: "wrench.and.screwdriver.fill")
                        .font(.body)
                        .foregroundColor(.primary)

                    if let instructions = job.instructions, !instructions.isEmpty {
                        Text("Instructions:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text(instructions)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        // Add service information under instructions
                        if let serviceSpecifications = job.serviceSpecifications, !serviceSpecifications.isEmpty {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)

                            Text(serviceSpecifications)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 2)
                        } else if let serviceInformation = job.serviceInformation, !serviceInformation.isEmpty {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)

                            Text(serviceInformation)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 2)
                        }
                    } else {
                        // If no instructions, still show service information
                        if let serviceSpecifications = job.serviceSpecifications, !serviceSpecifications.isEmpty {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            Text(serviceSpecifications)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        } else if let serviceInformation = job.serviceInformation, !serviceInformation.isEmpty {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            Text(serviceInformation)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PhotosSection: View {
    @ObservedObject var photoCaptureManager: PhotoCaptureManager
    @Binding var showingPhotoGallery: Bool

    var body: some View {
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
                        ForEach(Array(photoCaptureManager.capturedImages.prefix(5))) { photo in
                            // Simple image view to avoid type checking complexity
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActionButtonsSection: View {
    let job: JobberJob
    @ObservedObject var photoCaptureManager: PhotoCaptureManager

    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: QuoteFormView(job: job)) {
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

            CameraButton(photoCaptureManager: photoCaptureManager, jobId: job.jobId)
            LocationStatusView(photoCaptureManager: photoCaptureManager)
        }
    }
}

struct CameraButton: View {
    @ObservedObject var photoCaptureManager: PhotoCaptureManager
    let jobId: String

    var body: some View {
        Button(action: {
            photoCaptureManager.capturePhoto(for: jobId)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture Photo")
                        .font(.headline)
                    Text("Tap to take a photo with location")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.6)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct LocationStatusView: View {
    @ObservedObject var photoCaptureManager: PhotoCaptureManager

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: photoCaptureManager.isLocationAuthorized ? "location.fill" : "location.slash")
                    .foregroundColor(photoCaptureManager.isLocationAuthorized ? .green : .orange)
                Text(photoCaptureManager.formatLocationStatus())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            if let locationError = photoCaptureManager.locationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(locationError)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
