//
//  PencilKitTestView.swift
//  DTS App
//
//  Test harness for comparing PencilKit vs Custom annotation editors
//

import SwiftUI
import SwiftData

struct PencilKitTestView: View {
    @Query(sort: \PhotoRecord.createdAt, order: .reverse) private var photos: [PhotoRecord]
    @State private var showingPencilKitEditor = false
    @State private var showingCustomEditor = false
    @State private var selectedPhoto: PhotoRecord?

    var body: some View {
        NavigationStack {
            if photos.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Take a photo first to test annotation editors")
                )
            } else {
                List {
                    Section("Compare Editors") {
                        Text("Tap a photo to test both annotation systems")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Recent Photos") {
                        ForEach(photos.prefix(10)) { photo in
                            HStack {
                                // Thumbnail
                                if let uiImage = UIImage(contentsOfFile: photo.fileURL) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(photo.title.isEmpty ? "Untitled Photo" : photo.title)
                                        .font(.headline)

                                    HStack {
                                        if !photo.annotations.isEmpty {
                                            Label("\(photo.annotations.count)", systemImage: "pencil.tip.crop.circle")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }

                                        if photo.pencilKitDrawingData != nil {
                                            Label("PencilKit", systemImage: "pencil.and.scribble")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }

                                    Text(photo.createdAt, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                        }
                    }
                }
                .sheet(item: $selectedPhoto) { photo in
                    EditorChoiceSheet(
                        photo: photo,
                        showPencilKit: $showingPencilKitEditor,
                        showCustom: $showingCustomEditor
                    )
                }
                .sheet(isPresented: $showingPencilKitEditor) {
                    if let photo = selectedPhoto {
                        PencilKitPhotoEditor(photo: photo)
                    }
                }
                .sheet(isPresented: $showingCustomEditor) {
                    if let photo = selectedPhoto {
                        PhotoAnnotationEditor(photo: photo)
                    }
                }
                .navigationTitle("Editor Test")
            }
        }
    }
}

// MARK: - Editor Choice Sheet

struct EditorChoiceSheet: View {
    let photo: PhotoRecord
    @Binding var showPencilKit: Bool
    @Binding var showCustom: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Choose Editor") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPencilKit = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("PencilKit Editor")
                                    .font(.headline)
                                Text("Apple's native markup tools")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if photo.pencilKitDrawingData != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showCustom = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil.tip.crop.circle")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Custom Editor")
                                    .font(.headline)
                                Text("Current DTS annotation system")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !photo.annotations.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Annotate Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    PencilKitTestView()
        .modelContainer(for: [PhotoRecord.self])
}
