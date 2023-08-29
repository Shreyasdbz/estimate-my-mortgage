//
//  EstimateMyMortgageApp.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI

@main
struct EstimateMyMortgageApp: App {
    var body: some Scene {
        WindowGroup {
            HomeScreen(vm: .init(provider: MortgagesProvider.shared))
                .environment(\.managedObjectContext, MortgagesProvider.shared.viewContext)
        }
    }
}

