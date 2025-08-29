//
//  SettingsView.swift
//  DTS App
//
//  Created by Chandler Staton on 8/17/25.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]

    private var settings: AppSettings {
        if let existingSettings = settingsArray.first {
            return existingSettings
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            return newSettings
        }
    }

    // Simple decimal binding that actually works with decimals
    private func decimalBinding(for value: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                value.wrappedValue == 0 ? "" : String(value.wrappedValue)
            },
            set: { newValue in
                value.wrappedValue = Double(newValue) ?? 0
            }
        )
    }

    // Percentage binding (multiply by 100 for display)
    private func percentBinding(for value: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                value.wrappedValue == 0 ? "" : String(value.wrappedValue * 100)
            },
            set: { newValue in
                value.wrappedValue = (Double(newValue) ?? 0) / 100
            }
        )
    }

    private func saveSettings() {
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            Form {
                materialCostsSection
                componentCostsSection
                laborCostsSection
                defaultPricingSection
                gutterGuardPricingSection
                jobberSection
            }
            .navigationTitle("Settings")
            .onTapGesture {
                // Dismiss keyboard when tapping outside of text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - Sections

    private var materialCostsSection: some View {
        Section("Material Costs per Foot") {
            HStack {
                Text("Gutter")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.materialCostPerFootGutter },
                    set: { settings.materialCostPerFootGutter = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }

            HStack {
                Text("Downspout")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.materialCostPerFootDownspout },
                    set: { settings.materialCostPerFootDownspout = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }

            HStack {
                Text("Gutter Guard")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.gutterGuardMaterialPerFoot },
                    set: { settings.gutterGuardMaterialPerFoot = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }
        }
    }

    private var componentCostsSection: some View {
        Section("Component Costs") {
            HStack {
                Text("Elbow")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.costPerElbow },
                    set: { settings.costPerElbow = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }

            HStack {
                Text("Hanger")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.costPerHanger },
                    set: { settings.costPerHanger = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }

            HStack {
                Text("Hanger Spacing")
                Spacer()
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.hangerSpacingFeet },
                    set: { settings.hangerSpacingFeet = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("ft")
            }
        }
    }

    private var laborCostsSection: some View {
        Section("Labor Costs per Foot") {
            HStack {
                Text("Gutter Installation")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.laborPerFootGutter },
                    set: { settings.laborPerFootGutter = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }

            HStack {
                Text("Gutter Guard Installation")
                Spacer()
                Text("$")
                TextField("0", text: decimalBinding(for: Binding(
                    get: { settings.gutterGuardLaborPerFoot },
                    set: { settings.gutterGuardLaborPerFoot = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
            }
        }
    }

    private var defaultPricingSection: some View {
        Section("Default Pricing") {
            HStack {
                Text("Markup")
                Spacer()
                TextField("0", text: percentBinding(for: Binding(
                    get: { settings.defaultMarkupPercent },
                    set: { settings.defaultMarkupPercent = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("%")
            }

            HStack {
                Text("Profit Margin")
                Spacer()
                TextField("0", text: percentBinding(for: Binding(
                    get: { settings.defaultProfitMarginPercent },
                    set: { settings.defaultProfitMarginPercent = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("%")
            }

            HStack {
                Text("Sales Commission")
                Spacer()
                TextField("0", text: percentBinding(for: Binding(
                    get: { settings.defaultSalesCommissionPercent },
                    set: { settings.defaultSalesCommissionPercent = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("%")
            }
        }
    }

    private var gutterGuardPricingSection: some View {
        Section("Gutter Guard Pricing") {
            HStack {
                Text("Markup")
                Spacer()
                TextField("0", text: percentBinding(for: Binding(
                    get: { settings.gutterGuardMarkupPercent },
                    set: { settings.gutterGuardMarkupPercent = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("%")
            }

            HStack {
                Text("Profit Margin")
                Spacer()
                TextField("0", text: percentBinding(for: Binding(
                    get: { settings.gutterGuardProfitMarginPercent },
                    set: { settings.gutterGuardProfitMarginPercent = $0 }
                )))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.decimalPad)
                .onSubmit { saveSettings() }
                Text("%")
            }
        }
    }

    private var jobberSection: some View {
        Section("Jobber Integration") {
            if jobberAPI.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Connected to Jobber")
                            .font(.headline)
                        if let email = jobberAPI.connectedEmail {
                            Text("Account: \(email)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                Button("Disconnect") {
                    jobberAPI.signOut()
                }
                .foregroundColor(.red)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Not connected to Jobber")
                            .font(.headline)
                        Text("Connect to sync your jobs and quotes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Button(action: {
                    print("🔄 User tapped Connect to Jobber button")
                    print("Current authentication status: \(jobberAPI.isAuthenticated)")
                    print("Current loading status: \(jobberAPI.isLoading)")
                    if let error = jobberAPI.errorMessage {
                        print("Current error: \(error)")
                    }
                    jobberAPI.authenticate()
                }) {
                    HStack {
                        if jobberAPI.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.circle.fill")
                        }
                        Text(jobberAPI.isLoading ? "Connecting..." : "Connect to Jobber")
                    }
                }
                .disabled(jobberAPI.isLoading)

                // Show error message if there is one
                if let error = jobberAPI.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(JobberAPI())
}
