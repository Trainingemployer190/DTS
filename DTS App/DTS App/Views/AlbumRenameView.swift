//
//  AlbumRenameView.swift
//  DTS App
//
//  View for renaming album addresses
//

import SwiftUI

struct AlbumRenameView: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentAddress: String
    let onRename: (String) -> Void
    
    @State private var newAddress: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(currentAddress: String, onRename: @escaping (String) -> Void) {
        self.currentAddress = currentAddress
        self.onRename = onRename
        _newAddress = State(initialValue: currentAddress)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Album Address") {
                    Text(currentAddress)
                        .foregroundColor(.secondary)
                }
                
                Section("New Album Address") {
                    TextField("Enter new address", text: $newAddress)
                        .textCase(.none)
                        .focused($isTextFieldFocused)
                    
                    Text("This will update the album address and watermarks for all photos in this album")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button {
                        if !newAddress.isEmpty && newAddress != currentAddress {
                            onRename(newAddress)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Rename Album")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newAddress.isEmpty || newAddress == currentAddress)
                }
            }
            .navigationTitle("Rename Album")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AlbumRenameView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumRenameView(
            currentAddress: "123 Main St, City, State",
            onRename: { newAddress in
                print("Rename to: \(newAddress)")
            }
        )
    }
}
#endif
