//
//  HomeScreenViewModel.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/26/23.
//

import Foundation
import CoreData

@MainActor
final class HomeScreenViewModel: ObservableObject {
    
    var provider = MortgagesProvider.shared

    @Published var mortgageToEdit: Mortgage?
    
    
    init(provider: MortgagesProvider){
        self.provider = provider
    }
    
    func performDuplicate (_ mortgage: Mortgage) throws {
        let context = provider.newContext
        let newMortgage = Mortgage(context: context)

        newMortgage.name = "\(mortgage.name) duplicate"
        newMortgage.downpaymentValue = mortgage.downpaymentValue
        newMortgage.hoaFeesValue = mortgage.hoaFeesValue
        newMortgage.homeInsuranceValue = mortgage.homeInsuranceValue
        newMortgage.interestRatePercentage = mortgage.interestRatePercentage
        newMortgage.loanTermYears = mortgage.loanTermYears
        newMortgage.propertyValue = mortgage.propertyValue
        newMortgage.propertyTaxValue = mortgage.propertyTaxValue
        newMortgage.upkeepValue = mortgage.upkeepValue
        newMortgage.closingCostValue = mortgage.closingCostValue
        newMortgage.address = mortgage.address
        newMortgage.city = mortgage.city
        newMortgage.state = mortgage.state
        newMortgage.zip = mortgage.zip
        
        try context.save()
    }
    
    func delete(_ mortgage: Mortgage) throws {
        let context = provider.viewContext
        let existingMortgage = try context.existingObject(with: mortgage.objectID)
        context.delete(existingMortgage)
        Task(priority: .background) {
            try await context.perform {
                try context.save()
            }
        }
    }
}
