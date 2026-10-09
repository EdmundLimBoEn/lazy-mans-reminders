import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preflight", SCRIPT / "asc-preflight.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
FIXTURE = json.loads((SCRIPT / "tests/fixtures/asc-synthetic.json").read_text())
VERSION = "/v1/apps/6799138197/appStoreVersions"
BUILD = "/v1/appStoreVersions/version-1/build"
REVIEW = "/v1/appStoreVersions/version-1/appStoreReviewDetail"
SHOTS = "/v1/appScreenshotSets/set-1/appScreenshots"
AGE = "/v1/appInfos/info-1/ageRatingDeclaration"


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.evidence = copy.deepcopy(FIXTURE)

    def report(self):
        return {name: status for status, name, _ in m.Preflight(m.Evidence(self.evidence), "6799138197", "1.0", "IOS").run()}

    def attrs(self, path):
        data = self.evidence[path]["data"]
        return (data[0] if isinstance(data, list) else data)["attributes"]

    def test_good_evidence_still_has_explicit_human_blockers(self):
        report = self.report()
        self.assertEqual(report["build processing"], "PASS")
        self.assertEqual(report["delivered screenshots 1"], "PASS")
        self.assertEqual(report["current age-rating answer evidence"], "PASS")
        for key in ("privacy labels", "toolchain and SDK", "reviewer access", "screenshot completeness", "distribution prerequisites"):
            self.assertEqual(report[key], "UNKNOWN")

    def test_wrong_or_absent_version_platform_never_falls_back(self):
        for field, value in (("versionString", "2.0"), ("platform", "MAC_OS"), ("platform", None)):
            with self.subTest(field=field, value=value):
                self.evidence = copy.deepcopy(FIXTURE)
                self.attrs(VERSION)[field] = value
                self.assertEqual(self.report()["version scope"], "FAIL")
                self.assertNotIn("attached build scope", self.report())

    def test_ambiguous_version_fails(self):
        duplicate = copy.deepcopy(self.evidence[VERSION]["data"][0])
        duplicate["id"] = "other-version"
        self.evidence[VERSION]["data"].append(duplicate)
        self.assertEqual(self.report()["version scope"], "FAIL")

    def test_pagination_is_consumed(self):
        second = "/v1/apps/6799138197/appStoreVersions?cursor=next"
        self.evidence[second] = self.evidence[VERSION]
        self.evidence[VERSION] = {"data": [], "links": {"self": m.BASE + VERSION, "next": m.BASE + second}}
        self.assertEqual(self.report()["version scope"], "PASS")

    def test_missing_page_loop_and_foreign_url_fail_closed(self):
        for next_url in ("/v1/missing", VERSION, "https://example.invalid/steal"):
            with self.subTest(next_url=next_url):
                self.evidence[VERSION]["links"]["next"] = next_url
                self.assertEqual(self.report()["version scope"], "FAIL")

    def test_missing_and_malformed_builds_fail(self):
        for data in (None, {}, {"type": "builds", "id": "build-1"}):
            self.evidence[BUILD] = {"data": data}
            self.assertEqual(self.report()["attached build"], "FAIL")

    def test_build_scope(self):
        self.attrs("/v1/builds/build-1/preReleaseVersion")["platform"] = "MAC_OS"
        self.assertEqual(self.report()["attached build"], "FAIL")
        self.evidence = copy.deepcopy(FIXTURE)
        self.evidence["/v1/builds/build-1/app"]["data"]["id"] = "123"
        self.assertEqual(self.report()["attached build"], "FAIL")

    def test_processing_and_internal_only(self):
        for state in (None, "PROCESSING", "INVALID", "FAILED"):
            self.attrs(BUILD)["processingState"] = state
            self.assertEqual(self.report()["build processing"], "FAIL")
        for audience in (None, "INTERNAL_ONLY"):
            self.attrs(BUILD)["buildAudienceType"] = audience
            self.assertEqual(self.report()["App Store build eligibility"], "FAIL")

    def test_testflight_expiry_is_not_app_store_invalidity(self):
        self.assertTrue(self.attrs(BUILD)["expired"])
        self.assertEqual(self.report()["build processing"], "PASS")

    def test_encryption_false_is_explicit_evidence_not_truthiness(self):
        self.assertEqual(self.report()["encryption declaration"], "PASS")
        for answer in (None, "false", 0):
            self.attrs(BUILD)["usesNonExemptEncryption"] = answer
            self.assertEqual(self.report()["attached build"], "FAIL")

    def test_nonexempt_encryption_requires_attached_approved_declaration(self):
        self.attrs(BUILD)["usesNonExemptEncryption"] = True
        path = "/v1/builds/build-1/appEncryptionDeclaration"
        for state in (None, "IN_REVIEW", "REJECTED", "APPROVED"):
            self.evidence[path] = {"data": {"type": "appEncryptionDeclarations", "id": "encryption-1", "attributes": {"appEncryptionDeclarationState": state}}}
            self.assertEqual(self.report()["encryption declaration"], "PASS" if state == "APPROVED" else "FAIL")

    def test_empty_sets_are_not_screenshots(self):
        self.evidence[SHOTS]["data"] = []
        self.assertEqual(self.report()["delivered screenshots 1"], "FAIL")

    def test_screenshot_delivery_and_dimensions(self):
        for field, value in (("assetDeliveryState", {"state": "UPLOAD_COMPLETE"}), ("assetDeliveryState", {"state": "COMPLETE", "errors": [{"code": "ERROR"}]}), ("imageAsset", {"width": 0, "height": 2868}), ("imageAsset", None), ("fileSize", 0)):
            with self.subTest(field=field):
                self.evidence = copy.deepcopy(FIXTURE)
                self.attrs(SHOTS)[field] = value
                self.assertEqual(self.report()["delivered screenshots 1"], "FAIL")

    def test_too_many_screenshots(self):
        item = self.evidence[SHOTS]["data"][0]
        self.evidence[SHOTS]["data"] = [dict(copy.deepcopy(item), id=f"shot-{i}") for i in range(11)]
        self.assertEqual(self.report()["delivered screenshots 1"], "FAIL")

    def test_all_localizations_checked(self):
        path = "/v1/appStoreVersions/version-1/appStoreVersionLocalizations"
        self.evidence[path]["data"].append({"type": "appStoreVersionLocalizations", "id": "locale-2", "attributes": {"locale": "fr-FR"}})
        self.assertEqual(self.report()["listing metadata 2"], "FAIL")
        self.assertEqual(self.report()["delivered screenshots 2"], "FAIL")

    def test_id_only_review_and_missing_credentials_fail(self):
        self.evidence[REVIEW]["data"]["attributes"] = {}
        report = self.report()
        for field in ("review contact", "review instructions", "review sign-in fields"):
            self.assertEqual(report[field], "FAIL")
        self.evidence = copy.deepcopy(FIXTURE)
        del self.attrs(REVIEW)["demoAccountPassword"]
        self.assertEqual(self.report()["review sign-in fields"], "FAIL")

    def test_demo_not_required_does_not_prove_access(self):
        self.attrs(REVIEW)["demoAccountRequired"] = False
        del self.attrs(REVIEW)["demoAccountPassword"]
        self.assertEqual(self.report()["review sign-in fields"], "PASS")
        self.assertEqual(self.report()["reviewer access"], "UNKNOWN")

    def test_privacy_url_required(self):
        self.attrs("/v1/appInfos/info-1/appInfoLocalizations")["privacyPolicyUrl"] = ""
        self.assertEqual(self.report()["app name/privacy URL"], "FAIL")

    def test_old_questionnaire_and_string_false_fail(self):
        del self.attrs(AGE)["ageAssurance"]
        self.assertEqual(self.report()["current age-rating answer evidence"], "FAIL")
        self.attrs(AGE)["ageAssurance"] = "false"
        self.assertEqual(self.report()["current age-rating answer evidence"], "FAIL")

    def test_ambiguous_app_info_requires_explicit_selection(self):
        item = copy.deepcopy(self.evidence["/v1/apps/6799138197/appInfos"]["data"][0])
        item["id"] = "old-info"
        self.evidence["/v1/apps/6799138197/appInfos"]["data"].append(item)
        self.assertEqual(self.report()["app information"], "FAIL")

    def test_cli_withholds_review_secrets_even_on_malformed_evidence(self):
        for malformed in (False, True):
            with self.subTest(malformed=malformed), tempfile.TemporaryDirectory() as directory:
                evidence = copy.deepcopy(FIXTURE)
                evidence[REVIEW]["data"]["attributes"]["notes"] = "PRIVATE-NOTES"
                if malformed:
                    evidence[REVIEW] = {"errors": [{"detail": "PRIVATE-ERROR"}]}
                path = Path(directory) / "evidence.json"
                path.write_text(json.dumps(evidence))
                result = subprocess.run([str(SCRIPT / "asc-preflight.sh"), "--evidence", str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 1)
                for secret in ("PRIVATE-NOTES", "PRIVATE-ERROR", "SYNTHETIC-PASSWORD-NOT-REAL", "SYNTHETIC-ACCOUNT-NOT-REAL", "fixture@example.invalid"):
                    self.assertNotIn(secret, result.stdout + result.stderr)

    def test_only_get_transport_and_no_foreign_token_forwarding(self):
        class Reply:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self): return b'{"data": []}'
        with patch.object(m, "build_opener") as opener:
            opener.return_value.open.return_value = Reply()
            api = m.Evidence(token="PRIVATE-TOKEN")
            api.get("/v1/apps/123/appInfos")
            req = opener.return_value.open.call_args.args[0]
            self.assertEqual(req.get_method(), "GET")
            self.assertEqual(req.full_url, m.BASE + "/v1/apps/123/appInfos")
            self.assertIsNone(req.data)
            with self.assertRaises(m.MissingEvidence):
                api.get("https://example.invalid/v1/apps")
            self.assertEqual(opener.return_value.open.call_count, 1)
        with self.assertRaises(m.MissingEvidence):
            m.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.invalid")

    def test_public_http_probe_distinguishes_challenges_from_missing_pages(self):
        for code, expected in ((403, "UNKNOWN"), (429, "UNKNOWN"), (503, "UNKNOWN"), (404, "FAIL")):
            with patch.object(m, "build_opener") as opener:
                opener.return_value.open.side_effect = m.HTTPError("https://lmr.sillyapps.co/privacy", code, "PRIVATE-ERROR", {}, None)
                self.assertEqual(m.public_url("https://lmr.sillyapps.co/privacy")[0], expected)

    def test_public_probe_has_no_api_credentials_and_does_not_claim_policy_review(self):
        class Reply:
            status = 200
            headers = {"Content-Type": "text/html"}
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, limit): return b"<html>Example</html>"
        with patch.object(m, "build_opener") as opener:
            opener.return_value.open.return_value = Reply()
            status, detail = m.public_url("https://lmr.sillyapps.co/privacy")
            self.assertEqual(status, "PASS")
            self.assertIn("unverified", detail)
            req = opener.return_value.open.call_args.args[0]
            self.assertNotIn("Authorization", req.headers)
            self.assertIn("Mozilla/5.0", req.headers["User-agent"])
            self.assertEqual(m.public_url("https://127.0.0.1/privacy")[0], "UNKNOWN")
            self.assertEqual(opener.return_value.open.call_count, 1)


if __name__ == "__main__":
    unittest.main()
