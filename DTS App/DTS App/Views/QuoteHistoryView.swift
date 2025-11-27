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
    @State private var showingCleanupConfirmation = false
    @State private var orphanedPhotoCount = 0
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isBatchSyncing = false
    @State private var showingBatchSyncSheet = false
    @State private var batchSyncResults: String?

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

    // Count of quotes pending sync
    var pendingSyncQuotes: [QuoteDraft] {
        allRelevantQuotes.filter { quote in
            (quote.syncState == .pending || quote.syncState == .failed) &&
            quote.jobId != nil &&
            quote.syncAttemptCount < 10
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
            .sheet(isPresented: $showingBatchSyncSheet) {
                batchSyncView
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
                QuoteHistoryRow(
                    quote: quote,
                    onSync: {
                        sendQuoteToJobber(quote)
                    },
                    isSyncing: sendingQuoteId == quote.localId,
                    isNetworkConnected: networkMonitor.isConnected
                )
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

                GroupBox("Maintenance") {
                    VStack(spacing: 12) {
                        Button(action: {
                            orphanedPhotoCount = findOrphanedPhotos().count
                            showingCleanupConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.red)
                                Text("Clean Up Orphaned Photos")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)

                        Text("Removes photo files that are no longer associated with any quote")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
            .alert("Clean Up Photos?", isPresented: $showingCleanupConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clean Up", role: .destructive) {
                    cleanupOrphanedPhotos()
                }
            } message: {
                Text("Found \(orphanedPhotoCount) orphaned photo files. These are test photos or photos from deleted quotes that are no longer needed.")
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

    private func findOrphanedPhotos() -> [URL] {
        var orphanedPhotos: [URL] = []

        // Get all photo file URLs from existing quotes
        var validPhotoURLs = Set<String>()
        for quote in allQuotes {
            for photo in quote.photos {
                validPhotoURLs.insert(photo.fileURL)
            }
        }

        // Check temp directory for DTS_Photos
        let tempPhotosDir = FileManager.default.temporaryDirectory.appendingPathComponent("DTS_Photos")
        if let photoFiles = try? FileManager.default.contentsOfDirectory(at: tempPhotosDir, includingPropertiesForKeys: nil) {
            for fileURL in photoFiles {
                if !validPhotoURLs.contains(fileURL.path) {
                    orphanedPhotos.append(fileURL)
                }
            }
        }

        // Check shared container directory
        let storageDir = SharedContainerHelper.photosStorageDirectory
        if let photoFiles = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: nil) {
            for fileURL in photoFiles where fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "jpeg" {
                if !validPhotoURLs.contains(fileURL.path) {
                    orphanedPhotos.append(fileURL)
                }
            }
        }

        print("🔍 Found \(orphanedPhotos.count) orphaned photos")
        return orphanedPhotos
    }

    private func cleanupOrphanedPhotos() {
        let orphanedPhotos = findOrphanedPhotos()
        var deletedCount = 0

        for photoURL in orphanedPhotos {
            do {
                try FileManager.default.removeItem(at: photoURL)
                deletedCount += 1
                print("🗑️ Deleted orphaned photo: \(photoURL.lastPathComponent)")
            } catch {
                print("❌ Failed to delete orphaned photo \(photoURL.lastPathComponent): \(error)")
            }
        }

        print("✅ Cleaned up \(deletedCount) orphaned photos")
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

    // Batch sync view
    private var batchSyncView: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isBatchSyncing {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Syncing quotes...")
                        .font(.headline)
                        .padding()
                } else if let results = batchSyncResults {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Sync Complete")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(results)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sync Pending Quotes")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Upload \(pendingSyncQuotes.count) pending quote\(pendingSyncQuotes.count == 1 ? "" : "s") to Jobber?")
                            .foregroundColor(.secondary)

                        if networkMonitor.isCellular {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(.orange)
                                Text("You're on cellular data. Photos may use significant data.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(pendingSyncQuotes) { quote in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(quote.clientName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("$\(quote.finalTotal, specifier: "%.2f")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if quote.syncState == .failed {
                                            Text("Retry \(quote.syncAttemptCount)/10")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 200)

                        Button(action: syncAllPending) {
                            HStack {
                                Image(systemName: "arrow.clockwise.icloud")
                                Text("Sync All")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Batch Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(batchSyncResults != nil ? "Done" : "Cancel") {
                        showingBatchSyncSheet = false
                        batchSyncResults = nil
                    }
                }
            }
        }
    }

    private func syncAllPending() {
        isBatchSyncing = true

        Task {
            var successCount = 0
            var failedCount = 0
            let quotesToSync = pendingSyncQuotes

            for quote in quotesToSync {
                // Sync each quote sequentially to avoid overwhelming network
                await MainActor.run {
                    sendQuoteToJobber(quote)
                }

                // Wait for sync to complete (check every 0.5s for up to 30s)
                var attempts = 0
                while isSendingToJobber && attempts < 60 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    attempts += 1
                }

                // Check result
                await MainActor.run {
                    if quote.syncState == .synced {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }

            await MainActor.run {
                batchSyncResults = "\(successCount) of \(quotesToSync.count) quotes synced successfully.\(failedCount > 0 ? "\n\n\(failedCount) failed - you can retry them individually from Quote History." : "")"
                isBatchSyncing = false
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

        // Check network connectivity
        guard networkMonitor.isConnected else {
            jobberSubmissionError = "No internet connection. Please check your network and try again."
            return
        }

        // Check max attempts
        if quote.syncAttemptCount >= 10 {
            jobberSubmissionError = "Maximum upload attempts (10) reached for this quote. Please contact support for assistance."
            return
        }

        isSendingToJobber = true
        sendingQuoteId = quote.localId

        Task {
            // Update sync state to syncing
            await MainActor.run {
                quote.syncState = .syncing
                quote.lastSyncAttempt = Date()
                quote.syncAttemptCount += 1
                try? modelContext.save()
            }

            do {
                // Find the corresponding job from our fetched jobs
                guard let job = jobberAPI.jobs.first(where: { $0.jobId == jobId }) else {
                    throw JobberAPIError.invalidRequest("Could not find the associated Jobber assessment. The assessment may have been updated or removed.")
                }

                guard let requestId = job.requestId else {
                    throw JobberAPIError.invalidRequest("No request ID available for this assessment")
                }

                print("📤 Uploading quote to Jobber (Attempt \(quote.syncAttemptCount) of 10)...")

                // Calculate pricing
                let breakdown = PricingEngine.calculatePrice(quote: quote, settings: settings)

                // Load photos properly from PhotoRecord fileURL
                let photos = quote.photos.compactMap { photoRecord in
                    UIImage(contentsOfFile: photoRecord.fileURL)
                }
                print("📸 Loaded \(photos.count) photos from PhotoRecord array for Jobber upload")

                // Submit quote as note to Jobber
                let noteResult = await jobberAPI.submitQuoteAsNote(
                    requestId: requestId,
                    quote: quote,
                    breakdown: breakdown,
                    settings: settings,
                    photos: photos
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
                        // Mark as failed and save error
                        quote.syncState = .failed
                        quote.syncErrorMessage = errorMessages.joined(separator: "\n")
                        try? modelContext.save()

                        jobberSubmissionError = errorMessages.joined(separator: "\n")
                    } else {
                        // Mark quote as completed and synced
                        quote.quoteStatus = .completed
                        quote.completedAt = Date()
                        quote.savedToJobber = true
                        quote.syncState = .synced
                        quote.syncErrorMessage = nil
                        quote.syncAttemptCount = 0 // Reset on success

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
                    // Mark as failed and save error
                    quote.syncState = .failed
                    quote.syncErrorMessage = error.localizedDescription
                    try? modelContext.save()

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
    let onSync: (() -> Void)?
    let isSyncing: Bool
    let isNetworkConnected: Bool

    var body: some View {
        HStack {
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

                        // Sync state badge
                        switch quote.syncState {
                        case .synced:
                            Text("✓ SYNCED")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        case .pending:
                            Text("⏱ PENDING")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        case .failed:
                            if quote.syncAttemptCount >= 10 {
                                Text("⚠ FAILED (MAX)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        // Show error details
                                    }
                            } else {
                                Text("⚠ FAILED (\(quote.syncAttemptCount)/10)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        // Show error details
                                    }
                            }
                        case .syncing:
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("SYNCING")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
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

            // Sync button for unsynced quotes
            if quote.syncState != .synced && quote.jobId != nil && quote.syncAttemptCount < 10 {
                Button(action: {
                    onSync?()
                }) {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: quote.syncState == .failed ? "arrow.clockwise.circle.fill" : "icloud.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(quote.syncState == .failed ? .orange : .blue)
                    }
                }
                .disabled(!isNetworkConnected || isSyncing)
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    QuoteHistoryView()
        .modelContainer(for: [QuoteDraft.self, LineItem.self, PhotoRecord.self, AppSettings.self])
}

