//
//  DTS_AppApp.swift
//  DTS App
//
//  Created by Chandler Staton on 8/13/25.
//

import SwiftUI
import SwiftData

@main
struct DTS_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppSettings.self,
            JobberJob.self,
            QuoteDraft.self,
            LineItem.self,
            PhotoRecord.self,
            OutboxOperation.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        print("=== INCOMING URL ===")
        print("Full URL: \(url.absoluteString)")
        print("Scheme: \(url.scheme ?? "none")")
        print("Host: \(url.host ?? "none")")
        print("Path: \(url.path)")
        print("Query: \(url.query ?? "none")")

        guard url.scheme == "dtsapp" else {
            print("URL scheme is not 'dtsapp', ignoring")
            return
        }

        if url.host == "oauth" && url.path == "/callback" {
            print("✅ Received OAuth callback URL - ASWebAuthenticationSession will handle this")
            // OAuth callback will be handled by the ASWebAuthenticationSession automatically
            // The session will detect this URL and call our completion handler
        } else {
            print("⚠️ Unknown URL path for dtsapp scheme")
        }
    }
}
