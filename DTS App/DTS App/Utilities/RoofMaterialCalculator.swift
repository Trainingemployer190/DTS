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
        hasSprayFoamInsulation: Bool = false,
        chimneyCount: Int = 0,
        chimneyAgainstBrick: Bool = false,
        chimneyWidthFeet: Double = 3.0,
        chimneyNeedsCricket: Bool = false,
        wallFlashingAgainstBrick: Bool = false
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
        // NOTE: We don't put felt where ice & water goes, so subtract that area
        // Calculate ice & water sqft first to subtract from underlayment
        var iceWaterSqFt: Double = 0
        
        // For valleys - 3' width on each side
        if factors.requiresIceWaterForValleys && measurements.valleyFeet > 0 {
            iceWaterSqFt += measurements.valleyFeet * factors.iceWaterWidthFeet * 2
        }
        // For low-pitch areas
        if factors.requiresIceWaterForLowPitch && measurements.lowPitchSqFt > 0 {
            iceWaterSqFt += measurements.lowPitchSqFt
        }
        // For transitions
        if factors.requiresIceWaterForTransitions && measurements.transitionFeet > 0 {
            iceWaterSqFt += measurements.transitionFeet * factors.iceWaterWidthFeet * 2
        }
        
        if measurements.totalSquares > 0 {
            let wasteFactor = 1.0 + factors.underlaymentWasteFactor
            let totalSqFt = measurements.totalSquares * 100
            // Subtract ice & water areas - no felt needed there
            let feltSqFt = max(0, totalSqFt - iceWaterSqFt)
            let sqftNeeded = feltSqFt * wasteFactor
            let rollsNeeded = ceil(sqftNeeded / factors.underlaymentSqFtPerRoll)

            var notes = "\(String(format: "%.0f", sqftNeeded)) sqft coverage needed"
            if iceWaterSqFt > 0 {
                notes += " (excludes \(String(format: "%.0f", iceWaterSqFt)) sqft ice & water areas)"
            }

            materials.append(RoofMaterialLineItem(
                name: "GAF FELTBUSTER SYN ROOF FELT 10SQ",
                description: "10 SQ per roll (1000 sqft)",
                calculatedQuantity: rollsNeeded,
                unit: "rolls",
                category: "Underlayment",
                notes: notes
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

        // 6. DRIP EDGE - Alum 1-1/2x3-3/4 (10' pieces) - RAKES ONLY
        if factors.includesDripEdge && measurements.rakeFeet > 0 {
            let wasteFactor = 1.0 + factors.dripEdgeWasteFactor
            let piecesNeeded = ceil(measurements.rakeFeet * wasteFactor / factors.dripEdgeLFPerPiece)

            materials.append(RoofMaterialLineItem(
                name: "ALUM 1-1/2X3-3/4 OF DRIP EDGE BLACK",
                description: "1-1/2x3-3/4\" x 10' pieces",
                calculatedQuantity: piecesNeeded,
                unit: "pieces",
                category: "Flashing",
                notes: "\(String(format: "%.0f", measurements.rakeFeet)) LF rakes"
            ))
        }
        
        // 6B. GUTTER APRON - (10' pieces) - EAVES ONLY (where gutters go)
        if factors.includesDripEdge && measurements.eaveFeet > 0 {
            let wasteFactor = 1.0 + factors.dripEdgeWasteFactor
            let piecesNeeded = ceil(measurements.eaveFeet * wasteFactor / factors.dripEdgeLFPerPiece)

            materials.append(RoofMaterialLineItem(
                name: "ALUM GUTTER APRON 2.0\" BLACK",
                description: "AGA20BK - 10' pieces for eaves",
                calculatedQuantity: piecesNeeded,
                unit: "pieces",
                category: "Flashing",
                notes: "\(String(format: "%.0f", measurements.eaveFeet)) LF eaves"
            ))
        }

        // 7. ICE & WATER SHIELD - GAF WeatherWatch 36"x66.7' 2SQ/RL
        // Roll dimensions: 36" wide (3') x 66.7' long = 200 sqft (2 SQ)
        // - Valleys/Transitions: Calculate by LINEAR FEET (roll is 66.7' long)
        // - Low-pitch areas: Calculate by SQUARE FEET (covering whole sections)
        let rollLengthFeet = 66.7  // 66.7' per roll
        var iceWaterRolls: Double = 0
        var iceWaterNotes: [String] = []

        // Valleys - calculate by linear feet
        if factors.requiresIceWaterForValleys && measurements.valleyFeet > 0 {
            let valleyRolls = measurements.valleyFeet / rollLengthFeet
            iceWaterRolls += valleyRolls
            iceWaterNotes.append("\(String(format: "%.0f", measurements.valleyFeet)) LF valleys")
        }
        
        // Transitions - calculate by linear feet
        if factors.requiresIceWaterForTransitions && measurements.transitionFeet > 0 {
            let transitionRolls = measurements.transitionFeet / rollLengthFeet
            iceWaterRolls += transitionRolls
            iceWaterNotes.append("\(String(format: "%.0f", measurements.transitionFeet)) LF transitions")
        }
        
        // Low-pitch areas (under 4/12) - calculate by square feet
        if factors.requiresIceWaterForLowPitch && measurements.lowPitchSqFt > 0 {
            let lowPitchRolls = measurements.lowPitchSqFt / factors.iceWaterSqFtPerRoll
            iceWaterRolls += lowPitchRolls
            iceWaterNotes.append("\(String(format: "%.0f", measurements.lowPitchSqFt)) sqft low-pitch")
        }

        if iceWaterRolls > 0 {
            let wasteFactor = 1.10  // 10% waste
            let rollsNeeded = ceil(iceWaterRolls * wasteFactor)

            materials.append(RoofMaterialLineItem(
                name: "GAF WEATHERWATCH 36\"X66.7' 2SQ/RL",
                description: "66.7 LF per roll (36\" wide)",
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
        
        // 14. COUNTER FLASHING for walls/dormers against brick
        if measurements.stepFlashingFeet > 0 && wallFlashingAgainstBrick {
            // Counter flashing: 10' pieces for masonry walls
            let piecesNeeded = ceil(measurements.stepFlashingFeet / 10.0)
            
            materials.append(RoofMaterialLineItem(
                name: "GALV COUNTER FLASHING 4X4X10",
                description: "For brick/masonry wall termination",
                calculatedQuantity: piecesNeeded,
                unit: "pieces",
                category: "Flashing",
                notes: "Counter flashing for \(String(format: "%.0f", measurements.stepFlashingFeet)) LF of masonry wall"
            ))
        }
        
        // 15. CHIMNEY FLASHING - Step flashing, apron, and optional cricket
        if chimneyCount > 0 {
            // Each chimney needs:
            // - Step flashing on both sides (approximately 6' per side = 12' per chimney)
            // - L-flashing/apron at front (width of chimney)
            // - Cricket/saddle flashing at back (optional, for larger chimneys)
            // - Counter flashing if brick (perimeter of chimney)
            
            let stepFlashingPerChimney = 12.0  // ~6' per side
            let totalChimneyStepFlashing = Double(chimneyCount) * stepFlashingPerChimney
            let stepPiecesNeeded = totalChimneyStepFlashing * 2  // 2 pieces per LF
            let stepBundlesNeeded = ceil(stepPiecesNeeded / 100.0)
            
            materials.append(RoofMaterialLineItem(
                name: "ALUM PB STEP FLASH 8X8 BLACK 100/BD",
                description: "Chimney step flashing",
                calculatedQuantity: stepBundlesNeeded,
                unit: "bundles",
                category: "Flashing",
                notes: "\(chimneyCount) chimney(s) × 12 LF each"
            ))
            
            // L-flashing/apron for chimney front
            // Typically 4"x4" L-flashing, 10' pieces - need chimney width per chimney
            let apronLFNeeded = Double(chimneyCount) * chimneyWidthFeet
            let apronPiecesNeeded = ceil(apronLFNeeded / 10.0)
            
            materials.append(RoofMaterialLineItem(
                name: "GALV L FLASHING 4X4X10",
                description: "Chimney apron/front flashing",
                calculatedQuantity: max(1, apronPiecesNeeded),
                unit: "pieces",
                category: "Flashing",
                notes: "\(chimneyCount) chimney(s) × \(String(format: "%.0f", chimneyWidthFeet))' width"
            ))
            
            // Cricket framing and decking for back of chimney (optional)
            if chimneyNeedsCricket {
                // Cricket needs 2x4 framing and decking sheet
                // 2 2x4s per chimney for cricket frame
                materials.append(RoofMaterialLineItem(
                    name: "2X4X8 LUMBER",
                    description: "Cricket framing",
                    calculatedQuantity: Double(chimneyCount) * 2,
                    unit: "pieces",
                    category: "Flashing",
                    notes: "\(chimneyCount) chimney(s) × 2 boards each"
                ))
                
                // 1 sheet of decking per chimney
                materials.append(RoofMaterialLineItem(
                    name: "OSB BOARD 7/16\" 4'X8'",
                    description: "Cricket decking",
                    calculatedQuantity: Double(chimneyCount),
                    unit: "sheets",
                    category: "Flashing",
                    notes: "\(chimneyCount) chimney(s) - cricket deck"
                ))
            }
            
            // Counter flashing for brick chimneys
            if chimneyAgainstBrick {
                // Counter flashing covers perimeter: 2 sides + front + back
                // Estimate perimeter as: 2*(chimneyWidth + 2') per chimney (assume 2' depth)
                let perimeterPerChimney = 2 * (chimneyWidthFeet + 2.0)
                let totalCounterLF = Double(chimneyCount) * perimeterPerChimney
                let counterPiecesNeeded = ceil(totalCounterLF / 10.0)
                
                materials.append(RoofMaterialLineItem(
                    name: "GALV COUNTER FLASHING 4X4X10",
                    description: "For brick chimney masonry reglet",
                    calculatedQuantity: counterPiecesNeeded,
                    unit: "pieces",
                    category: "Flashing",
                    notes: "\(chimneyCount) brick chimney(s) - perimeter counter flash"
                ))
            }
        }
        
        // 16. PAINT/TOUCH-UP - PAINT ABC ROOF ACCES [COLOR]
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
        
        // 17. ZIPPER BOOT - 1 per job
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

        if !order.notes.isEmpty && includeNotes {
            body += "────────────────────────\nNOTES\n────────────────────────\n\n\(order.notes)\n\n"
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
            hasSprayFoamInsulation: order.hasSprayFoamInsulation,
            chimneyCount: order.chimneyCount,
            chimneyAgainstBrick: order.chimneyAgainstBrick,
            chimneyWidthFeet: order.chimneyWidthFeet,
            chimneyNeedsCricket: order.chimneyNeedsCricket,
            wallFlashingAgainstBrick: order.wallFlashingAgainstBrick
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
