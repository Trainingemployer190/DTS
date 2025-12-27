//
//  RoofMaterialCalculator.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Calculate required roofing materials from measurements with business rules
//

import Foundation
import SwiftData

/// Calculator for roof materials with preset and manual override support
class RoofMaterialCalculator {

    // MARK: - Main Calculation

    /// Calculate all materials from measurements using settings or preset
    /// - Parameters:
    ///   - measurements: Parsed roof measurements
    ///   - settings: App settings for calculation factors (used if no preset)
    ///   - preset: Optional preset to use instead of settings
    ///   - shingleType: Shingle type/name for the order
    ///   - shingleColor: Shingle color for the order
    /// - Returns: Array of material line items
    static func calculateMaterials(
        from measurements: RoofMeasurements,
        settings: AppSettings,
        preset: RoofPresetTemplate? = nil,
        shingleType: String = "GAF Timberline HDZ",
        shingleColor: String = "Charcoal",
        hasSprayFoamInsulation: Bool = false
    ) -> [RoofMaterialLineItem] {

        var materials: [RoofMaterialLineItem] = []

        // Get factors from preset or settings
        let factors = preset?.factors ?? factorsFromSettings(settings)
        
        // Build shingle name in supplier format: GAF SG TIMB HDZ [COLOR] 3/S
        let colorUpper = shingleColor.uppercased()
        let shingleName = colorUpper.isEmpty ? "GAF SG TIMB HDZ 3/S" : "GAF SG TIMB HDZ \(colorUpper) 3/S"

        // 1. SHINGLES - GAF SG Timb HDZ (3 bundles/square)
        if factors.bundlesPerSquare > 0 && measurements.totalSquares > 0 {
            let wasteFactor = 1.0 + factors.shingleWasteFactor
            let squaresWithWaste = measurements.totalSquares * wasteFactor
            let bundlesNeeded = ceil(squaresWithWaste * factors.bundlesPerSquare)

            var notes = "\(String(format: "%.1f", measurements.totalSquares)) SQ + \(Int(factors.shingleWasteFactor * 100))% waste = \(String(format: "%.1f", squaresWithWaste)) SQ × \(Int(factors.bundlesPerSquare)) = \(Int(bundlesNeeded)) bundles"
            if let pitch = measurements.pitch {
                notes += " (\(pitch) pitch)"
            }
            if !measurements.transitionDescriptions.isEmpty {
                notes += " [Multi-pitch]"
            }

            materials.append(RoofMaterialLineItem(
                name: shingleName,
                description: "3 bundles per square",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Shingles",
                notes: notes
            ))
        }

        // 2. UNDERLAYMENT - GAF FeltBuster Syn Roof Felt 10SQ (1000 sqft/roll)
        if measurements.totalSquares > 0 {
            let wasteFactor = 1.0 + factors.underlaymentWasteFactor
            let sqftNeeded = measurements.totalSquares * 100 * wasteFactor
            let rollsNeeded = ceil(sqftNeeded / factors.underlaymentSqFtPerRoll)

            materials.append(RoofMaterialLineItem(
                name: "GAF FELTBUSTER SYN ROOF FELT 10SQ",
                description: "10 SQ per roll (1000 sqft)",
                calculatedQuantity: rollsNeeded,
                unit: "rolls",
                category: "Underlayment",
                notes: "\(String(format: "%.0f", sqftNeeded)) sqft coverage needed"
            ))
        }

        // 3. STARTER STRIP - GAF Pro-Start Starter 120.33LF (120 LF/bundle)
        let starterLF = measurements.eaveFeet + measurements.rakeFeet
        if starterLF > 0 {
            let wasteFactor = 1.05  // 5% waste for starter
            let bundlesNeeded = ceil(starterLF * wasteFactor / factors.starterStripLFPerBundle)

            materials.append(RoofMaterialLineItem(
                name: "GAF PRO-START STARTER 120.33LF",
                description: "120 LF per bundle",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Starter",
                notes: "\(String(format: "%.0f", starterLF)) LF (eaves + rakes)"
            ))
        }

        // 4. RIDGE CAP - GAF SG S-A-R [COLOR] 25LF (25 LF/bundle)
        if factors.includesRidgeCap && (measurements.ridgeFeet + measurements.hipFeet) > 0 {
            let ridgeHipTotal = measurements.ridgeFeet + measurements.hipFeet
            let wasteFactor = 1.05  // 5% waste for ridge cap
            let bundlesNeeded = ceil(ridgeHipTotal * wasteFactor / factors.ridgeCapLFPerBundle)
            let ridgeCapName = colorUpper.isEmpty ? "GAF SG S-A-R 25LF" : "GAF SG S-A-R \(colorUpper) 25LF"

            materials.append(RoofMaterialLineItem(
                name: ridgeCapName,
                description: "25 LF per bundle",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Ridge Cap",
                notes: "\(String(format: "%.0f", ridgeHipTotal)) LF (ridge + hip)"
            ))
        }

        // 5. RIDGE VENT - GAF Cobra Rigid Vent 3 (4' pieces, for ridge only)
        // Skip if spray foam insulation (conditioned attic doesn't need ventilation)
        if measurements.ridgeFeet > 0 && !hasSprayFoamInsulation {
            // Cobra Rigid Vent comes in 4' sections
            let ventPiecesNeeded = ceil(measurements.ridgeFeet / 4.0)

            materials.append(RoofMaterialLineItem(
                name: "GAF COBRA RIGID VENT 3 12\" W/NAILS",
                description: "4' sections with nails",
                calculatedQuantity: ventPiecesNeeded,
                unit: "pieces",
                category: "Ventilation",
                notes: "\(String(format: "%.0f", measurements.ridgeFeet)) LF ridge"
            ))
        }

        // 6. DRIP EDGE - Alum 1-1/2x3-3/4 (10' pieces)
        if factors.includesDripEdge {
            let dripEdgeLF = measurements.rakeFeet + measurements.eaveFeet
            if dripEdgeLF > 0 {
                let wasteFactor = 1.0 + factors.dripEdgeWasteFactor
                let piecesNeeded = ceil(dripEdgeLF * wasteFactor / factors.dripEdgeLFPerPiece)

                materials.append(RoofMaterialLineItem(
                    name: "ALUM 1-1/2X3-3/4 OF DRIP EDGE BLACK",
                    description: "1-1/2x3-3/4\" x 10' pieces",
                    calculatedQuantity: piecesNeeded,
                    unit: "pieces",
                    category: "Flashing",
                    notes: "\(String(format: "%.0f", dripEdgeLF)) LF (rakes + eaves)"
                ))
            }
        }

        // 7. ICE & WATER SHIELD - GAF WeatherWatch 36"x66.7' 2SQ/RL (200 sqft/roll)
        var iceWaterSqFt: Double = 0
        var iceWaterNotes: [String] = []

        // For valleys (if enabled) - 3' width on each side
        if factors.requiresIceWaterForValleys && measurements.valleyFeet > 0 {
            let valleySqFt = measurements.valleyFeet * factors.iceWaterWidthFeet * 2  // Both sides
            iceWaterSqFt += valleySqFt
            iceWaterNotes.append("\(String(format: "%.0f", valleySqFt)) sqft for valleys")
        }

        // For low-pitch areas (under threshold, e.g., 3/12 and below)
        if factors.requiresIceWaterForLowPitch && measurements.lowPitchSqFt > 0 {
            iceWaterSqFt += measurements.lowPitchSqFt
            iceWaterNotes.append("\(String(format: "%.0f", measurements.lowPitchSqFt)) sqft for low-pitch areas")
        }

        // For transitions between different pitches
        if factors.requiresIceWaterForTransitions && measurements.transitionFeet > 0 {
            let transitionSqFt = measurements.transitionFeet * factors.iceWaterWidthFeet * 2
            iceWaterSqFt += transitionSqFt
            iceWaterNotes.append("\(String(format: "%.0f", transitionSqFt)) sqft for transitions")
        }

        if iceWaterSqFt > 0 {
            let wasteFactor = 1.10  // 10% waste
            let rollsNeeded = ceil(iceWaterSqFt * wasteFactor / factors.iceWaterSqFtPerRoll)

            materials.append(RoofMaterialLineItem(
                name: "GAF WEATHERWATCH 36\"X66.7' 2SQ/RL",
                description: "2 SQ per roll (200 sqft)",
                calculatedQuantity: rollsNeeded,
                unit: "rolls",
                category: "Ice & Water",
                notes: iceWaterNotes.joined(separator: ", ")
            ))
        }

        // 8. COIL NAILS - COIL NAIL ABC 1-1/4" EG (for shingles)
        // 1 box per 16 squares
        if measurements.totalSquares > 0 {
            let boxesNeeded = ceil(measurements.totalSquares / 16.0)

            materials.append(RoofMaterialLineItem(
                name: "COIL NAIL ABC 1-1/4\" EG",
                description: "Electro-galvanized for shingles",
                calculatedQuantity: max(boxesNeeded, 1),
                unit: "boxes",
                category: "Nails",
                notes: "1 box per 16 squares"
            ))
        }

        // 9. CAP NAILS - Nail ABC Plastic Cap 1" (for underlayment)
        // Typically need 1 pail per ~20-25 squares of underlayment
        if measurements.totalSquares > 0 {
            let pailsNeeded = ceil(measurements.totalSquares / 20.0)

            materials.append(RoofMaterialLineItem(
                name: "NAIL ABC PLASTIC CAP 1\" 3M/PAIL",
                description: "For underlayment installation",
                calculatedQuantity: max(pailsNeeded, 1),
                unit: "pails",
                category: "Nails",
                notes: "3M nails per pail"
            ))
        }

        // 10. SEALANT - MH JTS1 JOINT/TERM SEALNT 10OZ BLK
        // 2 tubes per job
        materials.append(RoofMaterialLineItem(
            name: "MH JTS1 JOINT/TERM SEALNT 10OZ BLK",
            description: "10oz tubes for flashings",
            calculatedQuantity: 2,
            unit: "tubes",
            category: "Accessories",
            notes: "2 tubes per job"
        ))

        // 11. PIPE BOOTS - IPS 4N1 Hardbase Flashing
        // Estimate based on roof size: ~1 per 20 squares, minimum 2, maximum 6
        if measurements.totalSquares > 0 {
            let estimatedBoots = max(2, min(6, ceil(measurements.totalSquares / 20.0)))

            materials.append(RoofMaterialLineItem(
                name: "IPS 4N1 HARDBASE FLASHING",
                description: "4-in-1 hardbase for plumbing vents",
                calculatedQuantity: estimatedBoots,
                unit: "pieces",
                category: "Flashing",
                notes: "Estimate ~1 per 20 sq - verify on site"
            ))
        }
        
        // 12. STEP FLASHING - Alum PB Step Flash 5X8 (100 pieces/bundle)
        if measurements.stepFlashingFeet > 0 {
            // Step flashing: ~2 pieces per linear foot (one every 6")
            let piecesNeeded = measurements.stepFlashingFeet * 2
            let bundlesNeeded = ceil(piecesNeeded / 100.0)
            
            materials.append(RoofMaterialLineItem(
                name: "ALUM PB STEP FLASH 8X8 BLACK 100/BD",
                description: "100 pieces per bundle",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Flashing",
                notes: "\(String(format: "%.0f", measurements.stepFlashingFeet)) LF step flashing"
            ))
        }
        
        // 13. ANGLE FLASHING - Galv Angle Flashing 4X4X10 (for step flashing areas)
        if measurements.stepFlashingFeet > 0 {
            // Angle flashing: 10' pieces, need enough to cover step flashing length
            let piecesNeeded = ceil(measurements.stepFlashingFeet / 10.0)
            
            materials.append(RoofMaterialLineItem(
                name: "GALV ANGLE FLASHING 4X4X10",
                description: "Galvanized for wall termination",
                calculatedQuantity: piecesNeeded,
                unit: "pieces",
                category: "Flashing",
                notes: "\(String(format: "%.0f", measurements.stepFlashingFeet)) LF coverage"
            ))
        }
        
        // 14. PAINT/TOUCH-UP - PAINT ABC ROOF ACCES [COLOR]
        // 1 can per job for color matching accessories
        let paintName = colorUpper.isEmpty ? "PAINT ABC ROOF ACCES" : "PAINT ABC ROOF ACCES \(colorUpper)"
        materials.append(RoofMaterialLineItem(
            name: paintName,
            description: "Touch-up for flashings/vents",
            calculatedQuantity: 1,
            unit: "cans",
            category: "Accessories",
            notes: "1 can per job"
        ))
        
        // 15. ZIPPER BOOT - 1 per job
        materials.append(RoofMaterialLineItem(
            name: "Zipper Boot",
            description: "Roof penetration boot",
            calculatedQuantity: 1,
            unit: "pieces",
            category: "Flashing",
            notes: "1 per job"
        ))

        return materials
    }

