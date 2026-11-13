# Alternate icon review

The comparison columns are **Default / Minimal / Bold**, left to right. In the
Home Screen illustrations these occupy the middle row; the other rows are grey
placeholder apps. The size chart rows are **180 / 120 / 87 / 58 / 40 px**, top to
bottom. Images deliberately have no new product copy. These are illustrative
wallpapers and approximate squircle masks, not iOS screenshots.

- [Light wallpaper](preview-home-light.png)
- [Dark wallpaper](preview-home-dark.png)
- [Size comparison](preview-sizes.png)

The shipped default is preserved byte for byte. Both alternatives derive from
its rounded page geometry and sampled cream background (`#ECE5D8`). Minimal
uses the original taupe (`#5C544A`), a 30 px border and one 30 px rule. Bold uses
slightly darker taupe (`#4A443C`), a 48 px border and four 42 px rules — three
times the original 16/14 px strokes. Both enlarge the page from 500 × 640 to
564 × 712 px. Artwork is drawn at 4× resolution and downsampled with Lanczos.
The 1024 × 1024 app icons are RGB PNGs without alpha or baked-in outer masks.

Regenerate from the repository root with Python 3 and Pillow:

```sh
python3 -m pip install -r scripts/icons/requirements.txt
python3 -B scripts/icons/generate_alternate_icons.py
python3 -B scripts/icons/render_previews.py
```

The first command that runs a script also regenerates the regular 48 pt preview
imagesets at 1×, 2× and 3×. Settings loads those resources, since app icon assets
are not ordinary UIImage resources. No input from `/workspace/notepad-icons`
is needed to reproduce the output; those earlier explorations were reference
only.

The Account settings sheet has three thumbnail selection rows, ordered as above.
Every new app-authored label, accessibility label and status message uses
`[PLACEHOLDER - Edmund to write]`. Edmund must supply distinct accessible labels,
the section heading, and unsupported/error/busy copy before release.

`AppIconSelection` reads the current selection from UIKit on appearance, on
foregrounding, and after a change completes. It disables unsupported/busy
choices, ignores repeat requests, and permits retry after a failed change.
Unknown system icon names leave all rows unselected. State is isolated to the
main actor; there is no separate persisted preference to get out of sync.
`AppIconOptionTests` covers the mappings, bundled previews, default restoration,
unsupported devices, failures/retry, refresh and overlapping requests.

XcodeGen settings are confined to the app target. Xcode should generate the
`CFBundleAlternateIcons` entries during asset compilation, as described in
[Apple's icon API documentation](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)).
No manual icon keys are added to the source Info.plist.

On a Mac, regenerate `ios/project.yml` with XcodeGen and run the existing
`LazyMansRemindersTests` target, including `AppIconOptionTests`. Check the built
app's Info.plist for `AppIcon-Minimal` and `AppIcon-Bold`; confirm the widget still
builds. On an iPhone, switch through all three choices, return to Default, reopen
Settings, and relaunch the app. Confirm the selected checkmark matches the Home
Screen and check VoiceOver/Larger Text. The system may display its own icon-change
confirmation. Native compilation, asset compilation and device behavior cannot
be verified on this Linux host.
