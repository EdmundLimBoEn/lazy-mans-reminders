# App Store Connect notes

Reference for the free 1.0 submission. Fill these fields in App Store Connect. Do not paste secrets.

## URLs

- Privacy: `https://lmr.edmundlim.systems/privacy`
- Support: `https://lmr.edmundlim.systems/support`
- Marketing / Support site: `https://lmr.edmundlim.systems`
- Terms (optional field): `https://lmr.edmundlim.systems/terms`

## Pricing

Price: Free. No in-app purchases. No subscriptions.

## Age rating

Age 4+. The app stores user-written reminder text. It is not a kids app, has no unrestricted web browsing, no gambling, no violence, and no user-generated public feed.

## Export compliance

`ITSAppUsesNonExemptEncryption` is false. The app uses HTTPS only. Answer No to proprietary encryption questions unless Apple’s questionnaire changes.

## Privacy nutrition labels (App Privacy)

Tracking: No.

Data not used to track you. Data not used for third-party advertising.

Declare as collected, linked to the user, used for App Functionality:

| Type | Why | Notes |
|------|-----|--------|
| Email Address | Account sign-in | Magic link, Apple, or Google |
| User ID | Account | Supabase user id |
| User Content | Reminders | Text on the board, widget, and Live Activity |
| Device ID | Push | APNs token, iOS only |

Do not declare Product Interaction, Advertising Data, or Precise Location. The app does not include a tracking SDK.

## Review notes

Paste into App Review Information:

```
Demo: create an account with Sign in with Apple, Google, or a magic-link email.
The board holds a small number of reminder lines (matched to the Lock Screen Live Activity).
Tap a circle to complete a line. The Lock Screen Live Activity starts from the reminder notification and stays until the board is empty.
Push: add a reminder from the web board at https://lmr.edmundlim.systems while the iPhone has notifications and Live Activities allowed.
Account deletion: More (ellipsis) → Delete Account. Also on the signed-in web board.
Data export: signed-in web board → Download my data.
No IAP. Contact hello@edmundlim.systems.
```

Sign-in with Apple is required because Google is offered (guideline 4.8). Both buttons are on the sign-in screen.

## Screenshots

Need 6.7" and 6.1" (and any other sizes Apple requires at submit time). Capture on a physical device after TestFlight smoke. This repo does not store screenshot PNGs.

## Human steps still required

See HUMANS.md. A reviewer still needs a signed TestFlight build, device smoke, and the Submit button in App Store Connect.
