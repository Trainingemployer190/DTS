import Foundation
import SwiftUI

final class AppRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    
    // Roof PDF import from Share Extension
    @Published var pendingRoofPDFImportId: String?
    @Published var showRoofPDFImport: Bool = false
    
    /// Navigate to Roof Orders tab and trigger import flow
    func navigateToRoofImport(pdfId: String) {
        pendingRoofPDFImportId = pdfId
        selectedTab = 4  // Roof Orders tab
        showRoofPDFImport = true
    }
    
    /// Clear pending import after processing
    func clearPendingImport() {
        pendingRoofPDFImportId = nil
        showRoofPDFImport = false
    }
}
