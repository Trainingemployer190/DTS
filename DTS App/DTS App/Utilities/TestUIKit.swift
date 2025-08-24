// TestUIKit.swift
// Simple file to test UIKit imports

import Foundation
import UIKit

struct TestUIKit {
    static func testUIKitAvailable() -> Bool {
        // Try to use a UIKit class
        _ = UIColor.red
        return true
    }
}
