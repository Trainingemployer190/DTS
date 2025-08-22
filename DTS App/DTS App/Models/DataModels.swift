//
//  DataModels.swift
//  DTS App
//
//  Created by Chandler Staton on 8/13/25.
//

import SwiftUI
import SwiftData
import Foundation
import CoreLocation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - SwiftData Models

@Model
final class AppSettings {
    // Gutter-specific material costs
    var materialCostPerFootGutter: Double = 1.62
    var materialCostPerFootDownspout: Double = 1.85
    var costPerElbow: Double = 2.03
    var costPerHanger: Double = 0.38
    var hangerSpacingFeet: Double = 3.0
    var gutterGuardMaterialPerFoot: Double = 2.00
    var gutterGuardLaborPerFoot: Double = 2.25

    // Labor rates
    var laborPerFootGutter: Double = 2.25

    // Markup and profit margins
    var defaultMarkupPercent: Double = 0.61
    var defaultProfitMarginPercent: Double = 0.35
    var defaultSalesCommissionPercent: Double = 0.03
    var gutterGuardMarkupPercent: Double = 0.61
    var gutterGuardProfitMarginPercent: Double = 0.35

    // Tax and currency
    var taxRate: Double = 0.08
    var currency: String = "USD"

    // Jobber integration
    var autoCreateJobberQuote: Bool = true
    var includePhotosInQuote: Bool = true

    init() {}
}

@Model
final class JobberJob {
    var jobId: String
    var clientName: String
    var clientPhone: String?
    var address: String
    var scheduledAt: Date
    var status: String

