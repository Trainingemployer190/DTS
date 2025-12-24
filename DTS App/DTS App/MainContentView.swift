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
                PhotoLibraryView()
            }
            .tabItem {
                Image(systemName: "photo.stack")
                Text("Photos")
            }
            .tag(3)

            // Roof Material Orders Tab
            RoofMaterialOrderView()
                .tabItem {
                    Image(systemName: "ruler.fill")
                    Text("Roof Orders")
                }
                .tag(4)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(5)
        }
        .onAppear {
            setupJobberAPI()
            checkForPendingRoofImport()
            migrateRoofSettingsIfNeeded()
        }
    }

    private func setupJobberAPI() {
        // Initialize JobberAPI with any necessary configuration
        if !jobberAPI.isAuthenticated {
            // Handle initial authentication if needed
        }
    }

    private func checkForPendingRoofImport() {
        // Check for pending PDF import from Share Extension
        let sharedDefaults = UserDefaults(suiteName: "group.DTS.DTS-App")
        if let pendingId = sharedDefaults?.string(forKey: "pendingRoofPDFImport") {
            print("📥 Found pending roof PDF import: \(pendingId)")
            router.navigateToRoofImport(pdfId: pendingId)
            // Clear the pending flag
            sharedDefaults?.removeObject(forKey: "pendingRoofPDFImport")
        }
    }

    private func migrateRoofSettingsIfNeeded() {
        // Check if migration is pending
        let pendingKey = "com.dtsapp.pendingRoofSettingsMigration"
        let migrationKey = "com.dtsapp.roofSettingsMigration_v1"

        guard UserDefaults.standard.bool(forKey: pendingKey) else { return }

        print("🔧 Performing roof settings migration...")

        // Fetch existing settings
        let descriptor = FetchDescriptor<AppSettings>()
        do {
            let allSettings = try modelContext.fetch(descriptor)

            if let settings = allSettings.first {
                // Update to correct defaults
                var didUpdate = false

                // Fix underlayment (was 400, should be 1000)
                if settings.roofUnderlaymentSqFtPerRoll < 500 {
                    settings.roofUnderlaymentSqFtPerRoll = 1000.0
                    print("  ✓ Updated underlayment to 1000 sqft/roll")
                    didUpdate = true
                }

                // Fix ice & water for eaves (should be OFF by default)
                if settings.roofAutoAddIceWaterForEaves {
                    settings.roofAutoAddIceWaterForEaves = false
                    print("  ✓ Disabled ice & water for eaves")
                    didUpdate = true
                }

                // Fix starter strip (was 100, should be 120)
                if settings.roofStarterStripLFPerBundle < 110 {
                    settings.roofStarterStripLFPerBundle = 120.0
                    print("  ✓ Updated starter strip to 120 LF/bundle")
                    didUpdate = true
                }

                // Fix ridge cap (was 33, should be 25)
                if settings.roofRidgeCapLFPerBundle > 30 {
                    settings.roofRidgeCapLFPerBundle = 25.0
                    print("  ✓ Updated ridge cap to 25 LF/bundle")
                    didUpdate = true
                }

                if didUpdate {
                    try modelContext.save()
                    print("✅ Roof settings migration completed")
                } else {
                    print("✅ Roof settings already correct, no migration needed")
                }
            }

            // Mark migration as complete
            UserDefaults.standard.removeObject(forKey: pendingKey)
            UserDefaults.standard.set(true, forKey: migrationKey)

        } catch {
            print("❌ Failed to migrate roof settings: \(error)")
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppRouter())
        .modelContainer(for: [AppSettings.self, QuoteDraft.self, LineItem.self, PhotoRecord.self, RoofMaterialOrder.self, RoofPresetTemplate.self, RoofParseFailureLog.self])
}
