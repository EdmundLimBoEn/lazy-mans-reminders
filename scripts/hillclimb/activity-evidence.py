#!/usr/bin/env python3
"""Capture real ActivityKit surfaces through a T3-pinned command.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse
import os
import datetime
import hashlib
import json
import pathlib
import shlex
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--command', required=True, help='Exact pinned device_open agentDevice.command')
parser.add_argument('--out', type=pathlib.Path, required=True, help='Use a fresh round directory to preserve prior evidence')
parser.add_argument('--style', choices=['light', 'dark'], required=True)
parser.add_argument('--size', choices=['default', 'XXXL'], required=True)
parser.add_argument('--text', choices=['short', 'long', 'multiline'], required=True)
parser.add_argument('--surface', choices=['prepare', 'collapsed', 'expanded', 'notification-center', 'end'], required=True)
a = parser.parse_args()
command = shlex.split(a.command)
if len(command) != 1 or '/device/targets/' not in command[0] or not command[0].endswith('/agent-device'):
    parser.error('Requires exact T3 pinned executable')
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
manifest_path = out / 'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'captures': [], 'operations': []}
freeze_path=os.environ.get('HILLCLIMB_SOURCE_FREEZE')
freeze=json.loads(pathlib.Path(freeze_path).read_text()) if freeze_path else None
manifest.update(sourceFreeze=freeze_path, sourceIdentity=freeze.get('sourceIdentity') if freeze else None, parentSourceSHA=freeze.get('sourceSHA') if freeze else None, deviceID='78F5A64F-7B2E-4562-8EF9-10F3312CC694', hostID='local',
                sourceSHA=(None if freeze.get('uncommittedProductionCorrection') else freeze['sourceSHA']) if freeze else subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                dirty=bool(freeze.get('uncommittedProductionCorrection')) if freeze else bool(subprocess.check_output(['git', 'status', '--porcelain'])))
def save():
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
def run(*args):
    result = subprocess.run(command + list(args), text=True, capture_output=True)
    manifest['operations'].append({'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'argv': command + list(args), 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
    save()
    print(result.stdout)
    if result.returncode:
        raise SystemExit(result.stderr or result.returncode)
if a.surface in ('prepare', 'end'):
    run('settings', 'appearance', a.style)
    run('settings', 'text-size', 'extra-extra-extra-large' if a.size == 'XXXL' else 'large')
    run('open', 'systems.edmundlim.NotepadHillclimb', '--relaunch', '--launch-args=--hillclimb-demo',
        '--launch-args=activity', '--launch-args=--hillclimb-activity',
        '--launch-args=' + ('end' if a.surface == 'end' else a.text),
        '--launch-args=--hillclimb-style', '--launch-args=' + a.style,
        '--launch-args=--hillclimb-size', '--launch-args=' + a.size)
else:
    # Navigate only after inspecting the fresh SpringBoard snapshot. This script
    # captures the current surface; it never substitutes a SwiftUI replica.
    path = out / f'{a.text}-{a.style}-{a.size}-{a.surface}.png'
    if path.exists():
        raise SystemExit('Refusing to overwrite existing native evidence: ' + str(path))
    if a.surface == 'expanded':
        video = path.with_suffix('.mp4')
        run('record', 'start', '--scope', 'device', '--hide-touches', str(video))
        try:
            run('longpress', '201', '30', '1500')
            run('snapshot', '-i')
        finally:
            run('record', 'stop')
        # Still screenshots omit the Island overlay on this simulator. Extract
        # an unmodified frame from the real device recording instead.
        subprocess.run(['ffmpeg', '-y', '-i', str(video), '-ss', '2', '-frames:v', '1', str(path)],
                       check=True, capture_output=True)
    else:
        run('screenshot', str(path), '--pixel-density', '3')
    manifest['captures'] = [c for c in manifest['captures'] if c['file'] != path.name]
    manifest['captures'].append({'file': path.name, 'surface': a.surface,
        'style': a.style, 'size': a.size, 'text': a.text,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    save()
