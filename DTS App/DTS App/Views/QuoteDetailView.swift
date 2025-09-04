import SwiftUI
import SwiftData
import PDFKit

#if canImport(PDFKit)
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Always reload the document to reflect file content changes even when the URL is identical.
        uiView.document = PDFDocument(url: url)
    }
}
#endif

struct QuoteDetailView: View {
    let quote: QuoteDraft
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]

    @State private var pdfURL: URL?
    @State private var showingEdit = false
    @State private var pdfRevision = 0
    // Added state for share sheet
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if let url = pdfURL {
                #if canImport(PDFKit)
                PDFKitView(url: url)
                    .id(pdfRevision) // force refresh when revision changes
                #else
                Text("PDF preview requires PDFKit")
                    .foregroundColor(.secondary)
                #endif
            } else {
                ProgressView("Generating PDF...")
                    .padding()
            }
        }
        .navigationTitle("Quote Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Share button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if pdfURL == nil { generatePDF() }
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(pdfURL == nil)
                .accessibilityLabel("Share PDF")
            }
            // Edit button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .onAppear { generatePDF() }
        .sheet(isPresented: $showingEdit, onDismiss: {
            // Regenerate PDF after edits
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generatePDF()
            }
        }) {
            QuoteFormView(existingQuote: quote)
                .environmentObject(jobberAPI)
        }
        // Share sheet for the generated PDF
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func generatePDF() {
        let settings = settingsArray.first ?? AppSettings()
        let breakdown = PricingEngine.calculatePrice(quote: quote, settings: settings)
        #if canImport(UIKit)
        // Try to gather any stored images for this quote if available
        let images: [UIImage] = [] // Could be loaded from PhotoRecord if wired up
        if let data = PDFGenerator.shared.generateQuotePDF(
            quote: quote,
            settings: settings,
            breakdown: breakdown,
            photos: images
        ) {
            pdfRevision += 1
            let filename = "quote_\(quote.localId.uuidString)_r\(pdfRevision).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                // Flip to nil first to force view refresh, then assign new URL.
                self.pdfURL = nil
                DispatchQueue.main.async { self.pdfURL = url }
            } catch {
                print("Failed to write PDF: \(error)")
            }
        }
        #else
        if let data = PDFGenerator.shared.generateQuotePDF(
            breakdown: breakdown,
            customerName: quote.clientName.isEmpty ? "Customer" : quote.clientName
        ) {
            pdfRevision += 1
            let filename = "quote_\(quote.localId.uuidString)_r\(pdfRevision).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: url)
            self.pdfURL = nil
            DispatchQueue.main.async { self.pdfURL = url }
        }
        #endif
    }
}