    init(jobId: String, clientName: String, clientPhone: String? = nil, address: String, scheduledAt: Date, status: String) {
        self.jobId = jobId
        self.clientName = clientName
        self.clientPhone = clientPhone
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
final class QuoteDraft: ObservableObject {
    var localId: UUID = UUID()
    var jobId: String?
    var clientId: String?
    var gutterFeet: Double = 0
    var downspoutFeet: Double = 0
    var elbowsCount: Int = 0
    var endCapPairs: Int = 0
    var includeGutterGuard: Bool = false
    var gutterGuardFeet: Double = 0
    var markupPercent: Double = 0.35  // Renamed from marginPercent
    var profitMarginPercent: Double = 0.20  // New profit margin field
    var salesCommissionPercent: Double = 0.03
    var notes: String = ""
    var syncStateRaw: String = SyncState.pending.rawValue
    var createdAt: Date = Date()

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

        // Add sales commission as a line item
        if commissionAmount > 0 {
            items.append(JobberLineItem(
                name: "Sales Commission",
                description: "Commission (\(Int(salesCommissionPercent * 100))%)",
                quantity: 1,
                unitPrice: commissionAmount
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

// MARK: - Additional Models

struct CapturedPhoto: Identifiable {
    let id: UUID
    let fileURL: String
    let jobId: String?
    let quoteDraftId: UUID?
    let location: CLLocation?
    let capturedAt: Date

    private var _cachedImage: UIImage?

    init(id: UUID = UUID(), fileURL: String, jobId: String? = nil, quoteDraftId: UUID? = nil, location: CLLocation? = nil, capturedAt: Date = Date()) {
        self.id = id
        self.fileURL = fileURL
        self.jobId = jobId
        self.quoteDraftId = quoteDraftId
        self.location = location
        self.capturedAt = capturedAt
        self._cachedImage = nil
    }

    var image: UIImage? {
        // Use lazy loading and cache management to reduce memory usage
        if let cached = _cachedImage {
            return cached
        }

        guard let uiImage = UIImage(contentsOfFile: fileURL) else {
            return nil
        }

        // Store reference for cache efficiency (but SwiftUI will handle memory management)
        return uiImage
    }
}

extension CapturedPhoto {
    var locationText: String {
        guard let location = location else { return "" }

        // Format coordinates to a reasonable precision
        let latitude = String(format: "%.4f", location.coordinate.latitude)
        let longitude = String(format: "%.4f", location.coordinate.longitude)
        return "\(latitude), \(longitude)"
    }
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String? // Optional in case some responses don't include it
}

struct PriceBreakdown {
    let materialsTotal: Double
    let laborTotal: Double
    let cost: Double  // C = materials + labor
    let markupPercent: Double  // k
    let markupAmount: Double  // k × C
    let price: Double  // P (before commission)
    let commissionPercent: Double  // s
    let commissionAmount: Double  // s × P
    let profitAmount: Double  // Profit after commission: P - C - Commission
    let profitMarginPercent: Double  // m = Profit ÷ P
    let finalTotal: Double  // P (since commission comes out of price)
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

        // Labor calculation - based on total installation footage
        let totalInstallationFeet = quote.gutterFeet + quote.downspoutFeet + Double(quote.elbowsCount)
        let gutterLaborCost = totalInstallationFeet * settings.laborPerFootGutter
        let gutterGuardLaborCost = quote.includeGutterGuard ?
            quote.gutterGuardFeet * settings.gutterGuardLaborPerFoot : 0

        // Add additional labor items
        let additionalLaborCost = quote.additionalLaborItems.reduce(0) { $0 + $1.amount }

        let laborTotal = gutterLaborCost + gutterGuardLaborCost + additionalLaborCost

        // Calculate base cost (C = materials + labor)
        let cost = materialsTotal + laborTotal

        // Apply markup: markup amount = cost × markup percentage
        let markupPercent = quote.markupPercent
        let markupAmount = cost * markupPercent

        // Price after markup: P = C + markup
        let priceBeforeCommission = cost + markupAmount

        // Calculate commission and add it to the total
        let commissionPercent = quote.salesCommissionPercent
        let commissionAmount = priceBeforeCommission * commissionPercent

        // Final price includes commission (customer pays for it)
        let price = priceBeforeCommission + commissionAmount
        let finalTotal = price

        // Profit = Price - Commission - Cost (profit after paying commission)
        let profitAmount = price - commissionAmount - cost

        // Profit margin = Profit ÷ Price
        let profitMarginPercent = price > 0 ? profitAmount / price : 0

        // Calculate composite feet and price per foot
        let compositeFeet = quote.gutterFeet + quote.downspoutFeet + Double(quote.elbowsCount)
        let pricePerFoot = compositeFeet > 0 ? finalTotal / compositeFeet : 0

        return PriceBreakdown(
            materialsTotal: materialsTotal,
            laborTotal: laborTotal,
            cost: cost,
            markupPercent: markupPercent,
            markupAmount: markupAmount,
            price: price,
            commissionPercent: commissionPercent,
            commissionAmount: commissionAmount,
            profitAmount: profitAmount,
            profitMarginPercent: profitMarginPercent,
            finalTotal: finalTotal,
            compositeFeet: compositeFeet,
            pricePerFoot: pricePerFoot
        )
    }

    static func updateQuoteWithCalculatedTotals(quote: QuoteDraft, breakdown: PriceBreakdown) {
        quote.materialsTotal = breakdown.materialsTotal
        quote.laborTotal = breakdown.laborTotal
        quote.markupAmount = breakdown.markupAmount
        quote.profitAmount = breakdown.profitAmount
        quote.commissionAmount = breakdown.commissionAmount
        quote.finalTotal = breakdown.finalTotal
    }
}

// MARK: - JobberAPI Response Models

struct AccountResponse: Codable {
    let data: AccountData
}

struct AccountData: Codable {
    let account: Account
}

struct Account: Codable {
    let id: String
    let name: String
}

struct ScheduledAssessmentsResponse: Codable {
    let data: ScheduledAssessmentsData
}

struct ScheduledAssessmentsData: Codable {
    let scheduledItems: ScheduledItems
}

struct ScheduledItems: Codable {
    let nodes: [ScheduledAssessment]
}

struct ScheduledAssessment: Codable {
    let id: String
    let title: String?
    let startAt: String
    let endAt: String?
    let completedAt: String?
    let client: AssessmentClient
    let assignedUsers: AssignedUsers
    let property: AssessmentProperty?
}

struct AssessmentClient: Codable {
    let id: String
    let name: String
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let emails: [ClientEmail]?
    let phones: [ClientPhone]?
    let billingAddress: ClientAddress?
}

struct ClientEmail: Codable {
    let address: String
    let description: String?
    let primary: Bool
}

struct ClientPhone: Codable {
    let number: String
    let description: String?
    let primary: Bool
}

struct ClientAddress: Codable {
    let street1: String?
    let city: String?
    let province: String?
    let postalCode: String?
}

struct AssignedUsers: Codable {
    let nodes: [AssignedUser]
}

struct AssignedUser: Codable {
    let name: AssignedUserName
}

struct AssignedUserName: Codable {
    let full: String
}

struct AssessmentProperty: Codable {
    let address: AssessmentAddress?
}

struct AssessmentAddress: Codable {
    let street1: String?
    let street2: String?
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
    let quote: JobberQuote?
    let userErrors: [JobberError]?
}

struct JobberQuote: Codable {
    let id: String
    let title: String
}

struct JobberError: Codable {
    let message: String
    let path: [String]?
}
