//
//  JobViews.swift
//  DTS App
//
//  Job-related views for Jobber integration
//

import SwiftUI
import SwiftData

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
    @EnvironmentObject var jobberAPI: JobberAPI
    @State private var showingQuoteForm = false
    @Query private var allQuoteDrafts: [QuoteDraft]

    // Find existing quote for this job
    private var existingQuote: QuoteDraft? {
        allQuoteDrafts.first { $0.jobId == job.jobId && $0.quoteStatus != .completed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                JobInfoSection(job: job)
                ServiceInfoSection(job: job)

                // Create/Edit Quote button
                Button(action: {
                    showingQuoteForm = true
                }) {
                    HStack {
                        Image(systemName: existingQuote != nil ? "doc.text" : "doc.text.fill")
                        Text(existingQuote != nil ? "Edit Quote" : "Create Quote")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Job Details")
        .sheet(isPresented: $showingQuoteForm) {
            NavigationView {
                QuoteFormView(job: job, prefilledQuoteDraft: nil)
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
    let appSettings: AppSettings

    @EnvironmentObject var settings: SettingsStore

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
                    // Updated segmented approach for gutters and gutter guard price per foot
                    let totalElbows = quoteDraft.aElbows + quoteDraft.bElbows + quoteDraft.twoCrimp + quoteDraft.fourCrimp
                    let elbowUnitCost = quoteDraft.isRoundDownspout ? appSettings.costPerRoundElbow : appSettings.costPerElbow
                    let elbowsCost = Double(totalElbows) * elbowUnitCost
                    let hangersCost = Double(quoteDraft.hangersCount) * appSettings.costPerHanger

                    let gutterMaterialsCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost + elbowsCost + hangersCost
                    let guardMaterialsCost = breakdown.gutterGuardCost
                    let gutterLaborCost = breakdown.gutterLaborCost
                    let guardLaborCost = breakdown.gutterGuardLaborCost

                    let gutterBaseCost = gutterMaterialsCost + gutterLaborCost + breakdown.additionalItemsCost
                    let guardBaseCost = guardMaterialsCost + guardLaborCost

                    let gutterTotalBeforeAddOns = gutterBaseCost + breakdown.gutterMarkupAmount
                    let guardTotalBeforeAddOns  = guardBaseCost + breakdown.guardMarkupAmount

                    let additionalCosts = breakdown.commissionAmount + breakdown.taxAmount
                    let totalBeforeAddOns = gutterTotalBeforeAddOns + guardTotalBeforeAddOns
                    let gutterShare = totalBeforeAddOns > 0 ? gutterTotalBeforeAddOns / totalBeforeAddOns : 0.5
                    let guardShare  = 1.0 - gutterShare

                    let gutterTotalCost = gutterTotalBeforeAddOns + additionalCosts * gutterShare
                    let guardTotalCost  = guardTotalBeforeAddOns + additionalCosts * guardShare

                    let effectiveGutterFeet = quoteDraft.gutterFeet + quoteDraft.downspoutFeet + Double(totalElbows)

                    let gutterPricePerFoot = effectiveGutterFeet > 0 ? gutterTotalCost / effectiveGutterFeet : 0
                    let guardPricePerFoot = quoteDraft.gutterGuardFeet > 0 ? guardTotalCost / quoteDraft.gutterGuardFeet : 0

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

                    Text("Based on \(effectiveGutterFeet.twoDecimalFormatted)ft effective gutters and \(quoteDraft.gutterGuardFeet.twoDecimalFormatted)ft guard")
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

            // Component totals section (only when gutter guard is enabled)
            if quoteDraft.includeGutterGuard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Component Totals")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    // Updated segmented approach for component totals
                    let _ = quoteDraft.gutterFeet + quoteDraft.downspoutFeet // gutterFeet not used
                    let _ = quoteDraft.gutterGuardFeet // guardFeet not used

                    let totalElbows = quoteDraft.aElbows + quoteDraft.bElbows + quoteDraft.twoCrimp + quoteDraft.fourCrimp
                    let elbowUnitCost = quoteDraft.isRoundDownspout ? appSettings.costPerRoundElbow : appSettings.costPerElbow
                    let elbowsCost = Double(totalElbows) * elbowUnitCost
                    let hangersCost = Double(quoteDraft.hangersCount) * appSettings.costPerHanger

                    let gutterMaterialsCost = breakdown.gutterMaterialsCost + breakdown.downspoutMaterialsCost + elbowsCost + hangersCost
                    let guardMaterialsCost = breakdown.gutterGuardCost
                    let gutterLaborCost = breakdown.gutterLaborCost
                    let guardLaborCost = breakdown.gutterGuardLaborCost

                    let gutterBaseCost = gutterMaterialsCost + gutterLaborCost + breakdown.additionalItemsCost
                    let guardBaseCost = guardMaterialsCost + guardLaborCost

                    let gutterTotalBeforeAddOns = gutterBaseCost + breakdown.gutterMarkupAmount
                    let guardTotalBeforeAddOns  = guardBaseCost + breakdown.guardMarkupAmount

                    let additionalCosts = breakdown.commissionAmount + breakdown.taxAmount
                    let totalBeforeAddOns = gutterTotalBeforeAddOns + guardTotalBeforeAddOns
                    let gutterShare = totalBeforeAddOns > 0 ? gutterTotalBeforeAddOns / totalBeforeAddOns : 0.5
                    let guardShare  = 1.0 - gutterShare

                    let gutterTotalCost = gutterTotalBeforeAddOns + additionalCosts * gutterShare
                    let guardTotalCost  = guardTotalBeforeAddOns + additionalCosts * guardShare

                    HStack {
                        Text("Gutters Total:")
                        Spacer()
                        Text(gutterTotalCost.toCurrency())
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Guard Total:")
                        Spacer()
                        Text(guardTotalCost.toCurrency())
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    HStack {
                        Text("Combined Total:")
                        Spacer()
                        Text((gutterTotalCost + guardTotalCost).toCurrency())
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .font(.title3)
                    }

                    // Verification that Component Totals = Grand Total (Bug 1 Fix)
                    let combinedTotal = gutterTotalCost + guardTotalCost
                    let difference = abs(combinedTotal - breakdown.totalPrice)
                    if difference > 0.01 {
                        Text("⚠️ Total mismatch: \(difference.toCurrency())")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    } else {
                        Text("✅ Component totals verified")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }

                Divider()
            }

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
    @AppStorage("hasSeenJobberAppSearchTip") private var hasSeenJobberAppSearchTip = false
    @State private var showingJobberAppTip = false
    @Query private var quoteDrafts: [QuoteDraft]

    // Find quote associated with this job
    private var associatedQuote: QuoteDraft? {
        quoteDrafts.first { $0.jobId == job.jobId && $0.jobberQuoteId != nil }
    }

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

                    // Check if there's a saved quote for this job
                    if let quote = associatedQuote, let quoteId = quote.jobberQuoteId {
                        print("🔗 Found saved quote ID: \(quoteId)")
                        job.quoteId = quoteId // Update job with saved quote ID
                    }

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

                    print("✅ Opening Jobber Web URL: \(jobberURL)")

                    if let url = URL(string: jobberURL) {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    } else {
                        print("❌ Failed to create URL from string: \(jobberURL)")
                    }
                }) {
                    Label("View in Jobber Web", systemImage: "link")
                        .foregroundColor(.blue)
                }

                // Button to copy client info and open Jobber app
                Button(action: {
                    print("🔍 Copying client name and opening Jobber app...")
                    print("🔍 hasSeenJobberAppSearchTip: \(hasSeenJobberAppSearchTip)")

                    // Copy client name to clipboard for easy search
                    #if canImport(UIKit)
                    UIPasteboard.general.string = job.clientName
                    #endif

                    print("✅ Copied to clipboard: \(job.clientName)")

                    // Show tip on first use, otherwise open immediately
                    if !hasSeenJobberAppSearchTip {
                        print("📱 Showing tip alert for first time")
                        showingJobberAppTip = true
                        hasSeenJobberAppSearchTip = true
                    } else {
                        print("📱 Opening Jobber app directly (user has seen tip)")
                        // Open Jobber app immediately
                        openJobberApp()
                    }
                }) {
                    Label("Open Jobber", systemImage: "magnifyingglass")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .alert("Tip: Search in Jobber", isPresented: $showingJobberAppTip) {
                    Button("Got it", role: .cancel) {
                        // Open Jobber app after user dismisses alert
                        openJobberApp()
                    }
                } message: {
                    Text("The client name has been copied to your clipboard. Paste it into the Jobber app's search bar to find this job.")
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

    private func openJobberApp() {
        #if canImport(UIKit)
        if let jobberAppURL = job.jobberAppURL,
           let url = URL(string: jobberAppURL) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("✅ Opened Jobber app - client name copied to clipboard")
                } else {
                    print("❌ Failed to open Jobber app")
                }
            }
        } else {
            // If no app URL, just open the app via scheme
            if let url = URL(string: "jobber://") {
                UIApplication.shared.open(url)
            }
        }
        #endif
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
