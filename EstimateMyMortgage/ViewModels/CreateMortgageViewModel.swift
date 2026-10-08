import CoreData
import Foundation

/// Identifies the editor input that needs correction and the keyboard focus destination.
enum MortgageEditorField: Hashable, Sendable {
    case name, address, property, downpayment, interest, term, tax, insurance, hoa, upkeep, closing

    init(_ field: MortgageTerms.Field) {
        switch field {
        case .propertyValue: self = .property
        case .downpaymentValue: self = .downpayment
        case .rate: self = .interest
        case .term: self = .term
        case .tax: self = .tax
        case .insurance: self = .insurance
        case .hoa: self = .hoa
        case .upkeep: self = .upkeep
        case .closing: self = .closing
        }
    }
}

/// Controls the unit of a single input without maintaining a second synchronized amount.
enum AmountInputUnit: String, CaseIterable, Identifiable {
    case dollars = "USD"
    case percent = "%"
    var id: Self { self }
}

/// Unsaved text belongs to the editor; invalid or empty numbers remain visible until corrected.
struct MortgageDraft: Equatable {
    var name = ""
    var address = ""
    var city = ""
    var state = ""
    var zip = ""
    var propertyValue = MortgageDraft.input(MortgageTerms().propertyValue)
    var downpayment = MortgageDraft.input(MortgageTerms().downpaymentValue)
    var downpaymentUnit = AmountInputUnit.dollars
    var interestRate = MortgageDraft.input(MortgageTerms().interestRatePercentage)
    var loanTerm = String(MortgageTerms().loanTermYears)
    var propertyTax = MortgageDraft.input(MortgageTerms().propertyTaxValue)
    var propertyTaxUnit = AmountInputUnit.dollars
    var insurance = MortgageDraft.input(MortgageTerms().homeInsuranceValue)
    var hoa = MortgageDraft.input(MortgageTerms().hoaFeesValue)
    var upkeep = MortgageDraft.input(MortgageTerms().upkeepValue)
    var closingCosts = MortgageDraft.input(MortgageTerms().closingCostValue)

    init(mortgage: Mortgage? = nil) {
        guard let mortgage else { return }
        name = mortgage.name
        address = mortgage.address
        city = mortgage.city
        state = mortgage.state
        zip = mortgage.zip
        propertyValue = Self.input(mortgage.propertyValue)
        downpayment = Self.input(mortgage.downpaymentValue)
        interestRate = Self.input(mortgage.interestRatePercentage)
        loanTerm = String(mortgage.loanTermYears)
        propertyTax = Self.input(mortgage.propertyTaxValue)
        insurance = Self.input(mortgage.homeInsuranceValue)
        hoa = Self.input(mortgage.hoaFeesValue)
        upkeep = Self.input(mortgage.upkeepValue)
        closingCosts = Self.input(mortgage.closingCostValue)
    }

    /// Uses the user's decimal separator, with no grouping that could make an edited number ambiguous.
    static func input(_ value: Double) -> String {
        let raw = String(value)
        let input = raw.hasSuffix(".0") ? String(raw.dropLast(2)) : raw
        return input.replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

    /// Requires the entire input to parse, including finite values; grouping and trailing text are rejected.
    static func number(_ input: String, locale: Locale = .current) -> Double? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        // A dot may be a thousands separator in comma-decimal regions. Never reinterpret a grouped amount as a smaller decimal.
        guard separator == "." || !raw.contains(".") else { return nil }
        if let grouping = locale.groupingSeparator, grouping != separator, raw.contains(grouping) {
            return nil
        }
        let normalized = raw.replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}

/// Validates a value draft and saves only after the user explicitly confirms the editor.
@MainActor
final class CreateMortgageViewModel: ObservableObject {
    @Published var draft: MortgageDraft
    let isNew: Bool
    private let provider: MortgagesProvider
    private var objectID: NSManagedObjectID?
    private var originalDraft: MortgageDraft?
    private let initialDraft: MortgageDraft

    var hasChanges: Bool { draft != initialDraft }

    init(provider: MortgagesProvider, mortgage: Mortgage? = nil) {
        self.provider = provider
        objectID = mortgage?.objectID
        isNew = mortgage == nil
        draft = MortgageDraft(mortgage: mortgage)
        initialDraft = MortgageDraft(mortgage: mortgage)
        originalDraft = mortgage.map { MortgageDraft(mortgage: $0) }
    }

    /// Converts the current raw input when its unit changes, preserving a single owner for the value.
    func changeDownpaymentUnit(to unit: AmountInputUnit) throws {
        draft.downpayment = try converted(draft.downpayment, from: draft.downpaymentUnit, to: unit, field: .downpayment)
        draft.downpaymentUnit = unit
    }

