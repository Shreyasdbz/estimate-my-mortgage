import XCTest
@testable import EstimateMyMortgage

final class MortgageCalculationTests: XCTestCase {
    func testStandardFixedRateLoanAndOwnershipCosts() throws {
        let terms = MortgageTerms(propertyValue: 400_000, downpaymentValue: 100_000, interestRatePercentage: 6, loanTermYears: 30, propertyTaxValue: 3_600, homeInsuranceValue: 1_200, hoaFeesValue: 600, upkeepValue: 1_800, closingCostValue: 8_000)
        let result = try XCTUnwrap(terms.calculation)
        // Independent published-formula fixture: $300,000, 6%, 360 payments.
        XCTAssertEqual(result.baseMonthlyPayment, 1_798.6515754582706, accuracy: 0.0000001)
        XCTAssertEqual(result.monthlyPayment, 2_398.6515754582706, accuracy: 0.0000001)
        XCTAssertEqual(result.totalInterest, 347_514.5671649774, accuracy: 0.0001)
        XCTAssertEqual(result.upfrontCostValue, 108_000)
        XCTAssertEqual(result.monthlySchedule.count, 360)
        XCTAssertEqual(result.annualSchedule.count, 30)
        XCTAssertEqual(result.monthlySchedule[0].interest, 1_500)
        XCTAssertEqual(result.monthlySchedule[0].principal, 298.6515754582706, accuracy: 0.0000001)
        XCTAssertEqual(result.monthlySchedule.last?.balance, 0)
        XCTAssertEqual(result.monthlySchedule.reduce(0) { $0 + $1.principal }, 300_000, accuracy: 0.000001)
        XCTAssertEqual(result.annualSchedule.reduce(0) { $0 + $1.interest }, result.totalInterest, accuracy: 0.000001)
    }

    func testZeroRateHasEqualPrincipalPayments() throws {
        let terms = MortgageTerms(propertyValue: 120_000, downpaymentValue: 0, interestRatePercentage: 0, loanTermYears: 10, propertyTaxValue: 0, homeInsuranceValue: 0, hoaFeesValue: 0, upkeepValue: 0, closingCostValue: 0)
        let result = try XCTUnwrap(terms.calculation)
        XCTAssertEqual(result.baseMonthlyPayment, 1_000)
        XCTAssertEqual(result.totalInterest, 0)
        XCTAssertEqual(result.monthlySchedule.first?.principal, 1_000)
        XCTAssertEqual(result.annualSchedule.first?.principal, 12_000)
        XCTAssertEqual(result.monthlySchedule.last?.balance, 0)
    }

    func testAllCashRetainsAnnualOwnershipExpenses() throws {
        let terms = MortgageTerms(propertyValue: 240_000, downpaymentValue: 240_000, interestRatePercentage: 0, loanTermYears: 30, propertyTaxValue: 2_400, homeInsuranceValue: 1_200, hoaFeesValue: 600, upkeepValue: 1_800, closingCostValue: 4_000)
        let result = try XCTUnwrap(terms.calculation)
        XCTAssertEqual(result.monthlyPayment, 500)
        XCTAssertEqual(result.baseMonthlyPayment, 0)
        XCTAssertEqual(result.totalLoanPayments, 0)
        XCTAssertEqual(result.totalInterest, 0)
        XCTAssertEqual(result.upfrontCostValue, 244_000)
        XCTAssertTrue(result.monthlySchedule.isEmpty)
        XCTAssertTrue(result.annualSchedule.isEmpty)
    }

    func testTinyRateRemainsFiniteAndNearZeroRatePayment() throws {
        var terms = MortgageTerms(propertyValue: 120_000, downpaymentValue: 0, interestRatePercentage: 1e-12, loanTermYears: 10)
        let result = try XCTUnwrap(terms.calculation)
        XCTAssertTrue(result.baseMonthlyPayment.isFinite)
        XCTAssertEqual(result.baseMonthlyPayment, 1_000, accuracy: 0.00000001)
        XCTAssertGreaterThan(result.totalInterest, 0)
        terms.interestRatePercentage = 0
        XCTAssertEqual(terms.calculation?.baseMonthlyPayment, 1_000)
    }

    func testInvalidInputsCannotProduceCalculation() {
        var terms = MortgageTerms()
        for price in [0, -1, Double.infinity, Double.nan] {
            terms.propertyValue = price
            XCTAssertNil(terms.calculation)
        }
        terms = MortgageTerms()
        for rate in [-1, 50.1, Double.infinity, Double.nan] {
            terms.interestRatePercentage = rate
            XCTAssertNil(terms.calculation)
        }
        terms = MortgageTerms()
        for years in [0, -1, 101, Int.max] {
            terms.loanTermYears = years
            XCTAssertNil(terms.calculation)
        }
        terms = MortgageTerms()
        terms.downpaymentValue = terms.propertyValue + 1
        XCTAssertNil(terms.calculation)
        terms = MortgageTerms()
        terms.homeInsuranceValue = -1
        XCTAssertNil(terms.calculation)
        terms = MortgageTerms()
        terms.hoaFeesValue = .nan
        XCTAssertNil(terms.calculation)
        terms = MortgageTerms()
        terms.closingCostValue = .infinity
        XCTAssertNil(terms.calculation)
    }

    func testSemanticValidationIdentifiesFieldsWithoutMatchingMessages() {
        let terms = MortgageTerms(propertyValue: 0, downpaymentValue: -1, interestRatePercentage: 51, loanTermYears: 0, propertyTaxValue: -1, homeInsuranceValue: .nan, hoaFeesValue: -1, upkeepValue: -1, closingCostValue: -1)
        XCTAssertEqual(terms.validationIssues.map(\.field), [.propertyValue, .downpaymentValue, .rate, .term, .tax, .insurance, .hoa, .upkeep, .closing])
        XCTAssertEqual(terms.validationErrors, terms.validationIssues.map(\.message))
        XCTAssertNil(terms.calculation)
        XCTAssertTrue(MortgageTerms().validationIssues.isEmpty)
    }

    func testUpperSupportedRateAndTermFullyAmortize() throws {
        let result = try XCTUnwrap(MortgageTerms(interestRatePercentage: 50, loanTermYears: 100).calculation)
        XCTAssertEqual(result.monthlySchedule.count, 1_200)
        XCTAssertTrue(result.totalInterest.isFinite)
        XCTAssertEqual(result.monthlySchedule.last!.payment, result.baseMonthlyPayment, accuracy: 0.000001)
        XCTAssertEqual(result.monthlySchedule.last?.balance, 0)
        XCTAssertEqual(result.monthlySchedule.reduce(0) { $0 + $1.principal }, result.principalValue, accuracy: 0.000001)
    }

    func testFiniteInputsThatOverflowTotalsAreRejected() {
        var terms = MortgageTerms()
        terms.propertyTaxValue = .greatestFiniteMagnitude
        terms.homeInsuranceValue = .greatestFiniteMagnitude
        XCTAssertNil(terms.calculation)
        terms = MortgageTerms(propertyValue: .greatestFiniteMagnitude, downpaymentValue: 0)
        XCTAssertNil(terms.calculation)
    }

    func testWhitespaceNamesAndFullPriceDownPayment() {
        XCTAssertFalse(validateNameInput(value: " \n\t"))
        XCTAssertTrue(validateNameInput(value: "Home"))
        XCTAssertTrue(validateDownpaymentValue(downpaymentValue: 100, propertyValue: 100))
        XCTAssertFalse(validatePropertyValue(value: .nan))
    }
}
