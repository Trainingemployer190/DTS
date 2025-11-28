//
//  SettingsView.swift
//  DTS App
//
//  Created by Chandler Staton on 8/17/25.
//

import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]

    // Focus states for each field
    @FocusState private var focusedField: FieldType?

    // Text field states
    @State private var materialCostGutterText = ""
    @State private var materialCostDownspoutText = ""
    @State private var gutterGuardMaterialText = ""
    @State private var costPerElbowText = ""
    @State private var costPerHangerText = ""
    @State private var hangerSpacingText = ""
    @State private var laborGutterText = ""
    @State private var gutterGuardLaborText = ""
    @State private var markupText = ""
    @State private var profitMarginText = ""
    @State private var salesCommissionText = ""
    @State private var taxRateText = ""
    @State private var gutterGuardMarkupText = ""
    @State private var gutterGuardProfitMarginText = ""
    @State private var materialCostRoundDownspoutText = ""
    @State private var costPerRoundElbowText = ""
    @State private var costPerWedgeText = ""
    @State private var wedgeSpacingText = ""
    @State private var wedgeLaborIncreaseText = ""

    enum FieldType {
        case materialCostGutter, materialCostDownspout, gutterGuardMaterial
        case costPerElbow, costPerHanger, hangerSpacing
        case laborGutter, gutterGuardLabor
        case markup, profitMargin, salesCommission
        case taxRate
        case gutterGuardMarkup, gutterGuardProfitMargin
        case materialCostRoundDownspout, costPerRoundElbow
        case costPerWedge, wedgeSpacing, wedgeLaborIncrease
    }

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

    private func updateTextFields() {
        materialCostGutterText = settings.materialCostPerFootGutter == 0 ? "" : String(settings.materialCostPerFootGutter)
        materialCostDownspoutText = settings.materialCostPerFootDownspout == 0 ? "" : String(settings.materialCostPerFootDownspout)
        gutterGuardMaterialText = settings.gutterGuardMaterialPerFoot == 0 ? "" : String(settings.gutterGuardMaterialPerFoot)
        costPerElbowText = settings.costPerElbow == 0 ? "" : String(settings.costPerElbow)
        costPerHangerText = settings.costPerHanger == 0 ? "" : String(settings.costPerHanger)
        hangerSpacingText = settings.hangerSpacingFeet == 0 ? "" : String(settings.hangerSpacingFeet)
        laborGutterText = settings.laborPerFootGutter == 0 ? "" : String(settings.laborPerFootGutter)
        gutterGuardLaborText = settings.gutterGuardLaborPerFoot == 0 ? "" : String(settings.gutterGuardLaborPerFoot)
        markupText = settings.defaultMarkupPercent == 0 ? "" : String(format: "%.1f", settings.defaultMarkupPercent * 100)
        profitMarginText = settings.defaultProfitMarginPercent == 0 ? "" : String(format: "%.1f", settings.defaultProfitMarginPercent * 100)
        salesCommissionText = settings.defaultSalesCommissionPercent == 0 ? "" : String(format: "%.1f", settings.defaultSalesCommissionPercent * 100)
        taxRateText = settings.taxRate == 0 ? "" : String(format: "%.1f", settings.taxRate * 100)
        gutterGuardMarkupText = settings.gutterGuardMarkupPercent == 0 ? "" : String(format: "%.1f", settings.gutterGuardMarkupPercent * 100)
        gutterGuardProfitMarginText = settings.gutterGuardProfitMarginPercent == 0 ? "" : String(format: "%.1f", settings.gutterGuardProfitMarginPercent * 100)
        materialCostRoundDownspoutText = settings.materialCostPerFootRoundDownspout == 0 ? "" : String(settings.materialCostPerFootRoundDownspout)
        costPerRoundElbowText = settings.costPerRoundElbow == 0 ? "" : String(settings.costPerRoundElbow)
        costPerWedgeText = settings.costPerWedge == 0 ? "" : String(settings.costPerWedge)
        wedgeSpacingText = settings.wedgeSpacingFeet == 0 ? "" : String(settings.wedgeSpacingFeet)
        wedgeLaborIncreaseText = settings.wedgeLaborIncrease == 0 ? "" : String(settings.wedgeLaborIncrease)
    }

    // Specific save functions for each property
    private func saveMaterialCostGutter(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.materialCostPerFootGutter = value
        saveSettings()
    }

    private func saveMaterialCostDownspout(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.materialCostPerFootDownspout = value
        saveSettings()
    }

    private func saveGutterGuardMaterial(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.gutterGuardMaterialPerFoot = value
        saveSettings()
    }

    private func saveCostPerElbow(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.costPerElbow = value
        saveSettings()
    }

    private func saveCostPerHanger(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.costPerHanger = value
        saveSettings()
    }

    private func saveHangerSpacing(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.hangerSpacingFeet = value
        saveSettings()
    }

    private func saveLaborGutter(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.laborPerFootGutter = value
        saveSettings()
    }

    private func saveGutterGuardLabor(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.gutterGuardLaborPerFoot = value
        saveSettings()
    }

    private func saveMarkup(_ text: String) {
        let value = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.defaultMarkupPercent = value
        saveSettings()
    }

    private func saveProfitMargin(_ text: String) {
        let m = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.defaultProfitMarginPercent = m
        // Auto-calc markup from margin: k = m / (1 - m)
        let k = m >= 1 ? 0 : (m / max(1 - m, 0.000001))
        settings.defaultMarkupPercent = k
        // Update UI mirror for markup so it reflects the computed value with 1 decimal place
        markupText = k == 0 ? "" : String(format: "%.1f", k * 100)
        saveSettings()
    }

    private func saveSalesCommission(_ text: String) {
        let value = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.defaultSalesCommissionPercent = value
        saveSettings()
    }

    private func saveTaxRate(_ text: String) {
        let value = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.taxRate = value
        saveSettings()
    }

    private func saveGutterGuardMarkup(_ text: String) {
        let value = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.gutterGuardMarkupPercent = value
        saveSettings()
    }

    private func saveGutterGuardProfitMargin(_ text: String) {
        let m = text.isEmpty ? 0 : ((Double(text) ?? 0) / 100)
        settings.gutterGuardProfitMarginPercent = m
        // Auto-calc markup from margin: k = m / (1 - m)
        let k = m >= 1 ? 0 : (m / max(1 - m, 0.000001))
        settings.gutterGuardMarkupPercent = k
        // Update UI mirror for markup so it reflects the computed value with 1 decimal place
        gutterGuardMarkupText = k == 0 ? "" : String(format: "%.1f", k * 100)
        saveSettings()
    }

    private func saveMaterialCostRoundDownspout(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.materialCostPerFootRoundDownspout = value
        saveSettings()
    }

    private func saveCostPerRoundElbow(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.costPerRoundElbow = value
        saveSettings()
    }

    private func saveCostPerWedge(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.costPerWedge = value
        saveSettings()
    }

    private func saveWedgeSpacing(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.wedgeSpacingFeet = value
        saveSettings()
    }

    private func saveWedgeLaborIncrease(_ text: String) {
        let value = text.isEmpty ? 0 : (Double(text) ?? 0)
        settings.wedgeLaborIncrease = value
        saveSettings()
    }

    private func saveSettings() {
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            VStack {
                SwiftUI.Form {
                    materialCostsSection
                    componentCostsSection
                    laborCostsSection
                    defaultPricingSection
                    gutterGuardPricingSection
                }
                .onTapGesture {
                    focusedField = nil
                }

                jobberSectionStandalone
            }
            .navigationTitle("Settings")
            .onAppear {
                updateTextFields()
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
                TextField("0", text: $materialCostGutterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .materialCostGutter)
                    .onSubmit {
                        saveMaterialCostGutter(materialCostGutterText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .materialCostGutter {
                            saveMaterialCostGutter(materialCostGutterText)
                        }
                    }
            }

            HStack {
                Text("Downspout")
                Spacer()
                Text("$")
                TextField("0", text: $materialCostDownspoutText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .materialCostDownspout)
                    .onSubmit {
                        saveMaterialCostDownspout(materialCostDownspoutText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .materialCostDownspout {
                            saveMaterialCostDownspout(materialCostDownspoutText)
                        }
                    }
            }

            HStack {
                Text("Round Downspout")
                Spacer()
                Text("$")
                TextField("0", text: $materialCostRoundDownspoutText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .materialCostRoundDownspout)
                    .onSubmit {
                        saveMaterialCostRoundDownspout(materialCostRoundDownspoutText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .materialCostRoundDownspout {
                            saveMaterialCostRoundDownspout(materialCostRoundDownspoutText)
                        }
                    }
            }

            HStack {
                Text("Gutter Guard")
                Spacer()
                Text("$")
                TextField("0", text: $gutterGuardMaterialText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .gutterGuardMaterial)
                    .onSubmit {
                        saveGutterGuardMaterial(gutterGuardMaterialText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .gutterGuardMaterial {
                            saveGutterGuardMaterial(gutterGuardMaterialText)
                        }
                    }
            }
        }
    }

    private var componentCostsSection: some View {
        Section("Component Costs") {
            HStack {
                Text("Elbow")
                Spacer()
                Text("$")
                TextField("0", text: $costPerElbowText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .costPerElbow)
                    .onSubmit {
                        saveCostPerElbow(costPerElbowText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .costPerElbow {
                            saveCostPerElbow(costPerElbowText)
                        }
                    }
            }

            HStack {
                Text("Round Elbow")
                Spacer()
                Text("$")
                TextField("0", text: $costPerRoundElbowText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .costPerRoundElbow)
                    .onSubmit {
                        saveCostPerRoundElbow(costPerRoundElbowText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .costPerRoundElbow {
                            saveCostPerRoundElbow(costPerRoundElbowText)
                        }
                    }
            }

            HStack {
                Text("Hanger")
                Spacer()
                Text("$")
                TextField("0", text: $costPerHangerText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .costPerHanger)
                    .onSubmit {
                        saveCostPerHanger(costPerHangerText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .costPerHanger {
                            saveCostPerHanger(costPerHangerText)
                        }
                    }
            }

            HStack {
                Text("Hanger Spacing")
                Spacer()
                TextField("0", text: $hangerSpacingText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .hangerSpacing)
                    .onSubmit {
                        saveHangerSpacing(hangerSpacingText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .hangerSpacing {
                            saveHangerSpacing(hangerSpacingText)
                        }
                    }
                Text("ft")
            }

            // Wedge costs section
            HStack {
                Text("Wedge (Slanted Fascia)")
                Spacer()
                Text("$")
                TextField("0", text: $costPerWedgeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .costPerWedge)
                    .onSubmit {
                        saveCostPerWedge(costPerWedgeText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .costPerWedge {
                            saveCostPerWedge(costPerWedgeText)
                        }
                    }
            }

            HStack {
                Text("Wedge Spacing")
                Spacer()
                TextField("0", text: $wedgeSpacingText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .wedgeSpacing)
                    .onSubmit {
                        saveWedgeSpacing(wedgeSpacingText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .wedgeSpacing {
                            saveWedgeSpacing(wedgeSpacingText)
                        }
                    }
                Text("ft")
            }

            HStack {
                Text("Wedge Labor Increase")
                Spacer()
                Text("$")
                TextField("0", text: $wedgeLaborIncreaseText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .wedgeLaborIncrease)
                    .onSubmit {
                        saveWedgeLaborIncrease(wedgeLaborIncreaseText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .wedgeLaborIncrease {
                            saveWedgeLaborIncrease(wedgeLaborIncreaseText)
                        }
                    }
                Text("/ft")
            }
        }
    }

    private var laborCostsSection: some View {
        Section("Labor Costs per Foot") {
            HStack {
                Text("Gutter Installation")
                Spacer()
                Text("$")
                TextField("0", text: $laborGutterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .laborGutter)
                    .onSubmit {
                        saveLaborGutter(laborGutterText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .laborGutter {
                            saveLaborGutter(laborGutterText)
                        }
                    }
            }

            HStack {
                Text("Gutter Guard Installation")
                Spacer()
                Text("$")
                TextField("0", text: $gutterGuardLaborText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .gutterGuardLabor)
                    .onSubmit {
                        saveGutterGuardLabor(gutterGuardLaborText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .gutterGuardLabor {
                            saveGutterGuardLabor(gutterGuardLaborText)
                        }
                    }
            }
        }
    }

    private var defaultPricingSection: some View {
        Section("Default Pricing") {
            HStack {
                Text("Markup")
                Spacer()
                TextField("0", text: $markupText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .markup)
                    .onSubmit {
                        saveMarkup(markupText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .markup {
                            saveMarkup(markupText)
                        }
                    }
                Text("%")
            }

            HStack {
                Text("Profit Margin")
                Spacer()
                TextField("0", text: $profitMarginText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .profitMargin)
                    .onSubmit {
                        saveProfitMargin(profitMarginText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .profitMargin {
                            saveProfitMargin(profitMarginText)
                        }
                    }
                Text("%")
            }

            HStack {
                Text("Sales Commission")
                Spacer()
                TextField("0", text: $salesCommissionText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .salesCommission)
                    .onSubmit {
                        saveSalesCommission(salesCommissionText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .salesCommission {
                            saveSalesCommission(salesCommissionText)
                        }
                    }
                Text("%")
            }

            HStack {
                Text("Tax")
                Spacer()
                TextField("0", text: $taxRateText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .taxRate)
                    .onSubmit {
                        saveTaxRate(taxRateText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .taxRate {
                            saveTaxRate(taxRateText)
                        }
                    }
                Text("%")
            }
        }
    }

    private var gutterGuardPricingSection: some View {
        Section("Gutter Guard Pricing") {
            HStack {
                Text("Markup")
                Spacer()
                TextField("0", text: $gutterGuardMarkupText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .gutterGuardMarkup)
                    .onSubmit {
                        saveGutterGuardMarkup(gutterGuardMarkupText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .gutterGuardMarkup {
                            saveGutterGuardMarkup(gutterGuardMarkupText)
                        }
                    }
                Text("%")
            }

            HStack {
                Text("Profit Margin")
                Spacer()
                TextField("0", text: $gutterGuardProfitMarginText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .gutterGuardProfitMargin)
                    .onSubmit {
                        saveGutterGuardProfitMargin(gutterGuardProfitMarginText)
                        focusedField = nil
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if newValue != .gutterGuardProfitMargin {
                            saveGutterGuardProfitMargin(gutterGuardProfitMarginText)
                        }
                    }
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
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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

    private var jobberSectionStandalone: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Jobber Integration")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 12) {
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

                    // Direct Button implementation without Form wrapper - like Add Labor Item
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
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(JobberAPI())
}

