#!/usr/bin/env python3
"""Capture only the assigned private Board17 through this task's pinned session."""
import hashlib, json, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)
CLI = '/Users/limboenedmund/.t3/userdata/device/targets/t3-63707fb017f3a6cee56af6ac/agent-device'
APP = 'systems.edmundlim.NotepadHillclimb'

def run(*args):
    result = subprocess.run([CLI, *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

manifest = dict(sourceSHA=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    hostId='local', deviceId='066ECE57-46B4-414A-B53E-523775329360', runtime='iOS 26.2',
    sources={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (ROOT/'ios/App').glob('*.swift')}, captures=[])
for style in ['light', 'dark']:
    for size in ['default', 'XXXL']:
        for mode, state in [('full',None),('empty',None),('empty','loading'),('empty','error-empty'),('full','error-populated')]:
            args=['open',APP,'--relaunch']
            for arg in ['--hillclimb-demo',mode,'--hillclimb-style',style,'--hillclimb-size',size] + (['--hillclimb-board-state',state] if state else []):
                args += ['--launch-args='+arg]
            run(*args)
            name=f'{state or mode}-{style}-{size}.png'
            run('screenshot',str(OUT/name),'--pixel-density','3')
            manifest['captures'].append(dict(file=name,mode=mode,state=state,style=style,size=size,
                sha256=hashlib.sha256((OUT/name).read_bytes()).hexdigest()))
            (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
            print(name,flush=True)
run('settings','appearance','light')
run('settings','text-size','large')
run('close',APP)
