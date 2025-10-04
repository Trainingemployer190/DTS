import SwiftUI
import SwiftData

// MARK: - Quote Form View

struct QuoteFormView: View {
    let job: JobberJob?
    let prefilledQuoteDraft: QuoteDraft?
    let existingQuote: QuoteDraft? // For editing existing quotes

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss // Add dismiss for editing mode
    @EnvironmentObject private var jobberAPI: JobberAPI
    @EnvironmentObject var router: AppRouter
    @Query private var settingsArray: [AppSettings]
    @State private var quoteDraft = QuoteDraft()
    @State private var showingPreview = false
    @State private var showingLineItemEditor = false
    @State private var newLineItemTitle = ""
    @State private var newLineItemAmount: Double = 0
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

    // Added focus state for sales commission field
    @FocusState private var isSalesCommissionFocused: Bool
    @FocusState private var isProfitMarginFocused: Bool

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
        self.existingQuote = nil
    }

    init(job: JobberJob?, prefilledQuoteDraft: QuoteDraft?) {
        self.job = job
        self.prefilledQuoteDraft = prefilledQuoteDraft
        self.existingQuote = nil
    }

    // New initializer for editing existing quotes
    init(existingQuote: QuoteDraft) {
        self.job = nil
        self.prefilledQuoteDraft = nil
        self.existingQuote = existingQuote
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
            } else if !newValue {
                quoteDraft.gutterGuardFeet = 0
            }

            // Apply independent pricing when toggling guard
            if newValue {
                // When guard is enabled, use the quote's guard-specific margin/markup
                if quoteDraft.guardProfitMarginPercent == 0 {
                    quoteDraft.guardProfitMarginPercent = settings.gutterGuardProfitMarginPercent
                }
                // Ensure guard markup matches guard margin
                let m = quoteDraft.guardProfitMarginPercent
                quoteDraft.guardMarkupPercent = m >= 1 ? 0 : (m / max(1 - m, 0.000001))
            } else {
                // When guard is disabled, keep regular gutter pricing intact; do not modify
            }
        }
    }


    private var breakdown: PricingEngine.PriceBreakdown {
        return PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
    }

    var body: some View {
        NavigationStack {
            formContent
            .navigationTitle(existingQuote != nil ? "Edit Quote" : (job != nil ? "Create Quote" : "Standalone Quote"))
            .toolbar {
                if existingQuote != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
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
            .safeAreaInset(edge: .top) {
                topActionButtonsBar
            }
            .safeAreaInset(edge: .bottom) {
                actionButtonsBar
            }
        }
        .onAppear {
            // If we have an existing quote (editing mode), use it
            if let existingQuote = existingQuote {
                quoteDraft = existingQuote
                print("Editing existing quote for client: \(existingQuote.clientName)")
                return
            }

            // If we have a pre-filled quote draft, use it
            if let prefilledQuoteDraft = prefilledQuoteDraft {
                quoteDraft = prefilledQuoteDraft
                print("Using pre-filled quote draft for client: \(prefilledQuoteDraft.clientName)")
            }

            // Populate client information from job if available
            if let job = job {
                quoteDraft.clientName = job.clientName
                quoteDraft.clientAddress = job.address
                quoteDraft.clientId = job.clientId
                print("Populated client info from job: \(job.clientName) at \(job.address)")
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

            if quoteDraft.includeGutterGuard {
                if quoteDraft.guardProfitMarginPercent == 0 {
                    quoteDraft.guardProfitMarginPercent = settings.gutterGuardProfitMarginPercent
                }
                let m = quoteDraft.guardProfitMarginPercent
                quoteDraft.guardMarkupPercent = m >= 1 ? 0 : (m / max(1 - m, 0.000001))
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
                clientInfoSectionContent
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
                        PreviewSection(quoteDraft: quoteDraft, breakdown: breakdown, appSettings: settings)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                photosSectionContent
            }
            .padding(.bottom, 16)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private var clientInfoSectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Information")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 16) {
                HStack {
                    Text("Client Name")
                    Spacer()
                    TextField("Enter client name", text: $quoteDraft.clientName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                .padding(.horizontal)

                HStack {
                    Text("Address")
                    Spacer()
                    TextField("Enter address", text: $quoteDraft.clientAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
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
                            let m = newProfitMarginPercent  // decimal 0..1
                            guard m >= 0 && m < 1 else { return }
                            quoteDraft.profitMarginPercent = m
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .focused($isProfitMarginFocused)
                    .onChange(of: quoteDraft.profitMarginPercent) { _, newValue in
                        // Immediately update markup when profit margin changes
                        let m = newValue
                        if m >= 0 && m < 1 {
                            let calculatedMarkup = m / max(1 - m, 0.000001)
                            quoteDraft.markupPercent = calculatedMarkup
                        }
                    }
                    .onSubmit {
                        let m = quoteDraft.profitMarginPercent
                        let calculatedMarkup = m / (1 - m)
                        quoteDraft.markupPercent = calculatedMarkup
                    }
                    .onChange(of: isProfitMarginFocused) { _, focused in
                        if !focused {
                            let m = quoteDraft.profitMarginPercent
                            let calculatedMarkup = m / (1 - m)
                            quoteDraft.markupPercent = calculatedMarkup
                        }
                    }
                    Text("%")
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Sales Commission %")
                            .fontWeight(.medium)
                        Text("(added to total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    TextField("3", text: clearablePercentFieldBinding(
                        get: { quoteDraft.salesCommissionPercent },
                        set: { newCommissionPercent in
                            // Update commission only; do not recalculate markup here
                            quoteDraft.salesCommissionPercent = newCommissionPercent
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .focused($isSalesCommissionFocused)
                    Text("%")
                }

                if quoteDraft.includeGutterGuard {
                    Divider().padding(.vertical, 4)
                    // Guard-specific pricing controls
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Guard Markup %")
                                .fontWeight(.medium)
                            Text("(calculated from guard margin)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f", quoteDraft.guardMarkupPercent * 100))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .foregroundColor(.secondary)
                        Text("%")
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Guard Profit Margin %")
                                .fontWeight(.medium)
                            Text("(based on price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("20", text: clearablePercentFieldBinding(
                            get: { quoteDraft.guardProfitMarginPercent },
                            set: { newMargin in
                                let m = newMargin
                                guard m >= 0 && m < 1 else { return }
                                quoteDraft.guardProfitMarginPercent = m
                                // Auto-calc guard markup from guard margin
                                let k = m / max(1 - m, 0.000001)
                                quoteDraft.guardMarkupPercent = k
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                        .onChange(of: quoteDraft.guardProfitMarginPercent) { _, newValue in
                            // Ensure guard markup updates immediately
                            let m = newValue
                            if m >= 0 && m < 1 {
                                let k = m / max(1 - m, 0.000001)
                                quoteDraft.guardMarkupPercent = k
                            }
                        }
                        Text("%")
                    }
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
    private var actionButtonsBar: some View {
        Group {
            if existingQuote != nil {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Save Changes") {
                            saveQuote()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        if existingQuote?.quoteStatus != .completed {
                            Button("Complete Quote") {
                                saveQuoteAsCompleted()
                            }
                            .disabled(quoteDraft.gutterFeet == 0)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Add "Save to Jobber" option for existing quotes that haven't been saved to Jobber yet
                    if jobberAPI.isAuthenticated && !quoteDraft.savedToJobber && quoteDraft.jobId != nil {
                        Button(action: {
                            saveEditedQuoteToJobber()
                        }) {
                            HStack {
                                if isSavingToJobber {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                    Text("Saving to Jobber...")
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Save to Jobber")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(quoteDraft.gutterFeet == 0 || isSavingToJobber)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            } else if jobberAPI.isAuthenticated && job != nil {
                EmptyView()
            } else {
                HStack {
                    Button("Complete Quote") {
                        saveQuoteAsCompleted()
                    }
                    .disabled(quoteDraft.gutterFeet == 0)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private var topActionButtonsBar: some View {
        if existingQuote == nil && jobberAPI.isAuthenticated && job != nil {
            HStack(spacing: 8) {
                Button(action: {
                    saveQuoteToJobber()
                }) {
                    Text(isSavingToJobber ? "Saving to Jobber…" : "Save to Jobber")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 150)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(quoteDraft.gutterFeet == 0 || isSavingToJobber)

                Button(action: {
                    saveQuoteAsDraft()
                }) {
                    Text("Save as Draft")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 150)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(quoteDraft.gutterFeet == 0)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .padding(.vertical, 4)
        } else {
            EmptyView()
        }
    }

    private func saveQuote() {
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Only insert if it's a new quote (not editing existing)
        if existingQuote == nil {
            modelContext.insert(quoteDraft)
        }

        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)

        // If editing, dismiss the view
        if existingQuote != nil {
            dismiss()
        }
    }

    private func saveQuoteAsCompleted() {
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)
        // Mark as completed and add to history
        quoteDraft.quoteStatus = .completed
        quoteDraft.completedAt = Date()
        if let job = job { quoteDraft.clientAddress = job.address }
        if existingQuote == nil { modelContext.insert(quoteDraft) }
        try? modelContext.save()
        // Generate PDF
        generateQuotePDF(breakdown: breakdown)
        // Navigate to Home after completion
        DispatchQueue.main.async {
            router.selectedTab = 0
            dismiss()
        }
    }

    private func saveQuoteAsDraft() {
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Mark as draft and add to history
        quoteDraft.quoteStatus = .draft
        quoteDraft.createdAt = Date()
        if let job = job {
            quoteDraft.clientAddress = job.address
            quoteDraft.clientName = job.clientName
        }

        if existingQuote == nil {
            modelContext.insert(quoteDraft)
        }
        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)

        // Navigate to Home after saving draft
        DispatchQueue.main.async {
            router.selectedTab = 0
            dismiss()
        }
    }

    private func saveQuoteToJobber() {
        isSavingToJobber = true

        // First save and complete the quote locally (same as saveQuoteAsCompleted)
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Mark as completed and add to history
        quoteDraft.quoteStatus = .completed
        quoteDraft.completedAt = Date()
        if let job = job { quoteDraft.clientAddress = job.address }
        if existingQuote == nil { modelContext.insert(quoteDraft) }
        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)

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
                    breakdown: breakdown,
                    settings: settings
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
                        // Mark as saved to Jobber when successful
                        quoteDraft.savedToJobber = true

                        // Show success message
                        showingJobberSuccess = true
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        // Navigate to Home after successful submission
                        DispatchQueue.main.async {
                            router.selectedTab = 0
                            dismiss()
                        }
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

    private func saveEditedQuoteToJobber() {
        isSavingToJobber = true

        // First save the quote locally with any changes
        let breakdown = PricingEngine.calculatePrice(quote: quoteDraft, settings: settings)
        PricingEngine.updateQuoteWithCalculatedTotals(quote: quoteDraft, breakdown: breakdown)

        // Mark as completed if it wasn't already
        if quoteDraft.quoteStatus != .completed {
            quoteDraft.quoteStatus = .completed
            quoteDraft.completedAt = Date()
        }

        try? modelContext.save()

        // Generate PDF
        generateQuotePDF(breakdown: breakdown)

        // Submit to Jobber
        Task {
            do {
                // Find the job from jobId since we're editing an existing quote
                guard let jobId = quoteDraft.jobId,
                      let job = jobberAPI.jobs.first(where: { $0.jobId == jobId }) else {
                    throw JobberAPIError.invalidRequest("Cannot find the associated Jobber assessment. The assessment may have been updated or removed.")
                }

                guard let requestId = job.requestId else {
                    throw JobberAPIError.invalidRequest("No request ID available for this assessment - this assessment might not be linked to a request")
                }

                print("📤 Submitting edited quote to Jobber with requestId: \(requestId)")

                // Get any existing photos for this quote
                let photos = quoteDraft.photos.compactMap { photoRecord in
                    UIImage(contentsOfFile: photoRecord.fileURL)
                }

                // Step 1: Submit quote as note to Jobber
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
                    breakdown: breakdown,
                    settings: settings
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
                        // Mark as saved to Jobber when successful
                        quoteDraft.savedToJobber = true
                        try? modelContext.save()

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
        let images = photoCaptureManager.capturedImages.map { $0.image }

        // Enhanced PDF with all details
        #if canImport(UIKit)
        if let pdfData = PDFGenerator.shared.generateQuotePDF(
            quote: quoteDraft,
            settings: settings,
            breakdown: breakdown,
            photos: images
        ) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("quote_\(quoteDraft.localId.uuidString).pdf")
            do {
                try pdfData.write(to: tempURL)
                generatedPDFURL = tempURL
                showingPDFAlert = true
            } catch {
                print("Error saving PDF: \(error)")
            }
        }
        #else
        // Fallback to basic PDF if UIKit not available
        if let pdfData = PDFGenerator.shared.generateQuotePDF(
            breakdown: breakdown,
            customerName: quoteDraft.clientName.isEmpty ? "Customer" : quoteDraft.clientName
        ) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("quote_\(quoteDraft.localId.uuidString).pdf")
            try? pdfData.write(to: tempURL)
            generatedPDFURL = tempURL
            showingPDFAlert = true
        }
        #endif
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

