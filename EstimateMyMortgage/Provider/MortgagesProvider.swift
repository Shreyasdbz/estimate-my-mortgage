import CoreData
import SwiftUI

/// Owns the store and main-queue display context; each write uses an isolated transaction.
@MainActor
final class MortgagesProvider: ObservableObject {
    static let shared = MortgagesProvider(inMemory: EnvironmentValues.isPreview)
    static let preview = MortgagesProvider(inMemory: true)

    @Published private(set) var loadError: Error?
    // All containers share one model so Core Data can resolve the Mortgage subclass unambiguously.
    private static let model = NSPersistentContainer(name: "MortgageDataModel").managedObjectModel
    private let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    /// An optional store URL supports disposable on-disk persistence checks.
    init(inMemory: Bool = false, storeURL: URL? = nil) {
        persistentContainer = NSPersistentContainer(name: "MortgageDataModel", managedObjectModel: Self.model)
        let description = NSPersistentStoreDescription()
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        if inMemory {
            description.type = NSInMemoryStoreType
        } else if let storeURL {
            description.url = storeURL
        } else {
            description.url = NSPersistentContainer.defaultDirectoryURL()
                .appendingPathComponent("MortgageDataModel.sqlite")
        }
        persistentContainer.persistentStoreDescriptions = [description]
        viewContext.automaticallyMergesChangesFromParent = true
        loadStore()
    }

    /// Retries opening the same store without deleting or replacing saved estimates.
    func retryLoading() {
        guard persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else { return }
        loadStore()
    }

    private func loadStore() {
        loadError = nil
        persistentContainer.loadPersistentStores { [self] _, error in
            // Store loading is explicitly synchronous on the calling main queue.
            loadError = error
        }
    }

    /// Commits all mutations together, merges successful saves into the UI, and rolls back failures.
    @discardableResult
    func performTransaction<T>(_ changes: (NSManagedObjectContext) throws -> T) throws -> T {
        if let loadError { throw loadError }
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        context.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
        do {
            let result = try changes(context)
            if context.hasChanges {
                try context.obtainPermanentIDs(for: Array(context.insertedObjects))
                let inserted = context.insertedObjects.map(\.objectID)
                let updated = context.updatedObjects.map(\.objectID)
                let deleted = context.deletedObjects.map(\.objectID)
                try context.save()
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [
                    NSInsertedObjectIDsKey: inserted,
                    NSUpdatedObjectIDsKey: updated,
                    NSDeletedObjectIDsKey: deleted
                ], into: [viewContext])
            }
            return result
        } catch {
            context.rollback()
            throw error
        }
    }
}

extension EnvironmentValues {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
