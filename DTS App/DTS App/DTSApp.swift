import SwiftUI
import SwiftData

@main
struct DTSApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .modelContainer(for: [AppSettings.self, QuoteDraft.self, PhotoRecord.self, JobberJob.self, LineItem.self, OutboxOperation.self])
        }
    }
}

struct MainContentView: View {
    @StateObject private var jobberAPI = JobberAPI()
    @State private var showLoadingScreen = true

    var body: some View {
        Group {
            if showLoadingScreen {
                LoadingScreenView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLoadingScreen = false
                    }
                }
            } else {
                TabView {
                    HomeView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .environmentObject(jobberAPI)

                    QuoteFormView()
                        .tabItem {
                            Image(systemName: "doc.text.fill")
                            Text("Quote")
                        }
                        .environmentObject(jobberAPI)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .environmentObject(jobberAPI)
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    MainContentView()
}
