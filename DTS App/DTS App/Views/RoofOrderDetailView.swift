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
import PDFKit

struct RoofOrderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var order: RoofMaterialOrder

    @Query private var settings: [AppSettings]
    @Query private var presets: [RoofPresetTemplate]

    @State private var showingEmailComposer = false
    @State private var showingShareSheet = false
    @State private var showingPresetPicker = false
    @State private var showingPDFViewer = false
    @State private var editingMeasurements = false
    @State private var selectedPresetId: UUID?
    @State private var showingAddMaterialSheet = false

    // Editable measurement copies
    @State private var editTotalSquares: String = ""
    @State private var editRidgeFeet: String = ""
    @State private var editValleyFeet: String = ""
    @State private var editRakeFeet: String = ""
    @State private var editEaveFeet: String = ""
    @State private var editHipFeet: String = ""
    
    // Custom shingle entry
    @State private var customShingleType: String = ""
    @State private var customShingleColor: String = ""
    
    // Common GAF shingle options
    private let shingleTypes = [
        "GAF Timberline HDZ",
        "GAF Timberline NS",
        "GAF Timberline AS II",
        "GAF Timberline CS",
        "GAF Royal Sovereign",
        "GAF Camelot II",
        "GAF Grand Sequoia",
        "Other"
    ]
    
    private let shingleColors = [
        "Charcoal",
        "Weathered Wood",
        "Hickory",
        "Barkwood",
        "Shakewood",
        "Pewter Gray",
        "Slate",
        "Mission Brown",
        "Hunter Green",
        "Birchwood",
        "Oyster Gray",
        "Patriot Red",
        "Other"
    ]
    
    // Check if current value is a preset or custom
    private var isCustomShingleType: Bool {
        !shingleTypes.contains(order.shingleType) || order.shingleType == "Other"
    }
    
    private var isCustomShingleColor: Bool {
        !shingleColors.contains(order.shingleColor) || order.shingleColor == "Other"
    }
    
    // Binding for shingle type picker that handles "Other"
    private var shingleTypePickerBinding: Binding<String> {
        Binding(
            get: {
                if shingleTypes.contains(order.shingleType) {
                    return order.shingleType
                } else {
                    return "Other"
                }
            },
            set: { newValue in
                if newValue == "Other" {
                    order.shingleType = "Other"
                    customShingleType = ""
                } else {
                    order.shingleType = newValue
                    customShingleType = ""
                }
            }
        )
    }
    
    // Binding for shingle color picker that handles "Other"
    private var shingleColorPickerBinding: Binding<String> {
        Binding(
            get: {
                if shingleColors.contains(order.shingleColor) {
                    return order.shingleColor
                } else {
                    return "Other"
                }
            },
            set: { newValue in
                if newValue == "Other" {
                    order.shingleColor = "Other"
                    customShingleColor = ""
                } else {
                    order.shingleColor = newValue
                    customShingleColor = ""
                }
            }
        )
    }

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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Please Verify Measurements")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("Confidence: \(Int(order.parseConfidence))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Show specific reasons for low confidence
                        if !order.parseWarnings.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Issues Found:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(order.parseWarnings, id: \.self) { warning in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundColor(.orange)
                                            .padding(.top, 5)
                                        Text(warning)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
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
            }
            
            // Shingle Selection
            Section("Shingle Selection") {
                Picker("Shingle Type", selection: shingleTypePickerBinding) {
                    ForEach(shingleTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                
                if isCustomShingleType {
                    TextField("Enter custom shingle type", text: $customShingleType)
                        .onSubmit {
                            if !customShingleType.isEmpty {
                                order.shingleType = customShingleType
                            }
                        }
                        .onChange(of: customShingleType) { _, newValue in
                            if !newValue.isEmpty {
                                order.shingleType = newValue
                            }
                        }
                        .onAppear {
                            // Load existing custom value
                            if !shingleTypes.contains(order.shingleType) && order.shingleType != "Other" {
                                customShingleType = order.shingleType
                            }
                        }
                }
                
                Picker("Color", selection: shingleColorPickerBinding) {
                    ForEach(shingleColors, id: \.self) { color in
                        Text(color).tag(color)
                    }
                }
                
                if isCustomShingleColor {
                    TextField("Enter custom color", text: $customShingleColor)
                        .onSubmit {
                            if !customShingleColor.isEmpty {
                                order.shingleColor = customShingleColor
                            }
                        }
                        .onChange(of: customShingleColor) { _, newValue in
                            if !newValue.isEmpty {
                                order.shingleColor = newValue
                            }
                        }
                        .onAppear {
                            // Load existing custom value
                            if !shingleColors.contains(order.shingleColor) && order.shingleColor != "Other" {
                                customShingleColor = order.shingleColor
                            }
                        }
                }
            }
            
            // PDF Format Info
            Section {
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
                
                // View Original PDF button
                if let pdfURL = order.pdfURL(in: SharedContainerHelper.roofPDFStorageDirectory),
                   FileManager.default.fileExists(atPath: pdfURL.path) {
                    Button {
                        showingPDFViewer = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.red)
                            Text("View Original PDF")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
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
                    // Show squares with 10% waste factor
                    let squaresWithWaste = order.measurements.totalSquares * 1.10
                    MeasurementDisplayRow(label: "Total Squares (w/ 10% waste)", value: squaresWithWaste, unit: "SQ", format: "%.2f")
                    MeasurementDisplayRow(label: "Total Area", value: order.measurements.totalSqFt, unit: "sqft", format: "%.0f")
                    MeasurementDisplayRow(label: "Ridge", value: order.measurements.ridgeFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Valley", value: order.measurements.valleyFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Rake", value: order.measurements.rakeFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Eave", value: order.measurements.eaveFeet, unit: "LF", format: "%.1f")
                    MeasurementDisplayRow(label: "Hip", value: order.measurements.hipFeet, unit: "LF", format: "%.1f")
                    if order.measurements.stepFlashingFeet > 0 {
                        MeasurementDisplayRow(label: "Step Flashing", value: order.measurements.stepFlashingFeet, unit: "LF", format: "%.1f")
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

            // Roof Options Section
            Section {
                Toggle(isOn: $order.hasSprayFoamInsulation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spray Foam Insulation")
                        Text("Skip ridge vent - conditioned attic space")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: order.hasSprayFoamInsulation) { _, _ in
                    recalculateMaterials()
                }
            } header: {
                Text("Roof Options")
            } footer: {
                if order.hasSprayFoamInsulation {
                    Text("Ridge vent excluded - spray foam creates a conditioned attic that doesn't require ventilation.")
                        .foregroundColor(.orange)
                }
            }
            
            // Chimney Flashing Section
            Section {
                Stepper(value: $order.chimneyCount, in: 0...10) {
                    HStack {
                        Text("Number of Chimneys")
                        Spacer()
                        Text("\(order.chimneyCount)")
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: order.chimneyCount) { _, _ in
                    recalculateMaterials()
                }
                
                if order.chimneyCount > 0 {
                    Toggle(isOn: $order.chimneyAgainstBrick) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brick/Masonry Chimney")
                            Text("Adds counter flashing for masonry")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: order.chimneyAgainstBrick) { _, _ in
                        recalculateMaterials()
                    }
                    
                    Toggle(isOn: $order.chimneyNeedsCricket) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Needs Cricket")
                            Text("Adds framing and decking to divert water")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: order.chimneyNeedsCricket) { _, _ in
                        recalculateMaterials()
                    }
                    
                    HStack {
                        Text("Avg Chimney Width")
                        Spacer()
                        TextField("Width", value: $order.chimneyWidthFeet, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("ft")
                            .foregroundColor(.secondary)
                    }
                    .onChange(of: order.chimneyWidthFeet) { _, _ in
                        recalculateMaterials()
                    }
                }
            } header: {
                Text("Chimney Flashing")
            } footer: {
                if order.chimneyCount > 0 {
                    Text("Each chimney needs step flashing on sides and apron at front.\(order.chimneyNeedsCricket ? " Cricket framing and decking will be added." : "")")
                        .foregroundColor(.secondary)
                }
            }
            
            // Wall/Dormer Flashing Section (only show if step flashing detected)
            if order.measurements.stepFlashingFeet > 0 {
                Section {
                    Toggle(isOn: $order.wallFlashingAgainstBrick) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wall/Dormer Against Brick")
                            Text("Adds counter flashing for masonry walls")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: order.wallFlashingAgainstBrick) { _, _ in
                        recalculateMaterials()
                    }
                } header: {
                    Text("Wall/Dormer Flashing")
                } footer: {
                    Text("\(String(format: "%.0f", order.measurements.stepFlashingFeet)) LF of step flashing detected. If against brick/masonry, counter flashing will be added.")
                        .foregroundColor(.secondary)
                }
            }
            
            // OSB Decking Section
            Section {
                Stepper(value: $order.osbSheetsNeeded, in: 0...100) {
                    HStack {
                        Text("OSB Sheets (7/16\" 4'x8')")
                        Spacer()
                        Text("\(order.osbSheetsNeeded)")
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: order.osbSheetsNeeded) { _, _ in
                    recalculateMaterials()
                }
                
                if order.osbSheetsNeeded > 0 {
                    TextField("OSB Notes (optional)", text: $order.osbNotes)
                        .onChange(of: order.osbNotes) { _, _ in
                            recalculateMaterials()
                        }
                }
            } header: {
                Text("Decking Replacement")
            } footer: {
                if order.osbSheetsNeeded > 0 {
                    Text("OSB will be added to materials list for deck replacement/repair.")
                        .foregroundColor(.secondary)
                }
            }

            // Materials Section
            Section {
                ForEach(order.materials) { material in
                    MaterialRowView(
                        material: material,
                        isCustom: material.isCustom,
                        onQuantityChange: { newQuantity in
                            updateMaterialQuantity(materialId: material.id, quantity: newQuantity)
                        },
                        onReset: {
                            resetMaterialToCalculated(materialId: material.id)
                        },
                        onDelete: material.isCustom ? {
                            deleteCustomMaterial(materialId: material.id)
                        } : nil
                    )
                }
                
                // Add custom material button
                Button {
                    showingAddMaterialSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add Custom Material")
                    }
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
                // Primary email button (if Mail is available)
                if MFMailComposeViewController.canSendMail() {
                    Button {
                        showingEmailComposer = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Email Order to Supplier")
                        }
                    }
                }

                // Share button (always available - works on simulator too)
                Button {
                    // Recalculate to ensure materials reflect latest changes
                    recalculateMaterials()
                    showingShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Order")
                    }
                }

                // Copy to clipboard
                Button {
                    // Recalculate to ensure materials reflect latest changes
                    recalculateMaterials()
                    let orderText = RoofMaterialCalculator.generateEmailBody(order: order)
                    UIPasteboard.general.string = orderText
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy to Clipboard")
                    }
                }
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: order.projectName) { _, _ in try? modelContext.save() }
        .onChange(of: order.clientName) { _, _ in try? modelContext.save() }
        .onChange(of: order.address) { _, _ in try? modelContext.save() }
        .onChange(of: order.notes) { _, _ in try? modelContext.save() }
        .onChange(of: order.statusRaw) { _, _ in try? modelContext.save() }
        .onChange(of: order.shingleType) { _, _ in try? modelContext.save() }
        .onChange(of: order.shingleColor) { _, _ in try? modelContext.save() }
        .sheet(isPresented: $showingEmailComposer) {
            MailComposerView(
                subject: RoofMaterialCalculator.generateEmailSubject(order: order),
                body: RoofMaterialCalculator.generateEmailBody(order: order),
                recipients: {
                    // Use order-specific email, or fall back to default
                    let email = order.supplierEmail ?? currentSettings.roofDefaultSupplierEmail
                    return email.isEmpty ? [] : [email]
                }(),
                attachments: getPDFAttachment()
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: getShareItems())
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
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfURL = order.pdfURL(in: SharedContainerHelper.roofPDFStorageDirectory) {
                PDFViewerView(
                    pdfURL: pdfURL,
                    title: order.pdfFilename ?? "Roof PDF"
                )
            }
        }
        .sheet(isPresented: $showingAddMaterialSheet) {
            AddCustomMaterialSheet { material in
                order.addCustomMaterial(material)
                try? modelContext.save()
            }
        }
        .onAppear {
            selectedPresetId = order.presetId
        }
    }
    
    // MARK: - Custom Material Helpers
    
    private func deleteCustomMaterial(materialId: UUID) {
        order.removeMaterial(id: materialId)
        try? modelContext.save()
    }
    
    // MARK: - PDF Attachment Helpers
    
    /// Get the PDF URL for the order
    private func getPDFURL() -> URL? {
        guard let _ = order.pdfFilename else { return nil }
        return order.pdfURL(in: SharedContainerHelper.roofPDFStorageDirectory)
    }
    
    /// Get PDF data and info for email attachment
    private func getPDFAttachment() -> [(data: Data, mimeType: String, filename: String)] {
        guard let pdfURL = getPDFURL(),
              let pdfData = try? Data(contentsOf: pdfURL) else {
            return []
        }
        
        let displayName = order.originalPDFName ?? order.pdfFilename ?? "roof_measurements.pdf"
        return [(data: pdfData, mimeType: "application/pdf", filename: displayName)]
    }
    
    /// Get items to share (text + optional PDF)
    private func getShareItems() -> [Any] {
        var items: [Any] = []
        
        // Always include the text version (works with Messages, Notes, etc.)
        let orderText = RoofMaterialCalculator.generateEmailBody(order: order)
        items.append(orderText)
        
        // Also include the combined PDF if available (works with Mail, Files, etc.)
        if let combinedPDF = createCombinedPDF() {
            items.append(combinedPDF)
        } else if let pdfURL = getPDFURL() {
            // Fallback to just the original PDF
            items.append(pdfURL)
        }
        
        return items
    }
    
    /// Create a combined PDF with original measurements + material order page
    private func createCombinedPDF() -> URL? {
        guard let originalURL = getPDFURL(),
              let originalDocument = PDFDocument(url: originalURL) else {
            return nil
        }
        
        // Get page size from original PDF to match
        let pageSize: CGSize
        if let firstPage = originalDocument.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            pageSize = bounds.size
        } else {
            pageSize = CGSize(width: 612, height: 792) // Default US Letter
        }
        
        // Create the material order page matching original size
        guard let orderPage = createMaterialOrderPDFPage(pageSize: pageSize) else {
            return nil
        }
        
        // Add material order page to the document
        originalDocument.insert(orderPage, at: originalDocument.pageCount)
        
        // Save to temp file for sharing with timestamp to prevent caching
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        let baseName = order.projectName.isEmpty ? "Roof_Order" : order.projectName.replacingOccurrences(of: " ", with: "_")
        let filename = "\(baseName)_\(timestamp)_materials.pdf"
        let outputURL = tempDir.appendingPathComponent(filename)
        
        // Clean up old temp files for this order
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(baseName) && file.lastPathComponent.hasSuffix("_materials.pdf") {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        if originalDocument.write(to: outputURL) {
            print("✅ Created combined PDF at: \(outputURL.path)")
            return outputURL
        }
        
        return nil
    }
    
    /// Create a PDF page containing the material order
    private func createMaterialOrderPDFPage(pageSize: CGSize? = nil) -> PDFPage? {
        // Use provided size or default to US Letter
        let pageWidth: CGFloat = pageSize?.width ?? 612
        let pageHeight: CGFloat = pageSize?.height ?? 792
        
        // Calculate scale factor based on page size (relative to US Letter)
        let scaleFactor: CGFloat = min(pageWidth / 612, pageHeight / 792)
        
        // Scale margin based on page size
        let margin: CGFloat = 50 * scaleFactor
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            
            // Scaled font sizes
            let titleFontSize: CGFloat = 24 * scaleFactor
            let headerFontSize: CGFloat = 16 * scaleFactor
            let bodyFontSize: CGFloat = 14 * scaleFactor
            let itemFontSize: CGFloat = 13 * scaleFactor
            let footerFontSize: CGFloat = 11 * scaleFactor
            let lineSpacing: CGFloat = 22 * scaleFactor
            let sectionSpacing: CGFloat = 35 * scaleFactor
            
            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: titleFontSize)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            
            let title = "MATERIAL ORDER"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += sectionSpacing
            
            // Project info
            let headerFont = UIFont.boldSystemFont(ofSize: headerFontSize)
            let bodyFont = UIFont.systemFont(ofSize: bodyFontSize)
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.black]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
            
            if !order.projectName.isEmpty {
                "Project: \(order.projectName)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttrs)
                yPosition += lineSpacing
            }
            
            if !order.address.isEmpty {
                "Address: \(order.address)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttrs)
                yPosition += lineSpacing
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            "Date: \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttrs)
            yPosition += sectionSpacing
            
            // Shingle info
            "Shingle: \(order.shingleType) - \(order.shingleColor)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttrs)
            yPosition += lineSpacing + 5 * scaleFactor
            
            // Draw separator line
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: yPosition))
            linePath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor.gray.setStroke()
            linePath.lineWidth = 1.5 * scaleFactor
            linePath.stroke()
            yPosition += 20 * scaleFactor
            
            // Materials header
            "MATERIALS LIST".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttrs)
            yPosition += lineSpacing + 5 * scaleFactor
            
            // Column headers
            let col1 = margin
            let col2 = pageWidth - margin - (120 * scaleFactor)
            
            let columnHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: itemFontSize),
                .foregroundColor: UIColor.darkGray
            ]
            "Item".draw(at: CGPoint(x: col1, y: yPosition), withAttributes: columnHeaderAttrs)
            "Qty".draw(at: CGPoint(x: col2, y: yPosition), withAttributes: columnHeaderAttrs)
            yPosition += lineSpacing
            
            // Materials list
            let itemFont = UIFont.systemFont(ofSize: itemFontSize)
            let itemAttrs: [NSAttributedString.Key: Any] = [.font: itemFont, .foregroundColor: UIColor.black]
            let qtyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: itemFontSize), .foregroundColor: UIColor.black]
            
            for material in order.materials {
                // Item name (truncate if too long)
                let maxNameWidth = col2 - col1 - (20 * scaleFactor)
                var name = material.name
                let nameSize = (name as NSString).size(withAttributes: itemAttrs)
                if nameSize.width > maxNameWidth {
                    while (name as NSString).size(withAttributes: itemAttrs).width > maxNameWidth && name.count > 10 {
                        name = String(name.dropLast())
                    }
                    name += "..."
                }
                name.draw(at: CGPoint(x: col1, y: yPosition), withAttributes: itemAttrs)
                
                // Quantity
                let qty = "\(Int(material.quantity)) \(material.unit)"
                qty.draw(at: CGPoint(x: col2, y: yPosition), withAttributes: qtyAttrs)
                
                yPosition += lineSpacing * 0.9
                
                // Check if we need a new page (leave room for footer)
                if yPosition > pageHeight - (100 * scaleFactor) {
                    yPosition = margin
                    context.beginPage()
                }
            }
            
            // Add note about spray foam if applicable
            if order.hasSprayFoamInsulation {
                yPosition += 15 * scaleFactor
                let noteAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: footerFontSize),
                    .foregroundColor: UIColor.orange
                ]
                "Note: Ridge vent excluded - spray foam attic".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: noteAttrs)
                yPosition += lineSpacing
            }
            
            // Footer
            let footerY = pageHeight - (60 * scaleFactor)
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: footerFontSize),
                .foregroundColor: UIColor.gray
            ]
            "Generated by DTS App".draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)
        }
        
        // Create PDFDocument from data and get the page(s)
        guard let pdfDocument = PDFDocument(data: pdfData),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }
        
        return page
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
    var isCustom: Bool = false
    let onQuantityChange: (Double?) -> Void
    let onReset: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isEditing = false
    @State private var editQuantity: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(material.name)
                    .font(.headline)

                if isCustom {
                    Text("Custom")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else if material.isManuallyAdjusted {
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

            HStack {
                if material.isManuallyAdjusted && !isCustom {
                    Text("Calculated: \(Int(ceil(material.calculatedQuantity))) \(material.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Reset") {
                        onReset()
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                }
                
                if let onDelete = onDelete {
                    Spacer()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Custom Material Sheet

struct AddCustomMaterialSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (RoofMaterialLineItem) -> Void
    
    @State private var materialName: String = ""
    @State private var quantity: String = ""
    @State private var selectedUnit: String = "pieces"
    @State private var notes: String = ""
    
    private let unitOptions = ["pieces", "bundles", "rolls", "sheets", "boxes", "bags", "lbs", "ft", "sqft"]
    
    var isValid: Bool {
        !materialName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(quantity) != nil &&
        Double(quantity)! > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Material Details") {
                    TextField("Material Name", text: $materialName)
                        .autocapitalization(.words)
                    
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 100)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(unitOptions, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("e.g., for valley repair", text: $notes)
                }
            }
            .navigationTitle("Add Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMaterial()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func addMaterial() {
        guard let qty = Double(quantity), qty > 0 else { return }
        
        let material = RoofMaterialLineItem.custom(
            name: materialName.trimmingCharacters(in: .whitespaces),
            quantity: qty,
            unit: selectedUnit,
            category: "Custom",
            notes: notes.isEmpty ? nil : notes
        )
        
        onAdd(material)
        dismiss()
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
    var attachments: [(data: Data, mimeType: String, filename: String)] = []
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        
        // Add attachments
        for attachment in attachments {
            composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.filename)
        }
        
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
