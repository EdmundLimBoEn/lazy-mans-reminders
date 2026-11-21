"""Inert enabled-paint states; footer positioning is explicit, never a gesture.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import sys,json,subprocess,hashlib,struct,datetime
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');configuration=sys.argv[1];assert configuration in ['normal','combined'];out=Path('hillclimb/rounds/7/signin-paint')/configuration;out.mkdir(parents=True,exist_ok=True);rows=[]
if configuration=='combined':
 values=json.loads((p/'manual-enabled.json').read_text());assert all(values[k]=='1' for k in ['Reduce Motion','Reduce Transparency','Increase Contrast'])
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
  cases=[(variant,filled,False) for variant in ['default','password'] for filled in [False,True]] if configuration=='combined' else []
  cases.append(('password',False,True))
  for variant,filled,bottom in cases:
   name=f'{style}-{size}-{variant}-'+('bottom' if bottom else 'filled' if filled else 'empty')
   args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant,'--hillclimb-signin-appearance','enabled']
   if filled:args+=['--hillclimb-signin-filled','yes']
   if bottom:args+=['--hillclimb-signin-scroll','bottom']
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+x for x in args]);op('wait','stable','1000','10000');(out/(name+'.json')).write_text(op('snapshot','-i','--json'));f=out/(name+'.png');assert not f.exists();op('screenshot',str(f),'--pixel-density','3');b=f.read_bytes();rows.append(dict(file=str(f),sha256=hashlib.sha256(b).hexdigest(),dimensions=struct.unpack('>II',b[16:24]),arguments=args,sourceIdentity=json.loads((t/'freeze.json').read_text())['sourceIdentity'],configuration=configuration,inertRoot=True,manualGestures=False,position='explicit bottom argument' if bottom else 'initial',captureUTC=datetime.datetime.now(datetime.timezone.utc).isoformat()));(out/'manifest.json').write_text(json.dumps(rows,indent=2));print(configuration,name,flush=True)
