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
    var costPerWedge: Double = 3.00  // Cost per wedge for slanted fascia
    var wedgeSpacingFeet: Double = 2.0  // Wedges every 2 feet
    var wedgeLaborIncrease: Double = 0.0  // Additional labor per foot when wedges are needed
    var gutterGuardMaterialPerFoot: Double = 2.00
    var gutterGuardLaborPerFoot: Double = 2.25

    // Labor rates
    var laborPerFootGutter: Double = 2.25

    // Markup and profit margins
    var defaultMarkupPercent: Double = 0.538  // Calculated from 35% margin: 0.35/(1-0.35)
    var defaultProfitMarginPercent: Double = 0.35
    var defaultSalesCommissionPercent: Double = 0.03
    var gutterGuardMarkupPercent: Double = 1.00  // 100% markup for 50% margin
    var gutterGuardProfitMarginPercent: Double = 0.50

    // Tax and currency
    var taxRate: Double = 0.0
    var currency: String = "USD"

    // Jobber integration
    var autoCreateJobberQuote: Bool = true
    var includePhotosInQuote: Bool = true

    // MARK: - Roof Material Calculation Settings

    // Shingles & Coverage
    var roofBundlesPerSquare: Double = 3.0  // 3 bundles per square (standard 3-tab or architectural)
    var roofShingleWasteFactor: Double = 0.10  // 10% waste default

    // Underlayment - GAF FeltBuster covers 10 squares (1000 sqft) per roll
    var roofUnderlaymentSqFtPerRoll: Double = 1000.0  // 10 squares per roll (GAF FeltBuster 10SQ)
    var roofUnderlaymentWasteFactor: Double = 0.10  // 10% waste

    // Starter Strip - GAF Pro-Start covers 120.33 LF per bundle
    var roofStarterStripLFPerBundle: Double = 120.0  // ~120 LF per bundle (GAF Pro-Start)
    var roofStarterStripWasteFactor: Double = 0.05  // 5% waste

    // Ridge Cap - GAF Seal-A-Ridge covers 25 LF per bundle
    var roofRidgeCapLFPerBundle: Double = 25.0  // 25 LF per bundle (GAF Seal-A-Ridge)
    var roofRidgeCapWasteFactor: Double = 0.05  // 5% waste

    // Drip Edge
    var roofDripEdgeLFPerPiece: Double = 10.0  // 10 feet per piece
    var roofDripEdgeWasteFactor: Double = 0.05  // 5% waste

    // Valley Flashing
    var roofIncludesValleyFlashing: Bool = false  // We don't use valley flashing - just ice & water in valleys
    var roofValleyFlashingLFPerPiece: Double = 10.0  // 10 feet per piece
    var roofValleyWasteFactor: Double = 0.10  // 10% waste

    // Ice & Water Shield - GAF WeatherWatch covers 2 squares (200 SF) per roll
    var roofIceWaterSqFtPerRoll: Double = 200.0  // 2 SQ per roll (GAF WeatherWatch 36"x66.7')
    var roofIceWaterWidthFeet: Double = 3.0  // 36" = 3 feet wide
    var roofIceWaterWasteFactor: Double = 0.10  // 10% waste

    // Nails
    var roofCoilNailsLbsPerSquare: Double = 2.0  // 2 lbs per square
    var roofCapNailsPerRidgeLF: Double = 4.0  // 4 cap nails per LF of ridge
    var roofCoilNailsPerBox: Double = 7200.0  // Nails per box (varies by manufacturer)
    var roofCapNailsPerBox: Double = 3000.0  // Cap nails per box

    // Auto-apply business rules
    var roofAutoAddIceWaterForValleys: Bool = true
    var roofAutoAddIceWaterForEaves: Bool = false  // Disabled - only add for valleys by default
    var roofAutoAddIceWaterForLowPitch: Bool = true  // Add ice & water for areas under lowPitchThreshold
    var roofAutoAddIceWaterForTransitions: Bool = true  // Add ice & water where different pitches meet
    var roofLowPitchThreshold: Int = 4  // Pitch BELOW this gets ice & water (3/12 and lower, NOT 4/12)
    var roofAutoAddDripEdgeForRakesEaves: Bool = true
    var roofEaveIceWaterWidthFeet: Double = 3.0  // How far up from eave for ice & water

    // Supplier settings
    var roofDefaultSupplierEmail: String = ""  // Default email for material orders

    // Parse confidence threshold
    var roofParseConfidenceThreshold: Double = 80.0  // Show warning below this %

    init() {}
}

