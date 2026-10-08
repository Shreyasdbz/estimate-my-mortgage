import Foundation
import CoreData

/// Saved estimate with the original store schema. Access it on its owning Core Data context.
final class Mortgage: NSManagedObject, Identifiable {
    
    // Persisted names and types match the original Core Data model.
    @NSManaged var name: String
    
    @NSManaged var propertyValue: Double
    @NSManaged var downpaymentValue: Double
    @NSManaged var hoaFeesValue: Double
    @NSManaged var homeInsuranceValue: Double
    @NSManaged var interestRatePercentage: Double
    @NSManaged var loanTermYears: Int16
    @NSManaged var propertyTaxValue: Double
    @NSManaged var upkeepValue: Double
    @NSManaged var closingCostValue: Double
    @NSManaged var address: String
    @NSManaged var city: String
    @NSManaged var state: String
    @NSManaged var zip: String

    /// Immutable calculation inputs. All ancillary expenses in the original store are annual amounts.
    var terms: MortgageTerms {
        MortgageTerms(propertyValue: propertyValue, downpaymentValue: downpaymentValue, interestRatePercentage: interestRatePercentage, loanTermYears: Int(loanTermYears), propertyTaxValue: propertyTaxValue, homeInsuranceValue: homeInsuranceValue, hoaFeesValue: hoaFeesValue, upkeepValue: upkeepValue, closingCostValue: closingCostValue)
    }

    var downpaymentPercentage: Double {
        guard propertyValue.isFinite, propertyValue > 0, downpaymentValue.isFinite else { return .nan }
        return 100 * (downpaymentValue / propertyValue)
    }
    /// Optional address components form one line without stray separators.
    var formattedAddressString: String {
        [address.trimmingCharacters(in: .whitespacesAndNewlines), city.trimmingCharacters(in: .whitespacesAndNewlines), [state, zip].filter { !$0.isEmpty }.joined(separator: " ")].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

extension Mortgage {
    override func awakeFromInsert() {
        super.awakeFromInsert()

        // Keep inserted records and the draft editor on the same financial defaults.
        let terms = MortgageTerms()
        setPrimitiveValue("", forKey: "name")
        setPrimitiveValue(terms.propertyValue, forKey: "propertyValue")
        setPrimitiveValue(terms.downpaymentValue, forKey: "downpaymentValue")
        setPrimitiveValue(terms.hoaFeesValue, forKey: "hoaFeesValue")
        setPrimitiveValue(terms.homeInsuranceValue, forKey: "homeInsuranceValue")
        setPrimitiveValue(terms.interestRatePercentage, forKey: "interestRatePercentage")
        setPrimitiveValue(Int16(terms.loanTermYears), forKey: "loanTermYears")
        setPrimitiveValue(terms.propertyTaxValue, forKey: "propertyTaxValue")
        setPrimitiveValue(terms.upkeepValue, forKey: "upkeepValue")
        setPrimitiveValue(terms.closingCostValue, forKey: "closingCostValue")
        for key in ["address", "city", "state", "zip"] {
            setPrimitiveValue("", forKey: key)
        }
    }
}

extension Mortgage {

    private static var mortgagesFetchRequest: NSFetchRequest<Mortgage> {
        NSFetchRequest(entityName: "Mortgage")
    }
    
    static func all() -> NSFetchRequest<Mortgage> {
        let request: NSFetchRequest<Mortgage> = mortgagesFetchRequest
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Mortgage.name, ascending: true)
        ]
        return request
    }
}

extension Mortgage {
    /// Inserts deterministic examples into an explicitly supplied context, intended only for previews and disposable validation stores.
    @MainActor
    @discardableResult
    static func makePreview(count: Int, in context: NSManagedObjectContext) -> [Mortgage] {
        (0..<max(0, count)).map { index in
            let mortgage = Mortgage(context: context)
            MortgageFixtures.populate(mortgage, index: index)
            return mortgage
        }
    }

    /// Creates a preview in a dedicated memory-only store when no context is supplied.
    @MainActor
    static func preview(context: NSManagedObjectContext? = nil) -> Mortgage {
        makePreview(count: 1, in: context ?? MortgageFixtures.context)[0]
    }

}
