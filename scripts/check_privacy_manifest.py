#!/usr/bin/env python3
"""Check this app's audited declarations, not SDK manifests or archive packaging.

Apple enums/reasons verified 2026-10-09:
https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype
https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
Refresh this intentional app-specific allowlist when data handling changes.
"""

import argparse
import copy
from pathlib import Path
import plistlib
import sys
import unittest

MANIFEST = Path(__file__).resolve().parents[1] / "ios/Shared/PrivacyInfo.xcprivacy"
DATA_TYPES = {
    "NSPrivacyCollectedDataType" + suffix
    for suffix in (
        "Name", "EmailAddress", "UserID", "OtherUserContent", "DeviceID",
        "OtherDataTypes", "OtherDiagnosticData",
    )
}
PURPOSE = "NSPrivacyCollectedDataTypePurposeAppFunctionality"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(manifest):
    require(isinstance(manifest, dict), "Manifest root must be a dictionary")
    require(set(manifest) == {
        "NSPrivacyTracking", "NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes",
        "NSPrivacyAccessedAPITypes",
    }, "Unexpected or missing top-level keys")
    require(manifest["NSPrivacyTracking"] is False, "Audited app does not track")
    require(manifest["NSPrivacyTrackingDomains"] == [], "Unexpected tracking domains")
    entries = manifest["NSPrivacyCollectedDataTypes"]
    require(isinstance(entries, list), "Collected data must be an array")
    seen = set()
    for entry in entries:
        require(isinstance(entry, dict) and set(entry) == {
            "NSPrivacyCollectedDataType", "NSPrivacyCollectedDataTypeLinked",
            "NSPrivacyCollectedDataTypeTracking", "NSPrivacyCollectedDataTypePurposes",
        }, "Unexpected or missing collected-data keys")
        data_type = entry["NSPrivacyCollectedDataType"]
        require(isinstance(data_type, str) and data_type in DATA_TYPES,
                f"Unknown or unaudited collected-data identifier: {data_type}")
        require(data_type not in seen, f"Duplicate collected-data identifier: {data_type}")
        seen.add(data_type)
        require(entry["NSPrivacyCollectedDataTypeLinked"] is True,
                f"Expected account-linked collection: {data_type}")
        require(entry["NSPrivacyCollectedDataTypeTracking"] is False,
                f"Unexpected tracking: {data_type}")
        require(entry["NSPrivacyCollectedDataTypePurposes"] == [PURPOSE],
                f"Unexpected collection purpose: {data_type}")
    require(seen == DATA_TYPES, "Missing audited collected-data declarations")
    entries = manifest["NSPrivacyAccessedAPITypes"]
    require(isinstance(entries, list) and len(entries) == 1,
            "Expected one audited required-reason API category")
    entry = entries[0]
    require(isinstance(entry, dict) and set(entry) == {
        "NSPrivacyAccessedAPIType", "NSPrivacyAccessedAPITypeReasons",
    }, "Unexpected or missing API keys")
    require(entry["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults",
            "Unexpected or unaudited API category")
    reasons = entry["NSPrivacyAccessedAPITypeReasons"]
    require(isinstance(reasons, list) and len(reasons) == 2
            and all(isinstance(reason, str) for reason in reasons)
            and set(reasons) == {"CA92.1", "1C8F.1"},
            "Need CA92.1 for app-only defaults and 1C8F.1 for App Group defaults")


class RegressionTests(unittest.TestCase):
    def setUp(self):
        self.manifest = plistlib.loads(MANIFEST.read_bytes())

    def test_current_manifest(self):
        validate(self.manifest)

    def test_rejects_invalid_user_content_identifier(self):
        self.manifest["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataType"] = (
            "NSPrivacyCollectedDataTypeUserContent"
        )
        with self.assertRaisesRegex(ValueError, "identifier"):
            validate(self.manifest)

    def test_requires_both_defaults_reasons(self):
        for reason in ("CA92.1", "1C8F.1"):
            with self.subTest(reason=reason):
                manifest = copy.deepcopy(self.manifest)
                manifest["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"] = [reason]
                with self.assertRaisesRegex(ValueError, "Need CA92.1"):
                    validate(manifest)

    def test_rejects_string_boolean(self):
        self.manifest["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypeLinked"] = "true"
        with self.assertRaisesRegex(ValueError, "account-linked"):
            validate(self.manifest)

    def test_rejects_unsupported_purpose(self):
        self.manifest["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypePurposes"] = ["AppFunctionality"]
        with self.assertRaisesRegex(ValueError, "purpose"):
            validate(self.manifest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(RegressionTests))
        sys.exit(0 if result.wasSuccessful() else 1)
    try:
        validate(plistlib.loads(MANIFEST.read_bytes()))
    except (ValueError, TypeError, OSError, plistlib.InvalidFileException) as error:
        print(f"Privacy manifest check failed: {error}", file=sys.stderr)
        sys.exit(1)
    print("Privacy manifest: plist structure and audited Apple declarations passed")