// JobberJob class for API data - simplified without @Model to avoid conflicts
final class JobberJob: Identifiable {
    var id: String { jobId } // Conforms to Identifiable
    var jobId: String
    var requestId: String? // Add request ID for note creation
    var quoteId: String? // Quote ID if a quote has been created
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
        // Priority 1: Use quote ID if a quote has been created
        if let quoteId = quoteId, !quoteId.isEmpty,
           let numericQuoteId = extractNumericId(from: quoteId) {
            let url = "https://secure.getjobber.com/quotes/\(numericQuoteId)"
            print("🔗 Using quote URL: \(url)")
            return url
        }

        // Priority 2: Use numeric request ID for requests page
        if let requestId = requestId, !requestId.isEmpty,
           let numericRequestId = extractNumericId(from: requestId) {
            let url = "https://secure.getjobber.com/requests/\(numericRequestId)"
            print("🔗 Using requests URL: \(url)")
            return url
        }

        // Priority 3: Fallback to client page if no request ID available
        if !clientId.isEmpty && clientId != "unknown",
           let numericClientId = extractNumericId(from: clientId) {
            let url = "https://secure.getjobber.com/clients/\(numericClientId)"
            print("🔗 Using client URL: \(url)")
            return url
        }

        print("❌ No valid IDs available for Jobber URL")
        return nil
    }

    // Computed property for Jobber app deep link
    var jobberAppURL: String? {
        // Priority 1: Try client path (most likely to work - shows all client jobs/requests)
        if !clientId.isEmpty && clientId != "unknown",
           let numericClientId = extractNumericId(from: clientId) {
            let appURL = "jobber://clients/\(numericClientId)"
            print("🔗 Attempting Jobber client app URL: \(appURL)")
            return appURL
        }

        // Priority 2: Try request/work order path
        if let requestId = requestId, !requestId.isEmpty,
           let numericRequestId = extractNumericId(from: requestId) {
            let appURL = "jobber://work_orders/\(numericRequestId)"
            print("🔗 Attempting Jobber work order app URL: \(appURL)")
            return appURL
        }

        print("❌ No valid IDs available for Jobber app URL")
        return nil
    }

    init(jobId: String, requestId: String? = nil, quoteId: String? = nil, clientId: String, propertyId: String? = nil, clientName: String, clientPhone: String?, address: String, scheduledAt: Date, status: String, serviceTitle: String? = nil, instructions: String? = nil, serviceInformation: String? = nil, serviceSpecifications: String? = nil) {
        self.jobId = jobId
        self.requestId = requestId
        self.quoteId = quoteId
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
    var jobberQuoteId: String? // Store the Jobber quote ID when created
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

    // Wedges for slanted fascia
    var includeWedges: Bool = false
    var wedgeCount: Int = 0  // Calculated based on gutterFeet and wedgeSpacing

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

    // Sync tracking fields
    var lastSyncAttempt: Date? // Last time upload was attempted
    var syncErrorMessage: String? // Error message from last failed sync
    var syncAttemptCount: Int = 0 // Number of upload attempts (max 10)

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
    var address: String? // Client address for grouping/album
    var uploaded: Bool = false

    // Watermark data (for regeneration)
    var originalTimestamp: Date? // Original photo capture time
    var watermarkAddress: String? // Address shown in watermark (can differ from album address)

    // Upload tracking (imgbb)
    var uploadAttempts: Int = 0
    var lastUploadError: String?

    // Google Photos upload tracking
    var uploadedToGooglePhotos: Bool = false
    var googlePhotosUploadAttempts: Int = 0
    var lastGooglePhotosUploadError: String?
    var googlePhotosUploadedAt: Date?
    var googlePhotosMediaItemId: String?  // Media item ID for adding to albums later
    var googlePhotosAlbumId: String?      // Album ID this photo belongs to

    // Annotation features
    var title: String = ""
    var notes: String = ""
    var tags: [String] = []
    var category: String = "General"
    var annotations: [PhotoAnnotation] = [] // Drawing/text annotations (custom system)
    var pencilKitDrawingData: Data? = nil  // PencilKit drawing data (prototype)

    init(fileURL: String, jobId: String? = nil, quoteDraftId: UUID? = nil, address: String? = nil) {
        self.fileURL = fileURL
        self.jobId = jobId
        self.quoteDraftId = quoteDraftId
        self.address = address
        self.originalTimestamp = Date()
        self.watermarkAddress = address
    }
}

