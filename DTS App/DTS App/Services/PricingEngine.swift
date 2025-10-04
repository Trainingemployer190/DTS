//
//  PricingEngine.swift
//  DTS App
//
//  Created by System on 8/22/25.
//

import Foundation
import SwiftData

// MARK: - Pricing Engine

struct PricingEngine {

    // MARK: - Price Breakdown

    struct PriceBreakdown {
        let materialsCost: Double
        let laborCost: Double
        let subtotal: Double
        let markupAmount: Double
        let gutterMarkupAmount: Double
        let guardMarkupAmount: Double
        let discountAmount: Double
        let commissionAmount: Double
        let taxAmount: Double
        let totalPrice: Double

        // Itemized breakdown
        let gutterMaterialsCost: Double
        let downspoutMaterialsCost: Double
        let gutterGuardCost: Double
        let additionalItemsCost: Double

        // Labor breakdown
        let gutterLaborCost: Double
        let gutterGuardLaborCost: Double

        // Measurement details
        let compositeFeet: Double

        // Computed properties expected by JobViews.swift
        var materialsTotal: Double { materialsCost }
        var laborTotal: Double { laborCost }
        var pricePerFoot: Double { compositeFeet > 0 ? totalPrice / compositeFeet : 0 }
        var finalTotal: Double { totalPrice }
    }

    // MARK: - Calculate Price

    static func calculatePrice(quote: QuoteDraft, settings: AppSettings) -> PriceBreakdown {
        // Calculate materials cost
        let gutterMaterialsCost = quote.gutterFeet * settings.materialCostPerFootGutter

        // Use different downspout cost based on round downspout toggle
        let downspoutMaterialsCost = quote.downspoutFeet * (quote.isRoundDownspout ?
            settings.materialCostPerFootRoundDownspout : settings.materialCostPerFootDownspout)

        let gutterGuardCost = quote.includeGutterGuard ? quote.gutterGuardFeet * settings.gutterGuardMaterialPerFoot : 0

        // Calculate costs for individual elbows, crimps and hangers
        // Use different elbow cost based on round downspout toggle
        let totalElbows = quote.aElbows + quote.bElbows + quote.twoCrimp + quote.fourCrimp
        let elbowsCost = Double(totalElbows) * (quote.isRoundDownspout ?
            settings.costPerRoundElbow : settings.costPerElbow)
        let hangersCost = Double(quote.hangersCount) * settings.costPerHanger

        // Additional items cost
        let additionalItemsCost = quote.additionalLaborItems.reduce(0) { $0 + $1.amount }

        let materialsCost = gutterMaterialsCost + downspoutMaterialsCost + gutterGuardCost + elbowsCost + hangersCost

        // Calculate composite feet (includes gutter, downspout, and elbows for labor calculation)
        let totalElbowsAndCrimps = Double(quote.aElbows + quote.bElbows + quote.twoCrimp + quote.fourCrimp)
        let compositeFeet = quote.gutterFeet + quote.downspoutFeet + totalElbowsAndCrimps

        // Calculate labor cost based on composite feet
        let gutterLaborCost = compositeFeet * settings.laborPerFootGutter
        let gutterGuardLaborCost = quote.includeGutterGuard ? quote.gutterGuardFeet * settings.gutterGuardLaborPerFoot : 0
        let laborCost = gutterLaborCost + gutterGuardLaborCost

        // Calculate subtotal FIRST (materials + labor + additional items)
        let subtotal = materialsCost + laborCost + additionalItemsCost

        // Segment base costs by component for component-level analysis
        let gutterBaseCost = (gutterMaterialsCost + downspoutMaterialsCost + elbowsCost + hangersCost) + gutterLaborCost + additionalItemsCost
        let guardBaseCost = gutterGuardCost + gutterGuardLaborCost

        // Apply markup to the SUBTOTAL (standard business practice)
        let gutterMarkupK = quote.markupPercent
        let guardMarkupK: Double = {
            if quote.guardMarkupPercent > 0 { return quote.guardMarkupPercent }
            let m = quote.guardProfitMarginPercent
            return m > 0 ? (m / max(1 - m, 0.000001)) : 0
        }()

        // Calculate markup amounts proportionally based on component costs
        let totalBaseCost = gutterBaseCost + guardBaseCost
        let gutterProportion = totalBaseCost > 0 ? gutterBaseCost / totalBaseCost : 1.0
        let guardProportion = totalBaseCost > 0 ? guardBaseCost / totalBaseCost : 0.0

        // Total markup is calculated on the subtotal
        let markupAmount = subtotal * gutterMarkupK

        // Distribute markup proportionally for component-level reporting
        let gutterMarkupAmount = markupAmount * gutterProportion
        let guardMarkupAmount = markupAmount * guardProportion

        let subtotalAfterMarkup = subtotal + markupAmount
        let discountAmount = 0.0 // No discount field in QuoteDraft
        let subtotalAfterMarkupDiscount = subtotalAfterMarkup - discountAmount

        // Calculate commission based on quote's commission percentage (added to customer total)
        let commissionAmount = subtotalAfterMarkupDiscount * quote.salesCommissionPercent

        // Pre-tax subtotal must include commission
        let preTaxSubtotal = subtotalAfterMarkupDiscount + commissionAmount

        // Tax is calculated on the final pre-tax subtotal (which includes commission)
        let taxAmount = preTaxSubtotal * settings.taxRate

        // Final total: pre-tax subtotal + tax
        let totalPrice = preTaxSubtotal + taxAmount

        return PriceBreakdown(
            materialsCost: materialsCost,
            laborCost: laborCost,
            subtotal: subtotal,
            markupAmount: markupAmount,
            gutterMarkupAmount: gutterMarkupAmount,
            guardMarkupAmount: guardMarkupAmount,
            discountAmount: discountAmount,
            commissionAmount: commissionAmount,
            taxAmount: taxAmount,
            totalPrice: totalPrice,
            gutterMaterialsCost: gutterMaterialsCost,
            downspoutMaterialsCost: downspoutMaterialsCost,
            gutterGuardCost: gutterGuardCost,
            additionalItemsCost: additionalItemsCost,
            gutterLaborCost: gutterLaborCost,
            gutterGuardLaborCost: gutterGuardLaborCost,
            compositeFeet: compositeFeet
        )
    }

    // MARK: - Update Quote With Calculated Totals

    static func updateQuoteWithCalculatedTotals(quote: QuoteDraft, breakdown: PriceBreakdown) {
        // Store calculated totals in the quote for audit/history purposes
        quote.materialsTotal = breakdown.materialsCost
        quote.laborTotal = breakdown.laborCost
        quote.markupAmount = breakdown.markupAmount
        quote.commissionAmount = breakdown.commissionAmount
        quote.finalTotal = breakdown.totalPrice
    }
}

