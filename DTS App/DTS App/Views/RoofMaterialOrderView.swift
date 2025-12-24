//
//  RoofMaterialOrderView.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Main view for roof material orders - list, import, and cleanup
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoofMaterialOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoofMaterialOrder.createdAt, order: .reverse) private var orders: [RoofMaterialOrder]
    @Query private var settings: [AppSettings]
    @Query private var allPresets: [RoofPresetTemplate]
    
    private var builtInPresets: [RoofPresetTemplate] {
        allPresets.filter { $0.isBuiltIn }
    }
    
    @State private var showingFilePicker = false
    @State private var showingCleanup = false
    @State private var selectedOrder: RoofMaterialOrder?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingImportError = false
    
    var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Import Section
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Roof Measurement PDF")
                                    .foregroundColor(.primary)
                                Text("iRoof, EagleView, Hover, and more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isImporting {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isImporting)
                }
                
                // Orders List
                if orders.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Roof Orders")
                                .font(.headline)
                            Text("Import a roof measurement PDF to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section("Recent Orders") {
                        ForEach(orders) { order in
                            NavigationLink {
                                RoofOrderDetailView(order: order)
                            } label: {
                                RoofOrderRowView(order: order)
                            }
                        }
                        .onDelete(perform: deleteOrders)
                    }
                }
                
                // Storage Section
                Section {
                    Button {
                        showingCleanup = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle")
                                .foregroundColor(.orange)
                            Text("Manage PDF Storage")
                            Spacer()
                            Text(SharedContainerHelper.formatBytes(SharedContainerHelper.totalRoofPDFSize))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Roof Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RoofSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf]
            ) { result in
                handlePDFImport(result: result)
            }
            .sheet(isPresented: $showingCleanup) {
                RoofPDFCleanupView()
            }
            .sheet(item: $selectedOrder) { order in
                NavigationStack {
                    RoofOrderDetailView(order: order)
                }
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Unknown error occurred")
            }
            .onAppear {
                ensureBuiltInPresetsExist()
            }
        }
    }
    
    private func handlePDFImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            isImporting = true
            
            Task {
                await importPDF(from: url)
                await MainActor.run {
                    isImporting = false
                }
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }
    
    private func importPDF(from url: URL) async {
        // Copy PDF to shared storage
        guard let savedURL = SharedContainerHelper.copyRoofPDF(from: url) else {
            await MainActor.run {
                importError = "Failed to save PDF file"
                showingImportError = true
            }
            return
        }
        
        // Parse PDF
        let parseResult = RoofPDFParser.parse(url: savedURL)
        
        // Create order
        await MainActor.run {
            let order = RoofMaterialOrder()
            order.pdfFilename = savedURL.lastPathComponent
            order.originalPDFName = url.lastPathComponent
            order.parseConfidence = parseResult.confidence
            order.detectedFormat = parseResult.detectedFormat
            order.parseWarnings = parseResult.warnings
            order.measurements = parseResult.measurements
            
            // Extract project name from filename
            let cleanName = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            order.projectName = cleanName
            
            // Calculate initial materials
            order.materials = RoofMaterialCalculator.calculateMaterials(
                from: parseResult.measurements,
                settings: currentSettings
            )
            
            modelContext.insert(order)
            try? modelContext.save()
            
            // Navigate to detail view
            selectedOrder = order
        }
    }
    
    private func deleteOrders(at offsets: IndexSet) {
        for index in offsets {
            let order = orders[index]
            // Delete associated PDF
            if let filename = order.pdfFilename {
                let pdfURL = SharedContainerHelper.roofPDFStorageDirectory.appendingPathComponent(filename)
                SharedContainerHelper.deleteRoofPDF(at: pdfURL)
            }
            modelContext.delete(order)
        }
        try? modelContext.save()
    }
    
    private func ensureBuiltInPresetsExist() {
        // Check if built-in presets exist, create if not
        if builtInPresets.isEmpty {
            let presets = RoofPresetTemplate.createBuiltInPresets()
            for preset in presets {
                modelContext.insert(preset)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Row View

struct RoofOrderRowView: View {
    let order: RoofMaterialOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(order.projectName.isEmpty ? "Unnamed Project" : order.projectName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                RoofOrderStatusBadge(status: order.status)
            }
            
            HStack {
                if order.measurements.totalSquares > 0 {
                    Text("\(String(format: "%.1f", order.measurements.totalSquares)) SQ")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if let format = order.detectedFormat {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(format)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(order.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Confidence warning
            if order.parseConfidence < 80 && order.parseConfidence > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Needs verification")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct RoofOrderStatusBadge: View {
    let status: RoofOrderStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }
    
    var backgroundColor: Color {
        switch status {
        case .draft: return .gray.opacity(0.2)
        case .ordered: return .blue.opacity(0.2)
        case .completed: return .green.opacity(0.2)
        }
    }
    
    var foregroundColor: Color {
        switch status {
        case .draft: return .gray
        case .ordered: return .blue
        case .completed: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    RoofMaterialOrderView()
        .modelContainer(for: [RoofMaterialOrder.self, AppSettings.self, RoofPresetTemplate.self])
}
