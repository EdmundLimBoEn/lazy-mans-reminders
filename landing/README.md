# notepads.dev landing

Static page. Copy is verbatim from the sillyapps.co Notepad entry, with final footer copy supplied by Edmund. The App Store button links to the released iOS app.

Not deployed yet. Deploy (after Edmund OKs), from repo root:

```sh
npx wrangler pages project create notepads-landing --production-branch main   # first time only
npx wrangler pages deploy landing --project-name notepads-landing --branch main
```

Then attach `notepads.dev` (and optionally `www.notepads.dev`) as a custom domain on the `notepads-landing` Pages project in the dashboard.
