import SwiftUI
import Charts
import CoreData

/// Payment assumptions and a fixed-rate amortization schedule for a saved estimate.
struct MortgageScreen: View {
    @ObservedObject var mortgage: Mortgage
    let provider: MortgagesProvider
    @State private var editorPresented = false
    @State private var annualCosts = false
    @State private var showMap = false

    var body: some View {
        List {
            if let calculation = mortgage.terms.calculation {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated monthly cost").fixedSize(horizontal: false, vertical: true).font(.subheadline).foregroundStyle(Color.primary)
                        Text(calculation.monthlyPayment, format: .currency(code: "USD"))
                            .font(.largeTitle.weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("monthlyTotal")
                        Text(calculation.principalValue == 0 ? "All-cash purchase" : "\(mortgage.loanTermYears)-year fixed · \(mortgage.interestRatePercentage.formatted())% interest")
                            .font(.subheadline).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 8)
                } footer: {
                    Text("Includes costs below. Excludes mortgage insurance.").foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
                }
                Section(header: Text("Cost breakdown").foregroundStyle(Color.primary)) {
                    Picker("Cost period", selection: $annualCosts) {
                        Text("Monthly").tag(false)
                        Text("Yearly").tag(true)
                    }.pickerStyle(.segmented)
                    AmountRow("Principal & interest", value: calculation.baseMonthlyPayment * (annualCosts ? 12 : 1))
                    AmountRow("Property tax", value: expense(mortgage.propertyTaxValue))
                    AmountRow("Home insurance", value: expense(mortgage.homeInsuranceValue))
                    AmountRow("HOA fees", value: expense(mortgage.hoaFeesValue))
                    AmountRow("Upkeep & utilities", value: expense(mortgage.upkeepValue))
                    AmountRow(annualCosts ? "Total per year" : "Total per month", value: calculation.monthlyPayment * (annualCosts ? 12 : 1), emphasized: true)
                }
                Section(header: Text("Property & purchase").foregroundStyle(Color.primary)) {
                    AmountRow("Property value", value: mortgage.propertyValue)
                    AmountRow("Down payment", value: mortgage.downpaymentValue)
                    LabeledContent {
                        Text("\(mortgage.downpaymentPercentage.formatted(.number.precision(.fractionLength(0...2))))%").foregroundStyle(Color.primary)
                    } label: { Text("Down payment percentage") }
                    AmountRow("Closing costs", value: mortgage.closingCostValue)
                    AmountRow("Cash at closing", value: calculation.upfrontCostValue, emphasized: true)
                }
                Section {
                    AmountRow("Loan principal", value: calculation.principalValue)
                    AmountRow("Total interest", value: calculation.totalInterest)
                    AmountRow("Total loan payments", value: calculation.totalLoanPayments, emphasized: true)
                    if !calculation.annualSchedule.isEmpty {
                        NavigationLink("Amortization Schedule") {
                            AmortizationView(calculation: calculation)
                        }.accessibilityIdentifier("amortization")
                    }
                } header: {
                    Text(calculation.principalValue == 0 ? "Loan totals" : "Loan over \(mortgage.loanTermYears) years").foregroundStyle(Color.primary)
                } footer: {
                    Text("Loan totals exclude taxes, insurance, HOA fees, upkeep and closing costs.").foregroundStyle(Color.primary)
                }
            } else {
                Section {
                    ContentUnavailableView("Review this estimate", systemImage: "exclamationmark.triangle", description: Text(mortgage.terms.validationErrors.joined(separator: "\n")))
                    Button("Edit Estimate") { editorPresented = true }
                }
            }
            if !mortgage.formattedAddressString.isEmpty {
                Section(header: Text("Location").foregroundStyle(Color.primary)) {
                    Text(mortgage.formattedAddressString).textSelection(.enabled)
                    if showMap {
                        PropertyMapView(address: mortgage.formattedAddressString)
                    } else {
                        Button("Show Property Map", systemImage: "map") { showMap = true }
                    }
                }
            }
            Section(header: Text("Estimate assumptions").foregroundStyle(Color.primary)) {
                Text("Assumes a fixed rate and constant costs. Lender fees outside closing costs are excluded. Not a lender quote.")
                    .font(.footnote).foregroundStyle(Color.primary)
            }
        }
        .navigationTitle(mortgage.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { editorPresented = true }
                    .accessibilityIdentifier("editEstimate")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareSummary) { Label("Share Estimate", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareEstimate")
            }
        }
        .sheet(isPresented: $editorPresented) {
            NavigationStack { CreateMortgageView(provider: provider, mortgage: mortgage) }
        }
    }

    private func expense(_ annual: Double) -> Double { annualCosts ? annual : annual / 12 }

    private var shareSummary: String {
        guard let calculation = mortgage.terms.calculation else { return "\(mortgage.name): Estimate needs input review." }
        return """
        \(mortgage.name)
        Property: \(mortgage.propertyValue.formatted(.currency(code: "USD")))
        Down payment: \(mortgage.downpaymentValue.formatted(.currency(code: "USD")))
        Loan: \(calculation.principalValue == 0 ? "None (all-cash purchase)" : "\(mortgage.loanTermYears) years at \(mortgage.interestRatePercentage.formatted())% fixed interest")
        Principal & interest: \(calculation.baseMonthlyPayment.formatted(.currency(code: "USD"))) / month
        Total ownership estimate: \(calculation.monthlyPayment.formatted(.currency(code: "USD"))) / month
        Cash at closing: \(calculation.upfrontCostValue.formatted(.currency(code: "USD")))
        Total loan interest: \(calculation.totalInterest.formatted(.currency(code: "USD")))
        Amounts in USD. Assumes constant costs. Excludes mortgage insurance. Estimate only; not a lender quote.
        """
    }
}

