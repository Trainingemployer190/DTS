//
//  CalculatorView.swift
//  DTS App
//
//  Calculator view for inputting measurements and calculations
//

import SwiftUI

struct CalculatorView: View {
    @Binding var isPresented: Bool
    let onComplete: (Double) -> Void

    @State private var display: String = "0"
    @State private var expression: String = ""
    @State private var currentNumber: String = "0"
    @State private var shouldResetDisplay = false

    private let buttons: [[String]] = [
        ["⌫", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"]
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Calculator Display
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(display)
                            .font(.system(size: min(geometry.size.width * 0.2, 80), weight: .thin, design: .default))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: geometry.size.height * 0.35)
                .background(Color.black)

                // Button Grid
                VStack(spacing: 1) {
                    // All 5 rows with equal button widths
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<buttons[row].count, id: \.self) { col in
                                let button = buttons[row][col]
                                CalculatorButton(
                                    title: button,
                                    action: { buttonPressed(button) },
                                    longPressAction: button == "⌫" ? { clear() } : nil,
                                    isSelected: false,
                                    size: CGSize(
                                        width: (geometry.size.width - 3) / 4,
                                        height: (geometry.size.height * 0.65 - 4) / 5
                                    )
                                )
                            }
                        }
                    }

                    // Bottom row: Done, 0, ., = (all same size)
                    HStack(spacing: 1) {
                        // "Done" button (bottom left)
                        CalculatorButton(
                            title: "Done",
                            action: { buttonPressed("Done") },
                            isSelected: false,
                            size: CGSize(
                                width: (geometry.size.width - 3) / 4,
                                height: (geometry.size.height * 0.65 - 4) / 5
                            )
                        )

                        // "0" button (same size as others)
                        CalculatorButton(
                            title: "0",
                            action: { buttonPressed("0") },
                            isSelected: false,
                            size: CGSize(
                                width: (geometry.size.width - 3) / 4,
                                height: (geometry.size.height * 0.65 - 4) / 5
                            )
                        )

                        // "." button
                        CalculatorButton(
                            title: ".",
                            action: { buttonPressed(".") },
                            isSelected: false,
                            size: CGSize(
                                width: (geometry.size.width - 3) / 4,
                                height: (geometry.size.height * 0.65 - 4) / 5
                            )
                        )

                        // "=" button
                        CalculatorButton(
                            title: "=",
                            action: { buttonPressed("=") },
                            isSelected: false,
                            size: CGSize(
                                width: (geometry.size.width - 3) / 4,
                                height: (geometry.size.height * 0.65 - 4) / 5
                            )
                        )
                    }
                }
                .background(Color.black)
            }
            .background(Color.black)
            .onAppear {
                // Reset calculator when it appears
                clear()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .overlay(
            // Cancel button overlay
            VStack {
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        )
    }

    private func buttonPressed(_ button: String) {
        switch button {
        case "⌫":
            backspace()
        case "±":
            toggleSign()
        case "%":
            percentage()
        case "=":
            equals()
        case "Done":
            let result = evaluateExpression(expression.isEmpty ? currentNumber : expression + currentNumber)
            onComplete(result)
            isPresented = false
        case "+", "-", "×", "÷":
            performOperation(button)
        case ".":
            addDecimal()
        default:
            if let digit = Int(button) {
                inputDigit(digit)
            }
        }
    }

    private func clear() {
        display = "0"
        expression = ""
        currentNumber = "0"
        shouldResetDisplay = false
    }

    private func backspace() {
        if shouldResetDisplay {
            // If we should reset display, just clear everything
            clear()
            return
        }

        if !expression.isEmpty && currentNumber == "0" {
            // We're in the middle of an expression, remove the last character from expression
            expression = String(expression.dropLast())
            if expression.isEmpty {
                currentNumber = "0"
            } else {
                // Find the last number in the expression
                let components = expression.components(separatedBy: CharacterSet(charactersIn: "+-×÷"))
                if let lastComponent = components.last, !lastComponent.isEmpty {
                    currentNumber = lastComponent
                    // Remove the number we just extracted from expression
                    let operatorIndex = expression.lastIndex { "+-×÷".contains($0) }
                    if let index = operatorIndex {
                        expression = String(expression[...index])
                    } else {
                        expression = ""
                    }
                } else {
                    currentNumber = "0"
                }
            }
        } else if currentNumber != "0" {
            // Remove the last digit from current number
            currentNumber = String(currentNumber.dropLast())
            if currentNumber.isEmpty || currentNumber == "-" {
                currentNumber = "0"
            }
        }

        updateDisplay()
    }

    private func toggleSign() {
        if currentNumber != "0" {
            if currentNumber.hasPrefix("-") {
                currentNumber = String(currentNumber.dropFirst())
            } else {
                currentNumber = "-" + currentNumber
            }
            updateDisplay()
        }
    }

    private func percentage() {
        if let value = Double(currentNumber) {
            currentNumber = formatNumber(value / 100)
            updateDisplay()
        }
    }

    private func inputDigit(_ digit: Int) {
        if shouldResetDisplay || currentNumber == "0" {
            currentNumber = String(digit)
            shouldResetDisplay = false
        } else {
            currentNumber += String(digit)
        }
        updateDisplay()
    }

    private func addDecimal() {
        if shouldResetDisplay {
            currentNumber = "0."
            shouldResetDisplay = false
        } else if !currentNumber.contains(".") {
            currentNumber += "."
        }
        updateDisplay()
    }

    private func performOperation(_ op: String) {
        if !shouldResetDisplay {
            expression += currentNumber + op
            shouldResetDisplay = true
            updateDisplay()
        } else if !expression.isEmpty {
            // Replace the last operator if user presses multiple operators
            expression = String(expression.dropLast()) + op
            updateDisplay()
        }
    }

    private func equals() {
        let fullExpression = expression + currentNumber
        let result = evaluateExpression(fullExpression)

        currentNumber = formatNumber(result)
        expression = ""
        shouldResetDisplay = true
        display = currentNumber
    }

    private func updateDisplay() {
        if expression.isEmpty {
            display = currentNumber
        } else {
            display = expression + (shouldResetDisplay ? "" : currentNumber)
        }
    }

    private func evaluateExpression(_ expr: String) -> Double {
        // Replace our display operators with standard operators for evaluation
        let standardExpr = expr.replacingOccurrences(of: "×", with: "*")
                              .replacingOccurrences(of: "÷", with: "/")

        // Use NSExpression for safe mathematical evaluation
        let expression = NSExpression(format: standardExpr)

        // Get the result directly since expressionValue doesn't throw
        if let result = expression.expressionValue(with: nil, context: nil) as? Double {
            return result
        }

        return 0
    }

    private func formatNumber(_ value: Double) -> String {
        // Handle very large numbers
        if abs(value) >= 1_000_000_000 {
            return String(format: "%.2e", value)
        }

        // For normal numbers, show up to 6 decimal places but remove trailing zeros
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1_000_000 {
            return String(format: "%.0f", value)
        } else {
            let formatted = String(format: "%.6f", value)
            // Remove trailing zeros and decimal point if not needed
            let trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            return trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
        }
    }
}

