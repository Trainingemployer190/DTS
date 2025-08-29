import Foundation

// MARK: - Calculator Utilities

/// Calculator utility functions for mathematical operations
struct Calculator {

    /// Evaluates a mathematical expression string
    static func evaluate(_ expression: String) -> Double? {
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
        return evaluateExpression(cleanExpression)
    }

    /// Internal function to evaluate mathematical expressions
    private static func evaluateExpression(_ expression: String) -> Double? {
        // Basic calculator evaluation logic
        let nsExpression = NSExpression(format: expression)
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            return result.doubleValue
        }
        return nil
    }
}
