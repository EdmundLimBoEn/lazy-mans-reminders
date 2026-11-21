import hashlib
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(__file__).resolve().parent
COMMAND = '/Users/limboenedmund/.t3/userdata/device/targets/t3-82dc311822b1fbe47b757197/agent-device'
APP = 'systems.edmundlim.NotepadHillclimb'
manifest = {'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'deviceID': '066ECE57-46B4-414A-B53E-523775329360', 'captures': [],
            'sourceDirty': subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--', 'ios/App', 'ios/UITests']).returncode != 0,
            'sourceHashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in (ROOT / 'ios/App').glob('*.swift')}}
def run(*args):
    subprocess.run([COMMAND, *args], check=True)
def shot(name):
    time.sleep(2)
    path = OUT / (name + '.png')
    run('screenshot', str(path), '--pixel-density', '3', '--normalize-status-bar')
    manifest['captures'].append({'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
try:
    for style in ['light', 'dark']:
        for size, mode in [('default', 'full'), ('XXXL', 'long-text')]:
            run('open', APP, '--relaunch', '--launch-args=--hillclimb-demo', '--launch-args=' + mode,
                '--launch-args=--hillclimb-style', '--launch-args=' + style,
                '--launch-args=--hillclimb-size', '--launch-args=' + size)
            shot(f'{mode}-{style}-{size}-top')
            run('swipe', '180', '250', '180', '550')
            run('swipe', '180', '650', '180', '260', '--count', '12', '--pause-ms', '200')
            shot(f'{mode}-{style}-{size}-bottom-after-pull')
        for size in ['default', 'XXXL']:
            run('open', APP, '--relaunch', '--launch-args=--hillclimb-demo', '--launch-args=composer',
                '--launch-args=--hillclimb-style', '--launch-args=' + style,
                '--launch-args=--hillclimb-size', '--launch-args=' + size)
            shot(f'composer-{style}-{size}-unfocused')
            run('click', "label='New reminder'")
            shot(f'composer-{style}-{size}-keyboard')
            run('click', "label='Done'")
            shot(f'composer-{style}-{size}-dismissed')
finally:
    run('close', APP)
