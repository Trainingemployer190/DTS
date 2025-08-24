import SwiftUI
import SwiftData
import BackgroundTasks
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register background task for token refresh
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.dtsapp.token-refresh", using: nil) { task in
            self.handleTokenRefreshTask(task: task as! BGAppRefreshTask)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleTokenRefresh()
    }

    private func scheduleTokenRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.dtsapp.token-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background token refresh scheduled")
        } catch {
            print("❌ Failed to schedule background token refresh: \(error)")
        }
    }

    private func handleTokenRefreshTask(task: BGAppRefreshTask) {
        scheduleTokenRefresh() // Schedule next refresh

        let jobberAPI = JobberAPI()

        Task {
            let success = await jobberAPI.ensureValidAccessToken()
            print("🔄 Background token refresh completed: \(success ? "success" : "failed")")
            task.setTaskCompleted(success: success)
        }
    }
}

@main
struct DTSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showLoadingScreen = true
    @StateObject private var jobberAPI = JobberAPI()

    var body: some Scene {
        WindowGroup {
            if showLoadingScreen {
                LoadingScreenView {
                    // Called when loading is complete
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLoadingScreen = false
                    }
                }
            } else {
                MainContentView()
                    .modelContainer(for: [AppSettings.self, QuoteDraft.self, PhotoRecord.self, LineItem.self, OutboxOperation.self])
                    .environmentObject(jobberAPI)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 Received URL: \(url.absoluteString)")
        
        // Handle Jobber OAuth callback
        if url.scheme == "dtsapp" {
            print("📱 Processing Jobber OAuth callback")
            Task {
                await jobberAPI.handleOAuthCallback(url)
            }
        }
    }
}