// Annotation data structure for drawing on photos
struct PhotoAnnotation: Codable {
    var id: UUID = UUID()
    var type: AnnotationType
    var points: [CGPoint] // For freehand drawing
    var text: String? // For text annotations
    var color: String // Hex color
    var position: CGPoint // For text/arrow position
    var size: CGFloat // Stroke width or text size
    var fontSize: CGFloat? // Font size for text annotations (separate from stroke width)
    var textBoxWidth: CGFloat? // Width for text wrapping (nil = no wrapping)
    var hasExplicitWidth: Bool = false // True if user has manually resized width (prevents auto-sizing)

    enum AnnotationType: String, Codable {
        case freehand = "freehand"
        case arrow = "arrow"
        case box = "box"
        case circle = "circle"
        case text = "text"

        // Custom decoder to handle legacy 'text' type gracefully
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            switch value {
            case "freehand": self = .freehand
            case "arrow": self = .arrow
            case "box": self = .box
            case "circle": self = .circle
            case "text": self = .text
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot initialize AnnotationType from invalid String value \(value)"
                )
            }
        }
    }

    // Custom Codable implementation to handle backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, type, points, text, color, position, size, fontSize, textBoxWidth, hasExplicitWidth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(AnnotationType.self, forKey: .type)
        points = try container.decode([CGPoint].self, forKey: .points)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        color = try container.decode(String.self, forKey: .color)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGFloat.self, forKey: .size)
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize)
        textBoxWidth = try container.decodeIfPresent(CGFloat.self, forKey: .textBoxWidth)
        // Default to false for old data that doesn't have this field
        hasExplicitWidth = try container.decodeIfPresent(Bool.self, forKey: .hasExplicitWidth) ?? false
    }

    // Standard initializer for creating new annotations
    init(id: UUID = UUID(), type: AnnotationType, points: [CGPoint], text: String? = nil,
         color: String, position: CGPoint, size: CGFloat, fontSize: CGFloat? = nil,
         textBoxWidth: CGFloat? = nil, hasExplicitWidth: Bool = false) {
        self.id = id
        self.type = type
        self.points = points
        self.text = text
        self.color = color
        self.position = position
        self.size = size
        self.fontSize = fontSize
        self.textBoxWidth = textBoxWidth
        self.hasExplicitWidth = hasExplicitWidth
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
    let address: String?
    let quoteDraftId: UUID?
    let jobId: String?

    #if canImport(UIKit)
    init(image: UIImage, location: String? = nil, address: String? = nil, quoteDraftId: UUID? = nil, jobId: String? = nil) {
        self.image = image
        self.timestamp = Date()
        self.location = location
        self.address = address
        self.quoteDraftId = quoteDraftId
        self.jobId = jobId
    }
    #endif
}

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Roof Material Order Models

/// Status of a roof material order
enum RoofOrderStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case ordered = "ordered"
    case completed = "completed"
}

/// Individual material line item with manual override support
struct RoofMaterialLineItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var calculatedQuantity: Double  // Auto-calculated quantity
    var manualQuantity: Double?  // User override (nil = use calculated)
    var unit: String  // "bundles", "rolls", "pieces", "lbs", "boxes"
    var category: String  // "Shingles", "Underlayment", "Flashing", etc.
    var supplierSKU: String?
    var notes: String?

    /// Returns the effective quantity (manual override or calculated)
    var quantity: Double {
        manualQuantity ?? calculatedQuantity
    }

    /// Whether user has manually adjusted this item
    var isManuallyAdjusted: Bool {
        manualQuantity != nil
    }

    /// Reset to calculated quantity
    mutating func resetToCalculated() {
        manualQuantity = nil
    }
}