/// Native label/value layout adapts to available width and the preferred text size.
struct AmountRow: View {
    let title: String
    let value: Double
    var emphasized = false

    init(_ title: String, value: Double, emphasized: Bool = false) {
        self.title = title
        self.value = value
        self.emphasized = emphasized
    }

    var body: some View {
        LabeledContent { amount } label: { Text(title) }
            .fontWeight(emphasized ? .semibold : .regular)
    }

    private var amount: some View {
        Text(value, format: .currency(code: "USD"))
            .monospacedDigit().foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
    }
}

private struct AmortizationView: View {
    let calculation: MortgageCalculation
    @State private var monthly = false

    var body: some View {
        List {
            Section(header: Text("Remaining loan balance").foregroundStyle(Color.primary)) {
                Chart {
                    LineMark(x: .value("Year", 0), y: .value("Balance", calculation.principalValue))
                    ForEach(calculation.annualSchedule) { year in
                        LineMark(x: .value("Year", year.year), y: .value("Balance", year.balance))
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel().foregroundStyle(Color.primary)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel().foregroundStyle(Color.primary)
                    }
                }
                .chartXAxisLabel { Text("Loan year").foregroundStyle(Color.primary) }
                .chartYAxisLabel { Text("USD").foregroundStyle(Color.primary) }
                .frame(height: 220)
                .accessibilityLabel("Loan balance decreases from \(calculation.principalValue.formatted(.currency(code: "USD"))) to zero over \(calculation.annualSchedule.count) years. Exact amounts follow below.")
            }
            Section {
                Picker("Schedule period", selection: $monthly) {
                    Text("Yearly").tag(false)
                    Text("Monthly").tag(true)
                }.pickerStyle(.segmented)
            } footer: {
                Text("Unrounded calculations; displayed amounts round to cents. Your lender's schedule may differ.").foregroundStyle(Color.primary)
            }
            if monthly {
                ForEach(calculation.monthlySchedule) { payment in
                    Section(header: Text("Month \(payment.month)").foregroundStyle(Color.primary)) {
                        AmountRow("Principal", value: payment.principal)
                        AmountRow("Interest", value: payment.interest)
                        AmountRow("Payment", value: payment.payment)
                        AmountRow("Balance", value: payment.balance)
                    }
                }
            } else {
                ForEach(calculation.annualSchedule) { year in
                    Section(header: Text("Year \(year.year)").foregroundStyle(Color.primary)) {
                        AmountRow("Principal", value: year.principal)
                        AmountRow("Interest", value: year.interest)
                        AmountRow("Payments", value: year.payment)
                        AmountRow("Balance", value: year.balance)
                    }
                }
            }
        }
        .navigationTitle("Amortization")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CompareEstimatesView: View {
    let mortgages: [Mortgage]
    @Environment(\.dismiss) private var dismiss
    @State private var first: NSManagedObjectID?
    @State private var second: NSManagedObjectID?

    init(mortgages: [Mortgage]) {
        self.mortgages = mortgages
        _first = State(initialValue: mortgages.first?.objectID)
        _second = State(initialValue: mortgages.dropFirst().first?.objectID)
    }

    var body: some View {
        Form {
            if mortgages.count >= 2 {
                Section(header: Text("Choose estimates").foregroundStyle(Color.primary)) {
                    LabeledContent("First estimate") {
                        Picker("First estimate", selection: $first) {
                            Text("Choose an estimate").tag(Optional<NSManagedObjectID>.none)
                            ForEach(mortgages) { Text($0.name).tag(Optional($0.objectID)) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Color.primary)
                        .accessibilityIdentifier("comparison.first")
                    }
                    LabeledContent("Second estimate") {
                        Picker("Second estimate", selection: $second) {
                            Text("Choose an estimate").tag(Optional<NSManagedObjectID>.none)
                            ForEach(mortgages) { Text($0.name).tag(Optional($0.objectID)) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Color.primary)
                        .accessibilityIdentifier("comparison.second")
                    }
                }
                if first == second {
                    Text("Choose two different estimates to compare.").foregroundStyle(Color.primary)
                } else if let firstMortgage = mortgages.first(where: { $0.objectID == first }),
                          let secondMortgage = mortgages.first(where: { $0.objectID == second }) {
                    if let a = firstMortgage.terms.calculation, let b = secondMortgage.terms.calculation {
                        Section(header: Text("Difference").foregroundStyle(Color.primary)) {
                            AmountRow("Monthly cost difference", value: abs(a.monthlyPayment - b.monthlyPayment))
                            if a.monthlyPayment.formatted(.currency(code: "USD")) == b.monthlyPayment.formatted(.currency(code: "USD")) {
                                Text("These estimates have the same monthly cost to the nearest cent.")
                            } else {
                                Text("\(a.monthlyPayment < b.monthlyPayment ? firstMortgage.name : secondMortgage.name) has the lower estimated monthly cost.")
                            }
                        }
                        amountComparison("Monthly cost", first: firstMortgage, second: secondMortgage,
                                         firstValue: a.monthlyPayment, secondValue: b.monthlyPayment, emphasized: true)
                        amountComparison("Cash at closing", first: firstMortgage, second: secondMortgage,
                                         firstValue: a.upfrontCostValue, secondValue: b.upfrontCostValue)
                        amountComparison("Total loan interest", first: firstMortgage, second: secondMortgage,
                                         firstValue: a.totalInterest, secondValue: b.totalInterest)
                        amountComparison("Property price", first: firstMortgage, second: secondMortgage,
                                         firstValue: firstMortgage.propertyValue, secondValue: secondMortgage.propertyValue)
                        amountComparison("Down payment", first: firstMortgage, second: secondMortgage,
                                         firstValue: firstMortgage.downpaymentValue, secondValue: secondMortgage.downpaymentValue)
                        Section(header: Text("Loan term").foregroundStyle(Color.primary)) {
                            LabeledContent {
                                Text(a.principalValue == 0 ? "No loan" : "\(firstMortgage.loanTermYears) years").foregroundStyle(Color.primary)
                            } label: { Text(firstMortgage.name) }
                            LabeledContent {
                                Text(b.principalValue == 0 ? "No loan" : "\(secondMortgage.loanTermYears) years").foregroundStyle(Color.primary)
                            } label: { Text(secondMortgage.name) }
                        }
                        Section(header: Text("Annual interest rate").foregroundStyle(Color.primary)) {
                            LabeledContent {
                                Text(a.principalValue == 0 ? "No loan" : "\(firstMortgage.interestRatePercentage.formatted())%").foregroundStyle(Color.primary)
                            } label: { Text(firstMortgage.name) }
                            LabeledContent {
                                Text(b.principalValue == 0 ? "No loan" : "\(secondMortgage.interestRatePercentage.formatted())%").foregroundStyle(Color.primary)
                            } label: { Text(secondMortgage.name) }
                        }
                    } else {
                        if !firstMortgage.terms.isValid {
                            Section(header: Text(firstMortgage.name).foregroundStyle(Color.primary)) { Text("Edit this estimate to correct its inputs.") }
                        }
                        if !secondMortgage.terms.isValid {
                            Section(header: Text(secondMortgage.name).foregroundStyle(Color.primary)) { Text("Edit this estimate to correct its inputs.") }
                        }
                    }
                } else {
                    Text("Choose two saved estimates. An estimate may have been deleted in another window.")
                }
            } else {
                ContentUnavailableView("Two estimates needed", systemImage: "square.split.2x1")
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: mortgages.map(\.objectID)) { _, identities in
            if let first, !identities.contains(first) { self.first = nil }
            if let second, !identities.contains(second) { self.second = nil }
        }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private func amountComparison(_ title: String, first: Mortgage, second: Mortgage,
                                  firstValue: Double, secondValue: Double, emphasized: Bool = false) -> some View {
        Section(header: Text(title).fixedSize(horizontal: false, vertical: true).foregroundStyle(Color.primary)) {
            AmountRow(first.name, value: firstValue, emphasized: emphasized)
            AmountRow(second.name, value: secondValue, emphasized: emphasized)
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section(header: Text("Estimate My Mortgage").foregroundStyle(Color.primary)) {
                Text("Save and compare fixed-rate mortgage estimates in US dollars.")
                LabeledContent {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").foregroundStyle(Color.primary)
                } label: { Text("Version") }
            }
            Section(header: Text("Privacy").foregroundStyle(Color.primary)) {
                Text("Estimates stay on this device. The app has no account, advertising or analytics service. Device backups may include your estimates.")
                Text("Address suggestions and maps send the address you request to Apple's MapKit service. No device location permission is requested. You can enter an address manually and calculate without using maps.")
                Text("Sharing sends the estimate summary only to the destination you choose in the system share sheet.")
            }
            Section(header: Text("Calculation limits").foregroundStyle(Color.primary)) {
                Text("Estimates assume a fixed rate, equal monthly payments and constant ownership costs. Mortgage insurance, future expense changes and adjustable rates are not included. Confirm costs and payment details with your lender.")
            }
        }
        .navigationTitle("About & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

#Preview("Payment details") {
    NavigationStack { MortgageScreen(mortgage: .preview(), provider: .preview) }
}

#Preview("Comparison") {
    NavigationStack {
        CompareEstimatesView(mortgages: Mortgage.makePreview(count: 2, in: MortgagesProvider.preview.viewContext))
    }
}

#Preview("About & Privacy") {
    NavigationStack { AboutView() }
}
