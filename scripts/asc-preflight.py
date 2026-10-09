#!/usr/bin/env python3
"""Conservative evidence checks against Apple's App Store Connect JSON:API."""
import argparse
import json
import os
import re
import sys
from urllib.parse import urlsplit
from urllib.error import HTTPError
from urllib.request import Request, build_opener, HTTPRedirectHandler

BASE = "https://api.appstoreconnect.apple.com"
PUBLIC_HOSTS = {"lmr.sillyapps.co", "lmr.edmundlim.systems", "lazy-mans-reminders.pages.dev"}
IPHONE_DISPLAY_TYPES = {"APP_IPHONE_67", "APP_IPHONE_65", "APP_IPHONE_61", "APP_IPHONE_58", "APP_IPHONE_55", "APP_IPHONE_47", "APP_IPHONE_40", "APP_IPHONE_35"}
# Apple Help dimensions; API suffixes do not establish a display-group mapping.
IPHONE_CURRENT_SIZES = {(1179, 2556), (1206, 2622), (1284, 2778), (1242, 2688), (1320, 2868), (1290, 2796), (1260, 2736)}


def public_url(value):
    if not url(value):
        return "FAIL", "missing or invalid public URL"
    p = urlsplit(value)
    if p.scheme != "https" or p.hostname not in PUBLIC_HOSTS or p.port not in (None, 443):
        return "UNKNOWN", "public URL host/scheme outside this app's HTTPS probe allowlist; check manually"
    try:
        req = Request(value, headers={"User-Agent": "Mozilla/5.0 (compatible; LMR-ReadOnly-Preflight)", "Accept": "text/html"}, method="GET")
        with build_opener(NoRedirect()).open(req, timeout=15) as response:
            body = response.read(65536).lower()
            if response.status != 200:
                return "UNKNOWN", "unexpected HTTP response; check manually"
            if any(marker in body for marker in (b"cf-chl-", b"challenge-platform", b"just a moment", b"verify you are human")):
                return "UNKNOWN", "possible browser challenge; HTTP probe cannot verify page"
            if "text/html" not in response.headers.get("Content-Type", "") or not body.strip():
                return "FAIL", "public URL did not return nonempty HTML"
            return "PASS", "HTTP 200 HTML only; rendered page, policy text and support usability unverified"
    except HTTPError as exc:
        if exc.code in (401, 403, 429) or 300 <= exc.code < 400 or exc.code >= 500:
            return "UNKNOWN", "HTTP access/challenge/redirect/server failure; inspect in browser"
        return "FAIL", "public page HTTP error (response content withheld)"
    except Exception:
        return "UNKNOWN", "network/TLS/redirect failure; rendered public page unverified"