    /// Property tax percentages represent an annual percentage of the property price.
    func changePropertyTaxUnit(to unit: AmountInputUnit) throws {
        draft.propertyTax = try converted(draft.propertyTax, from: draft.propertyTaxUnit, to: unit, field: .tax)
        draft.propertyTaxUnit = unit
    }

    private func converted(_ input: String, from oldUnit: AmountInputUnit, to newUnit: AmountInputUnit, field: MortgageEditorField) throws -> String {
        guard oldUnit != newUnit else { return input }
        guard let price = MortgageDraft.number(draft.propertyValue), price > 0 else {
            throw InputError("Enter a positive property price before changing the unit.", field: .property)
        }
        guard let value = MortgageDraft.number(input), value >= 0 else {
            throw InputError("Enter a valid nonnegative amount before changing its unit.", field: field)
        }
        let converted = newUnit == .percent ? value / price * 100 : value * price / 100
        guard converted.isFinite else {
            throw InputError("This amount is too large to convert. Enter a smaller value.", field: field)
        }
        return MortgageDraft.input(converted)
    }

    /// Throws an actionable validation or store error. Cancel never mutates the stored object.
    @discardableResult
    func save() throws -> NSManagedObjectID {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw InputError("Enter a name for this estimate.", field: .name) }
        let property = try number(draft.propertyValue, label: "Property price", field: .property)
        let downpayment = try number(draft.downpayment, label: "Down payment", field: .downpayment)
        let tax = try number(draft.propertyTax, label: "Property tax", field: .tax)
        guard let term = Int(draft.loanTerm.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw InputError("Loan term must be a whole number of years.", field: .term)
        }
        let terms = MortgageTerms(
            propertyValue: property,
            downpaymentValue: draft.downpaymentUnit == .percent ? downpayment * property / 100 : downpayment,
            interestRatePercentage: try number(draft.interestRate, label: "Interest rate", field: .interest),
            loanTermYears: term,
            propertyTaxValue: draft.propertyTaxUnit == .percent ? tax * property / 100 : tax,
            homeInsuranceValue: try number(draft.insurance, label: "Home insurance", field: .insurance),
            hoaFeesValue: try number(draft.hoa, label: "HOA fees", field: .hoa),
            upkeepValue: try number(draft.upkeep, label: "Upkeep & utilities", field: .upkeep),
            closingCostValue: try number(draft.closingCosts, label: "Closing costs", field: .closing)
        )
        if let issue = terms.validationIssues.first {
            throw InputError(issue.message, field: MortgageEditorField(issue.field))
        }
        let savedMortgage = try provider.performTransaction { context in
            let mortgage: Mortgage
            if let objectID {
                guard let existing = try context.existingObject(with: objectID) as? Mortgage else {
                    throw InputError("This estimate is no longer available. Close the editor and try again.")
                }
                if let originalDraft, MortgageDraft(mortgage: existing) != originalDraft {
                    throw InputError("This estimate changed while you were editing. Close the editor and reopen it to review the latest values.")
                }
                mortgage = existing
            } else {
                mortgage = Mortgage(context: context)
            }
            mortgage.name = name
            mortgage.propertyValue = terms.propertyValue
            mortgage.downpaymentValue = terms.downpaymentValue
            mortgage.interestRatePercentage = terms.interestRatePercentage
            mortgage.loanTermYears = Int16(terms.loanTermYears)
            mortgage.propertyTaxValue = terms.propertyTaxValue
            mortgage.homeInsuranceValue = terms.homeInsuranceValue
            mortgage.hoaFeesValue = terms.hoaFeesValue
            mortgage.upkeepValue = terms.upkeepValue
            mortgage.closingCostValue = terms.closingCostValue
            mortgage.address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
            mortgage.city = draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
            mortgage.state = draft.state.trimmingCharacters(in: .whitespacesAndNewlines)
            mortgage.zip = draft.zip.trimmingCharacters(in: .whitespacesAndNewlines)
            return mortgage
        }
        objectID = savedMortgage.objectID
        originalDraft = MortgageDraft(mortgage: savedMortgage)
        return savedMortgage.objectID
    }

    private func number(_ input: String, label: String, field: MortgageEditorField) throws -> Double {
        guard let value = MortgageDraft.number(input) else {
            throw InputError("\(label) must be a valid number. Use the decimal separator for your region and omit grouping separators.", field: field)
        }
        return value
    }

    struct InputError: LocalizedError {
        let message: String
        let field: MortgageEditorField?
        init(_ message: String, field: MortgageEditorField? = nil) {
            self.message = message
            self.field = field
        }
        var errorDescription: String? { message }
    }
}
