import SwiftUI
import SwiftData

// MARK: - Minimal JobViews for Build Success

struct JobRowView: View {
    let job: JobberJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(job.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(job.scheduledAt, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(job.status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LineItemEditorView: View {
    @Binding var title: String
    @Binding var amount: Double
    @State var isPresented: Binding<Bool>
    var onSave: () -> Void
    var onCancel: () -> Void
    var onSelectItem: (() -> Void)?

    var body: some View {
        VStack {
            Text("Line Item Editor - Implementation Pending")
                .foregroundColor(.secondary)

            Button("Save") {
                onSave()
            }

            Button("Cancel") {
                onCancel()
            }
        }
        .navigationTitle("Add Item")
    }
}

struct QuoteSummaryView: View {
    var body: some View {
        Text("Quote Summary - Implementation Pending")
            .foregroundColor(.secondary)
    }
}

// MARK: - Preview Providers

struct JobViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack {
                // Use sample data for preview
                JobRowView(job: JobberJob(
                    jobId: "1",
                    clientName: "Sample Client",
                    clientPhone: "555-1234",
                    address: "123 Main St",
                    scheduledAt: Date(),
                    status: "scheduled"
                ))
                QuoteSummaryView()
            }
        }
    }
}
