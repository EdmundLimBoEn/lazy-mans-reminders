# Sign-in surfaces

Scope is SignInView.swift, dedicated SignInSurfaceUITests.swift, and this evidence directory. No authentication SDK or service code changes. User-facing strings, provider actions, Apple style selection, legal links, submit actions, cancellation, validation, and focus transitions are retained. The outer card padding/backgrounds are removed; controls define the surfaces. The password toggle uses a plain label with a full-width 44pt target.

DEBUG-only launch argument `--hillclimb-signin-variant` supports default, password, inbox, error, keyboard, and password-keyboard. It is honored only for HillclimbDemo.mode == .signin, which uses the isolated offline client. HillclimbRoot's existing allowsHitTesting(false) remains intact. No real authentication or credentials are involved.

The native inputs retain their accessibility identities. Their full 44pt rows focus the input when tapped in production. UI checks measure those focus containers and independently verify the native text/secure fields still exist. They do not claim activation of blocked fixture controls. Text checks compare actual accessibility frames against font-derived multiline bounds without extra font leading. Keyboard checks compare actual focused-field and keyboard rectangles.

## Commands

Run `bash scripts/hillclimb/setup.sh` in an isolated worktree, then use this common prefix:

```sh
xcodebuild test -project ios/LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders \
  -destination 'platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD' \
  -derivedDataPath /tmp/hillclimb-signin-dd -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

The unit selector is `-only-testing:LazyMansRemindersTests`. Dedicated UI selectors are:

```text
-only-testing:HillclimbUITests/SignInSurfaceUITests/testDefaultAndXXXLControlsAndTextInBothAppearances
-only-testing:HillclimbUITests/SignInSurfaceUITests/testPasswordInboxAndErrorWrapInBothAppearancesAndSizes
-only-testing:HillclimbUITests/SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances
```

The first baseline ran 247 tests successfully. First combined run ran 247 unit passes and three UI failures for native input text-height frames. Second UI run exposed an unsuitable combined accessibility wrapper; it was removed. Third combined run passed 247 units plus the keyboard test, with two text-estimate failures caused by added font leading. Summaries retain these failures rather than discarding them.

`capture.py` uses the exact device_open-pinned command and writes a SHA256 manifest. Its captures are verification on the assigned Auth device. Parent grading must capture again on original17.

## Remaining baseline and evidence limits

The unrelated existing HillclimbUITests failures are owned by worker A and were not edited or weakened here:

- testComposerKeyboardDismissTarget previously failed on the 22pt composer field before reaching dismissal.
- testTopControlsAvoidIslandAndHave44PointTargets previously failed on the 36pt Account control.
- testFullBoardBottomAboveComposerAfterPullAndScroll previously timed out waiting for idle before its final assertion.
- testXXXLTextFitsAllocatedHeightAtBottom previously passed bounds but did not establish final-line ink contrast.

Those baseline gates were not rerun in this sign-in-only worker. Offline read-only captures do not validate actual provider presentation, email delivery, password authentication, VoiceOver traversal, physical touch response, or success/error haptic quality. No exact Apple authentication reference exists. Normal production scrolling is retained; fixture hit-testing intentionally blocks gestures.

Written by gpt-6.1-sol in Codex on behalf of Edmund

A fourth UI attempt stalled in Xcode's scheme/package-loading operations before executing tests. It was interrupted with SIGINT then terminated with SIGTERM after cancellation failed to settle. It is not counted as a pass. The next attempt uses `-disableAutomaticPackageResolution -skipPackageUpdates` and streams test-case progress directly.

The direct `.xctestrun` execution in `/tmp/hillclimb-signin-final6.xcresult` completed with 250 passes and zero failures/skips. Initial screenshot inspection then exposed missing XXXL keyboard coverage: the password field was below the keyboard in the read-only fixture. The follow-up adds ScrollViewReader scrolling to the focused field on keyboardDidShowNotification and expands the keyboard check to default and XXXL in both appearances. Authentication requests and submit semantics remain unchanged. The screenshot matrix is regenerated after this fix.

The fifth attempt executed both text/layout matrices successfully but failed the keyboard Done-toolbar timing check, then stalled during Xcode finalization. It was canceled and terminated. The committed fixture now waits briefly for presentation and the test waits for the existing Done control rather than sampling it immediately.

## Final verification

Source commit `04098b7` built successfully with `xcodebuild build-for-testing` using the common project/scheme/destination/derived-data prefix, `-disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO`.

The final executed command was:

```sh
xcodebuild test-without-building \
  -xctestrun /tmp/hillclimb-signin-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun \
  -destination 'platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD' \
  -parallel-testing-enabled NO \
  -only-testing:LazyMansRemindersTests \
  -only-testing:HillclimbUITests/SignInSurfaceUITests/testDefaultAndXXXLControlsAndTextInBothAppearances \
  -only-testing:HillclimbUITests/SignInSurfaceUITests/testPasswordInboxAndErrorWrapInBothAppearancesAndSizes \
  -only-testing:HillclimbUITests/SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances \
  -resultBundlePath /tmp/hillclimb-signin-final7.xcresult
```

Result: TEST EXECUTE SUCCEEDED, exit 0. Exactly 250 tests passed (247 existing units plus three dedicated UI tests), zero failed, zero skipped. Keyboard matrix now covers both sizes. The result summary records one runtime warning, “Invalid frame dimension (negative or non-finite).” Its source was not localized; it remains an integration follow-up rather than being suppressed. The final JSON summary is checked in; the full xcresult remains at the path above.

The app was installed with simctl install from the same single derived-data folder, then all 24 captures were regenerated through the pinned agent-device command. No PR, push, merge, deployment, submission, other worker file, or parent score/state edit was performed.

Written by gpt-6.1-sol in Codex on behalf of Edmund

Final captures wait two seconds after each launch before taking the PNG, so keyboard presentation and focus scrolling have settled. Earlier immediate captures were replaced because they could catch animation in flight. Direct device_screenshot inspection confirmed the settled XXXL password field above the keyboard. The manifest hashes the final replacements and records the exact production-source hash.

Written by gpt-6.1-sol in Codex on behalf of Edmund