class MissingEvidence(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise MissingEvidence("redirect refused")


class Evidence:
    def __init__(self, responses=None, token=None):
        self.responses = responses
        self.token = token

    def get(self, path):
        parsed = urlsplit(path)
        if parsed.scheme or parsed.netloc:
            if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com":
                raise MissingEvidence("untrusted pagination URL")
            path = parsed.path + ("?" + parsed.query if parsed.query else "")
        if not path.startswith("/v1/") or "#" in path:
            raise MissingEvidence("unsupported API path")
        try:
            if self.responses is not None:
                obj = self.responses[path]
            else:
                if not self.token:
                    raise MissingEvidence("no API token or offline evidence")
                req = Request(BASE + path, headers={"Authorization": "Bearer " + self.token}, method="GET")
                with build_opener(NoRedirect()).open(req, timeout=20) as response:
                    obj = json.load(response)
            if not isinstance(obj, dict) or "data" not in obj or obj.get("errors"):
                raise MissingEvidence("invalid API response")
            return obj
        except MissingEvidence:
            raise
        except Exception:
            # API payloads, errors and exception text may contain secrets.
            raise MissingEvidence("API evidence unavailable or malformed") from None

    def one(self, path, kind):
        item = self.get(path)["data"]
        return resource(item, kind)

    def many(self, path, kind):
        items, seen, total = [], set(), None
        while path:
            if path in seen or len(seen) >= 100:
                raise MissingEvidence("pagination incomplete")
            seen.add(path)
            obj = self.get(path)
            if not isinstance(obj["data"], list):
                raise MissingEvidence("expected collection")
            items.extend(resource(item, kind) for item in obj["data"])
            links = obj.get("links")
            if not isinstance(links, dict) or not present(links.get("self")):
                raise MissingEvidence("invalid pagination")
            if "meta" in obj:
                paging = obj["meta"].get("paging", {})
                page_total = paging.get("total")
                if type(page_total) is not int or page_total < 0 or (total is not None and total != page_total):
                    raise MissingEvidence("invalid or changing collection total")
                total = page_total
            path = links.get("next")
            if path is not None and not isinstance(path, str):
                raise MissingEvidence("invalid pagination")
        if len({item["id"] for item in items}) != len(items):
            raise MissingEvidence("duplicate collection resources")
        if total is not None and total != len(items):
            raise MissingEvidence("collection total indicates missing pages")
        return items


def resource(item, kind):
    if (not isinstance(item, dict) or item.get("type") != kind
            or not isinstance(item.get("id"), str)
            or not re.fullmatch(r"[A-Za-z0-9-]+", item["id"])
            or not isinstance(item.get("attributes"), dict)):
        raise MissingEvidence("missing typed resource attributes")
    return item


def present(value):
    return isinstance(value, str) and bool(value.strip())


def url(value):
    if not present(value):
        return False
    p = urlsplit(value)
    return p.scheme in ("http", "https") and bool(p.hostname) and not p.username and not p.password


class Preflight:
    def __init__(self, evidence, app, version, platform, info_id=None):
        self.api, self.app, self.version, self.platform = evidence, app, version, platform
        self.info_id = info_id
        self.results = []

    def record(self, name, ok, detail):
        self.results.append(("PASS" if ok else "FAIL", name, detail))

    def check(self, name, action):
        try:
            action()
        except MissingEvidence as exc:
            self.record(name, False, str(exc))
        except Exception:
            self.record(name, False, "malformed evidence; no response content printed")

    def public_check(self, name, value):
        if self.api.responses is not None:
            self.results.append(("UNKNOWN", name, "offline snapshot; public URL HTTP/rendered content not fetched"))
        else:
            status, detail = public_url(value)
            self.results.append((status, name, detail))

    def run(self):
        self.check("version scope", self.version_checks)
        self.check("app information", self.app_checks)
        for name, detail in [
            ("toolchain and SDK", "verify attached archive used stable Xcode and iOS 26 SDK or later; API SDK build IDs/minOsVersion do not prove this"),
            ("screenshot completeness", "verify current required device sizes, supported device families, localization scaling and screenshot content in ASC; delivered assets alone are insufficient"),
            ("reviewer access", "exercise sign-in with the submitted build; confirm valid demo account or Apple-approved access alternative, backend availability and instructions"),
            ("privacy labels", "verify published App Privacy answers match app and third-party behavior; privacy URL and bundled manifest are insufficient"),
            ("age rating completion", "confirm current questionnaire and calculated regional ratings in ASC; answer presence alone does not prove completion"),
            ("distribution prerequisites", "confirm pricing AND territory availability, agreements, content rights, category and applicable trader/compliance declarations in ASC"),
            ("device QA", "signed build, physical iPhone QA and Xcode validation remain human prerequisites"),
        ]:
            self.results.append(("UNKNOWN", name, detail))
        return self.results

    def version_checks(self):
        versions = self.api.many(f"/v1/apps/{self.app}/appStoreVersions", "appStoreVersions")
        matches = [v for v in versions if v["attributes"].get("versionString") == self.version
                   and v["attributes"].get("platform") == self.platform]
        if len(matches) != 1:
            raise MissingEvidence("need exactly one version with explicit matching versionString and platform")
        v = matches[0]
        self.record("version scope", True, "exact version/platform on app-scoped endpoint")
        self.record("version copyright", present(v["attributes"].get("copyright")), "copyright must be set")
        vid = v["id"]
        self.check("attached build", lambda: self.build_checks(vid))
        self.check("version localizations", lambda: self.localization_checks(vid))
        self.check("review information", lambda: self.review_checks(vid))

    def build_checks(self, vid):
        b = self.api.one(f"/v1/appStoreVersions/{vid}/build", "builds")
        bid, a = b["id"], b["attributes"]
        app = self.api.one(f"/v1/builds/{bid}/app", "apps")
        pre = self.api.one(f"/v1/builds/{bid}/preReleaseVersion", "preReleaseVersions")["attributes"]
        if app["id"] != self.app or pre.get("version") != self.version or pre.get("platform") != self.platform:
            raise MissingEvidence("attached build app/version/platform mismatch")
        self.record("attached build scope", True, "attached build matches app and pre-release version/platform")
        self.record("build processing", a.get("processingState") == "VALID", "processingState must be VALID")
        self.record("App Store build eligibility", a.get("buildAudienceType") == "APP_STORE_ELIGIBLE", "INTERNAL_ONLY or absent audience is not sufficient; TestFlight approval is not App Store approval")
        # TestFlight's expired flag concerns testing; it is not an App Store validity gate.
        self.record("build number", present(a.get("version")), "build version must be present")
        encryption = a.get("usesNonExemptEncryption")
        if encryption is False:
            self.record("encryption declaration", True, "attached build explicitly declares no non-exempt encryption; verify legal accuracy")
        elif encryption is True:
            declaration = self.api.one(f"/v1/builds/{bid}/appEncryptionDeclaration", "appEncryptionDeclarations")
            self.record("encryption declaration", declaration["attributes"].get("appEncryptionDeclarationState") == "APPROVED", "attached non-exempt declaration must be APPROVED; existence is insufficient")
        else:
            raise MissingEvidence("encryption answer missing on attached build")

    def localization_checks(self, vid):
        locs = self.api.many(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations", "appStoreVersionLocalizations")
        if not locs:
            raise MissingEvidence("no version localizations")
        locales = [loc["attributes"].get("locale") for loc in locs]
        if not all(present(locale) for locale in locales) or len(set(locales)) != len(locales):
            raise MissingEvidence("missing or duplicate localization locales")
        for index, loc in enumerate(locs, 1):
            a = loc["attributes"]
            self.record(f"listing metadata {index}", all(present(a.get(k)) for k in ("description", "keywords")) and url(a.get("supportUrl")), "description, keywords and support URL required; content and URL availability need review")
            self.public_check(f"support URL HTTP {index}", a.get("supportUrl"))
            self.check(f"delivered screenshots {index}", lambda loc=loc, index=index: self.screenshots(loc["id"], index))

    def screenshots(self, lid, index):
        sets = self.api.many(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets", "appScreenshotSets")
        count = 0
        size_evidence = False
        valid = bool(sets)
        for screenshot_set in sets:
            shots = self.api.many(f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots", "appScreenshots")
            valid = valid and present(screenshot_set["attributes"].get("screenshotDisplayType")) and 1 <= len(shots) <= 10
            count += len(shots)
            for shot in shots:
                a = shot["attributes"]
                image, delivery = a.get("imageAsset"), a.get("assetDeliveryState")
                valid = valid and isinstance(image, dict) and isinstance(delivery, dict)
                if not isinstance(image, dict) or not isinstance(delivery, dict):
                    continue
                valid = valid and delivery.get("state") == "COMPLETE" and not delivery.get("errors")
                valid = valid and type(a.get("fileSize")) is int and a["fileSize"] > 0
                valid = valid and present(a.get("fileName")) and all(type(image.get(k)) is int and image[k] > 0 for k in ("width", "height"))
                dimensions = (image.get("width"), image.get("height"))
                if (screenshot_set["attributes"].get("screenshotDisplayType") in IPHONE_DISPLAY_TYPES
                        and delivery.get("state") == "COMPLETE" and not delivery.get("errors")
                        and (dimensions in IPHONE_CURRENT_SIZES or dimensions[::-1] in IPHONE_CURRENT_SIZES)):
                    size_evidence = True
        self.record(f"delivered screenshots {index}", valid and count > 0, "actual assets must be COMPLETE with positive file size/dimensions, 1–10 per set; empty set IDs never count as screenshots")
        self.record(f"iPhone screenshot size evidence {index}", size_evidence, "documented iPhone API enum plus current medium/large/fallback pixel dimensions required; enum-to-group mapping and scaling remain UNKNOWN")

    def review_checks(self, vid):
        a = self.api.one(f"/v1/appStoreVersions/{vid}/appStoreReviewDetail", "appStoreReviewDetails")["attributes"]
        contacts = ("contactFirstName", "contactLastName", "contactEmail", "contactPhone")
        self.record("review contact", all(present(a.get(k)) for k in contacts), "all four review contact fields required; values withheld")
        self.record("review instructions", present(a.get("notes")), "review notes required for this sign-in app; values withheld")
        needed = a.get("demoAccountRequired")
        ok = type(needed) is bool and (needed is False or all(present(a.get(k)) for k in ("demoAccountName", "demoAccountPassword")))
        self.record("review sign-in fields", ok, "explicit demoAccountRequired answer; if true, both credentials required; usability/alternative access remains UNKNOWN")

    def app_checks(self):
        infos = self.api.many(f"/v1/apps/{self.app}/appInfos", "appInfos")
        matches = [i for i in infos if i["id"] == self.info_id] if self.info_id else infos
        if len(matches) != 1:
            raise MissingEvidence("ambiguous app info; set ASC_APP_INFO_ID to the current editable record")
        iid = matches[0]["id"]
        locs = self.api.many(f"/v1/appInfos/{iid}/appInfoLocalizations", "appInfoLocalizations")
        self.record("app name/privacy URL", bool(locs) and all(present(l["attributes"].get("locale")) and present(l["attributes"].get("name")) and url(l["attributes"].get("privacyPolicyUrl")) for l in locs), "all returned app-info localizations need name, locale and privacy URL; URL reachability/policy content unverified")
        for index, loc in enumerate(locs, 1):
            self.public_check(f"privacy URL HTTP {index}", loc["attributes"].get("privacyPolicyUrl"))
        a = self.api.one(f"/v1/appInfos/{iid}/ageRatingDeclaration", "ageRatingDeclarations")["attributes"]
        boolean_fields = "advertising gambling healthOrWellnessTopics lootBox messagingAndChat parentalControls ageAssurance socialMedia socialMediaAgeRestricted unrestrictedWebAccess userGeneratedContent".split()
        frequency_fields = "alcoholTobaccoOrDrugUseOrReferences contests gamblingSimulated gunsOrOtherWeapons medicalOrTreatmentInformation profanityOrCrudeHumor sexualContentGraphicAndNudity sexualContentOrNudity horrorOrFearThemes matureOrSuggestiveThemes violenceCartoonOrFantasy violenceRealisticProlongedGraphicOrSadistic violenceRealistic".split()
        allowed = {"NONE", "INFREQUENT_OR_MILD", "FREQUENT_OR_INTENSE", "INFREQUENT", "FREQUENT"}
        answered = all(type(a.get(k)) is bool for k in boolean_fields) and all(a.get(k) in allowed for k in frequency_fields)
        self.record("current age-rating answer evidence", answered, "current boolean/frequency fields must have typed answers; legacy 4+ or an object ID alone is insufficient")


def main():
    parser = argparse.ArgumentParser(description="Read-only ASC evidence checks. FAIL/UNKNOWN always exit 1. Never submits.")
    parser.add_argument("--evidence", help="offline JSON object mapping documented /v1/... GET paths to unmodified response envelopes; never commit real review credentials")
    args = parser.parse_args()
    app = os.getenv("ASC_APP_ID", "6799138197")
    version = os.getenv("ASC_VERSION", "1.0")
    platform = os.getenv("ASC_PLATFORM", "IOS")
    if not re.fullmatch(r"[0-9]+", app) or not present(version) or platform != "IOS":
        print("FAIL configuration: valid app ID/version and IOS required; other platforms unsupported")
        return 1
    try:
        responses = None
        if args.evidence:
            with open(args.evidence) as file:
                responses = json.load(file)
            if not isinstance(responses, dict):
                raise ValueError()
        results = Preflight(Evidence(responses, os.getenv("ASC_API_TOKEN")), app, version, platform, os.getenv("ASC_APP_INFO_ID")).run()
    except Exception:
        print("FAIL offline evidence unreadable or malformed; content withheld")
        return 1
    print("App Store preflight: read-only; offline snapshot" if args.evidence else "App Store preflight: read-only Apple API GETs")
    for status, name, detail in results:
        print(f"{status:7} {name}: {detail}")
    blockers = sum(status != "PASS" for status, _, _ in results)
    print(f"{blockers} unresolved checks. This report is not authorization to submit or Apple approval.")
    return 1 if blockers else 0


if __name__ == "__main__":
    sys.exit(main())
