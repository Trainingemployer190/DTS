//
//  QuoteViewComponents.swift
//  DTS App
//
//  Created by GitHub Copilot for missing components from JobViews
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct NewLaborItemView: View {
    @Binding var title: String
    @Binding var amount: Double
    let commonLaborItems: [CommonLaborItem]
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSelectItem: (CommonLaborItem) -> Void

    // Helper to bind the amount text field
    private func amountBinding() -> Binding<String> {
        Binding<String>(
            get: {
                if amount == 0 {
                    return ""
                } else {
                    // Format to 2 decimal places, but remove them if they are .00
                    return String(format: "%.2f", amount).replacingOccurrences(of: ".00", with: "")
                }
            },
            set: {
                if let value = Double($0) {
                    amount = value
                } else if $0.isEmpty {
                    amount = 0
                }
            }
        )
    }

    var body: some View {
        // Using a GroupBox to give it a distinct, contained look
        GroupBox("New Labor Item") {
            VStack(spacing: 16) {
                TextField("Item Description (e.g., Fascia Repair)", text: $title)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("$0.00", text: amountBinding())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                }

                // Quick-add common items with more responsive buttons
                if !commonLaborItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Items")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                            ForEach(commonLaborItems) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.leading)
                                    Text(item.amount.toCurrency())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onTapGesture {
                                    #if canImport(UIKit)
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    #endif
                                    onSelectItem(item)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                #if canImport(UIKit)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                #endif
                            }
                    )

                    Button(action: onSave) {
                        Text("Add Item")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty || amount <= 0 ? Color.gray.opacity(0.3) : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(title.isEmpty || amount <= 0)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                if !(title.isEmpty || amount <= 0) {
                                    #if canImport(UIKit)
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    #endif
                                }
                            }
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // This ensures the new view appears over the form, avoiding gesture conflicts
        .background(Color(.systemBackground))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct PreviewSection: View {
    @ObservedObject var quoteDraft: QuoteDraft
    let breakdown: PricingEngine.PriceBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quote Preview")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.bottom, 8)

            // Measurements summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Measurements")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Gutter:")
                    Spacer()
                    Text("\(quoteDraft.gutterFeet.formatted(.number.precision(.fractionLength(2)))) ft")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Downspout:")
                    Spacer()
                    Text("\(quoteDraft.downspoutFeet.twoDecimalFormatted) ft")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Elbows:")
                    Spacer()
                    Text("\(quoteDraft.elbowsCount)")
                        .fontWeight(.medium)
                }

                if quoteDraft.includeGutterGuard {
                    HStack {
                        Text("Gutter Guard:")
                        Spacer()
                        Text("\(quoteDraft.gutterGuardFeet.twoDecimalFormatted) ft")
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("Total Composite Feet:")
                    Spacer()
                    Text("\(breakdown.compositeFeet.twoDecimalFormatted) ft")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }

            Divider()

            // Price per foot information
            VStack(alignment: .leading, spacing: 4) {
                Text("Price Analysis")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Price per Foot:")
                    Spacer()
                    Text(breakdown.pricePerFoot.toCurrency() + "/ft")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .font(.title3)
                }

                Text("Based on \(breakdown.compositeFeet.twoDecimalFormatted) composite feet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            Divider()

            // Pricing summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Pricing")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Materials:")
                    Spacer()
                    Text(breakdown.materialsTotal.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Labor:")
                    Spacer()
                    Text(breakdown.laborTotal.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Markup:")
                    Spacer()
                    Text(breakdown.markupAmount.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Commission:")
                    Spacer()
                    Text(breakdown.commissionAmount.toCurrency())
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Tax:")
                    Spacer()
                    Text(breakdown.taxAmount.toCurrency())
                        .fontWeight(.medium)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Total:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(breakdown.finalTotal.toCurrency())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