    // MARK: - Settings Conversion

    /// Convert AppSettings to RoofPresetFactors
    private static func factorsFromSettings(_ settings: AppSettings) -> RoofPresetFactors {
        var factors = RoofPresetFactors()

        factors.bundlesPerSquare = settings.roofBundlesPerSquare
        factors.shingleWasteFactor = settings.roofShingleWasteFactor
        factors.underlaymentSqFtPerRoll = settings.roofUnderlaymentSqFtPerRoll
        factors.underlaymentWasteFactor = settings.roofUnderlaymentWasteFactor
        factors.starterStripLFPerBundle = settings.roofStarterStripLFPerBundle
        factors.ridgeCapLFPerBundle = settings.roofRidgeCapLFPerBundle
        factors.dripEdgeLFPerPiece = settings.roofDripEdgeLFPerPiece
        factors.dripEdgeWasteFactor = settings.roofDripEdgeWasteFactor
        factors.includesValleyFlashing = settings.roofIncludesValleyFlashing
        factors.valleyFlashingLFPerPiece = settings.roofValleyFlashingLFPerPiece
        factors.valleyWasteFactor = settings.roofValleyWasteFactor
        factors.iceWaterSqFtPerRoll = settings.roofIceWaterSqFtPerRoll
        factors.iceWaterWidthFeet = settings.roofIceWaterWidthFeet
        factors.requiresIceWaterForValleys = settings.roofAutoAddIceWaterForValleys
        factors.requiresIceWaterForLowPitch = settings.roofAutoAddIceWaterForLowPitch
        factors.requiresIceWaterForEaves = settings.roofAutoAddIceWaterForEaves
        factors.eaveIceWaterWidthFeet = settings.roofEaveIceWaterWidthFeet
        factors.coilNailsLbsPerSquare = settings.roofCoilNailsLbsPerSquare
        factors.capNailsPerRidgeLF = settings.roofCapNailsPerRidgeLF
        factors.includesDripEdge = settings.roofAutoAddDripEdgeForRakesEaves

        return factors
    }

