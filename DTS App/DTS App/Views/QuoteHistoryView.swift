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
    @EnvironmentObject var jobberAPI: JobberAPI
    @Query private var allQuotes: [QuoteDraft]
    @Query private var settingsArray: [AppSettings]
    @State private var searchText = ""
    @State private var showingStorageInfo = false
    @State private var isSendingToJobber = false
    @State private var sendingQuoteId: UUID?
    @State private var jobberSubmissionError: String?

    private var settings: AppSettings {
        settingsArray.first ?? AppSettings()
    }

    // Filter completed and draft quotes and limit to 100
    var allRelevantQuotes: [QuoteDraft] {
        let relevant = allQuotes
            .filter { $0.quoteStatus == .completed || $0.quoteStatus == .draft }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }

        return Array(relevant.prefix(100))
    }

    var filteredQuotes: [QuoteDraft] {
        if searchText.isEmpty {
            return allRelevantQuotes
        } else {
            return allRelevantQuotes.filter { quote in
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
                fixQuotesWithZeroTotals()
            }
            .alert("Jobber Submission Error", isPresented: .constant(jobberSubmissionError != nil)) {
                Button("OK") {
                    jobberSubmissionError = nil
                }
            } message: {
                Text(jobberSubmissionError ?? "")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Quotes Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your completed quotes and drafts will appear here")
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

                // Add "Send to Jobber" option for quotes that haven't been saved to Jobber yet
                if !quote.savedToJobber && quote.jobId != nil {
                    Button(sendingQuoteId == quote.localId ? "Sending..." : "Send to Jobber") {
                        sendQuoteToJobber(quote)
                    }
                    .tint(.blue)
                    .disabled(isSendingToJobber)
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
                            Text("\(allRelevantQuotes.filter { $0.quoteStatus == .completed }.count) / 100")
                                .fontWeight(.medium)
                        }

                        if allRelevantQuotes.filter({ $0.quoteStatus == .completed }).count >= 90 {
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

    private func fixQuotesWithZeroTotals() {
        let quotesWithZeroTotal = allQuotes
            .filter { $0.quoteStatus == .completed && $0.finalTotal == 0 }

        guard !quotesWithZeroTotal.isEmpty else { return }

        var hasChanges = false

        for quote in quotesWithZeroTotal {
            let breakdown = PricingEngine.calculatePrice(quote: quote, settings: settings)
            if breakdown.totalPrice > 0 {
                PricingEngine.updateQuoteWithCalculatedTotals(quote: quote, breakdown: breakdown)
                hasChanges = true
            }
        }

        if hasChanges {
            do {
                try modelContext.save()
                print("Fixed \(quotesWithZeroTotal.count) quotes with zero totals")
            } catch {
                print("Failed to fix quotes with zero totals: \(error)")
            }
        }
    }

    private func sendQuoteToJobber(_ quote: QuoteDraft) {
        // Check if authenticated
        guard jobberAPI.isAuthenticated else {
            jobberSubmissionError = "Please connect to Jobber first"
            return
        }

        // Check if we have a job ID
        guard let jobId = quote.jobId, !jobId.isEmpty else {
            jobberSubmissionError = "This quote is not linked to a Jobber assessment. Only quotes created from scheduled assessments can be sent to Jobber."
            return
        }

        isSendingToJobber = true
        sendingQuoteId = quote.localId

        Task {
            do {
                // Find the corresponding job from our fetched jobs
                guard let job = jobberAPI.jobs.first(where: { $0.jobId == jobId }) else {
                    throw JobberAPIError.invalidRequest("Could not find the associated Jobber assessment. The assessment may have been updated or removed.")
                }

                guard let requestId = job.requestId else {
                    throw JobberAPIError.invalidRequest("No request ID available for this assessment")
                }

                // Calculate pricing
                let breakdown = PricingEngine.calculatePrice(quote: quote, settings: settings)

                // Submit quote as note to Jobber
                let noteResult = await jobberAPI.submitQuoteAsNote(
                    requestId: requestId,
                    quote: quote,
                    breakdown: breakdown,
                    photos: quote.photos.map { _ in UIImage() } // Convert PhotoRecord to UIImage if needed
                )

                // Create actual quote in Jobber
                let quoteResult = await jobberAPI.createQuoteFromJobWithMeasurements(
                    job: job,
                    quoteDraft: quote,
                    breakdown: breakdown,
                    settings: settings
                )

                await MainActor.run {
                    var hasError = false
                    var errorMessages: [String] = []

                    // Check results
                    switch noteResult {
                    case .success(_):
                        print("✅ Note created successfully")
                    case .failure(let error):
                        hasError = true
                        errorMessages.append("Note creation failed: \(error.localizedDescription)")
                    }

                    switch quoteResult {
                    case .success(let quoteId):
                        print("✅ Quote created successfully with ID: \(quoteId)")
                    case .failure(let error):
                        hasError = true
                        errorMessages.append("Quote creation failed: \(error.localizedDescription)")
                    }

                    if hasError {
                        jobberSubmissionError = errorMessages.joined(separator: "\n")
                    } else {
                        // Mark quote as completed since it was successfully sent
                        quote.quoteStatus = .completed
                        quote.completedAt = Date()
                        quote.savedToJobber = true // Mark as saved to Jobber

                        do {
                            try modelContext.save()
                            print("✅ Quote successfully sent to Jobber and marked as completed")
                        } catch {
                            print("Failed to update quote status: \(error)")
                        }
                    }

                    isSendingToJobber = false
                    sendingQuoteId = nil
                }
            } catch {
                await MainActor.run {
                    jobberSubmissionError = error.localizedDescription
                    isSendingToJobber = false
                    sendingQuoteId = nil
                }
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

                    HStack(spacing: 8) {
                        HStack(spacing: 8) {
                        // Status badge
                        Text(quote.quoteStatus == .draft ? "DRAFT" : "COMPLETED")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(quote.quoteStatus == .draft ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)

                        // Jobber saved indicator
                        if quote.savedToJobber {
                            Text("JOBBER")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                        // Date
                        if let completedDate = quote.completedAt {
                            Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(quote.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

