import SwiftUI
import CoreData

/// Native editing form with isolated draft state and explicit Save/Cancel actions.
struct CreateMortgageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var vm: CreateMortgageViewModel
    @FocusState private var focusedField: MortgageEditorField?
    @State private var saveError: String?
    @State private var errorPresented = false
    @State private var errorTitle = "Unable to save"
    @State private var discardPresented = false
    @State private var inputError: CreateMortgageViewModel.InputError?
    private let onSaved: (NSManagedObjectID) -> Void

    /// `onSaved` receives the permanent identity only after the save succeeds.
    init(provider: MortgagesProvider, mortgage: Mortgage? = nil, onSaved: @escaping (NSManagedObjectID) -> Void = { _ in }) {
        _vm = StateObject(wrappedValue: CreateMortgageViewModel(provider: provider, mortgage: mortgage))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Estimated monthly cost").font(.subheadline)
                            if let cost = vm.monthlyCostPreview {
                                Text(cost, format: .currency(code: "USD"))
                                    .font(.title.weight(.semibold)).monospacedDigit()
                                    .contentTransition(reduceMotion ? .identity : .numericText(value: cost))
                                    .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: cost)
                            } else {
                                Text("Check the estimate details")
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("estimate.preview")
                    } footer: {
                        Text("Includes ownership costs. Excludes mortgage insurance.").foregroundStyle(Color.primary)
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name").font(.subheadline).foregroundStyle(Color.primary)
                            TextField("", text: $vm.draft.name, axis: nameAxis)
                                .lineLimit(1...3)
                                .frame(minHeight: 44)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .name)
                                .accessibilityLabel("Name")
                                .accessibilityIdentifier("estimate.name")
                            fieldError(.name)
                        }
                    }
                    .id(MortgageEditorField.name)
                    Section {
                        numberField("Property price", text: $vm.draft.propertyValue, unit: "USD", field: .property)
                        LabeledContent("Down payment unit") {
                            Picker("Down payment unit", selection: Binding(
                                get: { vm.draft.downpaymentUnit },
                                set: { unit in changeUnit { try vm.changeDownpaymentUnit(to: unit) } }
                            )) {
                                ForEach(AmountInputUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Color.primary)
                            .accessibilityIdentifier("estimate.downpaymentUnit")
                        }
                        numberField("Down payment", text: $vm.draft.downpayment,
                                    unit: vm.draft.downpaymentUnit.rawValue, field: .downpayment)
                        numberField("Annual interest rate", text: $vm.draft.interestRate, unit: "%", field: .interest)
                        numberField("Loan term", text: $vm.draft.loanTerm, unit: "years", field: .term, keyboard: .numberPad)
                    } header: {
                        Text("Purchase and loan").foregroundStyle(Color.primary)
                    } footer: {
                        Text("Fixed rates; 0% interest and all-cash purchases supported.").foregroundStyle(Color.primary)
                    }
                    Section {
                        LabeledContent("Property tax unit") {
                            Picker("Property tax unit", selection: Binding(
                                get: { vm.draft.propertyTaxUnit },
                                set: { unit in changeUnit { try vm.changePropertyTaxUnit(to: unit) } }
                            )) {
                                ForEach(AmountInputUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Color.primary)
                            .accessibilityIdentifier("estimate.taxUnit")
                        }
                        numberField("Property tax", text: $vm.draft.propertyTax,
                                    unit: vm.draft.propertyTaxUnit.rawValue, field: .tax)
                        numberField("Home insurance", text: $vm.draft.insurance, unit: "USD / year", field: .insurance)
                        numberField("HOA fees", text: $vm.draft.hoa, unit: "USD / year", field: .hoa)
                        numberField("Upkeep & utilities", text: $vm.draft.upkeep, unit: "USD / year", field: .upkeep)
                    } header: {
                        Text("Annual ownership costs").foregroundStyle(Color.primary)
                    } footer: {
                        Text("All amounts are annual. Tax % applies to the property price.").foregroundStyle(Color.primary)
                    }
                    Section(header: Text("One-time costs").foregroundStyle(Color.primary)) {
                        numberField("Closing costs", text: $vm.draft.closingCosts, unit: "USD", field: .closing)
                    }
                    Section {
                        AddressInput(address: $vm.draft.address, city: $vm.draft.city,
                                     state: $vm.draft.state, zip: $vm.draft.zip, focus: $focusedField)
                            .id(MortgageEditorField.address)
                    } header: {
                        Text("Property address").foregroundStyle(Color.primary)
                    } footer: {
                        Text("Optional.").foregroundStyle(Color.primary)
                    }
                }
                .accessibilityIdentifier("estimate.form")
                .scrollDismissesKeyboard(.interactively)
                if focusedField != nil {
                    HStack {
                        Spacer()
                        Button { focusedField = nil } label: {
                            Text("Done")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .tint(Color.primary)
                        .accessibilityIdentifier("estimate.keyboardDone")
                    }
                    .padding(.horizontal)
                    .background(.bar)
                }
            }
            .presentationDetents([.large])
            .navigationTitle(vm.isNew ? "New estimate" : "Edit estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        focusedField = nil
                        if vm.hasChanges { discardPresented = true } else { dismiss() }
                    }
                    .tint(Color.primary)
                    .accessibilityIdentifier("estimate.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: saveRole, action: save)
                        .tint(.indigo)
                        .accessibilityIdentifier("estimate.save")
                }
            }
            .interactiveDismissDisabled(vm.hasChanges)
            .confirmationDialog("Discard unsaved changes?", isPresented: $discardPresented, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .alert(errorTitle, isPresented: $errorPresented) {
                Button("OK", role: .cancel) {
                    if let field = inputError?.field {
                        proxy.scrollTo(field, anchor: .center)
                        Task { @MainActor in
                            await Task.yield()
                            focusedField = field
                        }
                    }
                }
            } message: {
                Text(saveError ?? "Please try again.")
            }
            .onChange(of: vm.draft) { _, _ in inputError = nil }
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String,
                             field: MortgageEditorField, keyboard: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(unit))")
                .font(.subheadline)
                .foregroundStyle(Color.primary)
            TextField("", text: text)
                .frame(minHeight: 44)
                .keyboardType(keyboard)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .focused($focusedField, equals: field)
                .accessibilityLabel("\(title), \(unit)")
                .accessibilityIdentifier("estimate.\(String(describing: field))")
            fieldError(field)
        }
        .id(field)
    }

    @ViewBuilder
    private func fieldError(_ field: MortgageEditorField) -> some View {
        if let inputError, inputError.field == field {
            Label {
                Text(inputError.message).foregroundStyle(Color.primary)
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
        }
    }

    private func changeUnit(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorTitle = "Unable to change unit"
            saveError = error.localizedDescription
            inputError = error as? CreateMortgageViewModel.InputError
            errorPresented = true
        }
    }

    private var saveRole: ButtonRole? {
        if #available(iOS 26.0, *) { .confirm } else { nil }
    }

    /// Name entry stays single-line where it fits; accessibility text wraps in compact layouts.
    private var nameAxis: Axis {
        textSize.isAccessibilitySize && widthClass == .compact ? .vertical : .horizontal
    }

    private func save() {
        focusedField = nil
        do {
            onSaved(try vm.save())
            dismiss()
        } catch {
            errorTitle = "Unable to save"
            saveError = error.localizedDescription
            inputError = error as? CreateMortgageViewModel.InputError
            errorPresented = true
        }
    }
}

#Preview {
    NavigationStack {
        CreateMortgageView(provider: .preview)
    }
}
