#!/usr/bin/env python3
"""Select the newest available iPhone runtime supported by the selected SDK."""

import json
import re
import sys


def select(devices, sdk):
    ceiling = tuple(int(part) for part in sdk.split('.')[:2])
    candidates = []
    for runtime, entries in devices.items():
        match = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-\d+)?', runtime)
        if not match:
            continue
        version = tuple(map(int, match.groups()))
        if version > ceiling:
            continue
        for device in entries:
            if device.get('isAvailable') and device['name'].startswith('iPhone'):
                candidates.append((version, device['name'], device['udid']))
    if not candidates:
        raise ValueError(f'No available iPhone simulator compatible with iOS SDK {sdk}')
    return max(candidates)[2]


if __name__ == '__main__':
    try:
        print(select(json.load(sys.stdin)['devices'], sys.argv[1]))
    except (ValueError, KeyError, IndexError) as error:
        sys.exit(str(error))
