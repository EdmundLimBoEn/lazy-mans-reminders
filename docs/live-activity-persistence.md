# Board persistence and November release checks

Target: release by **30 November 2026**. Persistence implementation updated 3 October; physical-device validation is still required.

## What research supports

- [Apple ActivityKit constraints](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities): an activity is active for at most eight hours. Its ended presentation can remain on the Lock Screen for up to four more hours. Extending `staleDate` does not extend that lifetime.
- [Apple background execution limits](https://developer.apple.com/forums/thread/685525): iOS suspends normal app execution. Background App Refresh is discretionary, with no guaranteed interval. Force-quitting expresses user intent to stop background launches. An accessibility permission cannot override these rules.
- [Apple push lifecycle](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications): push-to-start can launch an activity and give the app background runtime to receive/upload its update token. Token handling must work before a UI scene appears. APNs acceptance is not proof of display.
- [Mononote's developer listing](https://apps.apple.com/us/app/mononote-one-note/id6788222857) offers a Home Screen widget plus a Live Activity for urgent notes. Its public listing does not disclose a background keep-alive technique or guarantee unlimited Live Activity duration. We adopt the visible widget-plus-activity pattern, not an assumed private implementation.
- [Cheatsheet Notes](https://overdesigned.net/cheatsheet/) also uses Home Screen and Lock Screen widgets for persistent access to notes.

## Implementation

The server still attempts quiet updates every 15 minutes and replacement before the eight-hour limit, retaining the original until a replacement token arrives. The iOS app now owns registration at process launch instead of in `ContentView`. It registers with APNs on every launch, retains a device locator and pending token upload across termination, retries failures, and omits already-acknowledged activity tokens from later upserts. This prevents an old token from undoing server handoff state. A selected activity survives relaunch; newly discovered replacement activities take precedence over old ones. Local sync updates overlapping banners and leaves retirement to the server.

Background App Refresh requests an opportunity to sync after 30 minutes. iOS determines when, or whether, it runs. Work cancels on expiration. Home Screen small/medium widgets and existing Lock Screen accessories fetch with a valid shared session and keep cached content when offline or the session has expired. Credential renewal stays in the host app so a widget cannot rotate the SDK’s refresh token behind its back. Background refresh or opening the app renews the shared session. Widget timelines use one snapshot with a 30-minute refresh request instead of thousands of animation frames; this is a request, not a promised update cadence.

Transient session restoration failures preserve cached content. Failed server board reads never become a command to end activities. The account screen exposes permission state, the most recent successful push registration, a manual refresh, and widget setup instructions.

These fixes address reproducible code weaknesses. They do **not** prove which one caused the reported two-hour disappearance, and cannot guarantee delivery through iOS throttling, force-quit, offline periods, or disabled permissions. A widget has no ActivityKit eight-hour limit, but can show older cached content until iOS refreshes it.

## Deployment and investigation evidence

On 3 October the production scheduler was active at `*/15 * * * *`; its four most recent hourly responses were HTTP 200. The development registrations had a push-to-start token and a retiring token but no current activity update token, with the latest start at 14:15 UTC. That is consistent with a missing renewal acknowledgement, although it does not show whether the phone displayed a banner. The production registration had no Live Activity tokens; a signed-in launch of the new TestFlight build is necessary to register them.

The database-read protection was deployed to `send-reminder-push` on 3 October after confirming the deployed source matched the merged baseline. No database migration was needed for these changes. iOS additions require a new build.

## Device test checklist

Use a new signed build containing these changes; prior backend-only fixes did not include the new iOS lifecycle. Start with the development build for regression comparison, then repeat the soak test with TestFlight on stable iOS, detached from Xcode.

- [ ] Open once, sign in, allow Live Activities, and add a reminder. In Account → Keep Your Board Visible confirm a recent push registration. Add both a Home Screen Board widget and a Lock Screen accessory.
- [ ] **Normal background:** return to the Home Screen (do not swipe the app away), lock the phone, and check at 2h, 7–9h, 12h, and 24h. Reminders must remain in the widgets. Record whether a Live Activity remains or renews. Brief overlap can last until the next 15-minute server refresh.
- [ ] **Cold background launch:** after a normal launch, simulate process termination without the app-switcher force-quit flag, then trigger push-to-start in a controlled test. Verify the replacement update token reaches the server without opening any UI. Confirm updating and ending that replacement works.
- [ ] **Foreground during renewal:** open the app while both old and replacement banners exist. Neither should disappear because of arbitrary activity-list ordering; the server retires the old one after acknowledgement.
- [ ] **Remote edits:** while backgrounded, add/edit/complete reminders from the web. Check banner content and eventual widget refresh. Complete the last reminder during a handoff; both banners must end and stay ended.
- [ ] **Offline overnight:** enable Airplane Mode, leave the app closed overnight, then reconnect. Cached widgets should remain readable; registration should retry at the next execution opportunity. Opening offline must not erase the saved board. Record recovery time; do not claim a 15-minute guarantee.
- [ ] **Power/settings:** repeat with Low Power Mode and Background App Refresh off. Confirm the settings screen describes the limitation, widgets retain cached content, and enabling settings plus manual refresh recovers.
- [ ] **Force-quit separately:** swipe away the app, leave it overnight, then reopen. Do not use this as the ordinary-background acceptance test: iOS may suppress relaunch. Widgets should retain their last snapshot; reopening must restore sync.
- [ ] **Sign-out/account switch:** sign out and verify cached widgets and banners clear. Sign in to a second test account and verify no old board or activity token is attached to it.
- [ ] **Reboot:** reboot, unlock once, check cached widgets, then open the app and verify current content and registration.
- [ ] **Background expiration:** simulate BGAppRefresh launch/expiration on a Mac. The task must report completion exactly once, cancel work, and request the next opportunity. Confirm no excessive battery usage during a 48-hour run.

For each failure, record build number, iOS version, device model, last foreground time, disappearance time, network/power/settings state, whether the app was force-quit, whether the widget stayed visible, and whether recovery preceded reopening. Push registration time alone does not prove that a banner displayed.

## Release gates

- **By 31 October:** beta with this implementation, successful hosted iOS app/widget build and unit tests, stable signing/upload path, all targeted lifecycle cases exercised on a physical phone.
- **By 15 November:** at least seven consecutive days of TestFlight use, including two overnight runs without foregrounding, with no unexplained disappearing/duplicate boards or account data leaks. Investigate failures with device ActivityKit logs rather than adding keep-alive loops.
- **By 22 November:** release candidate; finish the existing sign-in, Siri, account deletion, widget layout/accessibility, privacy and App Store metadata checks in `HUMANS.md`. Describe Live Activities as best effort and widgets as the long-lived surface.
- **By 30 November:** submit/release only after the gates pass. App Review timing is external; submit before the deadline with time for review fixes.
