//
//  TextEditorOverlay.swift
//  DTS App
//
//  Shared text editor overlay for annotation tools
//

import SwiftUI

struct TextEditorOverlay: View {
    @Binding var text: String
    let fontSize: CGFloat
    let onCancel: () -> Void
    let onDone: () -> Void
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Enter text", text: $text, axis: .vertical)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.blue, lineWidth: 2)
                )
                .frame(minWidth: 250, maxWidth: 350)
                .focused($isTextFieldFocused)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.gray)
                .cornerRadius(8)

                Button("Done") {
                    onDone()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
}
