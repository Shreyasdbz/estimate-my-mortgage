import CoreData

/// Deterministic, explicitly requested examples. They never load or save the user's persistent store.
@MainActor
enum MortgageFixtures {
    static var context: NSManagedObjectContext { MortgagesProvider.preview.viewContext }

    /// Populates an unsaved object for previews, simulator captures, or tests. Financial costs are annual.
    static func populate(_ mortgage: Mortgage, index: Int) {
        let examples: [(String, Double, Double, Double, Int16, Double, Double, Double, Double, Double)] = [
            ("First home", 450_000, 90_000, 6.25, 30, 5_400, 1_800, 1_200, 3_000, 9_000),
            ("Condo", 320_000, 64_000, 5.75, 15, 3_840, 1_200, 3_600, 1_500, 6_400),
            ("All-cash purchase", 380_000, 380_000, 0, 30, 4_560, 1_600, 0, 2_400, 7_600)
        ]
        let example = examples[index % examples.count]
        mortgage.name = example.0
        mortgage.propertyValue = example.1
        mortgage.downpaymentValue = example.2
        mortgage.interestRatePercentage = example.3
        mortgage.loanTermYears = example.4
        mortgage.propertyTaxValue = example.5
        mortgage.homeInsuranceValue = example.6
        mortgage.hoaFeesValue = example.7
        mortgage.upkeepValue = example.8
        mortgage.closingCostValue = example.9
        mortgage.address = ""
        mortgage.city = ""
        mortgage.state = ""
        mortgage.zip = ""
    }
}
