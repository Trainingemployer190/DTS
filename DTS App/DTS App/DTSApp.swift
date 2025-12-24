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

        // Migrate photos from old Documents location to shared container
        migratePhotosIfNeeded()

        // Migrate roof settings to correct defaults (v1.1.6+)
        migrateRoofSettingsIfNeeded()

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

    private func migrateRoofSettingsIfNeeded() {
        // Check if roof settings migration has been done
        let migrationKey = "com.dtsapp.roofSettingsMigration_v1"
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)

        if !hasMigrated {
            print("🔧 Migrating roof settings to correct defaults...")

            // We need to update AppSettings directly in SwiftData
            // This will be done in MainContentView on first launch with access to modelContext
            UserDefaults.standard.set(true, forKey: "com.dtsapp.pendingRoofSettingsMigration")
            print("📋 Roof settings migration pending - will complete on first view load")
        }
    }

    private func migratePhotosIfNeeded() {
        // Check if migration is needed and has not been done before
        let migrationKey = "com.dtsapp.photoMigrationCompleted"
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)

        if !hasMigrated && SharedContainerHelper.needsMigration() {
            print("📦 Starting photo migration to shared container...")
            SharedContainerHelper.migrateExistingPhotos { count, errors in
                if errors.isEmpty {
                    print("✅ Successfully migrated \(count) photos")
                    UserDefaults.standard.set(true, forKey: migrationKey)
                } else {
                    print("⚠️ Migrated \(count) photos with \(errors.count) errors")
                    // Still mark as migrated to avoid repeated attempts
                    UserDefaults.standard.set(true, forKey: migrationKey)
                }
            }
        } else if hasMigrated {
            print("✅ Photo migration already completed")
        } else {
            print("✅ No photos to migrate")
        }
    }
}

@main
struct DTSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showLoadingScreen = true
    @StateObject private var jobberAPI = JobberAPI()
    @StateObject private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if showLoadingScreen {
                LoadingScreenView(onComplete: {
                    withAnimation {
                        showLoadingScreen = false
                    }
                })
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
            } else {
                MainContentView()
                    .modelContainer(for: [AppSettings.self, QuoteDraft.self, PhotoRecord.self, LineItem.self, RoofMaterialOrder.self, RoofPresetTemplate.self, RoofParseFailureLog.self])
                    .environmentObject(jobberAPI)
                    .environmentObject(router)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
                    .onAppear {
                        checkForPendingRoofPDFImport()
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if newPhase == .active {
                            // Check for pending imports when app becomes active
                            checkForPendingRoofPDFImport()
                        }
                    }
            }
        }
    }

    private func checkForPendingRoofPDFImport() {
        // Check for pending PDF import from Share Extension
        let sharedDefaults = UserDefaults(suiteName: "group.DTS.DTS-App")
        if let pendingId = sharedDefaults?.string(forKey: "pendingRoofPDFImport") {
            print("📥 Found pending roof PDF import on launch: \(pendingId)")
            router.navigateToRoofImport(pdfId: pendingId)
            // Clear the pending flag
            sharedDefaults?.removeObject(forKey: "pendingRoofPDFImport")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        print("🔗 Received URL: \(url.absoluteString)")

        // Handle Jobber OAuth callback
        if url.scheme == "dts-app" {
            // Check for roof PDF import URL: dts-app://import-roof-pdf
            if url.host == "import-roof-pdf" {
                print("📥 Received roof PDF import request from Share Extension")
                // Check for pending import in shared UserDefaults
                let sharedDefaults = UserDefaults(suiteName: "group.DTS.DTS-App")
                if let pendingId = sharedDefaults?.string(forKey: "pendingRoofPDFImport") {
                    print("📥 Found pending PDF ID: \(pendingId)")
                    router.navigateToRoofImport(pdfId: pendingId)
                    // Clear the pending flag
                    sharedDefaults?.removeObject(forKey: "pendingRoofPDFImport")
                } else {
                    // No pending ID, just navigate to roof orders tab
                    router.selectedTab = 4
                }
                return
            }

            // Otherwise, it's a Jobber OAuth callback
            print("📱 Processing Jobber OAuth callback")
            Task {
                await jobberAPI.handleOAuthCallback(url: url)
            }
        }

        // Handle Google OAuth callback
        if url.scheme == "com.googleusercontent.apps.871965263646-e5viush2cefbdtbe7tgmq3t0rr7bbl4g" {
            print("📱 Processing Google OAuth callback")
            // OAuth is handled by ASWebAuthenticationSession
        }
    }
}
