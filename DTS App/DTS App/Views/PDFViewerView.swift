//
//  PDFViewerView.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Display PDF documents for verification
//

import SwiftUI
import PDFKit
import UIKit

struct PDFViewerView: View {
    let pdfURL: URL
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PDFKitRepresentable(url: pdfURL)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // No updates needed
    }
}

#Preview {
    PDFViewerView(
        pdfURL: Bundle.main.url(forResource: "sample", withExtension: "pdf") ?? URL(fileURLWithPath: "/"),
        title: "Sample PDF"
    )
}
