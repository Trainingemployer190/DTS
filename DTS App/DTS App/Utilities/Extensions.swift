//
//  Extensions.swift
//  DTS App
//
//  Common extensions for the app
//

import Foundation

// MARK: - Formatting Extensions

extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var twoDecimalFormatted: String {
        return String(format: "%.2f", self)
    }

    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
