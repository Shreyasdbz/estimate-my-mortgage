# Version 2.0 verification — 8 October 2026

The app is rebuilt with Xcode 27.0 (27A266a), Swift 6 and the iOS 27 SDK. It retains the existing bundle identifier, Core Data entity and attributes, default SQLite path and annual expense units. The schema contents are unchanged from pre-modernization revision `20180ee`. The deployment target is iOS 17. The app icon uses a simplified original house motif with native asset-catalog Default, Dark and Tinted variants.

## Design and engineering audit

Separate agents reviewed calculation, persistence and UI behavior from engineering and Apple HIG perspectives. Rendered inspection and simulator interactions are separate evidence from those source reviews.

| Surface | Changes and checks |
| --- | --- |
| Launch and store recovery | Recoverable loading error and retry preserve the store. Disposable corrupt-store regression checks that opening, retrying and attempted saving do not replace its bytes. |
| Empty state and estimate list | Native split navigation, list links, search, sorting, swipe/context actions, named toolbar controls and explicit property-price labels. |
| Create and edit | Native Form, persistent labels, numeric keyboards, one keyboard-focus owner, isolated raw-text draft, field-specific errors, Save/Cancel and discard confirmation. Successful list-owned saves reveal results after dismissal and clear the search filter; failures/cancellation retain navigation. |
| Numeric units and validation | Regional decimal separator; grouped, nonfinite and malformed inputs rejected. Unit switches preserve input/unit if conversion fails. Fixed-rate, zero-interest and all-cash cases checked independently. All-cash list, detail, comparison and shared summaries identify that there is no loan. |
| Address entry and search | One full-address field composes legacy components without mutating them until editing. Native Apple Maps search has short-query guidance, loading/error states and canceled debounce/resolution requests. |
| Detail and ownership costs | Native monthly/yearly control, ownership expenses, closing cash and lifetime loan totals. Semantic primary text contrast and native LabeledContent adapt labels/values to available width and Dynamic Type. |
| Comparison | Stable object identities and unavailable-record guards; estimates grouped by metric; equal costs identified at displayed currency precision. |
| Amortization | Native Charts balance plot with primary-color axes, compact balance labels and chart height that scales with Dynamic Type. Monthly/yearly schedules and independent conservation, remaining-balance and extreme-rate/term checks. |
| Map and Maps handoff | Explicit lookup, native map with an 800 m neighborhood starting region, loading/error/retry, native request cancellation and Open in Maps. No fabricated default location. |
| Sharing | Native system share sheet with a textual estimate summary and stated calculation limits. |
| About and privacy | Native version, local-storage, Apple Maps, backups and sharing disclosures. Privacy manifest included in the built app. |
| Data mutations | Isolated Core Data transactions, rollback, permanent IDs, atomic delete, duplicate validation and stale-editor protection. |
| Appearance and accessibility | System typography, semantic colors, SF Symbols and native navigation/form/list controls. Screenshot and runtime audit results are recorded below. |

## Reproduce checks

```sh
xcodebuild -version
xcrun simctl list devices available
./scripts/test-ios.sh SIMULATOR_UUID /private/tmp/MortgageTests.xcresult
xcodebuild -project EstimateMyMortgage.xcodeproj -scheme EstimateMyMortgage \
  -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath /private/tmp/MortgageRelease CODE_SIGNING_ALLOWED=NO build
```

The shared scheme runs calculation/persistence and UI targets. UI journeys use unique disposable on-disk stores; Release ignores the debug-only store seam. Field replacement requires an available empty value within five seconds before typing and asserts the exact replacement. Persistent input labels and accessible names remain when numeric placeholders are empty. Native action checks use fresh screen geometry, keyboard/focus dismissal and editor preservation. Current checks allow 15 seconds for share-sheet Copy and 20 seconds for the Save button to disappear; these are test readiness checks, not changes to saving. XCTest is configured with 300-second case limits; synchronous native operations can overrun waiter or execution allowances. Result bundles and requested attachments remain enabled; diagnostic collection is disabled after an observed collection hang. GitHub Actions runs separate iPhone/iPad jobs, waits for simulator boot, retains bundles for 14 days and allows 35 minutes per job. Documentation-only pushes skip the simulator workflow; pull requests still run it.

## Runtime results and media

