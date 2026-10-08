import SwiftUI

@main
struct EstimateMyMortgageApp: App {
    @StateObject private var provider: MortgagesProvider

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           let identifier = ProcessInfo.processInfo.environment["EMM_TEST_STORE"],
           UUID(uuidString: identifier) != nil {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("UITest-\(identifier).sqlite")
            _provider = StateObject(wrappedValue: MortgagesProvider(storeURL: url))
        } else {
            _provider = StateObject(wrappedValue: MortgagesProvider.shared)
        }
        #else
        _provider = StateObject(wrappedValue: MortgagesProvider.shared)
        #endif
    }

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