/// Roof measurement data parsed from PDF
struct RoofMeasurements: Codable {
    var totalSquares: Double = 0  // Total roof area in squares (100 sqft)
    var totalSqFt: Double = 0  // Total roof area in square feet
    var ridgeFeet: Double = 0  // Ridge/hip linear feet
    var valleyFeet: Double = 0  // Valley linear feet
    var rakeFeet: Double = 0  // Rake (gable edge) linear feet
    var eaveFeet: Double = 0  // Eave linear feet
    var hipFeet: Double = 0  // Hip linear feet (separate from ridge)
    var stepFlashingFeet: Double = 0  // Step flashing linear feet
    var wallFlashingFeet: Double = 0  // Wall/headwall flashing linear feet
    var pitch: String?  // Primary roof pitch (e.g., "6/12")
    var pitchMultiplier: Double = 1.0  // Pitch factor for area calculations
    
    // Pitch breakdown - each pitch with its square footage
    var pitchBreakdown: [PitchArea] = []  // All pitches with their areas

    // Low pitch areas (under 4/12) - need ice & water shield
    var lowPitchSqFt: Double = 0  // Square footage of areas under 4/12 pitch (3/12 and below)
    var lowPitchAreas: [String] = []  // Description of low pitch areas

    // Pitch transitions (where different pitches meet) - need ice & water
    var transitionFeet: Double = 0  // Linear feet of transitions between different pitches
    var transitionDescriptions: [String] = []  // Description of transitions

    /// Check if any measurements were parsed
    var hasData: Bool {
        totalSquares > 0 || totalSqFt > 0 || ridgeFeet > 0 || valleyFeet > 0
    }

    /// Check if roof has low pitch areas requiring ice & water
    var hasLowPitchAreas: Bool {
        lowPitchSqFt > 0
    }

    /// Check if roof has pitch transitions
    var hasTransitions: Bool {
        transitionFeet > 0
    }
    
    /// Check if roof has multiple pitches
    var hasMultiplePitches: Bool {
        pitchBreakdown.count > 1
    }
}

/// Individual pitch area measurement
struct PitchArea: Codable, Identifiable {
    var id: UUID = UUID()
    var pitch: String  // e.g., "4/12", "10/12"
    var sqFt: Double  // Square footage at this pitch
    var squares: Double { sqFt / 100.0 }  // Converted to squares
    
    init(pitch: String, sqFt: Double) {
        self.pitch = pitch
        self.sqFt = sqFt
    }
}

/// SwiftData model for storing roof material orders
@Model
final class RoofMaterialOrder {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Job/Client information
    var projectName: String = ""
    var clientName: String = ""
    var address: String = ""
    var notes: String = ""
    
    // Shingle selection
    var shingleType: String = "GAF Timberline HDZ"  // Default shingle type
    var shingleColor: String = "Charcoal"  // Default color

    // PDF file reference
    var pdfFilename: String?  // Filename in SharedContainerHelper.roofPDFStorageDirectory
    var originalPDFName: String?  // Original filename before UUID prefix

    // Parse metadata
    var parseConfidence: Double = 0  // 0-100 confidence score
    var detectedFormat: String?  // "iRoof", "EagleView", "Manual", etc.
    var parseWarnings: [String] = []  // Any warnings during parsing

    // Measurements (stored as JSON)
    var measurementsJSON: Data?

    // Materials (stored as JSON)
    var materialsJSON: Data?

    // Preset used
    var presetId: UUID?
    var presetName: String?

    // Attic insulation type (affects ridge vent)
    var hasSprayFoamInsulation: Bool = false  // If true, skip ridge vent (conditioned attic)
    
    // Chimney flashing options
    var chimneyCount: Int = 0  // Number of chimneys on roof
    var chimneyAgainstBrick: Bool = false  // If true, chimneys are brick/masonry (need counter flashing)
    var chimneyWidthFeet: Double = 3.0  // Average chimney width for apron flashing calculation
    
    // Wall/Dormer flashing options (for step flashing areas)
    var wallFlashingAgainstBrick: Bool = false  // If true, walls are brick/masonry (need counter flashing)
    
