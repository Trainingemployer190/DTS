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
    /// - Returns: Array of material line items
    static func calculateMaterials(
        from measurements: RoofMeasurements,
        settings: AppSettings,
        preset: RoofPresetTemplate? = nil
    ) -> [RoofMaterialLineItem] {
        
        var materials: [RoofMaterialLineItem] = []
        
        // Get factors from preset or settings
        let factors = preset?.factors ?? factorsFromSettings(settings)
        
        // 1. SHINGLES - GAF SG Timb HDZ (3 bundles/square)
        if factors.bundlesPerSquare > 0 && measurements.totalSquares > 0 {
            let wasteFactor = 1.0 + factors.shingleWasteFactor
            let bundlesNeeded = ceil(measurements.totalSquares * factors.bundlesPerSquare * wasteFactor)
            
            var notes = "\(String(format: "%.1f", measurements.totalSquares)) squares @ \(Int(factors.bundlesPerSquare)) bundles/sq + \(Int(factors.shingleWasteFactor * 100))% waste"
            if let pitch = measurements.pitch {
                notes += " (\(pitch) pitch)"
            }
            if !measurements.transitionDescriptions.isEmpty {
                notes += " [Multi-pitch: \(measurements.transitionDescriptions.joined(separator: ", "))]"
            }
            
            materials.append(RoofMaterialLineItem(
                name: "GAF Timberline HDZ Shingles",
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
                name: "GAF FeltBuster Synthetic Underlayment",
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
                name: "GAF Pro-Start Starter Strip",
                description: "120 LF per bundle",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Starter",
                notes: "\(String(format: "%.0f", starterLF)) LF (eaves + rakes)"
            ))
        }
        
        // 4. RIDGE CAP - GAF SG S-A-R (Seal-A-Ridge) 25LF (25 LF/bundle)
        if factors.includesRidgeCap && (measurements.ridgeFeet + measurements.hipFeet) > 0 {
            let ridgeHipTotal = measurements.ridgeFeet + measurements.hipFeet
            let wasteFactor = 1.05  // 5% waste for ridge cap
            let bundlesNeeded = ceil(ridgeHipTotal * wasteFactor / factors.ridgeCapLFPerBundle)
            
            materials.append(RoofMaterialLineItem(
                name: "GAF Seal-A-Ridge Cap Shingles",
                description: "25 LF per bundle",
                calculatedQuantity: bundlesNeeded,
                unit: "bundles",
                category: "Ridge Cap",
                notes: "\(String(format: "%.0f", ridgeHipTotal)) LF (ridge + hip)"
            ))
        }
        
        // 5. RIDGE VENT - GAF Cobra Rigid Vent 3 (4' pieces, for ridge only)
        if measurements.ridgeFeet > 0 {
            // Cobra Rigid Vent comes in 4' sections
            let ventPiecesNeeded = ceil(measurements.ridgeFeet / 4.0)
            
            materials.append(RoofMaterialLineItem(
                name: "GAF Cobra Rigid Vent 3",
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
                    name: "Aluminum Drip Edge",
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
                name: "GAF WeatherWatch Ice & Water",
                description: "2 SQ per roll (200 sqft)",
                calculatedQuantity: rollsNeeded,
                unit: "rolls",
                category: "Ice & Water",
                notes: iceWaterNotes.joined(separator: ", ")
            ))
        }
        
        // 8. COIL NAILS - Coil Nail ABC 1-1/4" EG (for shingles)
        if measurements.totalSquares > 0 {
            let lbsNeeded = measurements.totalSquares * factors.coilNailsLbsPerSquare
            // Typical box is ~7200 nails, roughly 60 lbs
            let boxesNeeded = ceil(lbsNeeded / 60)
            
            materials.append(RoofMaterialLineItem(
                name: "Coil Nails 1-1/4\" EG",
                description: "Electro-galvanized for shingles",
                calculatedQuantity: max(boxesNeeded, 1),
                unit: "boxes",
                category: "Nails",
                notes: "\(String(format: "%.0f", lbsNeeded)) lbs @ \(String(format: "%.1f", factors.coilNailsLbsPerSquare)) lbs/sq"
            ))
        }
        
        // 9. CAP NAILS - Nail ABC Plastic Cap 1" (for underlayment)
        // Typically need 1 pail per ~20-25 squares of underlayment
        if measurements.totalSquares > 0 {
            let pailsNeeded = ceil(measurements.totalSquares / 20.0)
            
            materials.append(RoofMaterialLineItem(
                name: "Plastic Cap Nails 1\"",
                description: "For underlayment installation",
                calculatedQuantity: max(pailsNeeded, 1),
                unit: "pails",
                category: "Nails",
                notes: "3M nails per pail"
            ))
        }
        
        // 10. SEALANT - MH/TS1 Joint/Term Sealant 10oz
        // Typically 1-2 tubes per job for flashing/penetrations
        let sealantTubes = max(2, ceil(measurements.totalSquares / 30.0))
        materials.append(RoofMaterialLineItem(
            name: "Roofing Sealant",
            description: "10oz tubes for flashings",
            calculatedQuantity: sealantTubes,
            unit: "tubes",
            category: "Accessories",
            notes: "For flashings and penetrations"
        ))
        
        // 11. PIPE BOOTS - IPS 4N1 Hardbase Flashing
        // Estimate based on roof size: ~1 per 20 squares, minimum 2, maximum 6
        if measurements.totalSquares > 0 {
            let estimatedBoots = max(2, min(6, ceil(measurements.totalSquares / 20.0)))
            
            materials.append(RoofMaterialLineItem(
                name: "Pipe Boot Flashing",
                description: "4-in-1 hardbase for plumbing vents",
                calculatedQuantity: estimatedBoots,
                unit: "pieces",
                category: "Flashing",
                notes: "Estimate ~1 per 20 sq - verify on site"
            ))
        }
        
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
        
        var body = """
        ROOF MATERIAL ORDER
        ═══════════════════════════════════════════════
        
        Project: \(order.projectName.isEmpty ? "Unnamed Project" : order.projectName)
        Client: \(order.clientName.isEmpty ? "N/A" : order.clientName)
        Address: \(order.address.isEmpty ? "N/A" : order.address)
        Date: \(order.createdAt.formatted(date: .long, time: .omitted))
        
        ROOF SPECIFICATIONS
        ───────────────────────────────────────────────
        Total Area: \(String(format: "%.2f", measurements.totalSquares)) squares (\(String(format: "%.0f", measurements.totalSqFt)) sqft)
        Ridge: \(String(format: "%.1f", measurements.ridgeFeet)) LF
        Valley: \(String(format: "%.1f", measurements.valleyFeet)) LF
        Rake: \(String(format: "%.1f", measurements.rakeFeet)) LF
        Eave: \(String(format: "%.1f", measurements.eaveFeet)) LF
        Hip: \(String(format: "%.1f", measurements.hipFeet)) LF
        """
        
        if let pitch = measurements.pitch {
            body += "\nPitch: \(pitch)"
        }
        
        body += """
        
        
        MATERIALS REQUIRED
        ═══════════════════════════════════════════════
        
        """
        
        // Group materials by category
        let categories = Dictionary(grouping: materials, by: { $0.category })
        let categoryOrder = ["Shingles", "Underlayment", "Starter", "Ridge Cap", "Ventilation", "Flashing", "Ice & Water", "Nails", "Accessories"]
        
        for category in categoryOrder {
            guard let items = categories[category], !items.isEmpty else { continue }
            
            body += "\n\(category.uppercased())\n"
            body += "───────────────────────────────────────────────\n"
            
            for item in items {
                let qty = Int(ceil(item.quantity))
                let manualIndicator = item.isManuallyAdjusted ? " *" : ""
                body += "• \(item.name): \(qty) \(item.unit)\(manualIndicator)\n"
                
                if let notes = item.notes, includeNotes {
                    body += "  └─ \(notes)\n"
                }
            }
        }
        
        // Add legend if any manual adjustments
        if materials.contains(where: { $0.isManuallyAdjusted }) {
            body += "\n* = Manually adjusted quantity\n"
        }
        
        if !order.notes.isEmpty && includeNotes {
            body += """
            
            
            ADDITIONAL NOTES
            ───────────────────────────────────────────────
            \(order.notes)
            """
        }
        
        body += """
        
        
        ═══════════════════════════════════════════════
        Generated by DTS App
        """
        
        return body
    }
    
    /// Generate email subject line
    static func generateEmailSubject(order: RoofMaterialOrder) -> String {
        let address = order.address.isEmpty ? order.projectName : order.address
        let squares = String(format: "%.1f", order.measurements.totalSquares)
        return "Roof Material Order - \(address) - \(squares) SQ"
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
            preset: preset
        )
        
        // Preserve manual overrides from existing materials
        let existingMaterials = order.materials
        for existing in existingMaterials where existing.isManuallyAdjusted {
            // Find matching item by name and category
            if let index = newMaterials.firstIndex(where: {
                $0.name == existing.name && $0.category == existing.category
            }) {
                newMaterials[index].manualQuantity = existing.manualQuantity
            }
        }
        
        return newMaterials
    }
}
