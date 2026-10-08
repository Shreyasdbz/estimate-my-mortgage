import CoreData
import XCTest
@testable import EstimateMyMortgage

@MainActor
final class MortgagePersistenceTests: XCTestCase {
    func testLivePreviewValidatesInputWithoutSavingDraft() throws {
        let provider = MortgagesProvider(inMemory: true)
        let editor = CreateMortgageViewModel(provider: provider)
        XCTAssertNotNil(editor.monthlyCostPreview, "An unfinished name does not prevent a financial preview")
        editor.draft.propertyValue = ""
        XCTAssertNil(editor.monthlyCostPreview)
        XCTAssertEqual(editor.draft.propertyValue, "")
        editor.draft.propertyValue = "240000"
        editor.draft.downpaymentUnit = .percent
        editor.draft.downpayment = "100"
        editor.draft.propertyTaxUnit = .percent
        editor.draft.propertyTax = "1"
        editor.draft.insurance = "1200"
        editor.draft.hoa = "600"
        editor.draft.upkeep = "1800"
        XCTAssertEqual(editor.monthlyCostPreview, 500)
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 0)
        XCTAssertFalse(provider.viewContext.hasChanges)
        XCTAssertThrowsError(try editor.save(), "Saving still requires a name")
        editor.draft.name = "Previewed purchase"
        let identity = try editor.save()
        let saved = try XCTUnwrap(provider.viewContext.existingObject(with: identity) as? Mortgage)
        XCTAssertEqual(saved.terms.calculation?.monthlyPayment, editor.monthlyCostPreview)
    }

    private func create(_ provider: MortgagesProvider, name: String = "Original") throws -> Mortgage {
        let editor = CreateMortgageViewModel(provider: provider)
        editor.draft.name = name
        let objectID = try editor.save()
        XCTAssertFalse(objectID.isTemporaryID)
        return try XCTUnwrap(provider.viewContext.existingObject(with: objectID) as? Mortgage)
    }

    func testUnreadableStoreIsPreservedAndRetryDoesNotReplaceIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("MortgageDataModel.sqlite")
        let originalData = Data("Unusable store fixture".utf8)
        try originalData.write(to: url)
        let provider = MortgagesProvider(storeURL: url)
        XCTAssertNotNil(provider.loadError)
        provider.retryLoading()
        XCTAssertNotNil(provider.loadError)
        XCTAssertEqual(try Data(contentsOf: url), originalData)
        XCTAssertThrowsError(try create(provider))
        XCTAssertEqual(try Data(contentsOf: url), originalData)
    }

    func testCancelledDraftDoesNotChangeOrInsertStoredRecords() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        let editor = CreateMortgageViewModel(provider: provider, mortgage: original)
        editor.draft.name = "Unconfirmed change"
        editor.draft.propertyValue = "900000"
        let newEditor = CreateMortgageViewModel(provider: provider)
        newEditor.draft.name = "Unconfirmed new estimate"
        XCTAssertEqual(original.name, "Original")
        XCTAssertEqual(original.propertyValue, 500000)
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 1)
        XCTAssertFalse(provider.viewContext.hasChanges)
    }

    func testSaveUpdatesExistingRecordAndRetainsAnnualUnits() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        let editor = CreateMortgageViewModel(provider: provider, mortgage: original)
        editor.draft.name = "  Updated  "
        editor.draft.hoa = "2400"
        try editor.changeDownpaymentUnit(to: .percent)
        editor.draft.downpayment = "25"
        try editor.changePropertyTaxUnit(to: .percent)
        editor.draft.propertyTax = "2"
        let objectID = try editor.save()
        XCTAssertEqual(objectID, original.objectID)
        provider.viewContext.refresh(original, mergeChanges: true)
        XCTAssertEqual(original.name, "Updated")
        XCTAssertEqual(original.hoaFeesValue, 2400)
        XCTAssertEqual(original.downpaymentValue, 125000)
        XCTAssertEqual(original.propertyTaxValue, 10000)
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 1)
    }

    func testInvalidUnitConversionPreservesAmountAndUnit() {
        let editor = CreateMortgageViewModel(provider: MortgagesProvider(inMemory: true))
        for price in ["", "0", "-1", "invalid"] {
            editor.draft.propertyValue = price
            XCTAssertThrowsError(try editor.changeDownpaymentUnit(to: .percent))
            XCTAssertEqual(editor.draft.downpaymentUnit, .dollars)
            XCTAssertEqual(editor.draft.downpayment, "100000")
            XCTAssertThrowsError(try editor.changePropertyTaxUnit(to: .percent))
            XCTAssertEqual(editor.draft.propertyTaxUnit, .dollars)
            XCTAssertEqual(editor.draft.propertyTax, "7500")
        }
        editor.draft.propertyValue = "500000"
        editor.draft.downpayment = "invalid"
        XCTAssertThrowsError(try editor.changeDownpaymentUnit(to: .percent))
        XCTAssertEqual(editor.draft.downpaymentUnit, .dollars)
        XCTAssertEqual(editor.draft.downpayment, "invalid")
    }

    func testRepeatedSaveDoesNotCreateAnotherRecord() throws {
        let provider = MortgagesProvider(inMemory: true)
        let editor = CreateMortgageViewModel(provider: provider)
        editor.draft.name = "Saved once"
        let firstID = try editor.save()
        editor.draft.name = "Saved twice"
        XCTAssertEqual(try editor.save(), firstID)
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 1)
    }

    func testStaleEditorCannotOverwriteAnotherSavedEdit() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        let firstEditor = CreateMortgageViewModel(provider: provider, mortgage: original)
        let staleEditor = CreateMortgageViewModel(provider: provider, mortgage: original)
        firstEditor.draft.name = "Latest version"
        try firstEditor.save()
        staleEditor.draft.name = "Stale version"
        XCTAssertThrowsError(try staleEditor.save())
        provider.viewContext.refresh(original, mergeChanges: true)
        XCTAssertEqual(original.name, "Latest version")
    }

    func testDuplicateAndAtomicDelete() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        let list = HomeScreenViewModel(provider: provider)
        try list.performDuplicate(original)
        let mortgages = try provider.viewContext.fetch(Mortgage.all())
        XCTAssertEqual(mortgages.count, 2)
        let copy = try XCTUnwrap(mortgages.first { $0.objectID != original.objectID })
        XCTAssertEqual(copy.name, "Original copy")
        XCTAssertEqual(copy.propertyValue, original.propertyValue)
        XCTAssertEqual(copy.hoaFeesValue, original.hoaFeesValue)
        XCTAssertEqual(copy.address, original.address)
        try list.delete(mortgages)
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 0)
    }

    func testDuplicateRejectsInvalidLegacyEstimate() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        try provider.performTransaction { context in
            let legacy = try XCTUnwrap(context.existingObject(with: original.objectID) as? Mortgage)
            legacy.interestRatePercentage = -1
        }
        let list = HomeScreenViewModel(provider: provider)
        XCTAssertThrowsError(try list.performDuplicate(original))
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 1)
    }

    func testFailedCoreDataSaveRollsBackOnlyItsTransaction() throws {
        let provider = MortgagesProvider(inMemory: true)
        let original = try create(provider)
        let objectID = original.objectID
        XCTAssertThrowsError(try provider.performTransaction { context in
            let transactionOriginal = try context.existingObject(with: objectID)
            transactionOriginal.setValue(nil, forKey: "name") // Required schema attribute fails real save validation.
            let extra = Mortgage(context: context)
            extra.name = "Must roll back"
        })
        provider.viewContext.refresh(original, mergeChanges: true)
        XCTAssertEqual(original.name, "Original")
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 1)
        XCTAssertFalse(provider.viewContext.hasChanges)
    }

    func testNumberParsingUsesRegionalDecimalSeparatorAndRejectsGrouping() {
        let us = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")
        let french = Locale(identifier: "fr_FR")
        XCTAssertEqual(MortgageDraft.number("1234.50", locale: us), 1234.5)
        XCTAssertEqual(MortgageDraft.number("1234,50", locale: german), 1234.5)
        XCTAssertEqual(MortgageDraft.number("1234,50", locale: french), 1234.5)
        XCTAssertEqual(MortgageDraft.number(" 500000 ", locale: german), 500000)
        XCTAssertNil(MortgageDraft.number("500.000", locale: german))
        XCTAssertNil(MortgageDraft.number("500.000,50", locale: german))
        XCTAssertNil(MortgageDraft.number("500,000", locale: us))
        XCTAssertNil(MortgageDraft.number("500,000.50", locale: us))
        XCTAssertNil(MortgageDraft.number("500\u{202F}000,50", locale: french))
        XCTAssertNil(MortgageDraft.number("5.5", locale: french))
        XCTAssertNil(MortgageDraft.number("123abc", locale: us))
        XCTAssertNil(MortgageDraft.number("nan", locale: german))
        XCTAssertNil(MortgageDraft.number("inf", locale: german))
    }

    func testMalformedAndInvalidInputsNeverSave() throws {
        let provider = MortgagesProvider(inMemory: true)
        let editor = CreateMortgageViewModel(provider: provider)
        editor.draft.name = "Valid name"
        for value in ["", "123abc", "nan", "inf", "-1"] {
            editor.draft.propertyValue = value
            XCTAssertThrowsError(try editor.save(), "Input \(value) should fail")
        }
        editor.draft.propertyValue = "500000"
        editor.draft.loanTerm = "1.5"
        XCTAssertThrowsError(try editor.save())
        editor.draft.loanTerm = "30"
        editor.draft.hoa = "-2"
        XCTAssertThrowsError(try editor.save())
        editor.draft.hoa = "0"
        editor.draft.name = " \n "
        XCTAssertThrowsError(try editor.save())
        XCTAssertEqual(try provider.viewContext.count(for: Mortgage.all()), 0)
    }

    func testValidationIdentifiesTheInputForInlineFeedback() {
        let editor = CreateMortgageViewModel(provider: MortgagesProvider(inMemory: true))
        XCTAssertThrowsError(try editor.save()) { error in
            XCTAssertEqual((error as? CreateMortgageViewModel.InputError)?.field, .name)
        }
        editor.draft.name = "Input review"
        editor.draft.propertyValue = "0"
        XCTAssertThrowsError(try editor.save()) { error in
            XCTAssertEqual((error as? CreateMortgageViewModel.InputError)?.field, .property)
        }
        editor.draft.propertyValue = "500000"
        editor.draft.insurance = "invalid"
        XCTAssertThrowsError(try editor.save()) { error in
            XCTAssertEqual((error as? CreateMortgageViewModel.InputError)?.field, .insurance)
        }
    }

    func testZeroInterestAndAllCashSave() throws {
        let provider = MortgagesProvider(inMemory: true)
        let editor = CreateMortgageViewModel(provider: provider)
        editor.draft.name = "Cash purchase"
        editor.draft.interestRate = "0"
        editor.draft.downpayment = editor.draft.propertyValue
        let objectID = try editor.save()
        let mortgage = try XCTUnwrap(provider.viewContext.existingObject(with: objectID) as? Mortgage)
        XCTAssertEqual(mortgage.downpaymentValue, mortgage.propertyValue)
        XCTAssertEqual(mortgage.interestRatePercentage, 0)
    }

    func testOnDiskStoreSurvivesProviderRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("MortgageDataModel.sqlite")
        try autoreleasepool {
            let provider = MortgagesProvider(storeURL: storeURL)
            XCTAssertNil(provider.loadError)
            _ = try create(provider, name: "Persisted")
            // Explicitly close the first connection before reopening the store;
            // Core Data may retain it beyond the autorelease pool's lifetime.
            let coordinator = try XCTUnwrap(provider.viewContext.persistentStoreCoordinator)
            provider.viewContext.reset()
            for store in coordinator.persistentStores { try coordinator.remove(store) }
        }
        try autoreleasepool {
            let restarted = MortgagesProvider(storeURL: storeURL)
            XCTAssertNil(restarted.loadError)
            let mortgages = try restarted.viewContext.fetch(Mortgage.all())
            XCTAssertEqual(mortgages.count, 1)
            XCTAssertEqual(mortgages.first?.name, "Persisted")
            XCTAssertEqual(mortgages.first?.hoaFeesValue, 1000)
            // Close SQLite before deleting this test's temporary directory.
            let coordinator = try XCTUnwrap(restarted.viewContext.persistentStoreCoordinator)
            restarted.viewContext.reset()
            for store in coordinator.persistentStores { try coordinator.remove(store) }
        }
    }
}