    // Status
    var statusRaw: String = RoofOrderStatus.draft.rawValue
    var orderedAt: Date?
    var supplierEmail: String?

    var status: RoofOrderStatus {
        get { RoofOrderStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            if newValue == .ordered && orderedAt == nil {
                orderedAt = Date()
            }
        }
    }

    // Computed properties for measurements
    var measurements: RoofMeasurements {
        get {
            guard let data = measurementsJSON else { return RoofMeasurements() }
            return (try? JSONDecoder().decode(RoofMeasurements.self, from: data)) ?? RoofMeasurements()
        }
        set {
            measurementsJSON = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    // Computed properties for materials
    var materials: [RoofMaterialLineItem] {
        get {
            guard let data = materialsJSON else { return [] }
            return (try? JSONDecoder().decode([RoofMaterialLineItem].self, from: data)) ?? []
        }
        set {
            materialsJSON = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    // Get PDF URL if available - requires passing the storage directory
    func pdfURL(in storageDirectory: URL) -> URL? {
        guard let filename = pdfFilename else { return nil }
        return storageDirectory.appendingPathComponent(filename)
    }

    init() {}

    /// Update a specific material's manual quantity
    func updateMaterialQuantity(id: UUID, quantity: Double?) {
        var mats = materials
        if let index = mats.firstIndex(where: { $0.id == id }) {
            mats[index].manualQuantity = quantity
            materials = mats
        }
    }

    /// Reset all materials to calculated quantities
    func resetAllToCalculated() {
        var mats = materials
        for i in mats.indices {
            mats[i].manualQuantity = nil
        }
        materials = mats
    }

    /// Check if confidence is below threshold
    func needsVerification(threshold: Double = 80.0) -> Bool {
        return parseConfidence < threshold
    }
}

/// Preset template for material calculations
@Model
final class RoofPresetTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var presetDescription: String = ""  // Renamed from 'description' which is reserved in @Model
    var createdAt: Date = Date()
    var isBuiltIn: Bool = false  // Built-in presets cannot be deleted

    // Material factors (stored as JSON for flexibility)
    var factorsJSON: Data?

    var factors: RoofPresetFactors {
        get {
            guard let data = factorsJSON else { return RoofPresetFactors() }
            return (try? JSONDecoder().decode(RoofPresetFactors.self, from: data)) ?? RoofPresetFactors()
        }
        set {
            factorsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    init() {}

    init(name: String, presetDescription: String, isBuiltIn: Bool = false, factors: RoofPresetFactors = RoofPresetFactors()) {
        self.name = name
        self.presetDescription = presetDescription
        self.isBuiltIn = isBuiltIn
        self.factors = factors
    }

    /// Create default built-in presets
    static func createBuiltInPresets() -> [RoofPresetTemplate] {
        return [
            RoofPresetTemplate(
                name: "Standard Asphalt Shingle",
                presetDescription: "3-tab or architectural shingles with standard underlayment",
                isBuiltIn: true,
                factors: RoofPresetFactors()  // Uses defaults
            ),
            RoofPresetTemplate(
                name: "Metal Panel Roof",
                presetDescription: "Standing seam or ribbed metal panels",
                isBuiltIn: true,
                factors: RoofPresetFactors(
                    bundlesPerSquare: 0,  // Metal uses panels, not bundles
                    underlaymentSqFtPerRoll: 400.0,
                    usesSyntheticUnderlayment: true,
                    requiresIceWaterForValleys: true,
                    requiresIceWaterForEaves: false,
                    wasteFactor: 0.15  // Higher waste for metal
                )
            ),
            RoofPresetTemplate(
                name: "Low-Slope Modified Bitumen",
                presetDescription: "Flat or low-slope roof with mod-bit membrane",
                isBuiltIn: true,
                factors: RoofPresetFactors(
                    bundlesPerSquare: 0,  // Uses rolls instead
                    underlaymentSqFtPerRoll: 100.0,  // Mod-bit coverage
                    usesSyntheticUnderlayment: false,
                    includesDripEdge: false,
                    requiresIceWaterForValleys: false,
                    requiresIceWaterForEaves: false,
                    wasteFactor: 0.10,
                    includesRidgeCap: false
                )
            )
        ]
    }
}

/// Factors for preset calculations
struct RoofPresetFactors: Codable {
    // Shingles
    var bundlesPerSquare: Double
    var shingleWasteFactor: Double

    // Underlayment
    var underlaymentSqFtPerRoll: Double
    var underlaymentWasteFactor: Double
    var usesSyntheticUnderlayment: Bool

    // Starter & Ridge
    var starterStripLFPerBundle: Double
    var ridgeCapLFPerBundle: Double

    // Drip Edge
    var dripEdgeLFPerPiece: Double
    var dripEdgeWasteFactor: Double
    var includesDripEdge: Bool

    // Valley
    var includesValleyFlashing: Bool  // Whether to include valley flashing (vs just ice & water)
    var valleyFlashingLFPerPiece: Double
    var valleyWasteFactor: Double

    // Ice & Water Shield
    var iceWaterSqFtPerRoll: Double
    var iceWaterWidthFeet: Double
    var requiresIceWaterForValleys: Bool
    var requiresIceWaterForEaves: Bool
    var requiresIceWaterForLowPitch: Bool  // Ice & water for areas under lowPitchThreshold pitch
    var lowPitchThreshold: Int  // Pitch below this (e.g., 4) gets ice & water (exclusive - 3/12 and below)
    var requiresIceWaterForTransitions: Bool  // Ice & water where different pitches meet
    var eaveIceWaterWidthFeet: Double

    // Nails
    var coilNailsLbsPerSquare: Double
    var capNailsPerRidgeLF: Double

    // General
    var wasteFactor: Double
    var includesRidgeCap: Bool

    // Default initializer with all defaults
    init(
        bundlesPerSquare: Double = 3.0,
        shingleWasteFactor: Double = 0.10,
        underlaymentSqFtPerRoll: Double = 1000.0,  // GAF FeltBuster 10SQ
        underlaymentWasteFactor: Double = 0.10,
        usesSyntheticUnderlayment: Bool = true,
        starterStripLFPerBundle: Double = 120.0,  // GAF Pro-Start
        ridgeCapLFPerBundle: Double = 25.0,  // GAF Seal-A-Ridge
        dripEdgeLFPerPiece: Double = 10.0,
        dripEdgeWasteFactor: Double = 0.05,
        includesDripEdge: Bool = true,
        includesValleyFlashing: Bool = false,  // Default OFF - we use ice & water in valleys, not flashing
        valleyFlashingLFPerPiece: Double = 10.0,
        valleyWasteFactor: Double = 0.10,
        iceWaterSqFtPerRoll: Double = 200.0,
        iceWaterWidthFeet: Double = 3.0,
        requiresIceWaterForValleys: Bool = true,
        requiresIceWaterForEaves: Bool = false,
        requiresIceWaterForLowPitch: Bool = true,  // Enable by default
        lowPitchThreshold: Int = 4,  // Under 4/12 gets ice & water (exclusive - 3/12 and below)
        requiresIceWaterForTransitions: Bool = true,  // Enable by default for pitch transitions
        eaveIceWaterWidthFeet: Double = 3.0,
        coilNailsLbsPerSquare: Double = 2.0,
        capNailsPerRidgeLF: Double = 4.0,
        wasteFactor: Double = 0.10,
        includesRidgeCap: Bool = true
    ) {
        self.bundlesPerSquare = bundlesPerSquare
        self.shingleWasteFactor = shingleWasteFactor
        self.underlaymentSqFtPerRoll = underlaymentSqFtPerRoll
        self.underlaymentWasteFactor = underlaymentWasteFactor
        self.usesSyntheticUnderlayment = usesSyntheticUnderlayment
        self.starterStripLFPerBundle = starterStripLFPerBundle
        self.ridgeCapLFPerBundle = ridgeCapLFPerBundle
        self.dripEdgeLFPerPiece = dripEdgeLFPerPiece
        self.dripEdgeWasteFactor = dripEdgeWasteFactor
        self.includesDripEdge = includesDripEdge
        self.includesValleyFlashing = includesValleyFlashing
        self.valleyFlashingLFPerPiece = valleyFlashingLFPerPiece
        self.valleyWasteFactor = valleyWasteFactor
        self.iceWaterSqFtPerRoll = iceWaterSqFtPerRoll
        self.iceWaterWidthFeet = iceWaterWidthFeet
        self.requiresIceWaterForValleys = requiresIceWaterForValleys
        self.requiresIceWaterForEaves = requiresIceWaterForEaves
        self.requiresIceWaterForLowPitch = requiresIceWaterForLowPitch
        self.lowPitchThreshold = lowPitchThreshold
        self.requiresIceWaterForTransitions = requiresIceWaterForTransitions
        self.eaveIceWaterWidthFeet = eaveIceWaterWidthFeet
        self.coilNailsLbsPerSquare = coilNailsLbsPerSquare
        self.capNailsPerRidgeLF = capNailsPerRidgeLF
        self.wasteFactor = wasteFactor
        self.includesRidgeCap = includesRidgeCap
    }
}

/// Log entry for failed PDF parses (for format learning)
@Model
final class RoofParseFailureLog {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var pdfFilename: String = ""
    var sanitizedContent: String = ""  // PII-removed text content
    var errorMessage: String = ""
    var extractedPatterns: [String] = []  // Patterns that were recognized
    var missedPatterns: [String] = []  // Patterns that failed

    init() {}

    init(pdfFilename: String, content: String, error: String) {
        self.pdfFilename = pdfFilename
        self.sanitizedContent = Self.sanitizePII(content)
        self.errorMessage = error
    }

    /// Remove personally identifiable information from content
    static func sanitizePII(_ content: String) -> String {
        var sanitized = content

        // Remove phone numbers (various formats)
        let phonePatterns = [
            "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",  // 123-456-7890
            "\\b\\(\\d{3}\\)\\s*\\d{3}[-.]?\\d{4}\\b",  // (123) 456-7890
            "\\b\\d{10}\\b"  // 1234567890
        ]
        for pattern in phonePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "[PHONE]"
                )
            }
        }

        // Remove email addresses
        if let emailRegex = try? NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", options: []) {
            sanitized = emailRegex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "[EMAIL]"
            )
        }

        // Remove street addresses (basic pattern)
        if let addressRegex = try? NSRegularExpression(pattern: "\\b\\d+\\s+[A-Za-z]+\\s+(St|Street|Ave|Avenue|Rd|Road|Dr|Drive|Ln|Lane|Blvd|Boulevard|Ct|Court|Way|Circle|Cir)\\b", options: [.caseInsensitive]) {
            sanitized = addressRegex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "[ADDRESS]"
            )
        }

