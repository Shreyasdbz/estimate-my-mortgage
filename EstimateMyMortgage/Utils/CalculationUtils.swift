import Foundation

/// A fixed-rate purchase estimate. Tax, insurance, association fees, and upkeep are annual dollar amounts; closing costs are paid once.
struct MortgageTerms: Equatable, Sendable {
    var propertyValue: Double = 500_000
    var downpaymentValue: Double = 100_000
    var interestRatePercentage: Double = 5.5
    var loanTermYears: Int = 30
    var propertyTaxValue: Double = 7_500
    var homeInsuranceValue: Double = 1_500
    var hoaFeesValue: Double = 1_000
    var upkeepValue: Double = 3_500
    var closingCostValue: Double = 8_000

    /// Identifies the form value that needs correction, independent of localized error wording.
    enum Field: Equatable, Sendable {
        case propertyValue, downpaymentValue, rate, term, tax, insurance, hoa, upkeep, closing
    }

    /// A semantic input failure and the field responsible for it.
    struct ValidationIssue: Equatable, Sendable {
        let field: Field
        let message: String
    }

    /// Input errors in form order. No nonfinite or negative dollar amounts may enter a calculation.
    var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if !validatePropertyValue(value: propertyValue) {
            issues.append(ValidationIssue(field: .propertyValue, message: "Enter a home price greater than zero."))
        }
        if !validateDownpaymentValue(downpaymentValue: downpaymentValue, propertyValue: propertyValue) {
            issues.append(ValidationIssue(field: .downpaymentValue, message: "Enter a down payment from zero to the home price."))
        }
        if !validateInterestRateValue(value: interestRatePercentage) {
            issues.append(ValidationIssue(field: .rate, message: "Enter an annual interest rate from 0% to 50%."))
        }
        if !(1...100).contains(loanTermYears) {
            issues.append(ValidationIssue(field: .term, message: "Enter a loan term from 1 to 100 years."))
        }
        let costs: [(Field, String, Double)] = [(.tax, "Property tax", propertyTaxValue), (.insurance, "Home insurance", homeInsuranceValue), (.hoa, "Association fees", hoaFeesValue), (.upkeep, "Upkeep", upkeepValue), (.closing, "Closing costs", closingCostValue)]
        for (field, label, value) in costs {
            if !value.isFinite || value < 0 {
                issues.append(ValidationIssue(field: field, message: "\(label) must be zero or a positive dollar amount."))
            }
        }
        // Prevent finite inputs whose totals would overflow from becoming a valid saved estimate.
        if issues.isEmpty {
            let annualCosts = propertyTaxValue + homeInsuranceValue + hoaFeesValue + upkeepValue
            let upfront = downpaymentValue + closingCostValue
            let principal = propertyValue - downpaymentValue
            let payment = fixedMonthlyPayment(principal: principal, annualRate: interestRatePercentage, years: loanTermYears)
            if !annualCosts.isFinite || !upfront.isFinite || !payment.isFinite || !(payment * Double(loanTermYears * 12)).isFinite || !(payment + annualCosts / 12).isFinite || !(payment * 12 + annualCosts).isFinite {
                issues.append(ValidationIssue(field: .propertyValue, message: "These amounts are too large to calculate. Enter smaller values."))
            }
        }
        return issues
    }

    var validationErrors: [String] { validationIssues.map(\.message) }

    var isValid: Bool { validationErrors.isEmpty }

    /// Monthly loan and ownership cost for valid inputs, without building a payment schedule.
    var monthlyCostPreview: Double? {
        guard isValid else { return nil }
        return monthlyOwnershipCost
    }

    fileprivate var monthlyOwnershipCost: Double {
        fixedMonthlyPayment(principal: propertyValue - downpaymentValue, annualRate: interestRatePercentage, years: loanTermYears)
            + (propertyTaxValue + homeInsuranceValue + hoaFeesValue + upkeepValue) / 12
    }

    /// Returns nil for invalid terms. All-cash purchases retain ownership expenses and have no loan schedule.
    var calculation: MortgageCalculation? {
        guard isValid else { return nil }
        return MortgageCalculation(terms: self)
    }
}

