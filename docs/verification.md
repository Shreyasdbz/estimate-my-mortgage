# Version 2.0 verification — 8 October 2026

The app is rebuilt with Xcode 27.0 (27A266a), Swift 6 and the iOS 27 SDK. It retains the existing bundle identifier, Core Data entity and attributes, SQLite filename and annual expense units. The deployment target is iOS 17. The app icon uses a simplified original house motif with native asset-catalog Default, Dark and Tinted variants.

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
| Amortization | Native Charts balance plot with primary-color axes and monthly/yearly schedules. Independent conservation, remaining-balance and extreme-rate/term checks. |
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

The shared scheme runs calculation/persistence and UI targets. Each UI journey launches with a unique disposable on-disk store; the release build ignores this debug-only seam. The tests do not erase the normal user store. Name replacement uses the visible native Select All edit menu, verifies deletion, then asserts the exact replacement value before continuing. Numeric fields also exercise native hardware-keyboard selection. Test execution is bounded to 180 seconds per case; diagnostic collection is disabled after an observed simulator-diagnostics collection hang, while result bundles, failures and requested attachments remain enabled. GitHub Actions has separate iOS 27 iPhone/iPad jobs and retains their result bundles for 14 days.

## Runtime results and media

Completed local suites on iOS 27.0 (24A434):

| Device | Result | Local result bundle |
| --- | --- | --- |
| iPhone 17 Pro | 34 passed, 2 skips (live Maps and iPad-only), 0 failures | `/private/tmp/emm-final-whole-phone.xcresult` |
| iPad Pro 13-inch (M5), before touch-menu refinement | 34 passed, 1 live Maps skip, 1 hardware-selection timeout | `/private/tmp/emm-final-whole-ipad.xcresult` |
| Final touch-menu edit/cancel/relaunch and filtered-save journeys | iPhone: 2 passed; iPad: 2 passed; 0 failures on either device | `/private/tmp/emm-touch-name-phone.xcresult` and `/private/tmp/emm-touch-name-ipad.xcresult` |
| Generic iOS device, Release | Build succeeded; signing disabled | `/private/tmp/emm-release-acceptance.log` |

