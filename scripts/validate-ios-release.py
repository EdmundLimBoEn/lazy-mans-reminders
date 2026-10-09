#!/usr/bin/env python3
"""Check built Release bundles; no signing credentials or Apple services needed."""

import argparse
import json
import plistlib
import re
from pathlib import Path


def validate_bundle(bundle):
    with (bundle / 'Info.plist').open('rb') as source:
        info = plistlib.load(source)
    sdk = info.get('DTSDKName', '')
    if not re.fullmatch(r'iphoneos(?:2[6-9]|[3-9]\d)\.\d+(?:\.\d+)?', sdk):
        raise ValueError(f'{bundle.name}: expected device iOS SDK >=26, got {sdk!r}')
    xcode = info.get('DTXcode', '')
    if not str(xcode).isdigit() or int(xcode) < 2600:
        raise ValueError(f'{bundle.name}: expected Xcode >=26, got {xcode!r}')
    manifest = bundle / 'PrivacyInfo.xcprivacy'
    with manifest.open('rb') as source:
        if not isinstance(plistlib.load(source), dict):
            raise ValueError(f'{bundle.name}: invalid privacy manifest dictionary')
    return {key: info.get(key) for key in (
        'CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion',
        'DTXcode', 'DTXcodeBuild', 'DTSDKName', 'DTSDKBuild', 'MinimumOSVersion',
    )}


def validate(app):
    app_metadata = validate_bundle(app)
    if not (app / 'Assets.car').is_file():
        raise ValueError('App asset catalog is missing')
    with (app / 'Info.plist').open('rb') as source:
        icons = plistlib.load(source).get('CFBundleIcons', {})
    if not icons.get('CFBundlePrimaryIcon'):
        raise ValueError('App primary icon metadata is missing')
    widget = app / 'PlugIns' / 'ReminderWidgetExtension.appex'
    widget_metadata = validate_bundle(widget)
    for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'DTSDKName', 'DTXcode'):
        if not app_metadata.get(key) or app_metadata[key] != widget_metadata.get(key):
            raise ValueError(f'App and widget {key} must be present and match')
    return {'app': app_metadata, 'widget': widget_metadata}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        metadata = json.dumps(validate(args.app), indent=2) + '\n'
        if args.output:
            args.output.write_text(metadata)
        print(metadata, end='')
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        parser.exit(1, f'::error::{error}\n')
