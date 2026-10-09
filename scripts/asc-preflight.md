# Read-only submission preflight

Run `./scripts/asc-preflight.sh`. This now uses Apple's documented JSON:API GET
endpoints directly, not guessed `asc` commands. `asc` is absent on the Linux
validation host. Python 3 and a short-lived, authorized App Store Connect JWT
provided through `ASC_API_TOKEN` are required for live checks. Generate/inject the
JWT through your existing secure operator workflow; never paste it in command
arguments, commit it, or include it in logs. No JWT generation or ASC mutation is
performed here. Without a token or offline responses, checks fail closed.

Environment defaults: `ASC_APP_ID=6799138197`, `ASC_VERSION=1.0`,
`ASC_PLATFORM=IOS`. Other platforms are explicitly unsupported. If Apple returns
multiple app-information records, set `ASC_APP_INFO_ID` to the intended current
editable record after inspecting ASC; the checker never picks the first record.
The caller must select the current record even when only one is returned.

For offline evaluation:

```sh
./scripts/asc-preflight.sh --evidence scripts/tests/fixtures/asc-synthetic.json
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/asc-preflight.sh
```

The fixture contains synthetic contacts and unusable demo-account placeholders,
not a real reviewer identity. Its URLs intentionally use `example.invalid`.
It is not evidence about the production app. Offline files are a JSON object
mapping exact `/v1/...` and `/v3/appPricePoints/...` GET paths (including query
parameters and pagination) to original Apple
response envelopes. Use the fixture as a shape example. Keep real responses in
private temporary storage: review-detail responses can contain credentials.
Snapshots do not prove freshness, URL availability or current ASC state.

`PASS` means only the specifically named evidence check passed. `FAIL` means
missing, malformed, contradictory or incomplete evidence. `UNKNOWN` identifies
unsupported checks/human prerequisites. Both FAIL and UNKNOWN return exit 1,
including the complete synthetic fixture. There is deliberately no override or
attestation file that turns unchecked human prerequisites green. Do not use
this report as a submission or deployment command.

Checks resolve exactly one matching app-scoped version with explicit platform;
verify the attached build's app/pre-release version, VALID processing state and
APP_STORE_ELIGIBLE audience; inspect each returned localization, actual screenshot
resources and COMPLETE delivery; inspect required review contacts and conditional
demo credentials without printing their values; and require app names, privacy
URLs and typed current age-rating answers. Non-exempt encryption requires an
APPROVED declaration attached to the chosen build. An explicitly false
usesNonExemptEncryption is evidence of the recorded answer, not a legal conclusion.
TestFlight expiration concerns testing, so it is not used to reject a VALID App
Store build. TestFlight approval never counts as App Store approval.

Pricing evidence is fetched independently using the app-scoped
`GET /v1/apps/{id}/appPriceSchedule?include=app,baseTerritory`, then the schedule's
`manualPrices` GET collection filtered to its base territory. Pagination must
stay on that schedule and preserve the territory filter. Each price needs typed
manual/date/territory/price-point evidence; exactly one currently applicable
base-territory row is required. Its linked
`GET /v3/appPricePoints/{id}?include=app,territory` must match the selected point,
app and territory and expose a nonnegative decimal-string `customerPrice`.
Opaque point IDs are URL-encoded, never decoded to infer a price. The expected
base price for this app is free: decimal zero passes; a nonzero price fails.
Missing/null/404/malformed schedule, price or point responses fail. Zero
`proceeds`, an object ID, availability or an unrelated included object never
establishes a free customer price.

Price intervals require explicit start/end fields: null represents an unbounded
endpoint; non-null values must be ISO calendar dates. Every returned start/end
transition dated yesterday, today or tomorrow relative to the UTC check date
fails conservatively before selecting a price. A calendar date alone cannot
establish which price is live near a transition: Apple's country/region start
times may fall on an adjacent UTC date and adjust for US daylight saving time.
For example, a next-date Singapore free-to-paid transition can already be live
while the UTC date still precedes the scheduled date. The ±1-day guard deliberately
requires human verification instead of implementing a guessed storefront timezone
table. A zero-price interval away from all returned transition dates, including
an explicitly unbounded interval, can pass the narrow base-price evidence check.
This guard is not a guarantee of live storefront propagation: Apple notes that
changes can take up to 24 hours to display, and snapshots may be stale.
Future-only, past-only or overlapping current prices cannot pass. This does not
certify prices on the future submission/release date, manual territory overrides,
automatic equalization or distribution availability: those remain UNKNOWN and
require review in ASC. Offline snapshots do not prove live freshness.