    // MARK: - Email Generation

    /// Generate email body for supplier order
    static func generateEmailBody(
        order: RoofMaterialOrder,
        includeNotes: Bool = true
    ) -> String {
        let measurements = order.measurements
        let materials = order.materials
        
        // Calculate squares with 10% waste factor
        let squaresWithWaste = measurements.totalSquares * 1.10

        var body = """
        \(order.projectName.isEmpty ? "Roof Order" : order.projectName)
        \(order.address.isEmpty ? "" : order.address)
        
        \(String(format: "%.2f", squaresWithWaste)) SQ (w/ 10% waste)
        
        ────────────────────────
        MATERIALS
        ────────────────────────

        """

        // Materials list - grouped by category, compact format
        let categories = Dictionary(grouping: materials, by: { $0.category })
        let categoryOrder = ["Shingles", "Underlayment", "Starter", "Ridge Cap", "Ventilation", "Flashing", "Ice & Water", "Nails", "Accessories"]

        for category in categoryOrder {
            guard let items = categories[category], !items.isEmpty else { continue }

            for item in items {
                let qty = Int(ceil(item.quantity))
                let manualIndicator = item.isManuallyAdjusted ? " *" : ""
                body += "\(qty) \(item.unit)  -  \(item.name)\(manualIndicator)\n\n"
            }
        }

        // Measurements summary
        body += """
        ────────────────────────
        MEASUREMENTS
        ────────────────────────
        
        Ridge: \(String(format: "%.0f", measurements.ridgeFeet))'
        Valley: \(String(format: "%.0f", measurements.valleyFeet))'
        Rake: \(String(format: "%.0f", measurements.rakeFeet))'
        Eave: \(String(format: "%.0f", measurements.eaveFeet))'
        """

        if measurements.hipFeet > 0 {
            body += "\nHip: \(String(format: "%.0f", measurements.hipFeet))'"
        }

        if !order.notes.isEmpty && includeNotes {
            body += "\n\n────────────────────────\nNOTES\n────────────────────────\n\n\(order.notes)"
        }

        // Add legend if any manual adjustments
        if materials.contains(where: { $0.isManuallyAdjusted }) {
            body += "\n\n* = adjusted qty"
        }

        return body
    }

