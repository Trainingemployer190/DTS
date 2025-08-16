//
//  SettingsView.swift
//  DTS App
//
//  Created by Chandler Staton on 8/15/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var currentSettings: AppSettings?

    var body: some View {
        NavigationStack {
            Form {
                Section("Materials Costs") {
                    HStack {
                        Text("Siding Cost")
                        Spacer()
                        TextField("Cost per sq ft", value: Binding(
                            get: { currentSettings?.sidingCostPerSqFt ?? 0.0 },
                            set: { currentSettings?.sidingCostPerSqFt = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Paint Cost")
                        Spacer()
                        TextField("Cost per sq ft", value: Binding(
                            get: { currentSettings?.paintCostPerSqFt ?? 0.0 },
                            set: { currentSettings?.paintCostPerSqFt = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Roofing Cost")
                        Spacer()
                        TextField("Cost per sq ft", value: Binding(
                            get: { currentSettings?.roofingCostPerSqFt ?? 0.0 },
                            set: { currentSettings?.roofingCostPerSqFt = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Gutter Cost")
                        Spacer()
                        TextField("Cost per linear ft", value: Binding(
                            get: { currentSettings?.gutterCostPerLinearFt ?? 0.0 },
                            set: { currentSettings?.gutterCostPerLinearFt = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Window Cost")
                        Spacer()
                        TextField("Cost per window", value: Binding(
                            get: { currentSettings?.windowCostPerUnit ?? 0.0 },
                            set: { currentSettings?.windowCostPerUnit = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Door Cost")
                        Spacer()
                        TextField("Cost per door", value: Binding(
                            get: { currentSettings?.doorCostPerUnit ?? 0.0 },
                            set: { currentSettings?.doorCostPerUnit = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }
                }

                Section("Labor Rates") {
                    HStack {
                        Text("Hourly Labor Rate")
                        Spacer()
                        TextField("Rate", value: Binding(
                            get: { currentSettings?.laborRatePerHour ?? 0.0 },
                            set: { currentSettings?.laborRatePerHour = $0 }
                        ), format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Estimated Hours per Sq Ft")
                        Spacer()
                        TextField("Hours", value: Binding(
                            get: { currentSettings?.estimatedHoursPerSqFt ?? 0.0 },
                            set: { currentSettings?.estimatedHoursPerSqFt = $0 }
                        ), format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }
                }

                Section("Markup & Overhead") {
                    HStack {
                        Text("Material Markup")
                        Spacer()
                        TextField("Percentage", value: Binding(
                            get: { currentSettings?.materialMarkupPercentage ?? 0.0 },
                            set: { currentSettings?.materialMarkupPercentage = $0 }
                        ), format: .percent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }

                    HStack {
                        Text("Labor Markup")
                        Spacer()
                        TextField("Percentage", value: Binding(
                            get: { currentSettings?.laborMarkupPercentage ?? 0.0 },
                            set: { currentSettings?.laborMarkupPercentage = $0 }
                        ), format: .percent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }

                    HStack {
                        Text("Overhead Percentage")
                        Spacer()
                        TextField("Percentage", value: Binding(
                            get: { currentSettings?.overheadPercentage ?? 0.0 },
                            set: { currentSettings?.overheadPercentage = $0 }
                        ), format: .percent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }

                    HStack {
                        Text("Profit Margin")
                        Spacer()
                        TextField("Percentage", value: Binding(
                            get: { currentSettings?.profitMarginPercentage ?? 0.0 },
                            set: { currentSettings?.profitMarginPercentage = $0 }
                        ), format: .percent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }
                }

                Section("Jobber Integration") {
                    HStack {
                        Text("Auto-create Jobber Quote")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { currentSettings?.autoCreateJobberQuote ?? false },
                            set: { currentSettings?.autoCreateJobberQuote = $0 }
                        ))
                    }

                    HStack {
                        Text("Include Photos in Quote")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { currentSettings?.includePhotosInQuote ?? false },
                            set: { currentSettings?.includePhotosInQuote = $0 }
                        ))
                    }
                }

                Section("Calculation Settings") {
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        TextField("Percentage", value: Binding(
                            get: { currentSettings?.taxRate ?? 0.0 },
                            set: { currentSettings?.taxRate = $0 }
                        ), format: .percent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    }

                    HStack {
                        Text("Currency")
                        Spacer()
                        TextField("Currency", text: Binding(
                            get: { currentSettings?.currency ?? "USD" },
                            set: { currentSettings?.currency = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    }
                }

                Section {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.borderedProminent)

                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        if let existingSettings = settings.first {
            currentSettings = existingSettings
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            currentSettings = newSettings
        }
    }

    private func saveSettings() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    private func resetToDefaults() {
        currentSettings?.sidingCostPerSqFt = 8.50
        currentSettings?.paintCostPerSqFt = 3.25
        currentSettings?.roofingCostPerSqFt = 12.00
        currentSettings?.gutterCostPerLinearFt = 15.00
        currentSettings?.windowCostPerUnit = 450.00
        currentSettings?.doorCostPerUnit = 650.00
        currentSettings?.laborRatePerHour = 65.00
        currentSettings?.estimatedHoursPerSqFt = 0.25
        currentSettings?.materialMarkupPercentage = 0.20
        currentSettings?.laborMarkupPercentage = 0.15
        currentSettings?.overheadPercentage = 0.10
        currentSettings?.profitMarginPercentage = 0.15
        currentSettings?.taxRate = 0.08
        currentSettings?.currency = "USD"
        currentSettings?.autoCreateJobberQuote = true
        currentSettings?.includePhotosInQuote = true

        saveSettings()
    }
}

#Preview {
    SettingsView()
}