struct CalculatorButton: View {
    let title: String
    let action: () -> Void
    let longPressAction: (() -> Void)?
    let isSelected: Bool
    let size: CGSize

    init(title: String, action: @escaping () -> Void, longPressAction: (() -> Void)? = nil, isSelected: Bool = false, size: CGSize = CGSize(width: 80, height: 80)) {
        self.title = title
        self.action = action
        self.longPressAction = longPressAction
        self.isSelected = isSelected
        self.size = size
    }

    private var backgroundColor: Color {
        switch title {
        case "⌫", "±", "%":
            return Color(.systemGray)
        case "÷", "×", "-", "+", "=":
            return isSelected ? .white : .orange
        case "Done":
            return .green
        default:
            return .gray
        }
    }

    private var foregroundColor: Color {
        switch title {
        case "÷", "×", "-", "+", "=":
            return isSelected ? .orange : .white
        case "Done":
            return .white
        default:
            return title == "0" || title == "." || Int(title) != nil ? .white : .black
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: min(size.width * 0.4, 32), weight: title == "Done" ? .semibold : .regular))
                .foregroundColor(foregroundColor)
                .frame(width: size.width, height: size.height)
                .background(backgroundColor)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            longPressAction != nil ?
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    longPressAction?()
                } : nil
        )
    }
}

#Preview {
    CalculatorView(isPresented: .constant(true), onComplete: { result in
        print("Calculator result: \(result)")
    })
}
