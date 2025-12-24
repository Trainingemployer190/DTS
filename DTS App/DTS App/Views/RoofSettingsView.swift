//
//  RoofSettingsView.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Settings for roof material calculations and preset management
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoofSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]
    @Query(sort: \RoofPresetTemplate.name) private var presets: [RoofPresetTemplate]

    @State private var showingCreatePreset = false
    @State private var showingImportPreset = false
    @State private var editingPreset: RoofPresetTemplate?
    @State private var presetToExport: RoofPresetTemplate?
    @State private var showingExportShare = false

    private var settings: AppSettings {
        settingsArray.first ?? AppSettings()
    }

    var body: some View {
        List {
            // Supplier Settings
            Section("Supplier") {
                HStack {
                    Text("Default Email")
                    Spacer()
                    TextField("supplier@email.com", text: Binding(
                        get: { settings.roofDefaultSupplierEmail },
                        set: { settings.roofDefaultSupplierEmail = $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                }
            }

            // Default Calculation Settings
            Section {
                SettingSliderRow(
                    label: "Bundles per Square",
                    value: Binding(
                        get: { settings.roofBundlesPerSquare },
                        set: { settings.roofBundlesPerSquare = $0 }
                    ),
                    range: 2...4,
                    step: 0.5,
                    format: "%.1f"
                )

                SettingSliderRow(
                    label: "Shingle Waste Factor",
                    value: Binding(
                        get: { settings.roofShingleWasteFactor * 100 },
                        set: { settings.roofShingleWasteFactor = $0 / 100 }
                    ),
                    range: 5...25,
                    step: 1,
                    format: "%.0f%%"
                )
            } header: {
                Text("Shingles")
            } footer: {
                Text("Standard 3-tab shingles use 3 bundles per square")
            }

            Section("Underlayment") {
                SettingSliderRow(
                    label: "Coverage per Roll (sqft)",
                    value: Binding(
                        get: { settings.roofUnderlaymentSqFtPerRoll },
                        set: { settings.roofUnderlaymentSqFtPerRoll = $0 }
                    ),
                    range: 200...1000,
                    step: 50,
                    format: "%.0f"
                )

                SettingSliderRow(
                    label: "Waste Factor",
                    value: Binding(
                        get: { settings.roofUnderlaymentWasteFactor * 100 },
                        set: { settings.roofUnderlaymentWasteFactor = $0 / 100 }
                    ),
                    range: 5...20,
                    step: 1,
                    format: "%.0f%%"
                )
            }

            Section("Starter & Ridge Cap") {
                SettingSliderRow(
                    label: "Starter Strip (LF/bundle)",
                    value: Binding(
                        get: { settings.roofStarterStripLFPerBundle },
                        set: { settings.roofStarterStripLFPerBundle = $0 }
                    ),
                    range: 50...150,
                    step: 10,
                    format: "%.0f"
                )

                SettingSliderRow(
                    label: "Ridge Cap (LF/bundle)",
                    value: Binding(
                        get: { settings.roofRidgeCapLFPerBundle },
                        set: { settings.roofRidgeCapLFPerBundle = $0 }
                    ),
                    range: 20...50,
                    step: 5,
                    format: "%.0f"
                )
            }

            Section("Drip Edge & Flashing") {
                SettingSliderRow(
                    label: "Drip Edge (ft/piece)",
                    value: Binding(
                        get: { settings.roofDripEdgeLFPerPiece },
                        set: { settings.roofDripEdgeLFPerPiece = $0 }
                    ),
                    range: 8...12,
                    step: 1,
                    format: "%.0f"
                )

                SettingSliderRow(
                    label: "Valley (ft/piece)",
                    value: Binding(
                        get: { settings.roofValleyFlashingLFPerPiece },
                        set: { settings.roofValleyFlashingLFPerPiece = $0 }
                    ),
                    range: 8...12,
                    step: 1,
                    format: "%.0f"
                )
            }

            Section("Ice & Water Shield") {
                SettingSliderRow(
                    label: "Coverage per Roll (sqft)",
                    value: Binding(
                        get: { settings.roofIceWaterSqFtPerRoll },
                        set: { settings.roofIceWaterSqFtPerRoll = $0 }
                    ),
                    range: 150...300,
                    step: 25,
                    format: "%.0f"
                )

                SettingSliderRow(
                    label: "Eave Coverage Width (ft)",
                    value: Binding(
                        get: { settings.roofEaveIceWaterWidthFeet },
                        set: { settings.roofEaveIceWaterWidthFeet = $0 }
                    ),
                    range: 2...6,
                    step: 0.5,
                    format: "%.1f"
                )
            }

            Section("Auto-Apply Rules") {
                Toggle("Add Ice & Water for Valleys", isOn: Binding(
                    get: { settings.roofAutoAddIceWaterForValleys },
                    set: { settings.roofAutoAddIceWaterForValleys = $0 }
                ))

                Toggle("Add Ice & Water for Eaves", isOn: Binding(
                    get: { settings.roofAutoAddIceWaterForEaves },
                    set: { settings.roofAutoAddIceWaterForEaves = $0 }
                ))

                Toggle("Add Drip Edge for Rakes/Eaves", isOn: Binding(
                    get: { settings.roofAutoAddDripEdgeForRakesEaves },
                    set: { settings.roofAutoAddDripEdgeForRakesEaves = $0 }
                ))
            }

            Section {
                SettingSliderRow(
                    label: "Coil Nails (lbs/square)",
                    value: Binding(
                        get: { settings.roofCoilNailsLbsPerSquare },
                        set: { settings.roofCoilNailsLbsPerSquare = $0 }
                    ),
                    range: 1...4,
                    step: 0.5,
                    format: "%.1f"
                )

                SettingSliderRow(
                    label: "Cap Nails (per ridge LF)",
                    value: Binding(
                        get: { settings.roofCapNailsPerRidgeLF },
                        set: { settings.roofCapNailsPerRidgeLF = $0 }
                    ),
                    range: 2...8,
                    step: 1,
                    format: "%.0f"
                )
            } header: {
                Text("Nails")
            }

            Section {
                SettingSliderRow(
                    label: "Confidence Threshold",
                    value: Binding(
                        get: { settings.roofParseConfidenceThreshold },
                        set: { settings.roofParseConfidenceThreshold = $0 }
                    ),
                    range: 50...100,
                    step: 5,
                    format: "%.0f%%"
                )
            } header: {
                Text("PDF Parsing")
            } footer: {
                Text("Show verification warning when parse confidence is below this threshold")
            }

            // Presets Management
            Section {
                ForEach(presets.filter { $0.isBuiltIn }) { preset in
                    PresetManagementRow(
                        preset: preset,
                        onDuplicate: { duplicatePreset(preset) },
                        onExport: {
                            presetToExport = preset
                            showingExportShare = true
                        },
                        onEdit: nil,  // Can't edit built-in
                        onDelete: nil  // Can't delete built-in
                    )
                }
            } header: {
                Text("Built-in Presets")
            }

            let customPresets = presets.filter { !$0.isBuiltIn }
            if !customPresets.isEmpty {
                Section("Custom Presets") {
                    ForEach(customPresets) { preset in
                        PresetManagementRow(
                            preset: preset,
                            onDuplicate: { duplicatePreset(preset) },
                            onExport: {
                                presetToExport = preset
                                showingExportShare = true
                            },
                            onEdit: { editingPreset = preset },
                            onDelete: { deletePreset(preset) }
                        )
                    }
                }
            }

            Section {
                Button {
                    showingCreatePreset = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Preset")
                    }
                }

                Button {
                    showingImportPreset = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Preset")
                    }
                }
            }
        }
        .navigationTitle("Roof Settings")
        .sheet(isPresented: $showingCreatePreset) {
            PresetEditorView(preset: nil, onSave: { preset in
                modelContext.insert(preset)
                try? modelContext.save()
            })
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorView(preset: preset, onSave: { _ in
                try? modelContext.save()
            })
        }
        .fileImporter(
            isPresented: $showingImportPreset,
            allowedContentTypes: [.json, UTType(filenameExtension: "roofpreset") ?? .json]
        ) { result in
            handlePresetImport(result: result)
        }
        .sheet(isPresented: $showingExportShare) {
            if let preset = presetToExport,
               let data = preset.exportAsJSON() {
                ShareSheet(activityItems: [PresetFileWrapper(data: data, filename: "\(preset.name).roofpreset")])
            }
        }
    }

    // MARK: - Actions

    private func duplicatePreset(_ preset: RoofPresetTemplate) {
        let duplicate = RoofPresetTemplate()
        duplicate.name = preset.name + " (Copy)"
        duplicate.presetDescription = preset.presetDescription
        duplicate.factors = preset.factors
        duplicate.isBuiltIn = false

        modelContext.insert(duplicate)
        try? modelContext.save()
    }

    private func deletePreset(_ preset: RoofPresetTemplate) {
        guard !preset.isBuiltIn else { return }
        modelContext.delete(preset)
        try? modelContext.save()
    }

    private func handlePresetImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url),
               let preset = RoofPresetTemplate.importFromJSON(data) {
                modelContext.insert(preset)
                try? modelContext.save()
            }

        case .failure(let error):
            print("❌ Import failed: \(error)")
        }
    }
}

