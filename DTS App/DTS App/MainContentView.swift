import SwiftUI
import SwiftData

struct MainContentView: View {
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationView {
                HomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            NavigationView {
                QuoteFormView(job: nil)
            }
            .tabItem {
                Image(systemName: "doc.text")
                Text("Quotes")
            }
            .tag(1)

            NavigationView {
                QuoteHistoryView()
            }
            .tabItem {
                Image(systemName: "clock")
                Text("History")
            }
            .tag(2)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
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
        .environmentObject(AppRouter())
        .modelContainer(for: [AppSettings.self, QuoteDraft.self, LineItem.self, PhotoRecord.self, OutboxOperation.self])
}
