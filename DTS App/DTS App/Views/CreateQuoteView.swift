import SwiftUI
import SwiftData

// MARK: - Create Quote View

struct CreateQuoteView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @State private var selectedJobId: String? = nil
    @State private var showingNewQuoteForm = false

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
                        selectedJobId = nil
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
                                    selectedJobId = job.jobId
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
                QuoteFormView(jobId: selectedJobId)
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
}

#Preview {
    CreateQuoteView()
        .environmentObject(JobberAPI())
}
