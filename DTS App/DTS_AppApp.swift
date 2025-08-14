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
        guard url.scheme == "dtsapp" else { return }

        if url.host == "oauth" && url.path == "/callback" {
            // OAuth callback will be handled by the ASWebAuthenticationSession
            // No additional action needed here
        }
    }
}
