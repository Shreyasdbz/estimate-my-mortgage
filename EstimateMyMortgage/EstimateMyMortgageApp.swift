import SwiftUI

@main
struct EstimateMyMortgageApp: App {
    @StateObject private var provider: MortgagesProvider

    init() {
        #if DEBUG
        do {
            let isolatedProvider = try Self.uiTestProvider(arguments: ProcessInfo.processInfo.arguments,
                                                         environment: ProcessInfo.processInfo.environment)
            _provider = StateObject(wrappedValue: isolatedProvider ?? MortgagesProvider.shared)
        } catch {
            fatalError("UI-test store setup failed: \(error.localizedDescription)")
        }
        #else
        _provider = StateObject(wrappedValue: MortgagesProvider.shared)
        #endif
    }

    #if DEBUG
    /// Opens only the UUID-scoped debug store; requested fixtures require an empty store and throw on failure.
    /// Non-test launches return nil without accessing any store. No fixture failure falls back to the shared store.
    static func uiTestProvider(arguments: [String], environment: [String: String]) throws -> MortgagesProvider? {
        guard arguments.contains("--ui-testing") else { return nil }
        let fixture = environment["EMM_TEST_FIXTURE"]
        if let fixture, fixture != "search" { throw UITestFixtureError.unknownFixture(fixture) }
        guard let identifier = environment["EMM_TEST_STORE"], UUID(uuidString: identifier) != nil else {
            if fixture != nil { throw UITestFixtureError.invalidStoreIdentifier }
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("UITest-\(identifier).sqlite")
        let provider = MortgagesProvider(storeURL: url)
        if fixture == "search" {
            try provider.performTransaction { context in
                guard try context.count(for: Mortgage.all()) == 0 else { throw UITestFixtureError.nonemptyStore }
                for name in ["Cedar Home", "Birch Condo"] {
                    // Mortgage.awakeFromInsert supplies the same valid defaults as an untouched editor.
                    Mortgage(context: context).name = name
                }
            }
        }
        return provider
    }

    private enum UITestFixtureError: LocalizedError {
        case unknownFixture(String)
        case invalidStoreIdentifier
        case nonemptyStore

        var errorDescription: String? {
            switch self {
            case .unknownFixture(let fixture): "Unknown EMM_TEST_FIXTURE '\(fixture)'; supported fixture: search."
            case .invalidStoreIdentifier: "The search fixture requires a valid UUID in EMM_TEST_STORE."
            case .nonemptyStore: "The search fixture requires an empty isolated store. Use a fresh EMM_TEST_STORE UUID."
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if provider.loadError != nil {
                    ContentUnavailableView {
                        Label("Estimates couldn't be opened", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your saved store has been preserved. Try opening it again. If the problem continues, check available device storage.")
                    } actions: {
                        Button("Try Again") { provider.retryLoading() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    HomeScreen(provider: provider)
                        .environment(\.managedObjectContext, provider.viewContext)
                }
            }
            .preferredColorScheme(testColorScheme)
        }
    }

    /// Deterministic appearance for isolated debug UI journeys; release always follows the device.
    private var testColorScheme: ColorScheme? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return nil }
        switch ProcessInfo.processInfo.environment["EMM_TEST_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
