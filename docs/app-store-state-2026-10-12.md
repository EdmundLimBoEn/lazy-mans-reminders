# App Store state, 12 October 2026

These checks used Edmund's authenticated shared App Store Connect browser for app `6799138197`. They update the earlier source-only audits. No App Store review submission or public release occurred.

## Saved draft and declarations

The App Store draft now has the name **Lazy Man's Reminders**, subtitle **Lock Screen reminder board**, reviewed description and keywords, and canonical URLs at `https://lmr.sillyapps.co`. The copy describes Live Activities as subject to iOS, settings and connectivity rather than promising indefinite visibility. The old listing name and URLs were replaced. Primary category is Productivity, secondary Utilities. App Information currently displays a global age rating of **4+** with regional variants; physical QA does not follow from that rating.

App Review contact fields are complete. Sign-in is required and the dedicated account's credentials are saved in the private review fields. TestFlight beta description, URLs, contact, private review credentials and build-specific testing instructions are also saved. The reviewer route is **Use an Existing Password → Sign In with Password**. No credentials or private contact details appear in this repository. Backend password login was previously verified; fresh-install native reviewer access remains a device gate.

Version release is **manual**. Under Edmund's explicit declaration, the developer account is non-trader for all its EU apps, and this app's App Information confirms non-trader status.

The App Privacy responses were published for the current seven-type manifest: **Name, Email Address, Other User Content, User ID, Device ID, Other Diagnostic Data and Other Data Types**. Each is linked to the user, used for App Functionality and not used for tracking. The public privacy-policy URL is updated. Final SDK/aggregate privacy-report inspection remains an artifact gate; the published labels must be updated if actual collection changes. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

All 175 displayed storefront prices are zero, including **USD $0.00**. Availability is configured for all current and future countries or regions after release. Compatible Apple Silicon Mac and Vision Pro availability remain enabled at Edmund's explicit request; those environments were not tested here and are not advertised as separately verified native apps.

## Actual build provenance

The export workflow enables `manageAppVersionAndBuildNumber`, so its archive version is not necessarily the uploaded version. Do not tell testers to install the archive's floor number.

- [Run 38131374027](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/38131374027), source `c65ef2a`, archived **1.0 (9)** but uploaded **1.0 (21)**. CI upload ID `f8136ba3-75e2-4507-8368-f3f0619c5175` matches Apple's build 21.
- [Run 38185478817](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/38185478817), source `1be77dfa6825046fce43d8c63a4445cb4368e484`, archived **1.0 (10)** but uploaded **1.0 (22)**. CI upload ID `3179e099-c150-4820-83ab-c0a193847719` matches Apple's build 22, uploaded **11 October at 23:55 UTC**. The run passed **179 Swift tests**, archive, export and upload.

Apple reports build 22 as **Validated**, SDK `23F81a`, minimum iOS 17.0, non-exempt encryption **No**, and the expected app/widget identifiers, App Group, Sign in with Apple and production APNs entitlements. It initially replaced retired build 5 in the App Store draft; the final build 23 has since replaced it.

Build 22 was added to the existing **Internal Testers** group, which contains only Edmund. The group showed build 22 as **Testing**; build 23 has since been added. No other testers were invited, and no external beta review was submitted. The user's existing tester invitation still needs acceptance if TestFlight does not display the app.

## Final candidate and screenshots

Build 22 also reports **iPhone and iPad** support. The fix thread confirmed that XcodeGen's target preset overrides the project-level device-family setting. Follow-up **PR #67** explicitly sets the app and widget targets to iPhone and corrects a renewal-clock regression. PR #67 merged as `96c05726fcab7ac912e9d3d04d0edb12d9f25c75`. [Run 38187888975](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/38187888975) passed 180 Swift tests, archive, export and upload. Its downloaded `ios-export-metadata` artifact proves **1.0 (23)** for both app and widget, `UIDeviceFamily=[1]`, SDK `iphoneos26.5` / `23F81a`, Xcode `2660` / `17F113`, minimum iOS 17.0. Archive floor 11 is not the TestFlight number. Apple's upload row matches the exact upload ID `dc47475c-3ac4-47ad-80be-7bf6322e8223`, created **12 October at 00:32 UTC**. 

After processing, Apple reports **Validated**, device family **iPhone**, SDK `23F81a`, minimum iOS 17.0, non-exempt encryption **No**, and the expected production entitlements. 

Build **23** is selected in the saved App Store draft, replacing 22. The existing Edmund-only Internal Testers group shows **1 Tester / 4 Builds**, with build 23 **Testing**. Build-specific What to Test includes warm/offline recovery, overnight renewal and account lifecycle checks, verified after reloading. The version remains manual release. No external testers were invited and no review submission occurred. Mac and Vision Pro availability were rechecked after saving and reloading; both are enabled.

The required **iPhone with Dynamic Island, medium display** screenshot slot is empty: **0 of 10** screenshots. ASC accepts **1179×2556** or **1206×2622** portrait images for that slot. Other device tabs exist in the uploader, but a tab alone does not establish a requirement; confirm coverage against the final binary's supported families and Apple's current rules. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

This Linux environment's device tools report iOS unavailable because simulators require macOS/Xcode. No native screenshots or physical-device QA were fabricated. Capture the final candidate in use with fictional reminders, including the board, completion, Live Activity and widgets. Verify the actual required slots in ASC before submitting.

Final-candidate build/device-family verification is complete. The remaining release gates are fresh-install reviewer access, signed iPhone sign-in/widgets/deletion/accessibility checks, foreground and overnight persistence/soak acceptance, final privacy-report inspection, and real screenshots. Keep manual release and submission pending until those gates pass.

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
