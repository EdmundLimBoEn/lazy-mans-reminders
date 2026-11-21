# Sign-in native polish handoff

Passing implementation on `t3/signin-native-polish`, based on `9d48476`. Source/test commit `551f880`. Only `ios/App/LMRChrome.swift`, `ios/App/SignInView.swift`, `ios/Tests/LMRChromeTests.swift`, and `ios/UITests/SignInSurfaceUITests.swift` changed. All other new material is task-local. HillclimbDemo and Account/board implementations are untouched. Every existing user-facing literal call site, branding, glyph, provider order and control height is preserved; scope-integrity.json records the comparison.

Apple uses the native whiteOutline style in both appearances, replacing the old dark grouped-card assumption. Sign-in informational labels use adaptive primary neutral ink. The custom Done inset retains its real48pt target and8pt content clearance while removing4pt top/bottom padding (8pt total); the keyboard toolbar that previously faulted is not restored. The remaining form/scroll anchor is retained to avoid changing successful interactive dismissal/refocus behavior.

Explicit `--hillclimb-demo signin --hillclimb-signin-appearance enabled` enables provider styling under root `allowsHitTesting(false)`. Default demos still disable providers and submission exactly as before, with local editing/recovery retained. Every provider/submit callback, including keyboard submission, still guards blocksExternalActions for any sign-in demo. Legal links remain disabled. Native taps on Apple, Google, email and alternate action in the appearance fixture produced no keyboard, password mode or navigation change. This is an inert design fixture; no provider flow is claimed tested. Production auth behavior is unchanged.

## Build and tests

Own setup.sh generated isolated example config and xcodegen project. Own fresh DD `/tmp/notepad-signin-native-90ae0aca-dd`; unsigned arm64 build-for-testing succeeded for private Auth17, iOS26.2, UDID `8E8380DE-364D-4899-99B8-D15ED0494FFD`. Package resolution occurred only during setup. No updates/resolution were permitted afterward. Full exact build, runner and result paths are in build-Debug.json and *-process.json; original generated xctestrun is retained with SHA256 in artifacts.json.

```sh
xcodebuild test-without-building \
  -xctestrun /tmp/notepad-signin-native-90ae0aca-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun \
  -destination 'platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 240 \
  -collect-test-diagnostics never -disableAutomaticPackageResolution -skipPackageUpdates \
  -resultBundlePath /tmp/notepad-signin-native-90ae0aca-combined.xcresult CODE_SIGNING_ALLOWED=NO
```

| Run | Passed | Failed | Skipped | Runtime warnings | Scoped invalid frames |
|---|---:|---:|---:|---:|---:|
| Full existing suite + new pixel/inert-fixture test |277 (260 unit +17 UI)|0|0|0|0|
| Fresh keyboard matrix1 |1 (8 cases)|0|0|0|0|
| Fresh keyboard matrix2 |1 (8 cases)|0|0|0|0|
| Fresh keyboard matrix3 |1 (8 cases)|0|0|0|0|

Each repeat selects only `HillclimbUITests/SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances`. All original542b9f7 assertions, actual form scrolling, valid interactive dismissal/refocus,95% Done edge and5% alternate edge taps remain. matrix-proof.json verifies all32 completed cases across the full run and repeats, rather than counting runner exits. No failures occurred in this task; historical failed round3 evidence is untouched.

The new `testEnabledAppearanceIsInertAndAppleBoundaryIsVisible` uses actual native screenshot pixels, not a style-helper mirror: dark Apple interior boundary strip >80% white, and dominant solid normal-text ink contrast>=4.5. It also exercises inert fixture taps. Existing demo-disabled, local recovery, wrapping, password/inbox/error/loading, keyboard and whole-app tests passed. Chrome unit expectation now requires whiteOutline in dark.

## Native evidence and measured tradeoff

surfaces/manifest.json:24 settled1206×2622 native images (both appearances/default+XXXL × default/password/inbox/error/loading/inert-enabled). captures/manifest.json:8 additional native images after actual form pan and keyboard/Done verification. Both include every pinned operation, source attribution, dimensions and SHA256. pixel-test-native contains4 native XCTest screenshots. error-extra-settle.png is a separately retained fresh recheck. Total37 PNGs; image-integrity.json covers all37. Old evidence remains unchanged.

Inspected all8 post-pan keyboard originals; representative original disabled/enabled default/XXXL, password, inbox and error states; and all4 paired Apple Reminders compose references (reference/reminders-compose-light.png, reference/round2/reminders-compose-dark.png, reference/round3/reminders-compose-{light,dark}-XXXL.png). References establish form/keyboard conventions, not authentication parity. A resized image display initially appeared to omit upper error content. Original-resolution inspection and fresh device_screenshot confirmed complete ink; the extra check is retained rather than replacing evidence.

`python3 hillclimb/tasks/signin-native/measure.py` passed on unmodified PNGs with same-capture native accessibility rectangles:60 eligible normal-text samples have dominant black/white ink at21:1;12 dark Apple strips (enabled and disabled states) have100% pixels differing from black by>20. Intentionally disabled provider/submit/legal controls are excluded from normal-text contrast checks. These findings certify the captured states, not every accessibility setting/device.

Done is48pt high in all8 post-pan states,48pt wide/default and53pt/XXXL. Alternate action clearance is116–116.33pt, exceeding8pt, with legal links between alternate and Done. Native keyboard AX rect starts y583; Done bottoms are566/email and539/password, yielding17pt and44pt to that rect. Native rasters show that area contains keyboard rounding or the Passwords strip, not extra custom inset padding. The custom inset itself is now the48pt target; reducing it further would reduce the target. Remaining space above Done includes the existing legal footer and scroll bottom padding; this change deliberately makes a modest8pt improvement instead of removing the tested recovery layout. No claim that every visible gap is unavoidable is made.

## Integrity, diagnostics and cleanup

all-input-hashes.json covers89 tracked iOS inputs plus local generated/config/setup inputs. provenance.json covers78 Swift source/test files; artifacts.json covers native binary, generated xctestrun and config/package provenance. Source was committed after the successful build; recorded hashes establish identical bytes, not a rebuild after the commit. Full xcresults remain at the recorded /tmp paths. No Release build or backend tests were requested or claimed here.

Compiler AuthManager weak-capture/unused-try and existing unit-test warnings, AppIntents metadata warning, unsigned APNs/IOSurface and debugger-version diagnostics are retained. Scoped error/fault totals are8236/full,3812/matrix1,3806/matrix2,3806/matrix3. Complete scoped logs and xcresult issues are retained; zero invalid frames is not a global warning-free claim. Pillow emitted getdata deprecation warnings during offline measurement; assertions passed.

cleanup.json: own app and pinned session closed; light/large restored; Auth17 left booted; owned Activity IDs verified empty after the full-suite Activity test cleaned its own ID. No other sessions/devices, Duo, parent ignored config or untracked files were touched. No subagents, live auth/API/data writes, messages, push/PR/merge/deploy/store operations. Physical haptics and spoken VoiceOver are unobserved and uncertified.

Parent integrates passing branches, then runs the full original17 round4 recapture/regrade. No scores are assigned here.

Written by gpt-6.1-sol in Codex on behalf of Edmund
