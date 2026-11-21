"""Capture only Account on the exclusive T3 device session.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import hashlib
import json
import pathlib
import subprocess
import sys
import time

command = sys.argv[1]
style, size = sys.argv[2:4]
out = pathlib.Path(__file__).resolve().parent
manifest_path = out / 'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
    'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'device': {'hostId': 'local', 'id': '78F5A64F-7B2E-4562-8EF9-10F3312CC694',
               'name': 'Hillclimb iPhone 17 Pro', 'os': '26.2'},
    'captures': [], 'commands': [],
}
def run(*args):
    manifest['commands'].append([command, *args])
    result = subprocess.run([command, *args], capture_output=True, text=True)
    print(result.stdout[-1500:], flush=True)
    if result.returncode:
        manifest.setdefault('failures', []).append({'command': [command, *args], 'stdout': result.stdout, 'stderr': result.stderr})
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        print(result.stderr, flush=True)
        result.check_returncode()
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')

def launch():
    run('open', 'systems.edmundlim.NotepadHillclimb', '--relaunch',
        '--launch-args=--hillclimb-demo', '--launch-args=account',
        '--launch-args=--hillclimb-style', '--launch-args=' + style,
        '--launch-args=--hillclimb-size', '--launch-args=' + size)
    time.sleep(3)

def shot(detent, position):
    path = out / f'account-{style}-{size}-{detent}-{position}.png'
    run('screenshot', str(path), '--pixel-density', '3')
    manifest['captures'].append({'file': path.name, 'style': style, 'size': size,
                                'detent': detent, 'position': position,
                                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')

if '--medium-only' not in sys.argv:
    run('settings', 'appearance', style)
    run('settings', 'text-size', 'extra-extra-extra-large' if size == 'XXXL' else 'large')
    time.sleep(3)
    launch()
    shot('large', 'top')
    run('swipe', '201', '780', '201', '240', '--count', '8', '--pause-ms', '300')
    time.sleep(2)
    shot('large', 'lower')
    launch()
run('gesture', 'pan', '201', '69', '0', '355', '600')
time.sleep(3)
shot('medium', 'top')
run('swipe', '201', '780', '201', '530', '--count', '12', '--pause-ms', '300')
time.sleep(2)
shot('medium', 'lower')
run('snapshot', '-i')
