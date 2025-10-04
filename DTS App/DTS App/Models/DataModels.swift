//
//  DataModels.swift
//  DTS App
//
//  Created by Chandler Staton on 8/13/25.
//
//  COPILOT INSTRUCTIONS for GraphQL Integration:
//  When modifying JobberJob class or GraphQL-related models:
//  1. ALWAYS reference: DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt
//  2. JobberJob fields must match GraphQL response structure
//  3. Base64 IDs from GraphQL need extractNumericId() for web URLs
//  4. Schema validation required before adding new fields
//  5. Web URL construction follows: https://secure.getjobber.com/clients/{numericId}
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - SwiftData Models

@Model
final class AppSettings {
    // Gutter-specific material costs
    var materialCostPerFootGutter: Double = 1.62
    var materialCostPerFootDownspout: Double = 1.85
    var materialCostPerFootRoundDownspout: Double = 5.50  // New round downspout cost
    var costPerElbow: Double = 2.03
    var costPerRoundElbow: Double = 12.00  // New round elbow cost (higher price)
    var costPerHanger: Double = 0.38
    var hangerSpacingFeet: Double = 3.0
    var gutterGuardMaterialPerFoot: Double = 2.00
    var gutterGuardLaborPerFoot: Double = 2.25

    // Labor rates
    var laborPerFootGutter: Double = 2.25

    // Markup and profit margins
    var defaultMarkupPercent: Double = 0.538  // Calculated from 35% margin: 0.35/(1-0.35)
    var defaultProfitMarginPercent: Double = 0.35
    var defaultSalesCommissionPercent: Double = 0.03
    var gutterGuardMarkupPercent: Double = 0.538  // Calculated from 35% margin: 0.35/(1-0.35)
    var gutterGuardProfitMarginPercent: Double = 0.35

    // Tax and currency
    var taxRate: Double = 0.08
    var currency: String = "USD"

    // Jobber integration
    var autoCreateJobberQuote: Bool = true
    var includePhotosInQuote: Bool = true

    init() {}
}

// JobberJob class for API data - simplified without @Model to avoid conflicts
final class JobberJob: Identifiable {
    var id: String { jobId } // Conforms to Identifiable
    var jobId: String
    var requestId: String? // Add request ID for note creation
    var clientId: String // Required for quote creation
    var propertyId: String? // Required for quote creation if no requestId
    var clientName: String
    var clientPhone: String?
    var address: String
    var scheduledAt: Date
    var status: String
    var serviceTitle: String? // Service information from request title
    var instructions: String? // Assessment instructions with additional service details
    var serviceInformation: String? // Service information from request notes
    var serviceSpecifications: String? // Parsed service specifications from notes

    // Helper function to extract numeric ID from Base64 encoded Jobber GraphQL ID
    private func extractNumericId(from encodedId: String) -> String? {
        guard let data = Data(base64Encoded: encodedId),
              let decodedString = String(data: data, encoding: .utf8) else {
            print("❌ Failed to decode Base64 ID: \(encodedId)")
            return nil
        }

        print("🔍 Decoded ID: \(decodedString)")

        // Extract numeric part from format like "gid://Jobber/Client/80044538" or "gid://Jobber/Request/23776604"
        let components = decodedString.components(separatedBy: "/")
        guard let numericId = components.last, !numericId.isEmpty else {
            print("❌ Could not extract numeric ID from: \(decodedString)")
            return nil
        }

        print("✅ Extracted numeric ID: \(numericId)")
        return numericId
    }

    // Computed property for the best Jobber URL to use
    var assessmentURL: String? {
        // Priority 1: Use numeric client ID for client page (matches working Zapier format)
        if !clientId.isEmpty && clientId != "unknown",
           let numericClientId = extractNumericId(from: clientId) {
            let url = "https://secure.getjobber.com/clients/\(numericClientId)"
            print("🔗 Using client URL: \(url)")
            return url
        }

        // Priority 2: Use numeric request ID for work orders page
        if let requestId = requestId, !requestId.isEmpty,
           let numericRequestId = extractNumericId(from: requestId) {
            let url = "https://secure.getjobber.com/app/work_orders/\(numericRequestId)"
            print("🔗 Using work order URL: \(url)")
            return url
        }

        // Priority 3: Use numeric request ID for requests page
        if let requestId = requestId, !requestId.isEmpty,
           let numericRequestId = extractNumericId(from: requestId) {
            let url = "https://secure.getjobber.com/requests/\(numericRequestId)"
            print("🔗 Using requests URL: \(url)")
            return url
        }

        print("❌ No valid IDs available for Jobber URL")
        return nil
    }

