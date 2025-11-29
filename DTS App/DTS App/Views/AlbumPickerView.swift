//
//  AlbumPickerView.swift
//  DTS App
//
//  Album picker for moving photos between albums
//

import SwiftUI
import SwiftData

struct AlbumPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let photo: PhotoRecord
    let availableAlbums: [String]
    let onSelect: (String) -> Void

    @State private var newAlbumName = ""
    @State private var showingNewAlbum = false

    var body: some View {
        NavigationView {
            List {
                Section("Available Albums") {
                    ForEach(availableAlbums, id: \.self) { album in
                        Button {
                            onSelect(album)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(album)
                                        .foregroundColor(.primary)

                                    if album == photo.address {
                                        Text("Current album")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if album == photo.address {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(album == photo.address)
                    }
                }

                Section {
                    if showingNewAlbum {
                        HStack {
                            TextField("Album address", text: $newAlbumName)
                                .textInputAutocapitalization(.words)

                            Button("Create") {
                                if !newAlbumName.isEmpty {
                                    onSelect(newAlbumName)
                                    dismiss()
                                }
                            }
                            .disabled(newAlbumName.isEmpty)
                        }
                    } else {
                        Button {
                            showingNewAlbum = true
                        } label: {
                            Label("Create New Album", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Move to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG && canImport(UIKit)
struct AlbumPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PhotoRecord.self, configurations: config)

        let samplePhoto = PhotoRecord(
            fileURL: "sample.jpg",
            address: "123 Main St"
        )

        container.mainContext.insert(samplePhoto)

        return AlbumPickerView(
            photo: samplePhoto,
            availableAlbums: ["123 Main St", "456 Oak Ave", "789 Pine Rd"],
            onSelect: { _ in }
        )
    }
}
#endif
