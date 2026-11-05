#!/usr/bin/env bash
# Operation templates must come from help on the exact T3-returned command.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
python3 - "$@" <<'PY'
import argparse, datetime, hashlib, json, pathlib, shlex, subprocess, time, struct, os
p=argparse.ArgumentParser(description='Capture actual demo UI using a T3 pinned agent-device session')
p.add_argument('--round', required=True, type=int)
p.add_argument('--resume', action='store_true', help='Preserve successful captures and retain failed attempts')
p.add_argument('--device', required=True, help='JSON device object returned by device_open')
p.add_argument('--command', required=True, help='Exact agentDevice.command returned by device_open, including its session')
p.add_argument('--operations', required=True, help='JSON argv templates transcribed from pinned help; see harness.md')
a=p.parse_args()
d=json.loads(pathlib.Path(a.device).read_text())
if d.get('name') not in ('iPhone 17 Pro', 'Hillclimb iPhone 17 Pro') or d.get('version', '').removeprefix('iOS ') != '26.2' or d.get('hostId') != 'local':
    p.error('Requires local regular iPhone 17 Pro / iOS 26.2; Duo is forbidden')
if a.round < 1: p.error('round must be positive')
command=shlex.split(a.command)
if not any('agent-device' in part for part in command) or not (any('session' in part for part in command) or (len(command) == 1 and '/device/targets/' in command[0])):
    p.error('Pass the exact pinned agent-device command bound to its session from device_open')
ops=json.loads(pathlib.Path(a.operations).read_text())
ops.setdefault('appearance',['settings','appearance','{style}'])
ops.setdefault('text-size',['settings','text-size','{system_size}'])
for key in ('open','screenshot','bottom','pull','focus','close'):
    if not isinstance(ops.get(key),list) or not ops[key] or not all(isinstance(x,str) for x in ops[key]):
        p.error('Missing argv template: '+key)
# Open must substitute all launch controls, not silently reuse a previous fixture.
for token in ('{state}','{style}','{size}'):
    if not any(token in arg for arg in ops['open']): p.error('open must include '+token)
if not any('{path}' in arg for arg in ops['screenshot']): p.error('screenshot must include {path}')
out=pathlib.Path('hillclimb/rounds')/str(a.round)
if not a.resume and (out/'manifest.json').exists():
    p.error('Core manifest already exists; use --resume to preserve its history')
out.mkdir(parents=True,exist_ok=True)
freeze_path=os.environ.get('HILLCLIMB_SOURCE_FREEZE')
freeze=json.loads(pathlib.Path(freeze_path).read_text()) if freeze_path else None
sha=(None if freeze.get('uncommittedProductionCorrection') else freeze['sourceSHA']) if freeze else subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
manifest={'sourceSHA':sha,'dirty':bool(freeze.get('uncommittedProductionCorrection')) if freeze else bool(subprocess.check_output(['git','status','--porcelain'])), 'sourceFreeze':freeze_path, 'sourceIdentity':freeze.get('sourceIdentity') if freeze else None, 'parentSourceSHA':freeze.get('sourceSHA') if freeze else None,
 'device':d,'startedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'liveActivity':{'status':'unavailable','reason':'Offline fixture does not start ActivityKit or mutate shared board storage'},
 'captures':[],'operations':ops}
if a.resume:
    manifest=json.loads((out/'manifest.json').read_text())
    manifest.setdefault('operationAttempts', []).append(ops)
def save(): (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
def run(key,values):
    argv=[arg.format(**values) for arg in ops[key]]
    result=subprocess.run(command+argv,text=True,capture_output=True)
    manifest.setdefault('operationsLog',[]).append({'argv':command+argv,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr});save()
    if result.returncode: raise RuntimeError(result.stdout+result.stderr)
def capture(state,style,size,position='top'):
    if any(c['state']==state and c['style']==style and c['size']==size and c['position']==position and c['status']=='captured' for c in manifest['captures']):
        return
    path=(out/f'{state}-{style}-{size}-{position}.png').resolve()
    values=dict(state=state,style=style,size=size,path=str(path),system_size='extra-extra-extra-large' if size=='XXXL' else 'large')
    record=dict(state=state,style=style,size=size,position=position,path=path.name,status='pending')
    manifest['captures'].append(record);save()
    try:
        run('appearance',values)
        run('text-size',values)
        run('open',values)
        time.sleep(2)
        if state=='composer' and 'focus' in ops: run('focus',values);time.sleep(1)
        if position=='bottom-after-pull':
            run('pull',values)
            run('bottom',values)
            time.sleep(1)
        subprocess.run(command+['wait','stable','1000','10000'],check=True)
        run('screenshot',values)
        data=path.read_bytes()
        if not data.startswith(b'\x89PNG\r\n\x1a\n'): raise RuntimeError('Capture is not PNG')
        record.update(status='captured',sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),dimensions=list(struct.unpack('>II',data[16:24])))
    except Exception as error:
        record.update(status='failed',error=str(error));raise
    finally: save()
try:
    for style in ('light','dark'):
        for state in ('full','empty','composer','account','signin','long-text'):
            capture(state,style,'default')
        capture('full',style,'default','bottom-after-pull')
        capture('long-text',style,'XXXL')
        capture('long-text',style,'XXXL','bottom-after-pull')
finally:
    save()
    run('close',dict(state='full',style='light',size='default',path=''))
print(out/'manifest.json')
PY
