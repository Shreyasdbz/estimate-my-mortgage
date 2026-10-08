import SwiftUI
import CoreData

struct HomeScreen: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @FetchRequest(fetchRequest: Mortgage.all()) private var mortgages
    @StateObject private var vm: HomeScreenViewModel
    @State private var selection: NSManagedObjectID?
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var savedSelection: NSManagedObjectID?
    @State private var query = ""
    @State private var sort: EstimateSort = .name
    @State private var editorPresented = false
    @State private var editingMortgage: Mortgage?
    @State private var deletingMortgage: Mortgage?
    @State private var errorMessage: String?
    @State private var comparisonPresented = false
    @State private var aboutPresented = false

    init(provider: MortgagesProvider) {
        _vm = StateObject(wrappedValue: HomeScreenViewModel(provider: provider))
    }

    private var visibleMortgages: [Mortgage] {
        mortgages.filter {
            query.isEmpty || "\($0.name) \($0.formattedAddressString)".localizedStandardContains(query)
        }.sorted { left, right in
            switch sort {
            case .name: return left.name.localizedStandardCompare(right.name) == .orderedAscending
            case .monthlyPayment: return (left.terms.calculation?.monthlyPayment ?? .infinity) < (right.terms.calculation?.monthlyPayment ?? .infinity)
            case .propertyValue: return left.propertyValue < right.propertyValue
            }
        }
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            List(selection: $selection) {
                ForEach(visibleMortgages) { mortgage in
                    NavigationLink(value: mortgage.objectID) {
                        MortgageRowView(mortgage: mortgage)
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { edit(mortgage) }
                            .accessibilityIdentifier("editEstimateFromList")
                        Button("Duplicate", systemImage: "doc.on.doc") { duplicate(mortgage) }
                        Button("Delete", systemImage: "trash", role: .destructive) { deletingMortgage = mortgage }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Edit", systemImage: "pencil") { edit(mortgage) }.tint(.blue)
                        Button("Duplicate", systemImage: "doc.on.doc") { duplicate(mortgage) }.tint(.indigo)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) { deletingMortgage = mortgage }
                    }
                }
            }
            .overlay {
                if mortgages.isEmpty {
                    NoMortgagesView { edit(nil) }
                } else if visibleMortgages.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle("Estimates")
            .navigationSplitViewColumnWidth(min: 280, ideal: textSize.isAccessibilitySize ? 480 : 320, max: 560)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Estimate", systemImage: "plus") { edit(nil) }
                        .accessibilityIdentifier("newEstimate")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Estimate Actions", systemImage: "ellipsis") {
                        Picker("Sort by", selection: $sort) {
                            ForEach(EstimateSort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Button("Compare Estimates", systemImage: "square.split.2x1") { comparisonPresented = true }
                            .disabled(mortgages.count < 2)
                        Button("About & Privacy", systemImage: "info.circle") { aboutPresented = true }
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let mortgage = mortgages.first(where: { $0.objectID == selection }) {
                    MortgageScreen(mortgage: mortgage, provider: vm.provider)
                } else {
                    ContentUnavailableView("Select an estimate", systemImage: "house", description: Text("See payment details and the loan's amortization schedule."))
                }
            }
            .id(selection)
        }
        .onChange(of: mortgages.map(\.objectID)) { _, identities in
            if let selection, !identities.contains(selection) { self.selection = nil }
        }
        .sheet(isPresented: $editorPresented, onDismiss: revealSavedEstimate) {
            NavigationStack {
                CreateMortgageView(provider: vm.provider, mortgage: editingMortgage) { savedSelection = $0 }
            }
        }
        .sheet(isPresented: $comparisonPresented) {
            NavigationStack { CompareEstimatesView(mortgages: Array(mortgages)) }
        }
        .sheet(isPresented: $aboutPresented) {
            NavigationStack { AboutView() }
        }
        .confirmationDialog("Delete estimate?", isPresented: Binding(get: { deletingMortgage != nil }, set: { if !$0 { deletingMortgage = nil } }), titleVisibility: .visible) {
            Button("Delete Estimate", role: .destructive) {
                guard let mortgage = deletingMortgage else { return }
                do {
                    try vm.delete(mortgage)
                    if selection == mortgage.objectID { selection = nil }
                } catch { errorMessage = error.localizedDescription }
                deletingMortgage = nil
            }
        } message: { Text("This permanently removes the saved estimate from this device.") }
        .alert("Couldn't Update Estimates", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func edit(_ mortgage: Mortgage?) {
        savedSelection = nil
        editingMortgage = mortgage
        editorPresented = true
    }

    /// Navigate after the sheet closes so compact navigation and dismissal do not compete.
    private func revealSavedEstimate() {
        guard let identity = savedSelection else { return }
        query = ""
        selection = identity
        compactColumn = .detail
        savedSelection = nil
    }

    private func duplicate(_ mortgage: Mortgage) {
        do { try vm.performDuplicate(mortgage) }
        catch { errorMessage = error.localizedDescription }
    }
}

private enum EstimateSort: String, CaseIterable, Identifiable {
    case name = "Name", monthlyPayment = "Monthly cost", propertyValue = "Property value"
    var id: Self { self }
}
