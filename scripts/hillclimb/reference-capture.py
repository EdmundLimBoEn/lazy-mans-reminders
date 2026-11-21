#!/usr/bin/env python3
"""Capture an operator-navigated native state, or verify existing reference PNGs.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2] / 'hillclimb/reference'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--verify', action='store_true')
p.add_argument('--device-command', help='Exact pinned agent-device executable returned by YOUR device_open')
p.add_argument('--app', choices=['reminders', 'notes'])
p.add_argument('--state', choices=['top', 'bottom', 'compose', 'sheet', 'empty'])
p.add_argument('--appearance', choices=['light', 'dark'])
a = p.parse_args()
if a.verify:
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    for capture in manifest['captures']:
        data = (ROOT / capture['file']).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        assert list(struct.unpack('>II', data[16:24])) == [1206, 2622]
        assert hashlib.sha256(data).hexdigest() == capture['sha256']
    print(f"Verified {len(manifest['captures'])} PNG signatures, dimensions and SHA256 hashes")
else:
    if not all([a.device_command, a.app, a.state, a.appearance]):
        p.error('capture requires --device-command, --app, --state and --appearance')
    def run(*args):
        subprocess.run([a.device_command, *args], check=True)
    # Operator must open and navigate using this same pinned command first.
    run('settings', 'appearance', a.appearance)
    time.sleep(2)
    run('snapshot', '-i')
    input('Inspect device_screenshot; confirm settled requested state, then press Enter: ')
    target = ROOT / f'{a.app}-{a.state}-{a.appearance}.png'
    if target.exists():
        p.error(f'{target} already exists; preserve or explicitly move it before recapturing')
    run('screenshot', str(target), '--pixel-density', '3')
    print('Inspect saved PNG with view_image and add its metadata/hash to manifest.json.')
