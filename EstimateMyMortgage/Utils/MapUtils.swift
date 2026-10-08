import SwiftUI
import MapKit

/// Resolves only a requested address; never substitutes a default property location.
@MainActor
func mapItem(for address: String) async throws -> MKMapItem {
    try Task.checkCancellation()
    if #available(iOS 26.0, *), let request = MKGeocodingRequest(addressString: address) {
        let cancel: @MainActor @Sendable () -> Void = { request.cancel() }
        let items = try await withTaskCancellationHandler {
            try await request.mapItems
        } onCancel: {
            Task { @MainActor in cancel() }
        }
        try Task.checkCancellation()
        guard let item = items.first else { throw MapLookupError.notFound }
        return item
    }
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = address
    request.resultTypes = .address
    let search = MKLocalSearch(request: request)
    let cancel: @MainActor @Sendable () -> Void = { search.cancel() }
    let response = try await withTaskCancellationHandler {
        try await search.start()
    } onCancel: {
        Task { @MainActor in cancel() }
    }
    try Task.checkCancellation()
    guard let item = response.mapItems.first else { throw MapLookupError.notFound }
    return item
}

private enum MapLookupError: LocalizedError {
    case notFound
    var errorDescription: String? { "No map location was found for this address." }
}

/// Native map with explicit loading, failure, retry and handoff to Apple Maps.
struct PropertyMapView: View {
    let address: String
    @State private var item: MKMapItem?
    @State private var errorMessage: String?
    @State private var retry = 0

    // A single marker's automatic camera can hide nearby streets by zooming to the pin.
    private func neighborhoodRegion(for item: MKMapItem) -> MKCoordinateRegion {
        let coordinate: CLLocationCoordinate2D
        if #available(iOS 26.0, *) {
            coordinate = item.location.coordinate
        } else {
            coordinate = item.placemark.coordinate
        }
        return MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item {
                Map(initialPosition: .region(neighborhoodRegion(for: item))) { Marker(item: item) }
                    .mapControls { MapCompass() }
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 12))
                    .accessibilityLabel("Property map for \(address)")
                Button("Open in Maps", systemImage: "arrow.up.right.square") { item.openInMaps() }
            } else if let errorMessage {
                Label(errorMessage, systemImage: "map").foregroundStyle(Color.primary)
                Button("Retry map lookup") { retry += 1 }
            } else {
                ProgressView("Finding address…").frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task(id: "\(address)-\(retry)") {
            item = nil
            errorMessage = nil
            do { item = try await mapItem(for: address) }
            catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Map unavailable. Check the address or your connection."
            }
        }
    }
}