Each complete suite includes nine calculation tests, 14 persistence/editor tests and 13 UI journeys. The final complete iPhone run is offline. An earlier complete iPhone run passed 35 tests with one iPad-only skip in `/private/tmp/emm-acceptance-phone.xcresult`, including actual Apple Maps suggestions, address resolution, a property map and a foreground Maps handoff. A separate iPad live Maps journey passed after reboot in `/private/tmp/emm-ipad-recovery-final.xcresult`, although its older editing tests timed out. Enable this optional integration check with `TEST_RUNNER_EMM_LIVE_MAPS=1 ./scripts/test-ios.sh SIMULATOR_UUID RESULT_PATH`. Offline CI skips this provider-dependent journey. The hosted workflow runs both complete suites; its results and retained artifacts are available from [GitHub Actions](https://github.com/Shreyasdbz/estimate-my-mortgage/actions).

UI journeys exercise creation, editing, cancellation, validation, duplicate/delete confirmation, relaunch persistence, search, sort, unit conversion, all-cash estimates, comparison, monthly/yearly costs and schedules, sharing, About/privacy, manual address entry and canceled search. The filtered-save journey keeps search active, uses the list context-menu Edit action, verifies the saved result, then checks the cleared filter and actual list row after returning. The iPad-only journey confirms that switching estimates resets an open schedule. Portrait, landscape, light and dark appearance, and the largest accessibility text category are captured. Contrast, text-clipping and hit-region audits run on regular-text detail/editor, landscape and amortization screens, and the largest-text editor. The largest-text detail uses clipping and hit-region audits plus rendered contrast review: the native contrast auditor inconsistently samples partially offscreen rows and sometimes supplies no element. A recorded Cost breakdown report extended beyond the 874-point iPhone viewport; its visible white-on-black glyphs measured 21:1, and the test scrolls the heading fully into view for a separate capture. Scrolled purchase, comparison and disclosure sections are reviewed from rendered captures rather than passing occluded content to the contrast auditor.

The iOS 27.0 auditor reports contrast failures for native glass Cancel/Save controls despite measured rendered contrast: Cancel 19.66:1 in light and 11.18:1 in dark; Save 5.26:1 in light, 6.30:1 on dark iPhone and 6.25:1 on dark iPad. The test exception matches only those exact button identifiers, labels, OS version and verified appearances, retaining captures. Other findings still fail. Final rendered review also found native form values at 3.44:1; explicit primary value text and native labeled menu pickers now measure 21:1 in the retained light captures. Seven iPad large-text clipping reports were resolved by using native LabeledContent instead of manually stacked amount rows; they are not suppressed.

Native hardware Select All intermittently stalled while XCTest waited for animation completion, including after reboot and with both multiline and single-line fields. A three-second native sample found the app main thread idle throughout, which does not establish a root cause. Name input uses a native single-line field for regular layouts and wraps at accessibility text sizes in compact layouts. Repeated iPad editing/largest-text checks and the final phone complete suite passed, but a later iPad filtered-save journey still timed out after hardware selection. Name replacement tests now use the visible native touch edit menu, require Select All to be hittable, verify deletion, and assert the exact replacement. No animation disabling, private quiescence flags or larger timeouts are used. The comparison journey also finishes search through native list navigation before opening its toolbar menu, because the first toolbar tap while search had focus dismissed focus rather than opening the menu; final complete comparison checks passed on both devices.

Local runs retain unattributed SwiftUI “Invalid frame dimension (negative or non-finite)” warnings, generally at initial editor field focus. Source inspection and isolated toolbar/name-field probes did not identify their cause. Successful interaction runs, layout audits and rendered captures are recorded separately; this diagnostic remains unresolved and is not being attributed to an SDK defect without proof. The unpublished maintenance follow-up is to isolate the warning at editor focus, identify the responsible layout calculation and rerun the editing/accessibility journeys without the diagnostic; no tracker item has been published. These automated audits and screenshots do not establish physical-device performance or a complete assistive-technology certification.

The [36-second iPhone walkthrough](media/iphone-journey.mp4) and [37-second iPad walkthrough](media/ipad-journey.mp4) record native creation, navigation, payment details and schedules; only setup/idle time is trimmed. Screenshots are exported from the completed local test attachments, using synthetic estimate names and a public Apple Park address.

| Surface | iPhone | iPad |
| --- | --- | --- |
| Empty state | [Capture](media/iphone-empty-state.png) | [Capture](media/ipad-empty-state.png) |
| Saved estimates | [Capture](media/iphone-estimates.png) | [Capture](media/ipad-estimates.png) |
| Payment details | [Capture](media/iphone-payment-details.png) | [Capture](media/ipad-payment-details.png) |
| Native editor | [Capture](media/iphone-native-editor.png) | [Capture](media/ipad-native-editor.png) |
| Unit conversion | [Capture](media/iphone-native-units.png) | [Capture](media/ipad-native-units.png) |
| Comparison | [Capture](media/iphone-comparison.png) | [Capture](media/ipad-comparison.png) |
| All-cash result | [Capture](media/iphone-all-cash-details.png) | [Capture](media/ipad-all-cash-details.png) |
| All-cash comparison | [Capture](media/iphone-comparison-all-cash.png) | [Capture](media/ipad-comparison-all-cash.png) |
| Built Home Screen icon | [Capture](media/iphone-home-screen-icon.png) | [Capture](media/ipad-home-screen-icon.png) |
| Annual schedule | [Capture](media/iphone-amortization.png) | [Capture](media/ipad-amortization.png) |
| Monthly schedule | [Capture](media/iphone-monthly-amortization.png) | [Capture](media/ipad-monthly-amortization.png) |
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

[Light iPhone toolbar contrast capture](media/iphone-verified-native-toolbar-contrast-light.png), [dark iPhone capture](media/iphone-verified-native-toolbar-contrast-dark.png), [light iPad capture](media/ipad-verified-native-toolbar-contrast-light.png), [dark iPad capture](media/ipad-verified-native-toolbar-contrast-dark.png).

[Original app screenshot](media/before.png)

## Platform sources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass): standard system controls and navigation adopt the current platform appearance.
- [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) and [Writing](https://developer.apple.com/design/human-interface-guidelines/writing): clear labels, useful feedback and errors near the affected input.
- [MapKit](https://developer.apple.com/documentation/mapkit): optional address search, geocoding and Maps handoff.
- [GitHub Xcode 27 runner image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md): workflow toolchain and simulator availability.

Simulator checks establish local behavior; signed device distribution, App Store submission and actual lender schedules are separate outcomes. No App Store publication is performed by this repository change.
