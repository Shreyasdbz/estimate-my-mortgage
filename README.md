# Estimate My Mortgage

A native iPhone and iPad app for saving and comparing fixed-rate mortgage estimates in US dollars. Version 2.0 uses SwiftUI forms, system navigation, SF Symbols, semantic colors and Dynamic Type. Building with the iOS 27 SDK adopts the current system appearance. The deployment target remains iOS 17; verified runtime coverage is recorded in the delivery report.

The app supports creating, editing, duplicating, deleting, searching, sorting, comparing and sharing estimates. The editor previews validated monthly costs without saving, and saving from the list opens the calculated result. Detail views include monthly and yearly ownership costs, cash at closing, loan totals, an interactive amortization chart and monthly/yearly schedules. Optional Apple Maps address search and property maps have manual-entry and failure states. Input errors keep their guidance visible and focus the affected field directly; failed unit changes preserve the entered values. Exact verification status is recorded in the delivery report.

Calculations support zero interest and all-cash purchases. Property tax, home insurance, HOA fees and upkeep are **annual amounts**, preserving the original saved-data meaning. Closing costs are one-time amounts. Estimates assume constant costs and a fixed rate; mortgage insurance and future rate/cost changes are excluded. Confirm actual costs with a lender.

## Build and test

Open `EstimateMyMortgage.xcodeproj` in Xcode 27 and select the shared `EstimateMyMortgage` scheme. The app has no third-party dependencies. Swift 6 is enabled. For device distribution, use the existing bundle identifier and configure your signing team in Xcode.

```sh
xcrun simctl list devices available
./scripts/test-ios.sh SIMULATOR_UUID /private/tmp/MortgageTests.xcresult
# Optional: run one test group.
./scripts/test-ios.sh SIMULATOR_UUID /private/tmp/MortgageCoreTests.xcresult ui-core
# Verify the disposable CI keyboard fixture without native commands.
python3 -B -m unittest discover -s scripts -p 'test_configure_simulator_keyboard.py'
```

Omit the third argument to run the full shared scheme. Available groups are `units`, `ui-core`, `ui-accessibility` and `ui-navigation`. The shared scheme includes 26 calculation/persistence tests and 29 UI journeys, including comma-decimal entry, draft retention across rotation and separate search, comparison, regular dark and largest-text dark checks. Debug UI tests use unique disposable on-disk stores; search, comparison, split-view selection, largest-text editing and whole-year recovery use fixed estimates in an empty isolated store, while four focused CRUD journeys exercise native creation/relaunch, canceled edits, saved edits/relaunch and duplicate/delete/relaunch. Test fixtures never reset normal user estimates. GitHub Actions runs all four groups on iOS 27 iPhone and iPad and retains result bundles. Group validation rejects missing, duplicate or unexpected test identities and reported failures. The 14 Python fixture tests run separately from the native suite and exercise preservation and failure boundaries with private files and fake commands.

## Saved-data compatibility

The Core Data entity, attribute names and bundle identifier are unchanged. Existing annual expense values retain their meaning. The new editor validates an isolated text draft and commits only after Save; canceled or failed edits leave saved records intact. A failed store load preserves the store and offers retry rather than deleting data or crashing.

## Code organization

`MortgageTerms` in `Utils/CalculationUtils.swift` owns defaults, validation and fixed-rate calculations. Its schedules retain unrounded dollars; views round only for display. `Models/Mortgage.swift` maps the existing Core Data fields to those terms. `MortgagesProvider` opens the store and commits isolated transactions, while `CreateMortgageViewModel` owns unsaved text and unit conversion. SwiftUI screens and components own navigation and presentation. `MapSearch` and `MapUtils` contain cancelable Apple Maps requests. Calculation, persistence and native UI tests live in `Tests` and `UITests`.

## Delivery evidence

See [verification and media](docs/verification.md) for exact toolchain, device coverage, checks, screenshots and recordings. See [privacy policy](PrivacyPolicy.md) for local storage, Apple Maps and sharing behavior.