/// A single scheduled payment, without ownership costs. Values are unrounded dollars; month is one-based.
struct AmortizationPayment: Identifiable, Equatable, Sendable {
    let month: Int
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double
    var id: Int { month }
}

/// A loan year's payment totals and remaining balance. Year is one-based.
struct AmortizationYear: Identifiable, Equatable, Sendable {
    let year: Int
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double
    var id: Int { year }
}

/// Results for valid fixed-rate terms. No PMI, variable rates, or closing costs financed into the loan are assumed.
struct MortgageCalculation: Equatable, Sendable {
    let principalValue: Double
    let upfrontCostValue: Double
    let baseMonthlyPayment: Double
    let monthlyPayment: Double
    let totalInterest: Double
    let totalLoanPayments: Double
    let monthlySchedule: [AmortizationPayment]
    let annualSchedule: [AmortizationYear]

    fileprivate init(terms: MortgageTerms) {
        principalValue = terms.propertyValue - terms.downpaymentValue
        upfrontCostValue = terms.downpaymentValue + terms.closingCostValue
        baseMonthlyPayment = fixedMonthlyPayment(principal: principalValue, annualRate: terms.interestRatePercentage, years: terms.loanTermYears)
        monthlyPayment = terms.monthlyOwnershipCost

        let count = terms.loanTermYears * 12
        let monthlyRate = terms.interestRatePercentage / 1_200
        var balance = principalValue
        var payments: [AmortizationPayment] = []
        if principalValue > 0 {
            payments.reserveCapacity(count)
            let rateLog = log1p(monthlyRate)
            let denominator = -expm1(-Double(count) * rateLog)
            for month in 1...count {
                let interest = balance * monthlyRate
                let nextBalance: Double
                if monthlyRate == 0 {
                    nextBalance = principalValue * (Double(count - month) / Double(count))
                } else {
                    // The analytic balance avoids recurrence drift at long terms and high rates, where an early principal payment can round to zero.
                    nextBalance = principalValue * (-expm1(-Double(count - month) * rateLog) / denominator)
                }
                let principal = max(0, balance - nextBalance)
                balance = nextBalance
                payments.append(AmortizationPayment(month: month, payment: principal + interest, principal: principal, interest: interest, balance: balance))
            }
        }
        monthlySchedule = payments
        totalInterest = payments.reduce(0) { $0 + $1.interest }
        totalLoanPayments = principalValue + totalInterest

        var years: [AmortizationYear] = []
        for start in stride(from: 0, to: payments.count, by: 12) {
            let yearPayments = payments[start..<min(start + 12, payments.count)]
            years.append(AmortizationYear(year: start / 12 + 1, payment: yearPayments.reduce(0) { $0 + $1.payment }, principal: yearPayments.reduce(0) { $0 + $1.principal }, interest: yearPayments.reduce(0) { $0 + $1.interest }, balance: yearPayments.last!.balance))
        }
        annualSchedule = years
    }
}

/// Stable annuity formula, including zero rates. Caller validates finite inputs and the supported term/rate ranges.
private func fixedMonthlyPayment(principal: Double, annualRate: Double, years: Int) -> Double {
    guard principal > 0 else { return 0 }
    let count = Double(years * 12)
    let rate = annualRate / 1_200
    guard rate > 0 else { return principal / count }
    // log1p/expm1 preserve precision when the rate is near zero.
    return principal * (rate / -expm1(-count * log1p(rate)))
}

/// Estimate names need at least one non-whitespace character.
func validateNameInput(value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// Home prices must be positive and finite.
func validatePropertyValue(value: Double) -> Bool {
    value.isFinite && value > 0
}

/// A full-price down payment is a supported all-cash purchase.
func validateDownpaymentValue(downpaymentValue: Double, propertyValue: Double) -> Bool {
    validatePropertyValue(value: propertyValue) && downpaymentValue.isFinite && downpaymentValue >= 0 && downpaymentValue <= propertyValue
}

/// Supported fixed annual rates range from 0% to 50%.
func validateInterestRateValue(value: Double) -> Bool {
    value.isFinite && (0...50).contains(value)
}