The current pushed revision is [`6ef0f9df7e5e520f539e87c5a1924280d725ebe0`](https://github.com/Shreyasdbz/estimate-my-mortgage/commit/6ef0f9df7e5e520f539e87c5a1924280d725ebe0). Its [hosted verification run](https://github.com/Shreyasdbz/estimate-my-mortgage/actions/runs/37796311005) is running; final hosted verification remains outstanding. Production source is unchanged from `6b8f916`, whose Release build and complete hosted iPad suite passed.

The preceding [hosted run](https://github.com/Shreyasdbz/estimate-my-mortgage/actions/runs/37792134818), on `6b8f916`, completed with iPhone 33 passed, one failed and two skipped; iPad 35 passed, zero failed and one live-Maps skip. The phone's first accessibility case timed out collecting an XCUIScreen screenshot before the first Done geometry check or touch. All its remaining ten applicable UI journeys and 23 unit tests passed; the downloaded result summary contained no runtime warnings. The current test-only revision removes two unconditional diagnostic captures from action helpers while retaining dedicated media, failure captures and every functional assertion. A local rerun of the failed phone case passed; final complete hosted proof is still pending.

| Check | Verified result | Evidence basename |
| --- | --- | --- |
| Phone accessibility after diagnostic-capture removal | Passed in 64.511 seconds, zero failures. | `emm-final-no-extra-capture-phone.xcresult` |
| Final native accessibility and filtered-save regressions | Two cases passed on each device, zero failures. | `emm-final-anchor-phone.xcresult`, `emm-final-anchor-ipad.xcresult` |
| Earlier focused input, sharing and validation regressions | iPhone: five passed. iPad: four passed, one dark/largest-text case exceeded 300 seconds; sharing, filtered save and validation passed after XCTest restarted. The complete hosted iPad run above subsequently passed the dark-text journey. | `emm-final-native-readiness-phone.xcresult`, `emm-final-native-readiness-ipad.xcresult` |
| Maps cleanup, iPhone | Three passed: live Maps, manual address/canceled search and units/sorting. | `emm-shipping-maps-cleanup-phone.xcresult` |
| iOS 26 compatibility subset | 27 passed: all 23 calculation/persistence tests plus create/edit/cancel/delete/relaunch, units/sorting, validation and screenshot journeys. | `emm-final-compatibility-26.xcresult` |
| Current production Release | Build succeeded; version 2.0, deployment target iOS 17, signing disabled. | `emm-final-blank-field-release.log` |

The scheme contains nine calculation tests, 14 persistence/editor tests and 13 UI journeys. Offline CI skips live Apple Maps; iPhone skips the iPad-only selection journey. Enable live Maps with `TEST_RUNNER_EMM_LIVE_MAPS=1 ./scripts/test-ios.sh SIMULATOR_UUID RESULT_PATH`. Earlier isolated passes and interrupted runs do not establish a green complete suite for the current revision.

Earlier local runs included long XCTest animation-notification waits and the recorded iPad dark-text timeout. Independent source review found no app-owned explanation; an SDK cause has not been established. Those failures remain distinct from the later complete hosted iPad pass. Production contains no temporary sheet-sizing experiment or OSLog tracing.

The largest-text chart now scales its 220-point base height with `@ScaledMetric(relativeTo: .caption)` and uses native compact balance-axis labels. Eight chart PNGs from passed cases are in the gallery and reconciled manifest. Labels do not overlap, and the phone's largest chart scrolls to its bottom and schedule control.

The UI suite covers creation, editing, cancel/discard, validation, duplicate/delete, relaunch persistence, filtering and sorting, unit conversion, all-cash estimates, comparison, monthly/yearly costs and schedules, sharing, About/privacy, manual address entry and canceled search. Filtered saves reveal the result and clear search; iPad selection changes reset an open schedule. Captures cover portrait, landscape, light/dark appearance and the largest accessibility text category. These describe the test and capture scope, not a final complete-suite outcome.

Contrast, clipping and hit-region audits cover regular detail/editor, landscape and amortization screens, and the largest-text editor. Largest-text detail uses clipping/hit-region checks plus rendered contrast review because the native contrast auditor can sample partially offscreen rows; a visible white-on-black Cost breakdown heading measured 21:1. Selected-sidebar and form-value contrast defects were corrected through native selection foreground and primary value text. Native LabeledContent resolved the iPad amount-row clipping reports without suppressing them.

The only contrast exception matches native Cancel/Save identifiers and labels on exactly iOS 27.0.0 in verified light/dark appearances. Rendered Cancel contrast measured 19.66:1 in light and 11.18:1 in dark; Save measured 5.26:1 in light and 6.25–6.30:1 in dark. Captures are retained, and other findings still fail. These checks do not certify every assistive-technology interaction or physical-device performance. The current Release build has no source compiler errors; its App Intents metadata-extraction warning is expected because the app has no AppIntents dependency. Earlier unattributed invalid-frame warnings were not reproduced in the final focused checks; no maintenance tracker item has been published.

Both walkthroughs show two synthetic estimates, navigation, payment details, the current yearly/monthly charts and editor cancellation returning to details. They exclude the final Home Screen transition. Only boundary setup/idle time is trimmed, at ordinary speed with no internal cuts. Every raw and exported frame decoded successfully; visual inspection sampled interaction and trim boundaries, without a continuous-playback claim.

| Walkthrough | Delivered size and duration | Raw trim range | Exported frames decoded |
| --- | --- | --- | --- |
| [iPhone](media/iphone-journey.mp4) | 588 × 1280; 40.1 seconds | 4.5–44.6 seconds | 1,312 |
| [iPad](media/ipad-journey.mp4) | 960 × 1280; 41 seconds | 3.8–44.8 seconds | 797 |

The [media manifest](media/manifest.json) reconciles all 64 delivered assets: 62 PNGs and two movies, with no missing or duplicate entries. Delivered hashes and dimensions match retained provenance; all 63 updated assets have a specific Passed test-case node verified in their source result bundles. The original blank repository image retains its original attribution. Screenshots use synthetic estimates or a public Apple Park address, and some source bundles contain unrelated failed cases. The two largest-text iPad detail/cost images show the same frame. The public manifest contains source-bundle basenames rather than private paths or device identifiers; media proof does not establish final CI success.

| Surface | iPhone | iPad |
| --- | --- | --- |
| Empty state | [Capture](media/iphone-empty-state.png) | [Capture](media/ipad-empty-state.png) |
| Saved estimates | [Capture](media/iphone-estimates.png) | [Capture](media/ipad-estimates.png) |
| Payment details | [Capture](media/iphone-payment-details.png) | [Capture](media/ipad-payment-details.png) |
| Native editor | [Capture](media/iphone-native-editor.png) | [Capture](media/ipad-native-editor.png) |
| Focused numeric input | [Capture](media/iphone-numeric-focused-input.png) | [Capture](media/ipad-numeric-focused-input.png) |
| Dark focused input | [Capture](media/iphone-dark-normal-focused-input.png) | [Capture](media/ipad-dark-normal-focused-input.png) |
| Dark, largest text: focused input | [Capture](media/iphone-dark-large-text-focused-input.png) | [Capture](media/ipad-dark-large-text-focused-input.png) |
| Empty numeric input and inline validation | [Capture](media/iphone-empty-numeric-validation.png) | [Capture](media/ipad-empty-numeric-validation.png) |
| Unit conversion | [Capture](media/iphone-native-units.png) | [Capture](media/ipad-native-units.png) |
| Comparison | [Capture](media/iphone-comparison.png) | [Capture](media/ipad-comparison.png) |
| All-cash result | [Capture](media/iphone-all-cash-details.png) | [Capture](media/ipad-all-cash-details.png) |
| All-cash comparison | [Capture](media/iphone-comparison-all-cash.png) | [Capture](media/ipad-comparison-all-cash.png) |
| Built Home Screen icon | [Capture](media/iphone-home-screen-icon.png) | [Capture](media/ipad-home-screen-icon.png) |
| Annual schedule | [Capture](media/iphone-amortization.png) | [Capture](media/ipad-amortization.png) |
| Monthly schedule | [Capture](media/iphone-monthly-amortization.png) | [Capture](media/ipad-monthly-amortization.png) |
| Dark, largest text: annual schedule | [Capture](media/iphone-dark-large-text-amortization.png) | [Capture](media/ipad-dark-large-text-amortization.png) |
| Dark, largest text: monthly schedule | [Capture](media/iphone-dark-large-text-monthly-amortization.png) | [Capture](media/ipad-dark-large-text-monthly-amortization.png) |
| Address search | [Capture](media/iphone-address-search.png) | [Capture](media/ipad-address-search.png) |
| Apple Maps results | [Capture](media/iphone-address-results.png) | [Capture](media/ipad-address-results.png) |
| Property map | [Capture](media/iphone-property-map.png) | [Capture](media/ipad-property-map.png) |
| System sharing | [Capture](media/iphone-share-sheet.png) | [Capture](media/ipad-share-sheet.png) |
| About and privacy | [Capture](media/iphone-about-privacy.png) | [Capture](media/ipad-about-privacy.png) |
| Dark, largest text: details | [Capture](media/iphone-dark-large-text-details.png) | [Capture](media/ipad-dark-large-text-details.png) |
| Dark, largest text: ownership costs | [Capture](media/iphone-dark-large-text-costs.png) | [Capture](media/ipad-dark-large-text-costs.png) |
| Dark, largest text: editor | [Capture](media/iphone-dark-large-text-editor.png) | [Capture](media/ipad-dark-large-text-editor.png) |
| Landscape | [Capture](media/iphone-landscape-details.png) | [Capture](media/ipad-landscape-details.png) |
| Split-view selection reset | — | [Capture](media/ipad-selection.png) |

The empty-input captures show the caret, persistent field label and inline validation message. The native floating iPad keypad covers part of the property-price label in its capture; the image retains that actual state.

[Light iPhone toolbar contrast capture](media/iphone-verified-native-toolbar-contrast-light.png), [dark iPhone capture](media/iphone-verified-native-toolbar-contrast-dark.png), [light iPad capture](media/ipad-verified-native-toolbar-contrast-light.png), [dark iPad capture](media/ipad-verified-native-toolbar-contrast-dark.png).

[Original blank repository capture](media/before.png)

## Platform sources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass): standard system controls and navigation adopt the current platform appearance.
- [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) and [Writing](https://developer.apple.com/design/human-interface-guidelines/writing): clear labels, useful feedback and errors near the affected input.
- [SwiftUI submission](https://developer.apple.com/documentation/swiftui/view/onsubmit(of:_:)): numeric hardware Return clears focus without saving.
- [MapKit](https://developer.apple.com/documentation/mapkit): optional address search, geocoding and Maps handoff.
- [GitHub Xcode 27 runner image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md): workflow toolchain and simulator availability.

iOS 17 runtime behavior, signed device distribution, physical-device performance, App Store submission and actual lender schedules remain separate verification outcomes. No App Store publication is performed by this repository change.
