import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @State private var jobsError: String? = nil

    var allJobs: [JobberJob] { jobberAPI.jobs.sorted { $0.scheduledAt > $1.scheduledAt } }

    var body: some View {
        NavigationStack {
            VStack {
                if jobberAPI.isLoading {
                    ProgressView("Loading jobs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show connection status
                    HStack {
                        Image(systemName: jobberAPI.isAuthenticated ? "link.circle.fill" : "link.circle")
                            .foregroundColor(jobberAPI.isAuthenticated ? .green : .red)

                        if jobberAPI.isAuthenticated {
                            Text("Jobber Connected")
                                .foregroundColor(.green)
                        } else {
                            Text("Jobber Not Connected - Go to Settings to authenticate")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                    .padding(.bottom, 8)

                    if let errorMessage = jobberAPI.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.bottom, 8)
                    }

                    if allJobs.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "briefcase")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No Jobs Found")
                                .font(.title2)
                                .fontWeight(.medium)
                            if jobberAPI.isAuthenticated {
                                Text("No jobs found in Jobber. Check back later or create a new job in Jobber.")
                            } else {
                                Text("Connect to Jobber in Settings to see your scheduled jobs.")
                            }
                        }
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    } else {
                        List(allJobs, id: \.jobId) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                JobRowView(job: job)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scheduled Assessments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") { loadJobs() }
                }
            }
            .onAppear { loadJobs() }
            .refreshable { loadJobs() }
        }
    }

    private func loadJobs() {
        print("🔍 HomeView.loadJobs() called")
        print("🔍 JobberAPI isAuthenticated: \(jobberAPI.isAuthenticated)")
        print("🔍 JobberAPI jobs count: \(jobberAPI.jobs.count)")
        print("🔍 JobberAPI isLoading: \(jobberAPI.isLoading)")
        print("🔍 JobberAPI errorMessage: \(jobberAPI.errorMessage ?? "none")")

        guard jobberAPI.isAuthenticated else {
            print("❌ Not authenticated, skipping job load")
            return
        }

        Task {
            print("🔍 Starting fetchAllScheduledItems...")
            await jobberAPI.fetchAllScheduledItems()
            print("🔍 After fetchAllScheduledItems: \(jobberAPI.jobs.count) jobs")

            if jobberAPI.jobs.isEmpty {
                print("🔍 No jobs found, trying again...")
                await jobberAPI.fetchAllScheduledItems()
                print("🔍 After retry: \(jobberAPI.jobs.count) jobs")
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(JobberAPI())
}
