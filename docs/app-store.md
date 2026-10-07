# App Store Connect notes

Copy-paste source for the free **1.0** submission (target **27 Oct 2026**). App id `6799138197`. Do not paste secrets.

The iOS home-screen name is already **Lazy Man's Reminders** (`CFBundleDisplayName`). Do not change iOS code for this rename. App Store Connect still lists the app as **Lazy Mans Notepad**; that listing name (and any description that used it) must become **Lazy Man's Reminders** so they match (guideline 2.3.8).

Canonical listing copy is in this file. There are no Fastlane/`metadata/` trees in the repo.

## Name and subtitle

| Field | Value | Limit |
|-------|--------|--------|
| Name | `Lazy Man's Reminders` | 20 / 30 characters |
| Subtitle | `Lock Screen reminder board` | 26 / 30 characters |

Primary locale: `en-US`. Category: Productivity. Do not use “Notepad” on the product page.

## Description

Paste into the 1.0 version localization (`en-US`):

```
Lazy Man's Reminders is a small reminder board for your iPhone, the web, and the Lock Screen.

Add a few lines. They show up on Your Board, on Lock Screen and Home Screen widgets, and on a Lock Screen Live Activity that stays up while anything is still on the board. Complete every line and the Live Activity goes away.

Sign in with Apple, Google, or email so the same board syncs with https://lmr.sillyapps.co and with any agent you allow through MCP (Grok, Claude, Cursor, Codex).

On iOS 27, ask Siri to list reminders, add one, or mark one done in Lazy Man's Reminders.

Push banners are optional. If you turn notifications off, the in-app board still works.

Free. No in-app purchases. No subscriptions.

Privacy: https://lmr.sillyapps.co/privacy
Support: https://lmr.sillyapps.co/support
```

Keywords (100-character budget): `reminders,lock screen,live activity,todo,board,siri,widget`

Optional promotional text: `A reminder board that stays on the Lock Screen.`

What’s New (1.0): `First release of Lazy Man's Reminders.`

## Rename the ASC app (deploy bot)

`asc apps update` cannot change the listing name. It only patches bundle id, primary locale, and content rights.

Rename the app-info localization and set the privacy URL:

```sh
asc app-setup info set \
  --app 6799138197 \
  --locale en-US \
  --name "Lazy Man's Reminders" \
  --subtitle "Lock Screen reminder board" \
  --privacy-policy-url "https://lmr.sillyapps.co/privacy"
```

Update the 1.0 description and store URLs (version localization; no version id required):

```sh
asc apps info edit \
  --app 6799138197 \
  --version 1.0 \
  --platform IOS \
  --locale en-US \
  --description "Lazy Man's Reminders is a small reminder board for your iPhone, the web, and the Lock Screen.

Add a few lines. They show up on Your Board, on Lock Screen and Home Screen widgets, and on a Lock Screen Live Activity that stays up while anything is still on the board. Complete every line and the Live Activity goes away.

Sign in with Apple, Google, or email so the same board syncs with https://lmr.sillyapps.co and with any agent you allow through MCP (Grok, Claude, Cursor, Codex).

On iOS 27, ask Siri to list reminders, add one, or mark one done in Lazy Man's Reminders.

Push banners are optional. If you turn notifications off, the in-app board still works.

Free. No in-app purchases. No subscriptions.

Privacy: https://lmr.sillyapps.co/privacy
Support: https://lmr.sillyapps.co/support" \
  --keywords "reminders,lock screen,live activity,todo,board,siri,widget" \
  --support-url "https://lmr.sillyapps.co/support" \
  --marketing-url "https://lmr.sillyapps.co" \
  --whats-new "First release of Lazy Man's Reminders."
```

If `app-setup info set --name` is rejected (locked localization, state, or API rights), rename it by hand in App Store Connect → App Information → Name to **Lazy Man's Reminders**, then paste subtitle and description from this file. `asc` cannot rename via `apps update`.

Confirm with `asc localizations list --app 6799138197 --type app-info --locale en-US` and `asc apps info view --app 6799138197 --version 1.0 --platform IOS --locale en-US` before submit. Do not submit from these commands.

## URLs

Canonical host is `https://lmr.sillyapps.co`. `https://lmr.edmundlim.systems` 301s to it once that redirect is live.

- Privacy: `https://lmr.sillyapps.co/privacy`
- Support: `https://lmr.sillyapps.co/support`
- Marketing: `https://lmr.sillyapps.co`
- Terms (optional field): `https://lmr.sillyapps.co/terms`

## Availability, pricing, EU DSA

- Price: **Free**. No in-app purchases. No subscriptions.
- Territories: **all**, including new territories as Apple adds them.
- Content rights: does not use third-party content (`DOES_NOT_USE_THIRD_PARTY_CONTENT`). Reminder text is the signed-in user’s own.

**Digital Services Act (EU).** Edmund is an **individual** (natural person / sole operator), not a company. In App Store Connect → Business → Digital Services Act, complete trader status as an individual. Use his legal name, `hello@edmundlim.systems`, and the address/phone Apple asks for. Do not invent a company name, trade register, or VAT number. That contact block appears on the EU product page.

## Age rating

Age 4+. The app stores user-written reminder text. It is not a kids app, has no unrestricted web browsing, no gambling, no violence, and no user-generated public feed.

## Export compliance

`ITSAppUsesNonExemptEncryption` is false. The app uses HTTPS only. Answer No to proprietary encryption questions unless Apple’s questionnaire changes.

## App Privacy (nutrition labels)

Answers must match `ios/Shared/PrivacyInfo.xcprivacy`.

