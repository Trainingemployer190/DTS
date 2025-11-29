//
//  GooglePhotosSettingsView.swift
//  DTS App
//
//  Settings view for Google Photos integration
//

import SwiftUI

struct GooglePhotosSettingsView: View {
    @ObservedObject var googleAPI = GooglePhotosAPI.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: googleAPI.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(googleAPI.isAuthenticated ? .green : .red)
                        Text(googleAPI.isAuthenticated ? "Connected" : "Not Connected")
                            .font(.headline)
                    }
                    
                    if googleAPI.isPreconfiguredMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Using shared company account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if googleAPI.isAuthenticated {
                                Text("Authenticated automatically")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    } else if googleAPI.isAuthenticated {
                        Button("Sign Out") {
                            googleAPI.signOut()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Sign In with Google") {
                            googleAPI.startAuthentication()
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if googleAPI.isPreconfiguredMode {
                        Text("This app is configured to use a shared Google Photos account for all team members. No sign-in required.")
                    }
                }
                
                Section {
                    Toggle("Auto-Upload New Photos", isOn: Binding(
                        get: { googleAPI.autoUploadEnabled },
                        set: { googleAPI.setAutoUploadEnabled($0) }
                    ))
                    .disabled(!googleAPI.isAuthenticated)
                    
                    if googleAPI.isUploading {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Uploading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: googleAPI.uploadProgress)
                                .progressViewStyle(.linear)
                        }
                    }
                } header: {
                    Text("Auto-Upload")
                } footer: {
                    Text("When enabled, all photos captured in the app will automatically upload to your Google Photos library.")
                }
                
                if let errorMessage = googleAPI.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    } header: {
                        Text("Error")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Google Photos Integration")
                            .font(.headline)
                        
                        Text("This feature automatically backs up your photos to Google Photos when enabled. Photos are uploaded in the background and organized by address.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Photos retain their GPS watermarks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Uploads happen automatically after capture")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Your photos remain in the app even if upload fails")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Google Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GooglePhotosSettingsView()
}
