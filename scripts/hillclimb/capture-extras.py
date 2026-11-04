#!/usr/bin/env python3
"""Settled offline states using only the caller's pinned session.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,datetime,hashlib,json,pathlib,struct,subprocess
p=argparse.ArgumentParser();p.add_argument('--command',required=True);p.add_argument('--round',required=True,type=int);p.add_argument('--device',required=True);a=p.parse_args()
assert '/device/targets/' in a.command and a.command.endswith('/agent-device')
O=pathlib.Path('hillclimb/rounds')/str(a.round)/'extras';O.mkdir(parents=True,exist_ok=True);P=O/'manifest.json'
m=json.loads(P.read_text()) if P.exists() else {'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'device':json.loads(pathlib.Path(a.device).read_text()),'operations':[],'captures':[]}
def save():P.write_text(json.dumps(m,indent=2)+'\n')
def run(*args):
 r=subprocess.run([a.command,*args],text=True,capture_output=True);m['operations'].append({'argv':[a.command,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save()
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
def stable():run('wait','stable','1000','10000')
def launch(state,style,size,flag=None,variant=None):
 args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
 for v in ['--hillclimb-demo',state,'--hillclimb-style',style,'--hillclimb-size',size]+([flag,variant] if flag else []):args+=['--launch-args='+v]
 run(*args);stable()
def shot(name):
 if any(c['file']==name+'.png' for c in m['captures']):return
 stable();tree=run('snapshot','-i');(O/(name+'.txt')).write_text(tree)
 f=O/(name+'.png');run('screenshot',str(f.resolve()),'--pixel-density','3','--normalize-status-bar');b=f.read_bytes();m['captures'].append({'file':f.name,'status':'captured','sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'UTC':datetime.datetime.now(datetime.timezone.utc).isoformat()});save();print(name,flush=True)
for style in ['light','dark']:
 run('settings','appearance',style)
 for size in ['default','XXXL']:
  run('settings','text-size','extra-extra-extra-large' if size=='XXXL' else 'large')
  for variant in ['default','password','inbox','error','loading','keyboard','password-keyboard']:
   name=f'signin-{style}-{size}-{variant}'
   if any(c['file']==name+'.png' for c in m['captures']):continue
   launch('signin',style,size,'--hillclimb-signin-variant',variant)
   if 'keyboard' in variant:
    run('wait','text','Done','10000');stable()
   shot(name)
  for state in ['loading','error-empty','error-populated']:
   name=f'board-{state}-{style}-{size}'
   if any(c['file']==name+'.png' for c in m['captures']):continue
   launch('full' if state=='error-populated' else 'empty',style,size,'--hillclimb-board-state',state);shot(name)
   if state=='error-populated':run('click',"label='Dismiss'");shot(name+'-recovered')
  launch('empty',style,size);shot(f'guide-{style}-{size}-before');run('click',"label='New reminder'");run('wait','text','Done','10000');shot(f'guide-{style}-{size}-focused');run('click',"label='Done'");shot(f'guide-{style}-{size}-restored')
  launch('account',style,size);shot(f'account-{style}-{size}-large-top');run('swipe','201','780','201','240','--count','8','--pause-ms','300');shot(f'account-{style}-{size}-large-lower')
  launch('account',style,size);run('gesture','pan','201','69','0','355','600');shot(f'account-{style}-{size}-medium-top');run('swipe','201','780','201','510','--count','8','--pause-ms','300');shot(f'account-{style}-{size}-medium-lower')
run('settings','appearance','light');run('settings','text-size','large')
