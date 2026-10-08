import MapKit
import SwiftUI

/// Optional address entry remains usable when network search is unavailable.
struct AddressInput: View {
    @Binding var address: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    let focus: FocusState<MortgageEditorField?>.Binding
    @State private var searchPresented = false

    private var fullAddress: Binding<String> {
        Binding {
            [address.trimmingCharacters(in: .whitespacesAndNewlines),
             city.trimmingCharacters(in: .whitespacesAndNewlines),
             [state, zip].filter { !$0.isEmpty }.joined(separator: " ")]
                .filter { !$0.isEmpty }.joined(separator: ", ")
        } set: { value in
            // Keep existing stored components until an explicit edit; edited text is one full address.
            address = value
            city = ""
            state = ""
            zip = ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Full address").font(.subheadline).foregroundStyle(Color.primary)
            TextField("Street, city, state and postal code", text: fullAddress, axis: .vertical)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .lineLimit(2...4)
                .focused(focus, equals: .address)
                .accessibilityLabel("Full address")
                .accessibilityIdentifier("estimate.address")
        }
        Button("Find address", systemImage: "magnifyingglass") {
            focus.wrappedValue = nil
            searchPresented = true
        }
        .sheet(isPresented: $searchPresented) {
            NavigationStack {
                AddressSearchView { selectedAddress in
                    fullAddress.wrappedValue = selectedAddress
                    searchPresented = false
                }
            }
        }
    }
}

/// Apple Maps completions are resolved asynchronously before changing the user's address draft.
private struct AddressSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = MapSearch()
    @State private var resolving = false
    @State private var resolutionError: String?
    @State private var resolutionTask: Task<Void, Never>?
    @State private var activeSearch: MKLocalSearch?
    let onSelect: (String) -> Void

    var body: some View {
        List {
            if resolving || search.isSearching {
                ProgressView(resolving ? "Finding address…" : "Searching…")
            }
            if let error = resolutionError ?? search.errorMessage {
                Text(error).foregroundStyle(Color.primary)
            }
            ForEach(search.locationResults, id: \.self) { completion in
                Button {
                    resolutionTask?.cancel()
                    resolutionTask = Task { await resolve(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(completion.title).foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle).font(.subheadline).foregroundStyle(Color.primary)
                        }
                    }
                }
                .disabled(resolving)
            }
        }
        .searchable(text: $search.searchTerm, prompt: "Street address or place")
        .overlay {
            if search.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Find an address", systemImage: "magnifyingglass",
                                       description: Text("Search Apple Maps, or cancel to enter an address manually."))
            } else if search.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                ContentUnavailableView("Enter more of the address", systemImage: "magnifyingglass",
                                       description: Text("Use at least three characters to search Apple Maps."))
            } else if search.locationResults.isEmpty && !search.isSearching && !resolving && search.errorMessage == nil && resolutionError == nil {
                ContentUnavailableView.search(text: search.searchTerm)
            }
        }
        .navigationTitle("Find address")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancelSearch(); dismiss() }
                    .tint(Color.primary)
            }
        }
        .onChange(of: search.searchTerm) { _, _ in
            resolutionTask?.cancel()
            activeSearch?.cancel()
            resolutionError = nil
        }
        .onDisappear { cancelSearch() }
    }

    private func cancelSearch() {
        resolutionTask?.cancel()
        activeSearch?.cancel()
        search.stop()
    }

    @MainActor
    private func resolve(_ completion: MKLocalSearchCompletion) async {
        resolving = true
        resolutionError = nil
        defer { resolving = false; activeSearch = nil }
        do {
            let request = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            activeSearch = request
            let response = try await request.start()
            try Task.checkCancellation()
            guard let item = response.mapItems.first else {
                resolutionError = "No address was found. Try another result or enter it manually."
                return
            }
            if #available(iOS 26.0, *) {
                guard let fullAddress = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
                      !fullAddress.isEmpty else {
                    resolutionError = "This result has no postal address. Choose another result or enter it manually."
                    return
                }
                // Preserve the localized full address; its components cannot be safely parsed from display text.
                onSelect(fullAddress)
            } else {
                let placemark = item.placemark
                let street = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }.joined(separator: " ")
                let regionAndCode = [placemark.administrativeArea, placemark.postalCode].compactMap { $0 }.joined(separator: " ")
                let fullAddress = [street.isEmpty ? completion.title : street, placemark.locality,
                                   regionAndCode, placemark.country].compactMap { $0 }
                    .filter { !$0.isEmpty }.joined(separator: ", ")
                onSelect(fullAddress)
            }
        } catch {
            guard !Task.isCancelled else { return }
            resolutionError = "Unable to find this address. \(error.localizedDescription)"
        }
    }
}
