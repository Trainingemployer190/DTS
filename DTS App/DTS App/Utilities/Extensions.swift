import Foundation
import SwiftUI

// MARK: - String Extensions
extension String {
    func isValidEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    func formatPhoneNumber() -> String {
        let cleanNumber = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let mask = "(XXX) XXX-XXXX"

        var result = ""
        var index = cleanNumber.startIndex
        for ch in mask where index < cleanNumber.endIndex {
            if ch == "X" {
                result.append(cleanNumber[index])
                index = cleanNumber.index(after: index)
            } else {
                result.append(ch)
            }
        }
        return result
    }
}

// MARK: - Date Extensions
extension Date {
    func formatted(_ style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }

    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let secondaryGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let successGreen = Color(red: 0.2, green: 0.7, blue: 0.3)
    static let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let errorRed = Color(red: 0.8, green: 0.2, blue: 0.2)
}

// MARK: - Double Extensions
extension Double {
    func toCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var twoDecimalFormatted: String {
        // Format to 2 decimal places, but remove them if they are .00
        return String(format: "%.2f", self).replacingOccurrences(of: ".00", with: "")
    }
}
