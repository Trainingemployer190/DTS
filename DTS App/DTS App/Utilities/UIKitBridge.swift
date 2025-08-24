//
//  UIKitBridge.swift
//  DTS App
//
//  Created on 8/15/25.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

// Re-export UIKit types to ensure they're available throughout the app
public typealias AppUIView = UIView
public typealias AppUIColor = UIColor
public typealias AppUIImage = UIImage
public typealias AppUIActivityViewController = UIActivityViewController
public typealias AppUIViewController = UIViewController
public typealias AppUIImagePickerController = UIImagePickerController
public typealias AppUIButton = UIButton
public typealias AppUINavigationController = UINavigationController
public typealias AppUIApplicationDelegate = UIApplicationDelegate
public typealias AppUIApplication = UIApplication
public typealias AppUIInterfaceOrientationMask = UIInterfaceOrientationMask
public typealias AppUIInterfaceOrientation = UIInterfaceOrientation

// Common constants
public let AppUIApplicationDidReceiveMemoryWarningNotification = UIApplication.didReceiveMemoryWarningNotification
#else
// Fallback for previews or macOS builds - define stub types
import SwiftUI

public struct AppUIView { }
public struct AppUIColor {
    public static let red = Color.red
    public static let black = Color.black
    public static let white = Color.white
    public static let clear = Color.clear
}
public struct AppUIImage {
    public static func image(named: String) -> Image? { Image(named) }
    public init?() { }
    public init?(contentsOfFile: String) { nil }
}
public struct AppUIActivityViewController {
    public init(activityItems: [Any], applicationActivities: [Any]?) { }
}
public struct AppUIViewController { }
public struct AppUIImagePickerController { }
public struct AppUIButton { }
public struct AppUINavigationController { }
public struct AppUIApplicationDelegate { }
public struct AppUIApplication {
    public static let shared = AppUIApplication()
    public static let didReceiveMemoryWarningNotification = "UIApplicationDidReceiveMemoryWarningNotification"
}
public struct AppUIInterfaceOrientationMask {
    public static let portrait = AppUIInterfaceOrientationMask()
    public static let all = AppUIInterfaceOrientationMask()
}
public struct AppUIInterfaceOrientation {
    public static let portrait = AppUIInterfaceOrientation()
}

// Common constants
public let AppUIApplicationDidReceiveMemoryWarningNotification = "UIApplicationDidReceiveMemoryWarningNotification"
#endif
