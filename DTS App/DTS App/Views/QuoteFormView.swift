import SwiftUI
import SwiftData

// MARK: - Quote Form View

struct QuoteFormView: View {
    let job: JobberJob?
    let prefilledQuoteDraft: QuoteDraft?

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var jobberAPI: JobberAPI
    @Query private var settingsArray: [AppSettings]
    @State private var quoteDraft = QuoteDraft()
    @State private var showingPreview = false
    @State private var showingLineItemEditor = false
    @State private var newLineItemTitle = ""
    @State private var newLineItemAmount: Double = 0
    @State private var showingSaveToJobberAlert = false
    @State private var isSavingToJobber = false
    @State private var showingJobberSuccess = false
    @State private var jobberSubmissionError: String?
    @StateObject private var photoCaptureManager = PhotoCaptureManager()
    @State private var showingPhotoGallery = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var showingPDFAlert = false

    // Calculator state
    @State private var showingCalculator = false
    @State private var calculatorField: CalculatorField?

    enum CalculatorField {
        case gutterFeet
        case downspoutFeet
        case aElbows
        case bElbows
        case twoCrimp
        case fourCrimp
        case endCapPairs
    }

    // Convenience initializers
    init(job: JobberJob?) {
        self.job = job
        self.prefilledQuoteDraft = nil
    }

    init(job: JobberJob?, prefilledQuoteDraft: QuoteDraft?) {
        self.job = job
        self.prefilledQuoteDraft = prefilledQuoteDraft
    }

    // Common labor items for quick selection
    private let commonLaborItems = [
        CommonLaborItem(title: "TV Dish Removal", amount: 75.0),
        CommonLaborItem(title: "Debris Cleanup", amount: 50.0),
        CommonLaborItem(title: "Gutter Cleaning", amount: 150.0),
        CommonLaborItem(title: "Fascia Repair", amount: 100.0),
        CommonLaborItem(title: "Soffit Repair", amount: 125.0),
        CommonLaborItem(title: "Ladder Setup", amount: 25.0)
    ]

    private var settings: AppSettings {
        settingsArray.first ?? AppSettings()
    }

    // Computed properties to simplify complex bindings
    private var markupPercentBinding: Binding<Double> {
        Binding(
            get: { quoteDraft.markupPercent * 100 },
            set: { _ in
                // Markup is now read-only on quotes page - calculated from profit margin
                // No action needed as this will be updated automatically
            }
        )
    }