    /// Generate email subject line
    static func generateEmailSubject(order: RoofMaterialOrder) -> String {
        let address = order.address.isEmpty ? order.projectName : order.address
        let squaresWithWaste = order.measurements.totalSquares * 1.10
        let squares = String(format: "%.1f", squaresWithWaste)
        return "Roof Order - \(address) - \(squares) SQ"
    }

    // MARK: - Recalculation

    /// Recalculate materials while preserving manual overrides
    static func recalculate(
        order: RoofMaterialOrder,
        settings: AppSettings,
        preset: RoofPresetTemplate? = nil
    ) -> [RoofMaterialLineItem] {
        // Get new calculated materials
        var newMaterials = calculateMaterials(
            from: order.measurements,
            settings: settings,
            preset: preset,
            shingleType: order.shingleType,
            shingleColor: order.shingleColor,
            hasSprayFoamInsulation: order.hasSprayFoamInsulation
        )

        // Preserve manual overrides from existing materials
        let existingMaterials = order.materials
        for existing in existingMaterials where existing.isManuallyAdjusted {
            // Find matching item by category (name may change with shingle type)
            if let index = newMaterials.firstIndex(where: {
                $0.category == existing.category
            }) {
                newMaterials[index].manualQuantity = existing.manualQuantity
            }
        }

        return newMaterials
    }
}
