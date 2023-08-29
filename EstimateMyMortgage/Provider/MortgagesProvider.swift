//
//  MortgagesProvider.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import CoreData
import SwiftUI

final class MortgagesProvider {
    
    static let shared = MortgagesProvider()
    
    private let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    var newContext: NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    private init(){

        persistentContainer = NSPersistentContainer(name: "MortgageDataModel")
        
        if EnvironmentValues.isPreview {
            persistentContainer.persistentStoreDescriptions.first?.url = .init(filePath: "/dev/null", directoryHint: .inferFromPath)
        }
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                fatalError("[EMM] -- Unable to load data store with error: \(error)")
            }
        }
        
    }
}

extension EnvironmentValues {
    static var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
