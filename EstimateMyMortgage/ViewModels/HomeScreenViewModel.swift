import CoreData
import Foundation

/// Performs list mutations synchronously so callers can display persistence failures.
@MainActor
final class HomeScreenViewModel: ObservableObject {
    let provider: MortgagesProvider

    init(provider: MortgagesProvider) {
        self.provider = provider
    }

    /// Copies stored values into a new estimate in one isolated transaction.
    func performDuplicate(_ mortgage: Mortgage) throws {
        let objectID = mortgage.objectID
        try provider.performTransaction { context in
            guard let source = try context.existingObject(with: objectID) as? Mortgage else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            guard validateNameInput(value: source.name), source.terms.isValid else {
                throw CreateMortgageViewModel.InputError("This estimate has invalid values. Edit and save it before making a copy.")
            }
            let copy = Mortgage(context: context)
            for attribute in source.entity.attributesByName.keys {
                copy.setValue(source.value(forKey: attribute), forKey: attribute)
            }
            copy.name = "\(source.name) copy"
        }
    }

    /// Removes the stored estimate; a failed save leaves the original record intact.
    func delete(_ mortgage: Mortgage) throws {
        try delete([mortgage])
    }

    /// Deletes a selection atomically, avoiding a partially removed multi-row selection.
    func delete(_ mortgages: [Mortgage]) throws {
        let objectIDs = mortgages.map(\.objectID)
        try provider.performTransaction { context in
            for objectID in objectIDs {
                context.delete(try context.existingObject(with: objectID))
            }
        }
    }
}
