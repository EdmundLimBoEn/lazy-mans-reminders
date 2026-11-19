# notepads.dev landing page

`landing/` contains the static Notepad site served at <https://notepads.dev> by Cloudflare Pages project **`notepads-landing`**.

The **Open app** links point to <https://app.notepads.dev>. The App Store badge/button links to the released iOS app at <https://apps.apple.com/app/id6799138197>.

The final footer copy is exactly `Notepad by edmund at sillyapps.co`.

## Operator reference

Production deploys are done by **jeremy after Edmund explicitly OKs them**. Run the existing command from the repository root for an authorized deployment:

```sh
npx wrangler pages deploy landing --project-name notepads-landing --branch main
```

The Pages project already exists; project creation and domain attachment are not contributor setup steps. Do not deploy as part of this documentation work.
