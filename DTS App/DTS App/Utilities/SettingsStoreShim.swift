// SettingsStoreShim.swift
// Temporary compatibility shim to satisfy references to `SettingsStore`
// If older previews or code still refer to `SettingsStore`, this class prevents
// build failures. AppSettings remains the real source of settings data.

import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    // Intentionally empty; migrate code to use `AppSettings` via SwiftData where possible.
}
