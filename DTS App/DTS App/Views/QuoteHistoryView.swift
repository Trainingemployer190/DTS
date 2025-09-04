//
//  QuoteHistoryView.swift
//  DTS App
//
//  Created by Chandler Staton on 9/4/25.
//

import SwiftUI
import SwiftData

struct QuoteHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allQuotes: [QuoteDraft]
    @State private var searchText = ""
    @State private var showingStorageInfo = false

    // Filter completed quotes and limit to 100
    var completedQuotes: [QuoteDraft] {
        let completed = allQuotes
            .filter { $0.quoteStatus == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }

        return Array(completed.prefix(100))
    }

    var filteredQuotes: [QuoteDraft] {
        if searchText.isEmpty {
            return completedQuotes
        } else {
            return completedQuotes.filter { quote in
                quote.clientName.localizedCaseInsensitiveContains(searchText) ||
                quote.clientAddress.localizedCaseInsensitiveContains(searchText) ||
                quote.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if filteredQuotes.isEmpty {
                    emptyStateView
                } else {
                    quotesList
                }
            }
            .navigationTitle("Quote History")
            .searchable(text: $searchText, prompt: "Search quotes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Storage Info", systemImage: "info.circle") {
                            showingStorageInfo = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingStorageInfo) {
                storageInfoView
            }
            .navigationDestination(for: QuoteDraft.self) { quote in
                QuoteDetailView(quote: quote)
            }
            .onAppear {
                cleanupOldQuotes()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Quote History")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your completed quotes will appear here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var quotesList: some View {
        List(filteredQuotes) { quote in
            NavigationLink(value: quote) {
                QuoteHistoryRow(quote: quote)
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    deleteQuote(quote)
                }
            }
        }
    }

    private var storageInfoView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Storage Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Quotes:")
                            Spacer()
                            Text("\(completedQuotes.count) / 100")
                                .fontWeight(.medium)
                        }

                        if completedQuotes.count >= 90 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Approaching storage limit")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }

                GroupBox("About Quote History") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Only the most recent 100 quotes are kept")
                        Text("• Older quotes are automatically deleted")
                        Text("• Photos are included with quotes")
                        Text("• Swipe left on quotes to delete manually")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Storage Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingStorageInfo = false
                    }
                }
            }
        }
    }

    private func deleteQuote(_ quote: QuoteDraft) {
        // Delete associated photos first
        for photo in quote.photos {
            deletePhotoFile(photo)
            modelContext.delete(photo)
        }

        modelContext.delete(quote)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete quote: \(error)")
        }
    }

    private func deletePhotoFile(_ photo: PhotoRecord) {
        let fileURL = URL(fileURLWithPath: photo.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func cleanupOldQuotes() {
        let allCompletedQuotes = allQuotes
            .filter { $0.quoteStatus == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }

        if allCompletedQuotes.count > 100 {
            let quotesToDelete = Array(allCompletedQuotes.dropFirst(100))

            for quote in quotesToDelete {
                // Delete associated photos first
                for photo in quote.photos {
                    deletePhotoFile(photo)
                    modelContext.delete(photo)
                }
                modelContext.delete(quote)
            }

            do {
                try modelContext.save()
            } catch {
                print("Failed to cleanup old quotes: \(error)")
            }
        }
    }
}

struct QuoteHistoryRow: View {
    let quote: QuoteDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.clientName.isEmpty ? "Unknown Client" : quote.clientName)
                        .font(.headline)

                    if !quote.clientAddress.isEmpty {
                        Text(quote.clientAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(quote.finalTotal, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let completedDate = quote.completedAt {
                        Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                if quote.gutterFeet > 0 {
                    Label("\(Int(quote.gutterFeet))' gutter", systemImage: "house")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if quote.includeGutterGuard {
                    Label("Guard", systemImage: "shield")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !quote.photos.isEmpty {
                    Label("\(quote.photos.count)", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    QuoteHistoryView()
        .modelContainer(for: [QuoteDraft.self, LineItem.self, PhotoRecord.self, AppSettings.self])
}
