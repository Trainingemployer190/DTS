//
//  RoofPDFCleanupView.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Manage and cleanup orphaned roof measurement PDFs
//

import SwiftUI
import SwiftData

struct RoofPDFCleanupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var orders: [RoofMaterialOrder]
    
    @State private var allPDFs: [PDFFileInfo] = []
    @State private var selectedPDFs: Set<String> = []
    @State private var isLoading = true
    @State private var showingDeleteConfirmation = false
    
    var validFilenames: Set<String> {
        Set(orders.compactMap { $0.pdfFilename })
    }
    
    var orphanedPDFs: [PDFFileInfo] {
        allPDFs.filter { !validFilenames.contains($0.filename) }
    }
    
    var linkedPDFs: [PDFFileInfo] {
        allPDFs.filter { validFilenames.contains($0.filename) }
    }
    
    var totalSize: Int64 {
        allPDFs.reduce(0) { $0 + $1.size }
    }
    
    var orphanedSize: Int64 {
        orphanedPDFs.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        allPDFs.filter { selectedPDFs.contains($0.filename) }.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Storage Summary
                Section {
                    HStack {
                        Label("Total PDF Storage", systemImage: "doc.fill")
                        Spacer()
                        Text(SharedContainerHelper.formatBytes(totalSize))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Linked to Orders", systemImage: "link")
                        Spacer()
                        Text("\(linkedPDFs.count) files")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Orphaned Files", systemImage: "exclamationmark.triangle")
                            .foregroundColor(orphanedPDFs.isEmpty ? .primary : .orange)
                        Spacer()
                        Text("\(orphanedPDFs.count) files (\(SharedContainerHelper.formatBytes(orphanedSize)))")
                            .foregroundColor(orphanedPDFs.isEmpty ? .secondary : .orange)
                    }
                } header: {
                    Text("Storage Summary")
                }
                
                // Quick Actions
                if !orphanedPDFs.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            selectedPDFs = Set(orphanedPDFs.map { $0.filename })
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete All Orphaned PDFs")
                                Spacer()
                                Text(SharedContainerHelper.formatBytes(orphanedSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Quick Actions")
                    } footer: {
                        Text("Orphaned PDFs are not linked to any roof order and can be safely deleted")
                    }
                }
                
                // Orphaned PDFs
                if !orphanedPDFs.isEmpty {
                    Section("Orphaned PDFs") {
                        ForEach(orphanedPDFs, id: \.filename) { pdf in
                            PDFFileRow(
                                pdf: pdf,
                                isSelected: selectedPDFs.contains(pdf.filename),
                                isOrphaned: true
                            ) {
                                toggleSelection(pdf.filename)
                            }
                        }
                    }
                }
                
                // Linked PDFs
                if !linkedPDFs.isEmpty {
                    Section {
                        ForEach(linkedPDFs, id: \.filename) { pdf in
                            PDFFileRow(
                                pdf: pdf,
                                isSelected: selectedPDFs.contains(pdf.filename),
                                isOrphaned: false
                            ) {
                                toggleSelection(pdf.filename)
                            }
                        }
                    } header: {
                        Text("Linked PDFs")
                    } footer: {
                        Text("Deleting linked PDFs will remove the original file but keep the order data")
                    }
                }
                
                // Empty State
                if allPDFs.isEmpty && !isLoading {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No PDFs Stored")
                                .font(.headline)
                            Text("Imported roof measurement PDFs will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle("PDF Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !selectedPDFs.isEmpty {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete (\(selectedPDFs.count))")
                        }
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading PDFs...")
                }
            }
            .confirmationDialog(
                "Delete Selected PDFs?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(selectedPDFs.count) PDFs (\(SharedContainerHelper.formatBytes(selectedSize)))", role: .destructive) {
                    deleteSelectedPDFs()
                }
                Button("Cancel", role: .cancel) {
                    selectedPDFs.removeAll()
                }
            } message: {
                Text("This action cannot be undone. The original PDF files will be permanently removed.")
            }
            .onAppear {
                loadPDFs()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadPDFs() {
        isLoading = true
        
        Task {
            let pdfURLs = SharedContainerHelper.listRoofPDFs()
            var infos: [PDFFileInfo] = []
            
            for url in pdfURLs {
                if let info = SharedContainerHelper.getRoofPDFInfo(url: url) {
                    infos.append(PDFFileInfo(
                        filename: url.lastPathComponent,
                        size: info.size,
                        created: info.created,
                        url: url
                    ))
                }
            }
            
            // Sort by date, newest first
            infos.sort { $0.created > $1.created }
            
            await MainActor.run {
                allPDFs = infos
                isLoading = false
            }
        }
    }
    
    private func toggleSelection(_ filename: String) {
        if selectedPDFs.contains(filename) {
            selectedPDFs.remove(filename)
        } else {
            selectedPDFs.insert(filename)
        }
    }
    
    private func deleteSelectedPDFs() {
        for filename in selectedPDFs {
            if let pdf = allPDFs.first(where: { $0.filename == filename }) {
                SharedContainerHelper.deleteRoofPDF(at: pdf.url)
                
                // Clear PDF reference from any linked orders
                for order in orders where order.pdfFilename == filename {
                    order.pdfFilename = nil
                }
            }
        }
        
        try? modelContext.save()
        selectedPDFs.removeAll()
        loadPDFs()
    }
}

// MARK: - PDF File Info

struct PDFFileInfo {
    let filename: String
    let size: Int64
    let created: Date
    let url: URL
    
    var displayName: String {
        // Remove UUID prefix if present
        let name = filename
        if name.count > 37 && name.dropFirst(36).hasPrefix("_") {
            return String(name.dropFirst(37))
        }
        return name
    }
}

// MARK: - PDF File Row

struct PDFFileRow: View {
    let pdf: PDFFileInfo
    let isSelected: Bool
    let isOrphaned: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                // PDF icon
                Image(systemName: "doc.fill")
                    .foregroundColor(isOrphaned ? .orange : .blue)
                    .font(.title2)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(pdf.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(SharedContainerHelper.formatBytes(pdf.size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(pdf.created.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Orphaned indicator
                if isOrphaned {
                    Text("Orphaned")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    RoofPDFCleanupView()
        .modelContainer(for: [RoofMaterialOrder.self])
}
