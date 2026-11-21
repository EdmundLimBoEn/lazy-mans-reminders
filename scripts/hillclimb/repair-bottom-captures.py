#!/usr/bin/env python3
"""Verify final-row geometry after real pull/fling; preserve short-scroll attempts.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,json,pathlib,subprocess,hashlib,struct,re
p=argparse.ArgumentParser();p.add_argument('--command',required=True);p.add_argument('--round',required=True,type=int);p.add_argument('--fling-distance',type=int,default=300);a=p.parse_args();out=pathlib.Path('hillclimb/rounds')/str(a.round);mp=out/'manifest.json';m=json.loads(mp.read_text());opfile=out/'bottom-recapture-operations.json';ops=json.loads(opfile.read_text()) if opfile.exists() else []
def run(*args):
 r=subprocess.run([a.command,*args],text=True,capture_output=True);ops.append({'argv':[a.command,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});(out/'bottom-recapture-operations.json').write_text(json.dumps(ops,indent=2));r.check_returncode();return r.stdout
for style in ['light','dark']:
 name=f'long-text-{style}-XXXL-bottom-after-pull.png';path=out/name
 if any(c.get('path')==name and c.get('settling')=='Verified final row geometry after pull/fling' for c in m['captures']):continue
 assert not (out/'rejected'/name).exists(), 'Refusing to overwrite rejected evidence'
 run('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in ['--hillclimb-demo','long-text','--hillclimb-style',style,'--hillclimb-size','XXXL']]);run('wait','stable','1000','10000');run('swipe','180','250','180','550')
 for n in range(12):
  run('gesture','fling','up','180','650',str(a.fling_distance));run('wait','stable','1000','10000');tree=run('snapshot','-i')
  match=re.search(r'(\{"[^\n]*fixtureCount[^\n]*\})',tree)
  if not match:continue
  try:g=json.loads(match.group(1).replace('\\"','"'))
  except json.JSONDecodeError:continue
  key='00000000-0000-4000-8000-%012d'%g['fixtureCount'][0];row=g.get(key)
  if row and row[1]>=g['safeArea'][1] and row[1]+row[3]<=g['composer'][1]+.5:break
 else:raise RuntimeError('Final row not verified within12 flings; retain earlier attempt')
 (out/(name+'.geometry.json')).write_text(json.dumps(g,indent=2))
 rejected=out/'rejected';rejected.mkdir(exist_ok=True);path.rename(rejected/name)
 for c in m['captures']:
  if c['path']==name and c['status']=='captured':c.update(status='rejected',path='rejected/'+name,reason='Superseded by capture with explicit final-row geometry verification; earlier geometry was not recorded')
 run('screenshot',str(path.resolve()),'--pixel-density','3','--normalize-status-bar');b=path.read_bytes();m['captures'].append({'state':'long-text','style':style,'size':'XXXL','position':'bottom-after-pull','path':name,'status':'captured','sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'settling':'Verified final row geometry after pull/fling'});mp.write_text(json.dumps(m,indent=2))