// MARK: - Setting Slider Row

struct SettingSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

// MARK: - Preset Management Row

struct PresetManagementRow: View {
    let preset: RoofPresetTemplate
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(preset.name)
                    if preset.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(2)
                    }
                }
                if !preset.presetDescription.isEmpty {
                    Text(preset.presetDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Menu {
                if let onEdit = onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }

                Button {
                    onExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                if let onDelete = onDelete {
                    Divider()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preset Editor

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let preset: RoofPresetTemplate?
    let onSave: (RoofPresetTemplate) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var factors = RoofPresetFactors()

    var isEditing: Bool { preset != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }

                Section("Shingles") {
                    SettingSliderRow(
                        label: "Bundles per Square",
                        value: $factors.bundlesPerSquare,
                        range: 0...4,
                        step: 0.5,
                        format: "%.1f"
                    )
                    SettingSliderRow(
                        label: "Waste Factor",
                        value: Binding(
                            get: { factors.shingleWasteFactor * 100 },
                            set: { factors.shingleWasteFactor = $0 / 100 }
                        ),
                        range: 5...25,
                        step: 1,
                        format: "%.0f%%"
                    )
                }

                Section("Underlayment") {
                    SettingSliderRow(
                        label: "Coverage (sqft/roll)",
                        value: $factors.underlaymentSqFtPerRoll,
                        range: 100...1000,
                        step: 50,
                        format: "%.0f"
                    )
                    Toggle("Synthetic Underlayment", isOn: $factors.usesSyntheticUnderlayment)
                }

                Section("Auto-Apply Rules") {
                    Toggle("Ice & Water for Valleys", isOn: $factors.requiresIceWaterForValleys)
                    Toggle("Ice & Water for Eaves", isOn: $factors.requiresIceWaterForEaves)
                    Toggle("Include Drip Edge", isOn: $factors.includesDripEdge)
                    Toggle("Include Ridge Cap", isOn: $factors.includesRidgeCap)
                }

                Section("General Waste Factor") {
                    SettingSliderRow(
                        label: "Overall Waste",
                        value: Binding(
                            get: { factors.wasteFactor * 100 },
                            set: { factors.wasteFactor = $0 / 100 }
                        ),
                        range: 5...30,
                        step: 1,
                        format: "%.0f%%"
                    )
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreset()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let preset = preset {
                    name = preset.name
                    description = preset.presetDescription
                    factors = preset.factors
                }
            }
        }
    }

    private func savePreset() {
        if let preset = preset {
            preset.name = name
            preset.presetDescription = description
            preset.factors = factors
            onSave(preset)
        } else {
            let newPreset = RoofPresetTemplate()
            newPreset.name = name
            newPreset.presetDescription = description
            newPreset.factors = factors
            newPreset.isBuiltIn = false
            onSave(newPreset)
        }
    }
}

// Note: ShareSheet is defined in Utilities/ShareSheet.swift - no need to duplicate here

// Wrapper for preset file export
class PresetFileWrapper: NSObject, UIActivityItemSource {
    let data: Data
    let filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Create a temp file for sharing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        return tempURL
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Roof Preset: \(filename)"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RoofSettingsView()
    }
    .modelContainer(for: [AppSettings.self, RoofPresetTemplate.self])
}
