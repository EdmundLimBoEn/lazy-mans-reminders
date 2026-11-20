# Notepad for Mac

Notepad runs in the menu bar on macOS 14 and later. It opens the same board as
the iPhone and [web app](https://app.notepads.dev). Sign in with Apple, Google,
an email code, or an existing password. Add and complete up to 16 active
reminders. The board refreshes when opened and every 30 seconds while open.
Opening it also requests the shared best-effort cleanup of reminders completed
more than three days ago. The account link opens the web board’s deletion
controls. The popover includes keyboard and VoiceOver controls.

`NotepadMac` uses `PRODUCT_BUNDLE_IDENTIFIER` from the same local
`ios/Config.xcconfig` as the iPhone app. App Store Connect uses that shared ID
to add macOS to the existing record for universal purchase. The shared
`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` supply both platforms’
versions. The release PR sets the marketing version to 1.0.2.

The sandbox allows outbound networking and the build enables hardened
runtime. Supabase stores the session in the macOS Keychain under a Mac-specific
service. It uses no shared access group because neither the iPhone app nor a
Mac extension needs to read those credentials. The Mac privacy manifest
covers account details, reminder text, service diagnostics, and app-only
UserDefaults access.

## Before submission

- Add macOS to the existing Notepad record in App Store Connect and fill in the
  Mac listing and review details.
- Provision the shared bundle ID for Mac App Store distribution with Sign in
  with Apple enabled. Set up a signed Mac archive and upload workflow.
- Have Edmund test a signed sandboxed build on a Mac. Verify all four sign-in
  methods, Keychain restoration across relaunch, sign-out and account revocation,
  board sync, the 16-item cap, VoiceOver and shortcuts, and the web deletion link
  including the manual Apple access removal instructions when shown.
  Check that Supabase accepts Apple credentials from the signed build, allows the
  existing `lazymansreminders://auth/callback` redirect for Google, and sends
  email codes via the template’s `{{ .Token }}`.

The `mac` job in `ios-tests.yml` builds Debug and universal Release, runs the
Mac unit tests, and uploads board, dark board, signed-out, and full-board
screenshots as `notepad-mac-screenshots`. Debug snapshots run with
`-demo -snapshot /absolute/path.png` and use local sample reminders.
