//
//  RoofOrderDetailView.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Detailed view for roof order with editable measurements and materials
//

import SwiftUI
import SwiftData
import MessageUI

struct RoofOrderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var order: RoofMaterialOrder
    
    @Query private var settings: [AppSettings]
    @Query private var presets: [RoofPresetTemplate]
    
    @State private var showingEmailComposer = false
    @State private var showingPresetPicker = false
    @State private var editingMeasurements = false
    @State private var selectedPresetId: UUID?
    
    // Editable measurement copies
    @State private var editTotalSquares: String = ""
    @State private var editRidgeFeet: String = ""
    @State private var editValleyFeet: String = ""
    @State private var editRakeFeet: String = ""
    @State private var editEaveFeet: String = ""
    @State private var editHipFeet: String = ""
    
    var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }
    
    var selectedPreset: RoofPresetTemplate? {
        presets.first { $0.id == selectedPresetId }
    }
    
    var body: some View {
        List {
            // Confidence Warning Banner
            if order.needsVerification(threshold: currentSettings.roofParseConfidenceThreshold) {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Please Verify Measurements")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Confidence: \(Int(order.parseConfidence))% - Some values may need manual correction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Project Info
            Section("Project Information") {
                TextField("Project Name", text: $order.projectName)
                TextField("Client Name", text: $order.clientName)
                TextField("Address", text: $order.address)
                TextField("Supplier Email", text: Binding(
                    get: { order.supplierEmail ?? currentSettings.roofDefaultSupplierEmail },
                    set: { order.supplierEmail = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                
                if let format = order.detectedFormat {
                    HStack {
                        Text("PDF Format")
                        Spacer()
                        Text(format)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Picker("Status", selection: $order.statusRaw) {
                        ForEach(RoofOrderStatus.allCases, id: \.rawValue) { status in
                            Text(status.rawValue.capitalized).tag(status.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Measurements Section
            Section {
                if editingMeasurements {
                    MeasurementEditRow(label: "Total Squares", value: $editTotalSquares, unit: "SQ")
                    MeasurementEditRow(label: "Ridge", value: $editRidgeFeet, unit: "LF")
                    MeasurementEditRow(label: "Valley", value: $editValleyFeet, unit: "LF")
                    MeasurementEditRow(label: "Rake", value: $editRakeFeet, unit: "LF")
                    MeasurementEditRow(label: "Eave", value: $editEaveFeet, unit: "LF")
                    MeasurementEditRow(label: "Hip", value: $editHipFeet, unit: "LF")
                    
                    Button("Save & Recalculate") {
                        saveMeasurementsAndRecalculate()
                    }
                    .foregroundColor(.blue)
                } else {
                    MeasurementDisplayRow(label: "Total Squares", value: order.measurements.totalSquares, unit: "SQ", format: "%.2f")
                    MeasurementDisplayRow(label: "Total Area", value: order.measurements.totalSqFt, unit: "sqft", format: "%.0f")
                    MeasurementDisplayRow(label: "Ridge", value: order.measurements.ridgeFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Valley", value: order.measurements.valleyFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Rake", value: order.measurements.rakeFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Eave", value: order.measurements.eaveFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Hip", value: order.measurements.hipFeet, unit: "LF", format: "%.1f")
                    
                    if let pitch = order.measurements.pitch {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(pitch)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Measurements")
                    Spacer()
                    Button(editingMeasurements ? "Cancel" : "Edit") {
                        if editingMeasurements {
                            editingMeasurements = false
                        } else {
                            loadMeasurementsForEditing()
                            editingMeasurements = true
                        }
                    }
                    .font(.caption)
                }
            }
            
            // Preset Selector
            Section("Calculation Preset") {
                Button {
                    showingPresetPicker = true
                } label: {
                    HStack {
                        Text(selectedPreset?.name ?? order.presetName ?? "Default Settings")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Materials Section
            Section {
                ForEach(order.materials) { material in
                    MaterialRowView(
                        material: material,
                        onQuantityChange: { newQuantity in
                            updateMaterialQuantity(materialId: material.id, quantity: newQuantity)
                        },
                        onReset: {
                            resetMaterialToCalculated(materialId: material.id)
                        }
                    )
                }
                
                if order.materials.contains(where: { $0.isManuallyAdjusted }) {
                    Button("Reset All to Calculated") {
                        order.resetAllToCalculated()
                        try? modelContext.save()
                    }
                    .foregroundColor(.orange)
                }
            } header: {
                HStack {
                    Text("Materials")
                    Spacer()
                    Button("Recalculate") {
                        recalculateMaterials()
                    }
                    .font(.caption)
                }
            }
            
            // Notes
            Section("Notes") {
                TextEditor(text: $order.notes)
                    .frame(minHeight: 80)
            }
            
            // Actions
            Section {
                Button {
                    showingEmailComposer = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Email Order to Supplier")
                    }
                }
                .disabled(!MFMailComposeViewController.canSendMail())
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: order.projectName) { _, _ in try? modelContext.save() }
        .onChange(of: order.clientName) { _, _ in try? modelContext.save() }
        .onChange(of: order.address) { _, _ in try? modelContext.save() }
        .onChange(of: order.notes) { _, _ in try? modelContext.save() }
        .onChange(of: order.statusRaw) { _, _ in try? modelContext.save() }
        .sheet(isPresented: $showingEmailComposer) {
            MailComposerView(
                subject: RoofMaterialCalculator.generateEmailSubject(order: order),
                body: RoofMaterialCalculator.generateEmailBody(order: order),
                recipients: {
                    // Use order-specific email, or fall back to default
                    let email = order.supplierEmail ?? currentSettings.roofDefaultSupplierEmail
                    return email.isEmpty ? [] : [email]
                }()
            )
        }
        .sheet(isPresented: $showingPresetPicker) {
            PresetPickerView(
                presets: presets,
                selectedId: $selectedPresetId,
                onSelect: { preset in
                    applyPreset(preset)
                }
            )
        }
        .onAppear {
            selectedPresetId = order.presetId
        }
    }
    
    // MARK: - Actions
    
    private func loadMeasurementsForEditing() {
        let m = order.measurements
        editTotalSquares = String(format: "%.2f", m.totalSquares)
        editRidgeFeet = String(format: "%.1f", m.ridgeFeet)
        editValleyFeet = String(format: "%.1f", m.valleyFeet)
        editRakeFeet = String(format: "%.1f", m.rakeFeet)
        editEaveFeet = String(format: "%.1f", m.eaveFeet)
        editHipFeet = String(format: "%.1f", m.hipFeet)
    }
    
    private func saveMeasurementsAndRecalculate() {
        var m = order.measurements
        m.totalSquares = Double(editTotalSquares) ?? m.totalSquares
        m.totalSqFt = m.totalSquares * 100
        m.ridgeFeet = Double(editRidgeFeet) ?? m.ridgeFeet
        m.valleyFeet = Double(editValleyFeet) ?? m.valleyFeet
        m.rakeFeet = Double(editRakeFeet) ?? m.rakeFeet
        m.eaveFeet = Double(editEaveFeet) ?? m.eaveFeet
        m.hipFeet = Double(editHipFeet) ?? m.hipFeet
        
        order.measurements = m
        editingMeasurements = false
        
        recalculateMaterials()
    }
    
    private func recalculateMaterials() {
        order.materials = RoofMaterialCalculator.recalculate(
            order: order,
            settings: currentSettings,
            preset: selectedPreset
        )
        try? modelContext.save()
    }
    
    private func updateMaterialQuantity(materialId: UUID, quantity: Double?) {
        order.updateMaterialQuantity(id: materialId, quantity: quantity)
        try? modelContext.save()
    }
    
    private func resetMaterialToCalculated(materialId: UUID) {
        order.updateMaterialQuantity(id: materialId, quantity: nil)
        try? modelContext.save()
    }
    
    private func applyPreset(_ preset: RoofPresetTemplate?) {
        if let preset = preset {
            order.presetId = preset.id
            order.presetName = preset.name
        } else {
            order.presetId = nil
            order.presetName = nil
        }
        recalculateMaterials()
    }
}

// MARK: - Supporting Views

struct MeasurementDisplayRow: View {
    let label: String
    let value: Double
    let unit: String
    let format: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(String(format: format, value)) \(unit)")
                .foregroundColor(.secondary)
        }
    }
}

struct MeasurementEditRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}

struct MaterialRowView: View {
    let material: RoofMaterialLineItem
    let onQuantityChange: (Double?) -> Void
    let onReset: () -> Void
    
    @State private var isEditing = false
    @State private var editQuantity: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(material.name)
                    .font(.headline)
                
                if material.isManuallyAdjusted {
                    Text("Manual")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if isEditing {
                    HStack {
                        TextField("Qty", text: $editQuantity)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        
                        Button("Save") {
                            if let qty = Double(editQuantity) {
                                onQuantityChange(qty)
                            }
                            isEditing = false
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        editQuantity = String(format: "%.0f", material.quantity)
                        isEditing = true
                    } label: {
                        Text("\(Int(ceil(material.quantity))) \(material.unit)")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let description = material.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = material.notes {
                Text(notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            if material.isManuallyAdjusted {
                HStack {
                    Text("Calculated: \(Int(ceil(material.calculatedQuantity))) \(material.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button("Reset") {
                        onReset()
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PresetPickerView: View {
    let presets: [RoofPresetTemplate]
    @Binding var selectedId: UUID?
    let onSelect: (RoofPresetTemplate?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedId = nil
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("Default Settings")
                            Spacer()
                            if selectedId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("Built-in Presets") {
                    ForEach(presets.filter { $0.isBuiltIn }) { preset in
                        PresetRow(preset: preset, isSelected: selectedId == preset.id) {
                            selectedId = preset.id
                            onSelect(preset)
                            dismiss()
                        }
                    }
                }
                
                let customPresets = presets.filter { !$0.isBuiltIn }
                if !customPresets.isEmpty {
                    Section("Custom Presets") {
                        ForEach(customPresets) { preset in
                            PresetRow(preset: preset, isSelected: selectedId == preset.id) {
                                selectedId = preset.id
                                onSelect(preset)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PresetRow: View {
    let preset: RoofPresetTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .foregroundColor(.primary)
                    if !preset.presetDescription.isEmpty {
                        Text(preset.presetDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RoofOrderDetailView(order: {
            let order = RoofMaterialOrder()
            order.projectName = "123 Main Street"
            order.clientName = "John Doe"
            order.parseConfidence = 75
            order.detectedFormat = "iRoof"
            var m = RoofMeasurements()
            m.totalSquares = 24.5
            m.totalSqFt = 2450
            m.ridgeFeet = 45
            m.valleyFeet = 20
            m.rakeFeet = 60
            m.eaveFeet = 80
            order.measurements = m
            return order
        }())
    }
    .modelContainer(for: [RoofMaterialOrder.self, AppSettings.self, RoofPresetTemplate.self])
}
