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
        let discountAmount: Double
        let commissionAmount: Double
        let taxAmount: Double
        let totalPrice: Double

        // Itemized breakdown
        let gutterMaterialsCost: Double
        let downspoutMaterialsCost: Double
        let gutterGuardCost: Double
        let additionalItemsCost: Double

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

        let subtotal = materialsCost + laborCost + additionalItemsCost

        // Apply markup using the quote's markup percentage (not settings default)
        let markupAmount = subtotal * quote.markupPercent
        let discountAmount = 0.0 // No discount field in QuoteDraft

        let subtotalAfterMarkupDiscount = subtotal + markupAmount - discountAmount

        // Calculate commission based on quote's commission percentage
        // Commission is calculated on the subtotal after markup, but comes out of profit
        let commissionAmount = subtotalAfterMarkupDiscount * quote.salesCommissionPercent

        let taxAmount = subtotalAfterMarkupDiscount * settings.taxRate
        let totalPrice = subtotalAfterMarkupDiscount + taxAmount

        return PriceBreakdown(
            materialsCost: materialsCost,
            laborCost: laborCost,
            subtotal: subtotal,
            markupAmount: markupAmount,
            discountAmount: discountAmount,
            commissionAmount: commissionAmount,
            taxAmount: taxAmount,
            totalPrice: totalPrice,
            gutterMaterialsCost: gutterMaterialsCost,
            downspoutMaterialsCost: downspoutMaterialsCost,
            gutterGuardCost: gutterGuardCost,
            additionalItemsCost: additionalItemsCost,
            compositeFeet: compositeFeet
        )
    }

    // MARK: - Update Quote With Calculated Totals

    static func updateQuoteWithCalculatedTotals(quote: QuoteDraft, breakdown: PriceBreakdown) {
        // Note: In a real implementation, you might want to store calculated totals
        // For now, we'll keep the quote model simple and calculate on-demand
    }
}
