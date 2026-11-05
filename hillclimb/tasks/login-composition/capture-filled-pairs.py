"""Matched real input in ordinary guarded fixtures, with exact binary identity.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,subprocess,sys,hashlib,struct
p=Path(__file__).parent;phase=sys.argv[1];assert phase in ['before','after'];out=p/(phase+'-filled-ordinary');out.mkdir(exist_ok=True);rows=[]
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
  for variant in ['default','password']:
   args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+x for x in args]);op('wait','stable','1000','10000');op('press','role=textfield label="Email address"','--settle');op('wait','text','Done','10000');op('fill','role=textfield label="Email address"','you@example.com','--delay-ms','80','--settle')
   if variant=='password':
    op('press','role=securetextfield label="Password"','--settle');op('fill','role=securetextfield label="Password"','Demo-password','--delay-ms','80','--settle')
   op('press','role=button label="Done"','--settle');op('wait','stable','1000','10000');tree=json.loads(op('snapshot','-i','--json'));nodes=tree['data']['nodes'];email=next(n for n in nodes if n.get('type')=='TextField');assert email['value']=='you@example.com';assert any(n.get('type')=='Button' and n.get('label')=='Clear text' for n in nodes);submit=next(n for n in nodes if n.get('type')=='Button' and n.get('label') in ['Send Sign-In Link','Sign In with Password']);assert not submit['enabled']
   f=out/f'{style}-{size}-{variant}.png';assert not f.exists();f.with_suffix('.json').write_text(json.dumps(tree,indent=2));op('screenshot',str(f),'--pixel-density','3');b=f.read_bytes();rows.append(dict(file=str(f),sha256=hashlib.sha256(b).hexdigest(),dimensions=struct.unpack('>II',b[16:24]),arguments=args,sourceSHA='c8da74021a7d66d95d040817405044bbb3af3f9f' if phase=='before' else None,sourceIdentity=None if phase=='before' else json.loads((p/'freeze.json').read_text())['sourceIdentity'],binaryIdentity='before-binary.json' if phase=='before' else 'tested-artifacts.json',inputProtocol='Ordinary guarded fixture, real field-focus gesture, advised80ms input after settled keyboard, email filled and password filled when applicable, real Done tap. Demo submit remains disabled. Separate inert filled-enabled preview is not a matched-before claim.',fullDevice=True));(out/'manifest.json').write_text(json.dumps(rows,indent=2));print(phase,style,size,variant,flush=True)
op('settings','appearance','light');op('settings','text-size','large');op('close','systems.edmundlim.NotepadHillclimb')
assert len(rows)==8
