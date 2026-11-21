#!/usr/bin/env python3
"""Capture an already navigated Reminders state; never edits list data.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,pathlib,subprocess,json,hashlib,struct,datetime
p=argparse.ArgumentParser();p.add_argument('--command',required=True);p.add_argument('--device',required=True);p.add_argument('--out',required=True,type=pathlib.Path);p.add_argument('--state',required=True,choices=['top','bottom','compose','sheet']);p.add_argument('--style',required=True,choices=['light','dark']);p.add_argument('--size',default='XXXL');a=p.parse_args();a.out.mkdir(exist_ok=True,parents=True);mp=a.out/'manifest.json';m=json.loads(mp.read_text()) if mp.exists() else {'device':json.loads(pathlib.Path(a.device).read_text()),'captures':[],'operations':[]}
def run(*args):
 r=subprocess.run([a.command,*args],capture_output=True,text=True);m['operations'].append({'argv':[a.command,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});mp.write_text(json.dumps(m,indent=2));r.check_returncode();return r.stdout
f=a.out/f'reminders-{a.state}-{a.style}-{a.size}.png';assert not f.exists()
run('settings','appearance',a.style);run('wait','stable','1500','10000');tree=run('snapshot','-i');f.with_suffix('.txt').write_text(tree);run('screenshot',str(f.resolve()),'--pixel-density','3','--normalize-status-bar');b=f.read_bytes();m['captures'].append({'file':f.name,'state':a.state,'appearance':a.style,'size':a.size,'reference_status':'pending-inspection','dimensions':list(struct.unpack('>II',b[16:24])),'sha256':hashlib.sha256(b).hexdigest(),'capture_time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()});mp.write_text(json.dumps(m,indent=2));print(f)