Screenshot set IDs never count as files. At least one delivered screenshot and
no more than ten per returned set are required; dimensions and file sizes must be
positive. A separate size-evidence check requires a documented iPhone API enum
and portrait/landscape dimensions from the current medium, large or 6.5-inch
fallback groups: 1179×2556, 1206×2622, 1320×2868, 1290×2796, 1260×2736,
1284×2778 or 1242×2688. It does not infer a group from the numeric suffix.
This is asset-delivery/dimension evidence, not completeness for every supported
device, approved content, opacity or localization scaling. Empty optional sets
are conservatively flagged for inspection/removal. Required size/display-type
coverage remains UNKNOWN because Apple's current Help display naming and the
published API enum are not a verified one-to-one mapping. No undocumented
APP_IPHONE_69 constant is treated as proof of required coverage.

Live privacy/support URLs on this app's known hosts (`lmr.sillyapps.co`,
`lmr.edmundlim.systems`, `lazy-mans-reminders.pages.dev`) receive unauthenticated
HTTPS GET probes with a Mozilla user agent. HTTP 200 nonempty HTML is only HTTP
availability evidence, not a rendered policy/content review. Access challenges,
rate limits, redirects, server/network/TLS failures and other hosts remain UNKNOWN;
404/client missing-page errors fail. Redirects are refused; API authorization is
never attached to public requests. Offline runs do not probe URLs. Public
rendering, policy accuracy and support usability still require browser review.

Before submitting, a human must verify the selected archive's stable Xcode and
SDK, current required screenshot dimensions/device families/scaling/content,
reviewer sign-in and backend availability, published privacy labels (including
third parties), completion and accuracy of the current age questionnaire,
pricing AND territory availability, agreements, category/content rights and
applicable trader/regional declarations. The Linux host cannot run Xcode or
physical iPhone QA; no macOS build host/device was discovered for this change.

## Apple sources checked on 2026-10-09

- [Current SDK minimum](https://developer.apple.com/news/?id=ueeok6yw):
  iOS/iPadOS 26 SDK or later for uploads since April 28, 2026. Build minOsVersion
  is deployment compatibility, not SDK version. API SDK build identifiers do not
  establish stable Xcode or the semantic SDK version.
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications):
  current required iPhone Dynamic Island medium and iPad 13-inch if supported;
  review the documented scaling fallbacks rather than assuming a 6.9-inch ID.
- [ScreenshotDisplayType API enum](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype):
  documented iPhone types include 67, 65, 61, 58, 55, 47, 40 and 35;
  no documented 69/63 or authoritative suffix-to-current-display-group mapping.
- [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
  particularly 2.1: provide working reviewer access or approved alternatives.
- [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/):
  privacy-policy URL and privacy disclosures are separate requirements.
- [Age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/):
  answer the current questionnaire; don't assume the old 4+ label proves completion.
- [Encryption](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
- [Set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
  and [AppPriceSchedule API](https://developer.apple.com/documentation/appstoreconnectapi/apppriceschedule):
  pricing must be set before review; a base-territory price does not certify all
  storefront overrides. Apple's OpenAPI defines AppPriceSchedule relationships,
  AppPriceV2 interval/manual fields, AppPricePointV3 customerPrice and app/territory
  linkage, and the exact GET endpoints/filter/include parameters used here.
- [Pricing and availability start times by country or region](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-store-pricing-and-availability-start-times-by-country-or-region/):
  effective times vary by storefront/date and US daylight saving observance;
  late changes may take up to 24 hours to display. The interactive table's exact
  times are not inferred or reproduced by this preflight.
- [Apple OpenAPI specification](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip):
  fixture endpoint paths, resource types and attribute names verified against
  Apple's downloaded schema. Includes audience, processing, asset-delivery,
  review, age-rating and encryption states; no CLI output compatibility assumed.

Requirements evolve. Review these sources again before the actual submission.
