# App Store preparation — 13 October 2026

Version **2.0 (2)** targets iOS 17 and later, built with Xcode 27 / iOS 27 SDK. Existing app identity is preserved: Apple ID **6463742539**, bundle `shreyassane.EstimateMyMortgage`, signing team `8WH4G9YJ2J`.

## Saved App Store draft

The 2.0 **Prepare for Submission** draft contains the description, keywords, What's New, public support URL and review notes in [metadata.json](metadata.json) and [review-notes.txt](review-notes.txt). Manual release is selected and existing ratings are preserved. The clearer name and subtitle were saved on 13 October. The refreshed age-rating questionnaire calculates 4+; the existing published privacy disclosure is Data Not Collected and its policy URL matches this repository. Build 2.0 (2) uploaded successfully through Xcode Organizer. Processing, draft build selection and Ready for Review status remain unverified because further Chrome control was denied; access must be restored to finish those steps. No review submission or release has occurred.

TestFlight shows older 1.0.1 builds 1 and 2, and version 1.0; no 2.0 build was displayed before upload on 13 October. Organizer subsequently validated and successfully uploaded 2.0 (2). Apple’s App Store Improvement notice for 1.0.1 requires an update submitted and approved before **28 December 2026**.

## Screenshots

Four screenshots for each required family were uploaded through Chrome and their order read back in Media Manager. Old iPad 13-inch / 12.9-inch and iPhone Face ID / Home Button draft overrides were removed; originals remain in the Asset Library. All inspected optional display sizes now inherit the new set. The published 1.0.1 listing has not been changed.

The new presentation preserves real native UI inside a restrained device frame with short, readable headlines. The ordered story is monthly ownership costs, different loan options, repayment balance, then live editing. [gallery.html](gallery.html) shows all eight exports; [presentation.html](presentation.html) is the reproducible layout; [screenshots.json](screenshots.json) records upload files, dimensions, hashes and capture provenance. The capture journey passed on iPhone (90.573 seconds) and iPad (90.632 seconds), each with one passed case and no failed/skipped cases or native runtime warnings. All 39 native input hashes matched the captured candidate. Three build messages concern skipped AppIntents metadata extraction; they are distinct from runtime warnings. An independent UX reviewer inspected all eight compositions with no blocking findings. Current screenshots must remain distinct from historical QA assets in `docs/media/manifest.json`.

Apple recommends a clear focal point, brief text, a cohesive visual style and leading with the strongest features: [asset guidance](https://developer.apple.com/app-store/asset-best-practices/). Required portrait exports are 1206 × 2622 for iPhone and 2064 × 2752 for iPad, matching the [current specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). Optional preview videos are not a release requirement; retained QA recordings are linked in [verification](../verification.md).

## Verified release boundaries

An unsigned Release device archive at `ReleaseArtifacts/EstimateMyMortgage-2.0-QA.xcarchive` builds successfully. Local inspection confirms arm64 iOS device code, version/build identity, matching dSYM, packaged privacy manifest, Boolean false for non-exempt encryption, and absence of Debug UI fixture keys in the executable. This is a **QA archive, not an uploadable signed build**.

The focused native About/share journey passed once on iPhone and once on iPad after correcting test queries to match native Link controls. Initial Button-query failures were retained and diagnosed; successor cases passed in 49.276 and 50.667 seconds with no native test warnings. New links are visible in [iPhone](iphone-about-privacy.png) and [iPad](ipad-about-privacy.png) captures. These checks cover the changed release links, not a new full regression matrix. Historical broader results retain their original revisions in [verification](../verification.md).

## Signing and remaining submission steps

The Release archive at `ReleaseArtifacts/EstimateMyMortgage-2.0-Signed.xcarchive` is signed for the original personal team `8WH4G9YJ2J` and verifies against the system trust store. After explicit approval, Organizer re-signed 2.0 (2) with a cloud-managed Apple Distribution certificate and App Store profile expiring 4 June 2027. Symbols are included and debugging is disabled. **Apple Organizer validation passed and upload completed** on 13 October.

The exported IPA at `ReleaseArtifacts/Distribution-2.0-2/EstimateMyMortgage.ipa` verifies against the system trust store and contains the correct distribution entitlements. Local inspection confirms matching symbols, packaged privacy, expected SDK/minimum OS and absence of Debug fixture markers. [release-evidence.json](release-evidence.json) records delivered-byte hashes and scope. Processing and draft build selection remain unverified. [Cloud-managed signing](https://developer.apple.com/help/account/certificates/cloud-managed-certificates) is supported by Xcode Organizer.

Wait for processing and select the accepted build in the saved draft. Use Add for Review to validate required metadata and prepare the review draft; [Apple documents](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app) that this does not send the version to review until the separate Submit for Review action. Recheck any newly reported compliance requirements before submitting. Distribution signing and upload were explicitly approved. Any legal agreement acceptance or membership renewal still requires the owner's action or explicit confirmation. A previously observed membership notice listed 24 October 2026; a Paid Apps agreement notice also appeared, whose effect on this free app remains unverified. No payment or agreement was accepted.

No App Store accessibility badges are claimed without the corresponding manual device validation. VoiceOver navigation, runtime Reduce Motion behavior and physical haptic output still need manual confirmation.

## Reproduce local checks

```sh
python3 -B -m unittest discover -s scripts -p 'test_validate_app_store.py'
python3 -B scripts/validate-app-store.py --archive ReleaseArtifacts/EstimateMyMortgage-2.0-QA.xcarchive
./scripts/archive-ios.sh --unsigned /absolute/path/new-QA.xcarchive
# With correct-team signing configured, omit --unsigned for a distribution candidate.
./scripts/archive-ios.sh /absolute/path/new-signed.xcarchive
```

To reproduce presentation, serve this folder on localhost, open `presentation.html?device=iphone&shot=1` (or `ipad`, shots 1–4) in Chrome, use the exact required viewport dimensions above, and capture the page. The committed exports are Chrome JPEG captures converted to RGB PNG with `sips`; the native UI is uniformly scaled as a whole, not reconstructed. Recompute manifest hashes if exporting again.

`archive-ios.sh` refuses to overwrite existing output and never creates credentials or uploads. [ExportOptions.plist](ExportOptions.plist) is for exporting a signed archive; it does not make an unsigned archive uploadable. Local metadata/image/binary checks complement the observed Organizer validation and upload; they do not establish App Store processing or App Review approval. This scoped release-preparation commit uses focused native checks and the package validator; no new full CI matrix is claimed. `ReleaseArtifacts/` stays ignored; private contact fields, account screenshots, signing material and native result bundles are not source-controlled.