    // Helper function to create a binding that clears zero values
    private func clearableNumberBinding(for value: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                if value.wrappedValue == 0 {
                    return ""
                } else {
                    // Use NumberFormatter for consistent formatting
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 2
                    formatter.usesGroupingSeparator = false
                    return formatter.string(from: NSNumber(value: value.wrappedValue)) ?? "\(value.wrappedValue)"
                }
            },
            set: { newValue in
                if let doubleValue = Double(newValue) {
                    value.wrappedValue = doubleValue
                } else if newValue.isEmpty {
                    value.wrappedValue = 0
                }
            }
        )
    }

    // Helper function for integer fields
    private func clearableIntBinding(for value: Binding<Int>) -> Binding<String> {
        Binding<String>(
            get: {
                if value.wrappedValue == 0 {
                    return ""
                } else {
                    return String(value.wrappedValue)
                }
            },
            set: { newValue in
                if let intValue = Int(newValue) {
                    value.wrappedValue = intValue
                } else if newValue.isEmpty {
                    value.wrappedValue = 0
                }
            }
        )
    }

    // New binding for percentage fields that handles the *100 conversion without auto-formatting
    private func clearablePercentFieldBinding(get: @escaping () -> Double, set: @escaping (Double) -> Void) -> Binding<String> {
        Binding<String>(
            get: {
                let percentValue = get() * 100
                if percentValue == 0 {
                    return ""
                } else {
                    // Use NumberFormatter like measurements to avoid auto-formatting
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 1
                    formatter.usesGroupingSeparator = false
                    return formatter.string(from: NSNumber(value: percentValue)) ?? "\(percentValue)"
                }
            },
            set: { newValue in
                // Don't format during typing - just parse the value and convert
                if newValue.isEmpty {
                    set(0)
                } else if let doubleValue = Double(newValue) {
                    set(doubleValue / 100)
                }
                // If parsing fails, don't update - let user continue typing
            }
        )
    }

    // Simple percentage binding for settings (no *100 conversion)
    private func clearablePercentBinding(get: @escaping () -> Double, set: @escaping (Double) -> Void) -> Binding<String> {
        Binding<String>(
            get: {
                let percentValue = get()
                if percentValue == 0 {
                    return ""
                } else {
                    return String(format: "%.1f", percentValue)
                }
            },
            set: { newValue in
                // Don't format during typing - just parse the value
                if newValue.isEmpty {
                    set(0)
                } else if let doubleValue = Double(newValue) {
                    set(doubleValue)
                }
                // If parsing fails, don't update - let user continue typing
            }
        )
    }

    @ViewBuilder
    private var measurementsSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                HStack {
                    Text("Gutter Feet")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .gutterFeet
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableNumberBinding(for: $quoteDraft.gutterFeet))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("Downspout Feet")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .downspoutFeet
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableNumberBinding(for: $quoteDraft.downspoutFeet))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("Round Downspout")
                    Spacer()
                    Toggle("", isOn: $quoteDraft.isRoundDownspout)
                        .labelsHidden()
                }

                // Individual Elbows and Crimps
                HStack {
                    Text("A Elbows")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .aElbows
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableIntBinding(for: $quoteDraft.aElbows))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("B Elbows")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .bElbows
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableIntBinding(for: $quoteDraft.bElbows))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("2\" Crimp")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .twoCrimp
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableIntBinding(for: $quoteDraft.twoCrimp))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("4\" Crimp")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .fourCrimp
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableIntBinding(for: $quoteDraft.fourCrimp))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("End Cap Pairs")
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            calculatorField = .endCapPairs
                            showingCalculator = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        TextField("0", text: clearableIntBinding(for: $quoteDraft.endCapPairs))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }

                HStack {
                    Text("Hangers (auto-calculated)")
                    Spacer()
                    Text("\(quoteDraft.hangersCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Total Footage")
                    Spacer()
                    Text(String(format: "%.1f ft", quoteDraft.gutterFeet + quoteDraft.downspoutFeet + Double(quoteDraft.aElbows + quoteDraft.bElbows + quoteDraft.twoCrimp + quoteDraft.fourCrimp)))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var colorSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Selection")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                HStack {
                    Text("Gutter Color")
                    Spacer()
                    TextField("Enter color", text: $quoteDraft.gutterColor)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var gutterGuardSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gutter Guard")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                Toggle("Include Gutter Guard", isOn: $quoteDraft.includeGutterGuard)

                if quoteDraft.includeGutterGuard {
                    HStack {
                        Text("Gutter Guard Feet")
                        Spacer()
                        TextField("0", text: clearableNumberBinding(for: $quoteDraft.gutterGuardFeet))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .onChange(of: quoteDraft.includeGutterGuard) { _, newValue in
            if newValue && quoteDraft.gutterGuardFeet == 0 {
                quoteDraft.gutterGuardFeet = quoteDraft.gutterFeet
            }
        }
    }


    private var breakdown: PricingEngine.PriceBreakdown {
        return PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
    }

    var body: some View {
        NavigationStack {
            formContent
            .navigationTitle(job != nil ? "Create Quote" : "Standalone Quote")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarContent
                }
            }
            .alert("Save to Jobber", isPresented: $showingSaveToJobberAlert) {
                alertButtons
            } message: {
                Text("Would you like to save this quote locally only or submit it to Jobber?\n\nJobber submission will:\n• Add quote details as a note with photos\n• Create an official quote with proper line items")
            }
            .fullScreenCover(isPresented: $photoCaptureManager.showingCamera) {
                CameraView(isPresented: $photoCaptureManager.showingCamera, captureCount: $photoCaptureManager.captureCount) { image in
                    photoCaptureManager.processImage(image, quoteDraftId: quoteDraft.localId)
                }
            }
            .sheet(isPresented: $photoCaptureManager.showingPhotoLibrary) {
                PhotoLibraryPicker(isPresented: $photoCaptureManager.showingPhotoLibrary) { image in
                    photoCaptureManager.processImage(image, quoteDraftId: quoteDraft.localId)
                }
            }
            .sheet(isPresented: $showingPhotoGallery) {
                PhotoGalleryView(photos: photoCaptureManager.capturedImages)
            }
            .alert("PDF Generated", isPresented: $showingPDFAlert) {
                Button("View & Share PDF") {
                    if generatedPDFURL != nil {
                        showingShareSheet = true
                    }
                }
                Button("OK") { }
            } message: {
                Text("Quote PDF has been generated successfully. You can view and share it with your client.")
            }
            .alert("Quote Submitted Successfully!", isPresented: $showingJobberSuccess) {
                Button("OK") { }
            } message: {
                Text("Your quote has been added as a note to the Jobber assessment and created as an official quote with proper line items and pricing.")
            }
            .alert("Submission Failed", isPresented: .constant(jobberSubmissionError != nil)) {
                Button("OK") {
                    jobberSubmissionError = nil
                }
            } message: {
                Text(jobberSubmissionError ?? "Unknown error occurred")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = generatedPDFURL {
                    ShareSheet(activityItems: [pdfURL])
                }
            }
            .sheet(isPresented: $showingCalculator) {
                CalculatorView(isPresented: $showingCalculator, onComplete: { result in
                    handleCalculatorResult(result)
                })
            }
        }
        .onAppear {
            // If we have a pre-filled quote draft, use it
            if let prefilledQuoteDraft = prefilledQuoteDraft {
                quoteDraft = prefilledQuoteDraft
                print("Using pre-filled quote draft for client: \(prefilledQuoteDraft.clientName)")
            }

            // Initialize with default values from settings
            // For new quotes (where all percentages are 0), always apply current settings
            if quoteDraft.markupPercent == 0 && quoteDraft.profitMarginPercent == 0 && quoteDraft.salesCommissionPercent == 0 {
                quoteDraft.markupPercent = settings.defaultMarkupPercent
                quoteDraft.profitMarginPercent = settings.defaultProfitMarginPercent  
                quoteDraft.salesCommissionPercent = settings.defaultSalesCommissionPercent
                print("Applied current settings to new quote: Markup \(settings.defaultMarkupPercent*100)%, Profit \(settings.defaultProfitMarginPercent*100)%, Commission \(settings.defaultSalesCommissionPercent*100)%")
            } else {
                // For existing quotes, only fill in missing values
                if quoteDraft.markupPercent == 0 {
                    quoteDraft.markupPercent = settings.defaultMarkupPercent
                }
                if quoteDraft.profitMarginPercent == 0 {
                    quoteDraft.profitMarginPercent = settings.defaultProfitMarginPercent
                }
                if quoteDraft.salesCommissionPercent == 0 {
                    quoteDraft.salesCommissionPercent = settings.defaultSalesCommissionPercent
                }
            }

            // Set job ID if available
            if let jobId = job?.jobId {
                quoteDraft.jobId = jobId
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                colorSectionContent
                measurementsSectionContent
                gutterGuardSectionContent
                additionalLaborSectionContent

                if showingLineItemEditor {
                    NewLaborItemView(
                        title: $newLineItemTitle,
                        amount: $newLineItemAmount,
                        commonLaborItems: commonLaborItems,
                        onSave: saveNewLineItem,
                        onCancel: cancelLineItemEdit,
                        onSelectItem: selectCommonLineItem
                    )
                }

                pricingSectionContent

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    VStack {
                        PreviewSection(quoteDraft: quoteDraft, breakdown: breakdown)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                photosSectionContent
            }
            .padding(.bottom, 50)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private var additionalLaborSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Labor")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                ForEach(Array(quoteDraft.additionalLaborItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline)
                            Text(item.amount.toCurrency())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            removeLineItem(item)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Direct Button implementation without Form wrapper
                Button(action: addNewLineItem) {
                    Text("Add Labor Item")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var pricingSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Markup %")
                            .fontWeight(.medium)
                        Text("(calculated from margin)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f", quoteDraft.markupPercent * 100))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        .foregroundColor(.secondary)
                    Text("%")
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Profit Margin %")
                            .fontWeight(.medium)
                        Text("(based on price)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    TextField("20", text: clearablePercentFieldBinding(
                        get: { quoteDraft.profitMarginPercent },
                        set: { newProfitMarginPercent in
                            let m = newProfitMarginPercent  // profit margin as decimal
                            let s = quoteDraft.salesCommissionPercent  // commission as decimal

                            // Validate that m + s < 1 (mathematically required)
                            guard m >= 0 && (m + s) < 1 else {
                                return  // Don't update if invalid
                            }

                            quoteDraft.profitMarginPercent = m

                            // Auto-calculate markup from profit margin using commission-aware formula
                            // Formula: k = (m + s) / (1 - m - s)
                            let calculatedMarkup = (m + s) / (1 - m - s)
                            quoteDraft.markupPercent = calculatedMarkup
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    Text("%")
                }

                HStack {
                    Text("Sales Commission %")
                    Spacer()
                    TextField("3", text: clearablePercentFieldBinding(
                        get: { quoteDraft.salesCommissionPercent },
                        set: { newCommissionPercent in
                            quoteDraft.salesCommissionPercent = newCommissionPercent

                            // When commission changes, recalculate markup from current profit margin
                            // to maintain the mathematical relationship
                            let m = quoteDraft.profitMarginPercent  // current profit margin
                            let s = newCommissionPercent  // new commission as decimal

                            // Ensure the calculated relationship is valid
                            if m >= 0 && (m + s) < 1 {
                                // Recalculate markup: k = (m + s) / (1 - m - s)
                                let calculatedMarkup = (m + s) / (1 - m - s)
                                quoteDraft.markupPercent = calculatedMarkup
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    Text("%")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // Computed property for filtered photos
    private var quoteDraftPhotos: [CapturedPhoto] {
        return photoCaptureManager.capturedImages
    }

    @ViewBuilder
    private var photosButtonSection: some View {
        HStack {
            Button(action: {
                photoCaptureManager.capturePhoto(quoteDraftId: quoteDraft.localId)
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Capture Photo")
                }
                .foregroundColor(.blue)
            }

            Spacer()

            if !quoteDraftPhotos.isEmpty {
                Button("View Photos (\(quoteDraftPhotos.count))") {
                    showingPhotoGallery = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }

        @ViewBuilder
    private func photoPreviewSection() -> some View {
        if !quoteDraftPhotos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<min(quoteDraftPhotos.count, 3), id: \.self) { index in
                        let image = quoteDraftPhotos[index].image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    }

                    if quoteDraftPhotos.count > 3 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)

                            VStack {
                                Image(systemName: "photo.stack")
                                    .foregroundColor(.gray)
                                Text("+\(quoteDraftPhotos.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 100)
        }
    }

    @ViewBuilder
    private var photosSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                photosButtonSection
                photoPreviewSection()

                if let locationError = photoCaptureManager.locationError {
                    Text(locationError)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var toolbarContent: some View {
        HStack {
            if jobberAPI.isAuthenticated && job != nil {
                Button(isSavingToJobber ? "Saving..." : "Save to Jobber") {
                    showingSaveToJobberAlert = true
                }
                .disabled(quoteDraft.gutterFeet == 0 || isSavingToJobber)
            }

            Button("Save Quote") {
                saveQuote()
            }
            .disabled(false)
        }
    }

    @ViewBuilder
    private var alertButtons: some View {
        Button("Save Local Only") {
            saveQuote()
        }

        Button(isSavingToJobber ? "Saving..." : "Save to Jobber") {
            saveQuoteToJobber()
        }
        .disabled(isSavingToJobber)

        Button("Cancel", role: .cancel) { }
    }

    private func saveQuote() {
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Save quote to database
        modelContext.insert(quoteDraft)
        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)
    }

    private func saveQuoteToJobber() {
        isSavingToJobber = true

        // First save locally
        saveQuote()

        // Then submit to Jobber as note AND create a quote
        Task {
            do {
                guard let job = job else {
                    throw JobberAPIError.invalidRequest("No job available")
                }

                print("🔍 saveQuoteToJobber - Job: \(job.jobId)")
                print("🔍 saveQuoteToJobber - Job requestId: \(String(describing: job.requestId))")

                guard let requestId = job.requestId else {
                    throw JobberAPIError.invalidRequest("No request ID available for this assessment - this assessment might not be linked to a request")
                }

                print("📤 Submitting quote to Jobber with requestId: \(requestId)")

                // Calculate current breakdown
                let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)

                // Get captured photos
                let photos = photoCaptureManager.capturedImages.map { $0.image }

                // Step 1: Submit quote as note to Jobber (existing functionality)
                let noteResult = await jobberAPI.submitQuoteAsNote(
                    requestId: requestId,
                    quote: quoteDraft,
                    breakdown: breakdown,
                    photos: photos
                )

                // Step 2: Create actual quote in Jobber with proper line items
                let quoteResult = await jobberAPI.createQuoteFromJobWithMeasurements(
                    job: job,
                    quoteDraft: quoteDraft,
                    breakdown: breakdown
                )

                await MainActor.run {
                    var hasError = false
                    var errorMessages: [String] = []

                    // Check note creation result
                    switch noteResult {
                    case .success(_):
                        print("✅ Note created successfully")
                    case .failure(let error):
                        hasError = true
                        errorMessages.append("Note creation failed: \(error.localizedDescription)")
                    }

                    // Check quote creation result
                    switch quoteResult {
                    case .success(let quoteId):
                        print("✅ Quote created successfully with ID: \(quoteId)")
                    case .failure(let error):
                        hasError = true
                        errorMessages.append("Quote creation failed: \(error.localizedDescription)")
                    }

                    if hasError {
                        jobberSubmissionError = errorMessages.joined(separator: "\n")
                    } else {
                        // Show success message
                        showingJobberSuccess = true
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }

                    isSavingToJobber = false
                }
            } catch {
                await MainActor.run {
                    jobberSubmissionError = error.localizedDescription
                    isSavingToJobber = false
                }
            }
        }
    }

    private func generateQuotePDF(breakdown: PricingEngine.PriceBreakdown) {
        // Get photos for this quote (currently unused but available for future features)
        let _ = photoCaptureManager.capturedImages

        // Generate PDF
        if let pdfData = PDFGenerator.shared.generateQuotePDF(
            breakdown: breakdown,
            customerName: "Customer" // TODO: Add customer name field to QuoteDraft
        ) {
            // Save to temporary URL for sharing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("quote_\(quoteDraft.localId.uuidString).pdf")
            do {
                try pdfData.write(to: tempURL)
                generatedPDFURL = tempURL
                showingPDFAlert = true
            } catch {
                print("Error saving PDF: \(error)")
            }
        }
    }

    // MARK: - Additional Labor Item Management

    private func addNewLineItem() {
        showingLineItemEditor = true
        newLineItemTitle = ""
        newLineItemAmount = 0
    }

    private func selectCommonLineItem(_ item: CommonLaborItem) {
        newLineItemTitle = item.title
        newLineItemAmount = item.amount
    }

    private func saveNewLineItem() {
        let newItem = LineItem(title: newLineItemTitle, amount: newLineItemAmount)
        quoteDraft.additionalLaborItems.append(newItem)

        cancelLineItemEdit()
    }

    private func removeLineItem(_ item: LineItem) {
        if let index = quoteDraft.additionalLaborItems.firstIndex(where: { $0.title == item.title && $0.amount == item.amount }) {
            quoteDraft.additionalLaborItems.remove(at: index)
        }
    }

    private func handleCalculatorResult(_ result: Double) {
        guard let field = calculatorField else { return }

        switch field {
        case .gutterFeet:
            quoteDraft.gutterFeet = result
        case .downspoutFeet:
            quoteDraft.downspoutFeet = result
        case .aElbows:
            quoteDraft.aElbows = Int(result)
        case .bElbows:
            quoteDraft.bElbows = Int(result)
        case .twoCrimp:
            quoteDraft.twoCrimp = Int(result)
        case .fourCrimp:
            quoteDraft.fourCrimp = Int(result)
        case .endCapPairs:
            quoteDraft.endCapPairs = Int(result)
        }

        calculatorField = nil
    }

    private func cancelLineItemEdit() {
        showingLineItemEditor = false
        newLineItemTitle = ""
        newLineItemAmount = 0
    }
}
