import Combine
import MapKit

/// Debounced address suggestions. Failures leave manual address entry available.
@MainActor
final class MapSearch: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published var searchTerm = ""
    @Published private(set) var locationResults: [MKLocalSearchCompletion] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSearching = false
    private let completer = MKLocalSearchCompleter()
    private var subscription: AnyCancellable?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        subscription = $searchTerm
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                clear()
                let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard query.count >= 3 else { return }
                isSearching = true
                completer.queryFragment = query
            }
    }

    func clear() {
        completer.cancel()
        locationResults = []
        errorMessage = nil
        isSearching = false
    }

    /// Stops suggestions and pending debounced input when the search screen is dismissed.
    func stop() {
        subscription?.cancel()
        subscription = nil
        clear()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard subscription != nil, completer.queryFragment == searchTerm.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        locationResults = Array(completer.results.prefix(5))
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard subscription != nil, completer.queryFragment == searchTerm.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        locationResults = []
        isSearching = false
        errorMessage = "Address suggestions are unavailable. You can enter the address manually."
    }
}
