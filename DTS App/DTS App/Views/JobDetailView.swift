//
//  JobDetailView.swift
//  DTS App
//
//  Basic job detail view for displaying Jobber job information
//

import SwiftUI
import SwiftData
import MapKit

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Job Detail View

struct JobDetailView: View {
    let job: JobberJob
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @State private var showingQuoteForm = false
    @State private var showingMap = false
    @State private var coordinateRegion = MKCoordinateRegion()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(job.clientName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("Job ID: \(job.jobId)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            StatusBadge(status: job.status)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                    // Client Information
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Client Information", icon: "person.fill")

                        InfoRow(icon: "person.crop.circle", title: "Name", value: job.clientName)

                        if let clientPhone = job.clientPhone {
                            InfoRow(icon: "phone.fill", title: "Phone", value: clientPhone, isCallable: true)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                    // Address Information
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Location", icon: "location.fill")

                        InfoRow(icon: "mappin.circle", title: "Address", value: job.address)

                        Button(action: {
                            showingMap = true
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("View on Map")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                    // Scheduling Information
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Scheduling", icon: "calendar.fill")

                        InfoRow(icon: "clock.fill", title: "Scheduled", value: formatDate(job.scheduledAt))

                        InfoRow(icon: "info.circle", title: "Status", value: job.status.capitalized)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingQuoteForm = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("Create Quote")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }

                        if let phone = job.clientPhone {
                            Button(action: {
                                makePhoneCall(phone)
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call Client")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Job Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingQuoteForm) {
                QuoteFormView(jobId: job.jobId)
            }
            .sheet(isPresented: $showingMap) {
                MapView(address: job.address, coordinateRegion: $coordinateRegion)
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }

    private func setupMapRegion() {
        // Geocode the job address to get the actual coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(job.address) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                // If geocoding fails, use a default region
                DispatchQueue.main.async {
                    coordinateRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
                print("Failed to geocode address: \(job.address)")
                return
            }

            // Update the map region with the actual location
            DispatchQueue.main.async {
                coordinateRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }

    private func makePhoneCall(_ phoneNumber: String) {
        let cleanedPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleanedPhone)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var isCallable: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(isCallable ? .blue : .primary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCallable {
                let cleanedPhone = value.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let url = URL(string: "tel://\(cleanedPhone)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: String

    var badgeColor: Color {
        switch status.lowercased() {
        case "active", "in_progress", "scheduled":
            return .blue
        case "completed", "finished":
            return .green
        case "cancelled", "canceled":
            return .red
        case "pending", "quote":
            return .orange
        default:
            return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(6)
    }
}

struct MapView: View {
    let address: String
    @Binding var coordinateRegion: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss
    @State private var mapAnnotation: MapAnnotation?

    var body: some View {
        NavigationView {
            VStack {
                Map(coordinateRegion: $coordinateRegion, annotationItems: mapAnnotation != nil ? [mapAnnotation!] : []) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: .red)
                }
                .ignoresSafeArea()

                VStack {
                    Text(address)
                        .font(.body)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)

                    Button("Open in Maps") {
                        let geocoder = CLGeocoder()
                        geocoder.geocodeAddressString(address) { placemarks, error in
                            if let placemark = placemarks?.first,
                               let _ = placemark.location {
                                let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                                mapItem.name = address
                                mapItem.openInMaps(launchOptions: [:])
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Job Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                geocodeAddress()
            }
        }
    }

    private func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("Failed to geocode address in MapView: \(address)")
                return
            }

            DispatchQueue.main.async {
                coordinateRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapAnnotation = MapAnnotation(coordinate: location.coordinate)
            }
        }
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    NavigationView {
        JobDetailView(job: JobberJob(
            jobId: "12345",
            clientName: "John Doe",
            clientPhone: "+1 (555) 123-4567",
            address: "123 Main Street, San Francisco, CA 94102",
            scheduledAt: Date(),
            status: "scheduled"
        ))
    }
    .environmentObject(JobberAPI())
}