        // Remove ZIP codes
        if let zipRegex = try? NSRegularExpression(pattern: "\\b\\d{5}(-\\d{4})?\\b", options: []) {
            sanitized = zipRegex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "[ZIP]"
            )
        }

        // Remove names (words that look like proper nouns after common titles)
        let titlePatterns = ["Mr\\.?", "Mrs\\.?", "Ms\\.?", "Dr\\.?"]
        for title in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: "\(title)\\s+[A-Z][a-z]+\\s+[A-Z][a-z]+", options: []) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "[NAME]"
                )
            }
        }

        return sanitized
    }
}

// MARK: - Preset Export/Import

extension RoofPresetTemplate {
    /// Export preset as JSON data for sharing
    func exportAsJSON() -> Data? {
        let exportData = RoofPresetExport(
            version: 1,
            name: name,
            description: presetDescription,
            factors: factors
        )
        return try? JSONEncoder().encode(exportData)
    }

    /// Import preset from JSON data
    static func importFromJSON(_ data: Data) -> RoofPresetTemplate? {
        guard let exportData = try? JSONDecoder().decode(RoofPresetExport.self, from: data) else {
            return nil
        }

        let preset = RoofPresetTemplate()
        preset.name = exportData.name + " (Imported)"
        preset.presetDescription = exportData.description
        preset.factors = exportData.factors
        preset.isBuiltIn = false
        return preset
    }
}

/// Export format for preset sharing
struct RoofPresetExport: Codable {
    var version: Int = 1
    var name: String
    var description: String
    var factors: RoofPresetFactors
}

