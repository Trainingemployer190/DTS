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
        guard jobberAPI.isAuthenticated else { return }

        Task {
            // Try both assessments and visits
            await jobberAPI.fetchScheduledAssessments()
            if jobberAPI.jobs.isEmpty {
                await jobberAPI.fetchWeekScheduledRequests()
            }
        }
    }

}

// MARK: - Supporting Views
struct StatusBadge: View {
    let status: String
    var statusColor: Color {
        switch status.lowercased() {
        case "scheduled": return .blue
        case "in_progress": return .orange
        case "completed": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
}

// Map helper
func openInMaps(address: String) {
    let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let url = URL(string: "http://maps.apple.com/?address=\(encoded)") {
        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
