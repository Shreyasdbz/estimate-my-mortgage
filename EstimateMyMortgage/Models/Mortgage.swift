//
//  Mortgage.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import CoreData
import SwiftUI

final class Mortgage: NSManagedObject, Identifiable  {
    
    // basics
//    @NSManaged var id: UUID
    @NSManaged var name: String
    
    // values
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

    // derived calculations
    var principleValue: Double {
        propertyValue - downpaymentValue
    }
    var downpaymentPercentage: Double {
        100 * (downpaymentValue / propertyValue)
    }
    var propertyTaxPercentage: Double {
        100 * ( propertyTaxValue / propertyValue)
    }
    var monthlyMortgagePayment: Double {
        calculateMonthlyPaymentValue(
            principleValue: principleValue,
            annualInterestRate: interestRatePercentage,
            loanTerm: loanTermYears,
            propertyTaxValue: propertyTaxValue,
            insuranceValue: homeInsuranceValue,
            hoaFeesValue: hoaFeesValue,
            upkeepValue: upkeepValue
        )
    }
    var totalInterestAccruedValue: Double {
        Double(loanTermYears) * 12 * monthlyMortgagePayment - principleValue
    }
    
    // formated values
    var formattedPropertyValue: String {
        String(propertyValue.formatted(.currency(code: "usd")))
    }
    var formattedPrincipleValue: String {
        String(principleValue.formatted(.currency(code: "usd")))
    }
    var formattedDownPaymentValue: String {
        String(downpaymentValue.formatted(.currency(code: "usd")))
    }
    var formattedDownPaymentPercentage: String {
        String(Double(round(100 * downpaymentPercentage)/100)) + "%"
    }
    var formattedLoanTerm: String {
        String(loanTermYears) + " years"
    }
    var formattedInterestRate: String {
        String(Double(round(100 * interestRatePercentage)/100)) + "%"
    }
    var formattedInsuranceValue: String {
        String(homeInsuranceValue.formatted(.currency(code: "usd")))
    }
    var formattedPropertyTaxValue: String {
        String(propertyTaxValue.formatted(.currency(code: "usd")))
    }
    var formattedPropertyTaxPercentage: String {
        String(Double(round(100 * (propertyTaxValue * 100 / propertyValue) )/100)) + "%"
    }
    var formattedClosingCostValue: String {
        String(closingCostValue.formatted(.currency(code: "usd")))
    }
    var formattedHoaFeesValue:String {
        String(hoaFeesValue.formatted(.currency(code: "usd")))
    }
    var formattedUpkeepValue:String {
        String(upkeepValue.formatted(.currency(code: "usd")))
    }
    var formattedAddressString: String {
        address + ", " + city + ", " + state + " " + zip
    }
    var formattedMonthlyMortgagePayment:String {
        String(monthlyMortgagePayment.formatted(.currency(code: "usd"))) + " /month"
    }
    var formattedTotalInterestAccrued: String {
        String(totalInterestAccruedValue.formatted(.currency(code: "usd")))
    }
    var formattedTotalLoanValue: String {
        let total = totalInterestAccruedValue + principleValue
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedPurchasePrice: String {
        let total = downpaymentValue + closingCostValue
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyPrincipleValue: String {
        let total = principleValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyInterestValue: String {
        let total = totalInterestAccruedValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyTaxValue: String {
        let total = propertyTaxValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyInsuranceValue: String {
        let total = homeInsuranceValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyUpkeepValue: String {
        let total = upkeepValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedMonthlyHoaFeesValue: String {
        let total = hoaFeesValue / (Double(loanTermYears) * 12)
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyPrincipleValue: String {
        let total = principleValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyInterestValue: String {
        let total = totalInterestAccruedValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyTaxValue: String {
        let total = propertyTaxValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyInsuranceValue: String {
        let total = homeInsuranceValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyUpkeepValue: String {
        let total = upkeepValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyHoaFeesValue: String {
        let total = hoaFeesValue / (Double(loanTermYears))
        return String(total.formatted(.currency(code: "usd")))
    }
    var formattedYearlyMortgagePayment:String {
        let total = monthlyMortgagePayment * 12
        return String(total.formatted(.currency(code: "usd")))
    }}

extension Mortgage {
    override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set random values for things
        setPrimitiveValue(INITIAL_PROPERTY_VALUE, forKey: "propertyValue")
        setPrimitiveValue(INITIAL_DOWNPAYMENT_VALUE, forKey: "downpaymentValue")
        setPrimitiveValue(INITIAL_HOA_FEES_VALUE, forKey: "hoaFeesValue")
        setPrimitiveValue(INITIAL_HOME_INSURANCE_VALUE, forKey: "homeInsuranceValue")
        setPrimitiveValue(INITIAL_INTEREST_RATE_PERCENTAGE, forKey: "interestRatePercentage")
        setPrimitiveValue(INITIAL_LOAN_TERM_YEARS, forKey: "loanTermYears")
        setPrimitiveValue(INITIAL_PROPERTY_TAX_VALUE, forKey: "propertyTaxValue")
        setPrimitiveValue(INITIAL_UPKEEP_VALUE, forKey: "upkeepValue")
        setPrimitiveValue(INITIAL_ADDRESS, forKey: "address")
        setPrimitiveValue(INITIAL_CITY, forKey: "city")
        setPrimitiveValue(INITIAL_STATE, forKey: "state")
        setPrimitiveValue(INITIAL_ZIP, forKey: "zip")
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
    
    @discardableResult
    static func makePreview(count: Int, in context: NSManagedObjectContext) -> [Mortgage] {
        
        var mortgages = [Mortgage]()

        for i in 0..<count {
            let mortgage = Mortgage(context: context)

//            mortgage.id = UUID()
            mortgage.name = "Option \(i)"
            mortgage.propertyValue = Double(randomBetween(100000, 1000000))
            mortgage.downpaymentValue = mortgage.propertyValue * Double(randomBetween(5, 50)) / 100
            mortgage.closingCostValue = mortgage.propertyValue * Double(randomBetween(1, 3)) / 100
            mortgage.hoaFeesValue = Double(randomBetween(500, 3000))
            mortgage.homeInsuranceValue = Double(randomBetween(500, 3000))
            mortgage.interestRatePercentage = Double(randomBetween(1, 8))
            mortgage.loanTermYears = Int16((randomBetween(10, 40)))
            mortgage.propertyTaxValue = mortgage.propertyValue * Double(randomBetween(0.5, 3)) / 100
            mortgage.upkeepValue = mortgage.propertyValue * Double(randomBetween(1, 5)) / 100
            mortgage.address = INITIAL_ADDRESS
            mortgage.city = INITIAL_CITY
            mortgage.state = INITIAL_STATE
            mortgage.zip = INITIAL_ZIP

            mortgages.append(mortgage)
        }

        return mortgages
    }
    
    static func preview(context: NSManagedObjectContext = MortgagesProvider.shared.viewContext) -> Mortgage {
        return makePreview(count: 1, in: context)[0]
    }
    
    
    static func empty(context: NSManagedObjectContext = MortgagesProvider.shared.viewContext) -> Mortgage {
        return Mortgage(context: context)
    }
}
