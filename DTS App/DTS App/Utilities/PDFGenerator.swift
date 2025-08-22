//
//  PDFGenerator.swift
//  DTS App
//
//  PDF generation utility for quotes with photos and detailed breakdown
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class PDFGenerator: ObservableObject {
    static func generateQuotePDF(
        quote: QuoteDraft,
        breakdown: PriceBreakdown,
        settings: AppSettings,
        photos: [CapturedPhoto],
        jobInfo: JobberJob? = nil
    ) -> URL? {

        let pageSize = CGSize(width: 612, height: 792) // Standard US Letter size
        let margin: CGFloat = 50

        // Create PDF using UIGraphicsPDFRenderer
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "Quote_\(Date().timeIntervalSince1970).pdf"
        let pdfURL = documentsPath.appendingPathComponent(fileName)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        do {
            let pdfData = pdfRenderer.pdfData { context in
                context.beginPage()

                var currentY: CGFloat = margin

                // Helper function to draw text
                func drawText(_ text: String, fontSize: CGFloat, bold: Bool = false, at point: CGPoint) -> CGFloat {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize),
                        .foregroundColor: UIColor.black
                    ]

                    let attributedString = NSAttributedString(string: text, attributes: attributes)
                    let textSize = attributedString.size()

                    attributedString.draw(at: point)

                    return textSize.height + 5
                }

                // Helper function to draw a line
                func drawLine(from startPoint: CGPoint, to endPoint: CGPoint) {
                    let path = UIBezierPath()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                    path.stroke()
                }

                // Header - Quote
                currentY += drawText("Quote", fontSize: 32, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 20

                // Company info - Down the Spout Gutters and Roofing
                currentY += drawText("Down the Spout Gutters and Roofing", fontSize: 18, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("Professional Gutter Installation & Repair", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("Date: \(Date().formatted(date: .abbreviated, time: .omitted))", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                currentY += 30

                // Customer Information
                currentY += drawText("CUSTOMER INFORMATION", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 10

                // Use jobber job info if available
                if let job = jobInfo {
                    currentY += drawText("Client: \(job.clientName)", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += drawText("Address: \(job.address)", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                    currentY += drawText("Scheduled: \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))", fontSize: 12, at: CGPoint(x: margin, y: currentY))
                }

                currentY += 25

                // Quote details
                currentY += drawText("QUOTE DETAILS", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 10

                // Measurements
                currentY += drawText("Measurements:", fontSize: 14, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += drawText("• Gutter Feet: \(quote.gutterFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Downspout Feet: \(quote.downspoutFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Elbows: \(quote.elbowsCount)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• End Cap Pairs: \(quote.endCapPairs)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                currentY += drawText("• Hangers: \(quote.hangersCount)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))

                if quote.includeGutterGuard {
                    currentY += drawText("• Gutter Guard Feet: \(quote.gutterGuardFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                }

                // Add composite feet for price calculation clarity
                if breakdown.compositeFeet > 0 {
                    currentY += drawText("• Total Composite Feet: \(breakdown.compositeFeet.twoDecimalFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                }
                currentY += 15

                // Additional labor items
                if !quote.additionalLaborItems.isEmpty {
                    currentY += drawText("Additional Labor:", fontSize: 14, bold: true, at: CGPoint(x: margin, y: currentY))
                    for item in quote.additionalLaborItems {
                        currentY += drawText("• \(item.title): \(item.amount.currencyFormatted)", fontSize: 12, at: CGPoint(x: margin + 20, y: currentY))
                    }
                    currentY += 15
                }

                // Pricing breakdown
                currentY += drawText("PRICING BREAKDOWN", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                currentY += 10

                let pricingItems = [
                    ("Materials Total:", breakdown.materialsTotal.currencyFormatted),
                    ("Labor Total:", breakdown.laborTotal.currencyFormatted),
                    ("Subtotal:", (breakdown.materialsTotal + breakdown.laborTotal).currencyFormatted),
                    ("Markup (\(String(format: "%.1f", quote.markupPercent * 100))%):", breakdown.markupAmount.currencyFormatted),
                    ("Profit Margin (\(String(format: "%.1f", quote.profitMarginPercent * 100))%):", breakdown.profitAmount.currencyFormatted),
                    ("Commission (\(String(format: "%.1f", quote.salesCommissionPercent * 100))%):", breakdown.commissionAmount.currencyFormatted)
                ]

                for (label, value) in pricingItems {
                    let labelY = currentY
                    currentY += drawText(label, fontSize: 12, at: CGPoint(x: margin, y: labelY))
                    _ = drawText(value, fontSize: 12, at: CGPoint(x: pageSize.width - margin - 100, y: labelY))
                }

                // Draw line before total
                currentY += 10
                drawLine(from: CGPoint(x: margin, y: currentY), to: CGPoint(x: pageSize.width - margin, y: currentY))
                currentY += 15

                // Final total
                let totalY = currentY
                currentY += drawText("TOTAL:", fontSize: 16, bold: true, at: CGPoint(x: margin, y: totalY))
                _ = drawText(breakdown.finalTotal.currencyFormatted, fontSize: 16, bold: true, at: CGPoint(x: pageSize.width - margin - 120, y: totalY))

                if breakdown.compositeFeet > 0 {
                    currentY += 15
                    let pricePerFootY = currentY
                    currentY += drawText("Price per Composite Foot:", fontSize: 12, at: CGPoint(x: margin, y: pricePerFootY))
                    _ = drawText(breakdown.pricePerFoot.currencyFormatted, fontSize: 12, at: CGPoint(x: pageSize.width - margin - 100, y: pricePerFootY))
                }

                currentY += 40

                // Include photos if available
                if !photos.isEmpty {
                    currentY += drawText("PHOTOS", fontSize: 16, bold: true, at: CGPoint(x: margin, y: currentY))
                    currentY += 20

                    let contentWidth = pageSize.width - (margin * 2)
                    let photoWidth: CGFloat = (contentWidth - 20) / 2 // Two photos per row
                    let photoHeight: CGFloat = photoWidth * 0.75 // 4:3 aspect ratio

                    var photoX: CGFloat = margin
                    var photosInRow = 0

                    for photo in photos {
                        if let image = photo.image {
                            // Draw photo
                            let photoRect = CGRect(x: photoX, y: currentY, width: photoWidth, height: photoHeight)
                            image.draw(in: photoRect)

                            // Add photo info below image
                            let infoY = currentY + photoHeight + 5
                            _ = drawText("Captured: \(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))", fontSize: 10, at: CGPoint(x: photoX, y: infoY))

                            if let location = photo.location {
                                let coordinates = String(format: "GPS: %.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
                                _ = drawText(coordinates, fontSize: 10, at: CGPoint(x: photoX, y: infoY + 12))
                            }

                            photosInRow += 1

                            if photosInRow == 2 {
                                // Move to next row
                                currentY += photoHeight + 40
                                photoX = margin
                                photosInRow = 0

                                // Check if we need a new page
                                if currentY + photoHeight > pageSize.height - margin {
                                    context.beginPage()
                                    currentY = margin
                                }
                            } else {
                                // Move to next column
                                photoX += photoWidth + 20
                            }
                        }
                    }

                    // If we ended with an odd number of photos, move to next row
                    if photosInRow == 1 {
                        currentY += photoHeight + 40
                    }
                }

                // Footer
                let footerY = pageSize.height - margin - 40
                drawLine(from: CGPoint(x: margin, y: footerY), to: CGPoint(x: pageSize.width - margin, y: footerY))
                _ = drawText("This quote is valid for 30 days from the date above.", fontSize: 10, at: CGPoint(x: margin, y: footerY + 10))
                _ = drawText("Generated by DTS App", fontSize: 10, at: CGPoint(x: pageSize.width - margin - 120, y: footerY + 10))
            }

            try pdfData.write(to: pdfURL)
            return pdfURL

        } catch {
            print("Error generating PDF: \(error)")
            return nil
        }
    }
}
