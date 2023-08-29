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
