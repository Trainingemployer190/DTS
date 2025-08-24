import SwiftUI
import SwiftData

struct MainContentView: View {
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            NavigationView {
                QuoteFormView()
            }
            .tabItem {
                Image(systemName: "doc.text")
                Text("Quotes")
            }
            .tag(1)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
        .onAppear {
            setupJobberAPI()
        }
    }

    private func setupJobberAPI() {
        // Initialize JobberAPI with any necessary configuration
        if !jobberAPI.isAuthenticated {
            // Handle initial authentication if needed
        }
    }
}

#Preview {
    MainContentView()
        .modelContainer(for: [AppSettings.self, QuoteDraft.self, LineItem.self, PhotoRecord.self, OutboxOperation.self])
}
