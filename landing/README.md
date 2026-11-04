# notepads.dev landing

Static page. Copy is verbatim from the sillyapps.co Notepad entry; text starting with `Placeholder:` (App Store button, footer) is temporary and should be replaced with final copy. The App Store button is a non-link until the app is live.

Not deployed yet. Deploy (after Edmund OKs), from repo root:

```sh
npx wrangler pages project create notepads-landing --production-branch main   # first time only
npx wrangler pages deploy landing --project-name notepads-landing --branch main
```

Then attach `notepads.dev` (and optionally `www.notepads.dev`) as a custom domain on the `notepads-landing` Pages project in the dashboard.
