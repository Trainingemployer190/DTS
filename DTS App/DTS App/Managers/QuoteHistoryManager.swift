//
//  QuoteHistoryManager.swift
//  DTS App
//
//  Created by Chandler Staton on 9/4/25.
//

import SwiftUI
import SwiftData
import Foundation

@Observable
class QuoteHistoryManager {
    private let modelContext: ModelContext
    private let maxQuoteHistory = 100

    var completedQuotes: [QuoteDraft] = []
    var isLoading = false
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCompletedQuotes()
    }

    // MARK: - Public Methods

    /// Load all completed quotes, sorted by completion date (newest first)
    func loadCompletedQuotes() {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<QuoteDraft>(
                predicate: #Predicate<QuoteDraft> { quote in
                    quote.quoteStatusRaw == "completed"
                },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )

            completedQuotes = try modelContext.fetch(descriptor)
            isLoading = false
        } catch {
            errorMessage = "Failed to load quote history: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Mark a quote as completed and manage storage limit
    func completeQuote(_ quote: QuoteDraft) {
        do {
            quote.quoteStatus = .completed
            quote.completedAt = Date()

            try modelContext.save()

            // Check if we need to clean up old quotes
            cleanupOldQuotes()

            // Reload the completed quotes list
            loadCompletedQuotes()

        } catch {
            errorMessage = "Failed to complete quote: \(error.localizedDescription)"
        }
    }

    /// Delete a specific quote from history
    func deleteQuote(_ quote: QuoteDraft) {
        do {
            modelContext.delete(quote)
            try modelContext.save()
            loadCompletedQuotes()
        } catch {
            errorMessage = "Failed to delete quote: \(error.localizedDescription)"
        }
    }

    /// Get storage information
    func getStorageInfo() -> (quotesCount: Int, estimatedSize: String) {
        let quotesCount = completedQuotes.count
        let estimatedSize = formatBytes(estimateStorageSize())
        return (quotesCount, estimatedSize)
    }

    // MARK: - Private Methods

    /// Remove oldest quotes when limit is exceeded
    private func cleanupOldQuotes() {
        do {
            let descriptor = FetchDescriptor<QuoteDraft>(
                predicate: #Predicate<QuoteDraft> { quote in
                    quote.quoteStatusRaw == "completed"
                },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )

            let allCompletedQuotes = try modelContext.fetch(descriptor)

            if allCompletedQuotes.count > maxQuoteHistory {
                let quotesToDelete = Array(allCompletedQuotes.dropFirst(maxQuoteHistory))

                for quote in quotesToDelete {
                    // Delete associated photos first
                    for photo in quote.photos {
                        deletePhotoFile(photo)
                        modelContext.delete(photo)
                    }
                    modelContext.delete(quote)
                }

                try modelContext.save()
            }

        } catch {
            errorMessage = "Failed to cleanup old quotes: \(error.localizedDescription)"
        }
    }

    /// Delete photo file from disk
    private func deletePhotoFile(_ photo: PhotoRecord) {
        let fileURL = URL(fileURLWithPath: photo.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Estimate total storage size used by completed quotes
    private func estimateStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        // Estimate quote data size (rough calculation)
        totalSize += Int64(completedQuotes.count * 2048) // ~2KB per quote

        // Calculate photo storage
        for quote in completedQuotes {
            for photo in quote.photos {
                if let fileSize = getFileSize(at: photo.fileURL) {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

    /// Get file size at path
    private func getFileSize(at path: String) -> Int64? {
        let fileURL = URL(fileURLWithPath: path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return fileSize
    }

    /// Format bytes to human readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Search and Filter Extensions

extension QuoteHistoryManager {
    /// Search quotes by client name or address
    func searchQuotes(searchText: String) -> [QuoteDraft] {
        if searchText.isEmpty {
            return completedQuotes
        }

        return completedQuotes.filter { quote in
            quote.clientName.localizedCaseInsensitiveContains(searchText) ||
            quote.clientAddress.localizedCaseInsensitiveContains(searchText) ||
            quote.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Filter quotes by date range
    func filterQuotesByDateRange(from startDate: Date, to endDate: Date) -> [QuoteDraft] {
        return completedQuotes.filter { quote in
            guard let completedDate = quote.completedAt else { return false }
            return completedDate >= startDate && completedDate <= endDate
        }
    }

    /// Get quotes grouped by month
    func getQuotesGroupedByMonth() -> [String: [QuoteDraft]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: completedQuotes) { quote in
            dateFormatter.string(from: quote.completedAt ?? quote.createdAt)
        }

        return grouped
    }
}