    init(jobId: String, requestId: String? = nil, clientId: String, propertyId: String? = nil, clientName: String, clientPhone: String?, address: String, scheduledAt: Date, status: String, serviceTitle: String? = nil, instructions: String? = nil, serviceInformation: String? = nil, serviceSpecifications: String? = nil) {
        self.jobId = jobId
        self.requestId = requestId
        self.clientId = clientId
        self.propertyId = propertyId
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.address = address
        self.scheduledAt = scheduledAt
        self.status = status
        self.serviceTitle = serviceTitle
        self.instructions = instructions
        self.serviceInformation = serviceInformation
        self.serviceSpecifications = serviceSpecifications
    }
}

enum SyncState: String, Codable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed
}

enum QuoteStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case completed = "completed"
    case archived = "archived"
}

@Model
final class QuoteDraft: ObservableObject {
    var localId: UUID = UUID()
    var jobId: String?
    var clientId: String?
    var clientName: String = ""
    var clientAddress: String = "" // Add address for history display
    var gutterFeet: Double = 0
    var downspoutFeet: Double = 0
    var isRoundDownspout: Bool = false  // Round downspout toggle

    // Individual elbow and crimp types
    var aElbows: Int = 0
    var bElbows: Int = 0
    var twoCrimp: Int = 0
    var fourCrimp: Int = 0
    var endCapPairs: Int = 0

    // Color selection
    var gutterColor: String = "White"

    var includeGutterGuard: Bool = false
    var gutterGuardFeet: Double = 0
    var markupPercent: Double = 0  // Initialize to 0, will be set from settings
    var profitMarginPercent: Double = 0  // Initialize to 0, will be set from settings
    var guardProfitMarginPercent: Double = 0  // Independent profit margin for gutter guard
    var guardMarkupPercent: Double = 0  // Auto-calculated from guardProfitMarginPercent
    var salesCommissionPercent: Double = 0  // Initialize to 0, will be set from settings
    var notes: String = ""
    var syncStateRaw: String = SyncState.pending.rawValue
    var quoteStatusRaw: String = QuoteStatus.draft.rawValue
    var createdAt: Date = Date()
    var completedAt: Date? // Track when quote was completed
    var savedToJobber: Bool = false // Track if quote was saved to Jobber

    // Computed totals (stored for audit)
    var materialsTotal: Double = 0
    var laborTotal: Double = 0
    var markupAmount: Double = 0  // Renamed from marginAmount
    var profitAmount: Double = 0  // New profit amount field
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

    var quoteStatus: QuoteStatus {
        get { QuoteStatus(rawValue: quoteStatusRaw) ?? .draft }
        set {
            quoteStatusRaw = newValue.rawValue
            if newValue == .completed && completedAt == nil {
                completedAt = Date()
            }
        }
    }

    var hangersCount: Int {
        return Int(ceil(gutterFeet / 3.0)) // Default spacing of 3 feet
    }

    init() {}

    /// Initialize quote draft with current app settings
    func applyDefaultSettings(_ settings: AppSettings) {
        if self.markupPercent == 0 {
            self.markupPercent = settings.defaultMarkupPercent
        }
        if self.profitMarginPercent == 0 {
            self.profitMarginPercent = settings.defaultProfitMarginPercent
        }
        if self.salesCommissionPercent == 0 {
            self.salesCommissionPercent = settings.defaultSalesCommissionPercent
        }
        if self.guardProfitMarginPercent == 0 {
            self.guardProfitMarginPercent = settings.gutterGuardProfitMarginPercent
        }
        if self.guardMarkupPercent == 0 {
            // Calculate from margin: k = m / (1 - m)
            let m = self.guardProfitMarginPercent
            self.guardMarkupPercent = m >= 1 ? 0 : (m / max(1 - m, 0.000001))
        }
    }
}

@Model
final class LineItem {
    var title: String
    var amount: Double

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

struct QuoteDraftLineItem {
    let name: String
    let description: String
    let quantity: Double
    let unitPrice: Double
    let totalPrice: Double
}

// MARK: - Photo Capture Models

struct CapturedPhoto: Identifiable {
    let id = UUID()
    #if canImport(UIKit)
    let image: UIImage
    #endif
    let timestamp: Date
    let location: String?

    #if canImport(UIKit)
    init(image: UIImage, location: String? = nil) {
        self.image = image
        self.timestamp = Date()
        self.location = location
    }
    #endif
}

#if canImport(UIKit)
import UIKit
#endif

