#!/usr/bin/env python3
"""Capture read-only sign-in variants using the task's pinned device session."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
agent = '/Users/limboenedmund/.t3/userdata/device/targets/t3-cec581e093978751ab7cd54e/agent-device'
manifest = {
    'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'source_sha256': hashlib.sha256((root / 'ios/App/SignInView.swift').read_bytes()).hexdigest(),
    'device': '8E8380DE-364D-4899-99B8-D15ED0494FFD',
    'safety': 'Read-only offline fixture; no authentication controls enabled.',
    'captures': [],
    'author': 'Written by gpt-6.1-sol in Codex on behalf of Edmund',
}
for style in ('light', 'dark'):
    for size in ('default', 'XXXL'):
        for variant in ('default', 'password', 'inbox', 'error', 'keyboard', 'password-keyboard'):
            path = out / f'signin-{style}-{size}-{variant}.png'
            record = dict(style=style, size=size, variant=variant, path=path.name)
            try:
                subprocess.run([agent, 'open', 'systems.edmundlim.NotepadHillclimb', '--relaunch',
                                '--launch-args=--hillclimb-demo', '--launch-args=signin',
                                '--launch-args=--hillclimb-style', f'--launch-args={style}',
                                '--launch-args=--hillclimb-size', f'--launch-args={size}',
                                '--launch-args=--hillclimb-signin-variant', f'--launch-args={variant}'], check=True)
                subprocess.run([agent, 'screenshot', str(path), '--pixel-density', '3', '--normalize-status-bar'], check=True)
                record.update(status='captured', sha256=hashlib.sha256(path.read_bytes()).hexdigest())
            except Exception as error:
                record.update(status='failed', error=str(error))
                raise
            finally:
                manifest['captures'].append(record)
                (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
subprocess.run([agent, 'close', 'systems.edmundlim.NotepadHillclimb'], check=True)
