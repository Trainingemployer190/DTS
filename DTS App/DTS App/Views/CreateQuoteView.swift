import SwiftUI
import SwiftData

// MARK: - Create Quote View

struct CreateQuoteView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var appSettings: [AppSettings]
    @State private var selectedJob: JobberJob? = nil
    @State private var showingNewQuoteForm = false
    @State private var prefilledQuoteDraft: QuoteDraft? = nil
    @State private var showingJobberQuoteAlert = false
    @State private var pendingQuoteDraft: QuoteDraft? = nil
    
    private var settings: AppSettings {
        return appSettings.first ?? AppSettings()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Create Quotes")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Generate professional quotes for your jobs")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                Spacer()

                // Quick actions
                VStack(spacing: 16) {
                    // Create new standalone quote
                    Button(action: {
                        selectedJob = nil
                        showingNewQuoteForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create New Quote")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    // Create quote from existing job
                    if !jobberAPI.jobs.isEmpty {
                        Menu {
                            ForEach(jobberAPI.jobs.prefix(10), id: \.jobId) { job in
                                Button(action: {
                                    selectedJob = job
                                    showingNewQuoteForm = true
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(job.clientName)
                                            .lineLimit(1)
                                        Text(job.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            if jobberAPI.jobs.count > 10 {
                                Button("View All Jobs...") {
                                    // Could navigate to job selection view
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "briefcase.fill")
                                    .font(.title2)
                                Text("Quote from Job")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(jobberAPI.jobs.isEmpty)
                    }

                    // Create quote from assessment (pre-filled)
                    if !jobberAPI.jobs.isEmpty {
                        Menu {
                            ForEach(jobberAPI.jobs.prefix(10), id: \.jobId) { job in
                                Button(action: {
                                    createQuoteFromJob(job)
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(job.clientName)
                                            .lineLimit(1)
                                        Text(job.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Assessment → Quote")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.title2)
                                Text("Quote from Assessment")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(jobberAPI.jobs.isEmpty)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Connection status
                HStack {
                    Image(systemName: jobberAPI.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(jobberAPI.isAuthenticated ? .green : .red)

                    Text(jobberAPI.isAuthenticated ? "Connected to Jobber" : "Not connected to Jobber")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Quotes")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewQuoteForm) {
                QuoteFormView(job: selectedJob, prefilledQuoteDraft: prefilledQuoteDraft)
            }
            .alert("Create Quote", isPresented: $showingJobberQuoteAlert) {
                Button("Create in Jobber") {
                    createJobberQuoteFromJob()
                }
                Button("Create Locally") {
                    createLocalQuoteFromJob()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Would you like to create this quote directly in Jobber or create it locally first?")
            }
            .onAppear {
                if jobberAPI.isAuthenticated && jobberAPI.jobs.isEmpty {
                    Task {
                        await jobberAPI.fetchAllScheduledItems()
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func createQuoteFromJob(_ job: JobberJob) {
        print("Creating quote from job: \(job.clientName)")

        // Create a pre-filled quote draft from the job
        let quoteDraft = QuoteDraft()
        quoteDraft.jobId = job.jobId
        quoteDraft.clientName = job.clientName
        quoteDraft.notes = "Quote for \(job.clientName)\nAddress: \(job.address)\nScheduled: \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))"
        
        // Apply default settings for markup and commission percentages
        quoteDraft.applyDefaultSettings(settings)

        // Show alert asking if user wants to create in Jobber or locally
        showingJobberQuoteAlert = true
        pendingQuoteDraft = quoteDraft
        selectedJob = job

        print("Pre-filled quote draft created for \(job.clientName)")
    }

    private func createJobberQuoteFromJob() {
        guard let job = selectedJob, let quoteDraft = pendingQuoteDraft else { return }

        Task {
            await jobberAPI.createQuoteFromJob(job: job, quoteDraft: quoteDraft) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let quoteId):
                        // Show success message
                        print("✅ Quote created in Jobber with ID: \(quoteId)")
                        // Optionally show success alert or navigate somewhere
                    case .failure(let error):
                        print("❌ Failed to create quote in Jobber: \(error.localizedDescription)")
                        // Show error to user
                        jobberAPI.errorMessage = "Failed to create quote in Jobber: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func createLocalQuoteFromJob() {
        guard let _ = selectedJob, let quoteDraft = pendingQuoteDraft else { return }

        // Set the pre-filled draft and selected job for local editing
        prefilledQuoteDraft = quoteDraft
        showingNewQuoteForm = true
    }
}

#Preview {
    CreateQuoteView()
        .environmentObject(JobberAPI())
}