Tracking: **No**. `NSPrivacyTracking` is false. `NSPrivacyTrackingDomains` is empty. Data is not used to track you and is not used for third-party advertising.

Declare as **collected**, **linked to the user**, **not used for tracking**, purpose **App Functionality** only:

| Type | PrivacyInfo key | Why | Notes |
|------|-----------------|-----|--------|
| Email Address | `NSPrivacyCollectedDataTypeEmailAddress` | Account sign-in | Magic link, Sign in with Apple, or Google |
| User ID | `NSPrivacyCollectedDataTypeUserID` | Account | Supabase user id |
| User Content | `NSPrivacyCollectedDataTypeUserContent` | Reminders | Text on the board, widgets, and Live Activity |
| Device ID | `NSPrivacyCollectedDataTypeDeviceID` | Push | APNs device / Live Activity tokens, iOS only |

Do not declare Name, Phone Number, Product Interaction, Advertising Data, Precise Location, Purchases, Crash Data, or other diagnostic types. The app does not include a tracking SDK.

The manifest also lists `NSPrivacyAccessedAPICategoryUserDefaults` reason `1C8F.1`. That is an accessed-API reason, not a nutrition-label data type. Do not add it as collected data.

## Review notes

Sign-in is **required**. There is no useful unsigned-in board: lines sync with the web board, Live Activity start/update/end and reminder push are server-driven (APNs device token, push-to-start, and activity tokens), and MCP agents act only as the signed-in user.

Reviewers can tap **Sign in with Apple** on the Sign In screen to create an account. Sign in with Apple is also required because Google is offered (guideline 4.8). Both buttons are on that screen.

Paste into App Review Information (`demoAccountRequired` stays false until a demo account exists):

```
Sign-in is required. There is no guest board. The same reminders sync with the web board at https://lmr.sillyapps.co, the Lock Screen Live Activity is started and renewed from our server over APNs, and MCP agents (Grok, Claude, Cursor, Codex) can only use a signed-in account.

Please create an account with Sign in with Apple on the Sign In screen. Google and magic-link email also work.

Demo account: none yet.
Username:
Password:

The Lock Screen Live Activity is the board, not a one-shot event. It stays on screen while any reminder is active. The server refreshes it about every 15 minutes and replaces it before Apple's eight-hour cap, so a non-empty board can remain visible with the app closed. That is intended.

To end the Live Activity: complete or delete every reminder until Your Board shows All Clear. The banner dismisses immediately. Swiping it away is not the supported end path; an active board will be renewed.

Push notification permission is optional. If you deny the prompt, the in-app board, widgets, Siri, and account still work. Account → Notifications shows Off and a Settings link. Live Activities are a separate Settings toggle.

Siri (iOS 27, signed in):
- “Hey Siri, list reminders in Lazy Man's Reminders”
- “Hey Siri, add a reminder in Lazy Man's Reminders”
- “Hey Siri, remind me to buy milk in Lazy Man's Reminders”
- With the board on screen: “Hey Siri, mark this as done”
- “Hey Siri, complete milk in Lazy Man's Reminders”
Unsigned-in, Siri asks you to sign in on this iPhone.

Account (person icon) → Delete Account removes reminders, device tokens, lock-screen prefs, agent access, and the sign-in. Data export is Download my data on the signed-in web board.

No IAP. Contact hello@edmundlim.systems.
```

Continue with Grok and Continue with ChatGPT are off in shipped builds (`GROK_SIGN_IN_ENABLED = NO`, `CHATGPT_SIGN_IN_ENABLED = NO`). Before a build turns either on, name it in the Email Address row and the demo line above, and keep Sign in with Apple first and at least as large.

## Screenshots

Required set: **6.9" iPhone** (`APP_IPHONE_69`). Capture on an iPhone 16 Pro Max, 17 Pro Max, or iPhone Air after TestFlight smoke. Portrait sizes Apple accepts include **1320 × 2868** and **1260 × 2736**.

This is an **iPhone-only** app (`TARGETED_DEVICE_FAMILY` is `1`). Do **not** upload iPad screenshots.

Guideline 2.3.3: the set must show the app **in use**. Do not submit a login-only set. Do not put the Sign In screen in the 6.9" set. Do not add device frames.

This repo does not store screenshot PNGs.

### Shot list (5–6)

| # | Capture | Caption |
|---|---------|---------|
| 1 | **Your Board** with several live reminder lines and the bottom composer | Your board. That's it. |
| 2 | Completing a line (filled circle or leading swipe Complete) | Tap or swipe to complete. |
| 3 | Lock Screen **Live Activity** showing the same lines | The board stays on the Lock Screen. |
| 4 | Lock Screen **Board** widget (accessory rectangular) | The same lines on the Lock Screen widget. |
| 5 | Home Screen **Board** widget | Glance the board from Home Screen. |
| 6 | **Account** sheet (Notifications On or Off is fine) | Push is optional. The board still works. |

Skip Sign In. Use real reminder text, not lorem ipsum or “test”.

## Preflight (read only)

```sh
./scripts/asc-preflight.sh
```

Runs `asc validate --app 6799138197 --version 1.0` plus read-only checks (build attached, 6.9" screenshots present, review details set, pricing set). Prints a pass/fail list. **Never submits.**

## Human steps still required

See **App Store submission (target 27 Oct 2026)** in `HUMANS.md`. A reviewer still needs a signed TestFlight build, device smoke, screenshots, the ASC fields above, and the Submit button in App Store Connect.

TestFlight binaries come from `.github/workflows/ios-testflight.yml` (stable Xcode). Jeremy owns the GitHub secrets named in that file and in HUMANS.md. Do not put those values in this repo.
