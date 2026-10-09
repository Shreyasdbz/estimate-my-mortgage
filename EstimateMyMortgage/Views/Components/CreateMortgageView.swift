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
    @State private var nameFrame = CGRect.zero
    @State private var formFrame = CGRect.zero
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
        // Give the long iPad form native page dimensions; compact and iOS 17 keep system sizing.
        if #available(iOS 18.0, *), widthClass == .regular {
            NavigationStack { editorContent }.presentationSizing(.page)
        } else {
            NavigationStack { editorContent }
        }
    }

    private var editorContent: some View {
        let tracksNameGeometry = nameAxis == .vertical
        return ScrollViewReader { proxy in
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
                            fieldError(.name)
                            TextField("", text: $vm.draft.name, axis: nameAxis)
                                .lineLimit(1...3)
                                .frame(minHeight: 44)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .name)
                                .accessibilityLabel("Name")
                                .accessibilityIdentifier("estimate.name")
                                .accessibilityHint(inputError?.field == .name ? inputError?.message ?? "" : "")
                                .onGeometryChange(for: CGRect.self) {
                                    tracksNameGeometry ? $0.frame(in: .global) : .zero
                                } action: { frame in
                                    nameFrame = frame
                                    revealNameIfNeeded(using: proxy)
                                }
                        }
                        .id(MortgageEditorField.name)
                    }
                    Section {
                        numberField("Property price", text: $vm.draft.propertyValue, unit: "USD", field: .property)
                        Picker("Down payment unit", selection: Binding(
                            get: { vm.draft.downpaymentUnit },
                            set: { unit in changeUnit(using: proxy) { try vm.changeDownpaymentUnit(to: unit) } }
                        )) {
                            ForEach(AmountInputUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.primary)
                        .accessibilityValue(vm.draft.downpaymentUnit.rawValue)
                        .accessibilityIdentifier("estimate.downpaymentUnit")
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
                        Picker("Property tax unit", selection: Binding(
                            get: { vm.draft.propertyTaxUnit },
                            set: { unit in changeUnit(using: proxy) { try vm.changePropertyTaxUnit(to: unit) } }
                        )) {
                            ForEach(AmountInputUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.primary)
                        .accessibilityValue(vm.draft.propertyTaxUnit.rawValue)
                        .accessibilityIdentifier("estimate.taxUnit")
                        numberField("Property tax", text: $vm.draft.propertyTax,
                                    unit: vm.draft.propertyTaxUnit.rawValue, field: .tax)
                        numberField("Home insurance", text: $vm.draft.insurance, unit: "USD / year", field: .insurance)
                        numberField("HOA fees", text: $vm.draft.hoa, unit: "USD / year", field: .hoa)
                        numberField("Upkeep & utilities", text: $vm.draft.upkeep, unit: "USD / year", field: .upkeep)
                    } header: {
                        Text("Annual ownership costs").foregroundStyle(Color.primary)
                    } footer: {
                        Text("All amounts are annual. Tax % applies to the property price.")
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Section {
                        numberField("Closing costs", text: $vm.draft.closingCosts, unit: "USD", field: .closing)
                    } header: {
                        Text("One-time costs").foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
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
                .onGeometryChange(for: CGRect.self) {
                    tracksNameGeometry ? $0.frame(in: .global) : .zero
                } action: { frame in
                    formFrame = frame
                    revealNameIfNeeded(using: proxy)
                }
                .scrollDismissesKeyboard(.immediately)
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
                    Button("Save", role: saveRole) { save(using: proxy) }
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
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "Please try again.")
            }
            .onChange(of: vm.draft) { _, _ in inputError = nil }
            .onChange(of: focusedField) { _, _ in revealNameIfNeeded(using: proxy) }
        }
    }

    /// Recenter only an obscured, focused wrapping name after actual input/keyboard layout.
    private func revealNameIfNeeded(using proxy: ScrollViewProxy) {
        guard focusedField == .name, nameAxis == .vertical,
              !nameFrame.isEmpty, !formFrame.isEmpty else { return }
        let viewport = formFrame.insetBy(dx: 0, dy: 8)
        // A short landscape viewport may need native internal caret scrolling instead.
        guard !viewport.isEmpty, nameFrame.height <= viewport.height, nameFrame.width <= viewport.width else { return }
        // Native caret avoidance follows the keyboard; the form also reserves its Done bar.
        if !viewport.contains(nameFrame) {
            proxy.scrollTo(MortgageEditorField.name, anchor: .center)
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String,
                             field: MortgageEditorField, keyboard: UIKeyboardType = .decimalPad) -> some View {
        let label = Text("\(title) (\(unit))")
            .font(.subheadline).foregroundStyle(Color.primary)
        let input = TextField("", text: text)
            // Keep an adequate touch target even when the numeric value is empty.
            .frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(Color.primary)
            // Avoid a separate iPad numeric popover obscuring the input labels.
            .keyboardType(widthClass == .regular ? .numbersAndPunctuation : keyboard)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            .focused($focusedField, equals: field)
            .accessibilityLabel("\(title), \(unit)")
            .accessibilityIdentifier("estimate.\(String(describing: field))")
            .accessibilityHint(inputError?.field == field ? inputError?.message ?? "" : "")
        return VStack(alignment: .leading, spacing: 6) {
            // Native label/value rows use the iPad's width; large text keeps stacked inputs.
            if widthClass == .regular && !textSize.isAccessibilitySize {
                fieldError(field)
                LabeledContent {
                    input.multilineTextAlignment(.trailing)
                } label: {
                    label
                }
            } else {
                label
                fieldError(field)
                input
            }
        }
        .id(field)
    }

    /// Placed before its input to keep correction guidance above native keyboard avoidance.
    @ViewBuilder
    private func fieldError(_ field: MortgageEditorField) -> some View {
        if let inputError, inputError.field == field {
            Label {
                Text(inputError.message).foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(inputError.message)
            .accessibilityIdentifier("estimate.error.\(String(describing: field))")
        }
    }

    private func changeUnit(using proxy: ScrollViewProxy, _ change: () throws -> Void) {
        do {
            try change()
        } catch {
            present(error, title: "Unable to change unit", using: proxy)
        }
    }

    /// Correctable field errors retain the draft and lead straight to the input.
    /// Fieldless stale-record and storage failures still require an explicit alert.
    private func present(_ error: Error, title: String, using proxy: ScrollViewProxy) {
        if let issue = error as? CreateMortgageViewModel.InputError, let field = issue.field {
            inputError = issue
            focusedField = nil
            // Position the correction before restoring focus.
            // Run for every failure, including an unchanged value submitted again.
            Task { @MainActor in
                await Task.yield()
                guard focusedField == nil, inputError?.field == field,
                      inputError?.message == issue.message else { return }
                proxy.scrollTo(field, anchor: .center)
                focusedField = field
            }
        } else {
            inputError = nil
            errorTitle = title
            saveError = error.localizedDescription
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

    private func save(using proxy: ScrollViewProxy) {
        focusedField = nil
        do {
            onSaved(try vm.save())
            dismiss()
        } catch {
            present(error, title: "Unable to save", using: proxy)
        }
    }
}

#Preview {
    CreateMortgageView(provider: .preview)
}
