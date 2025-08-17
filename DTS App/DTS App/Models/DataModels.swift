//
//  DataModels.swift
//  DTS App
//
//  Created by Chandler Staton on 8/13/25.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - SwiftData Models

@Model
final class AppSettings {
    // Gutter-specific material costs
    var materialCostPerFootGutter: Double = 3.50
    var materialCostPerFootDownspout: Double = 4.00
    var costPerElbow: Double = 8.00
    var costPerHanger: Double = 2.50
    var hangerSpacingFeet: Double = 3.0
    var gutterGuardMaterialPerFoot: Double = 6.00
    var gutterGuardLaborPerFoot: Double = 3.00

    // Labor rates
    var laborPerFootGutter: Double = 5.00

    // Markup and profit margins
    var defaultMarkupPercent: Double = 0.35
    var defaultProfitMarginPercent: Double = 0.20
    var defaultSalesCommissionPercent: Double = 0.03
    var gutterGuardMarkupPercent: Double = 0.40
    var gutterGuardProfitMarginPercent: Double = 0.25

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
    var address: String
    var scheduledAt: Date
    var status: String

    init(jobId: String, clientName: String, address: String, scheduledAt: Date, status: String) {
        self.jobId = jobId
        self.clientName = clientName
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
