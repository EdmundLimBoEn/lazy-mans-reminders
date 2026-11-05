"""Settled full-device secure-entry supplements, retaining immediate originals. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,hashlib
p=pathlib.Path(__file__).parent;out=p/'settled-secure';out.mkdir(exist_ok=True);rows=[]
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
for phase,app in [('before','/tmp/hillclimb-signin-density-before.app'),('after','/tmp/hillclimb-signin-density-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app')]:
 subprocess.run(['xcrun','simctl','install','8E8380DE-364D-4899-99B8-D15ED0494FFD',app],check=True)
 for style in ['light','dark']:
  for size in ['default','XXXL']:
   args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password-keyboard']
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+a for a in args]);op('wait','stable','1000','10000');j=json.loads(op('snapshot','-i','--json'));field=next(n for n in j['data']['nodes'] if n.get('type')=='SecureTextField');op('fill','@'+field['ref'],'offline-only','--settle');op('wait','stable','2000','10000')
   for state in ['focused','dismissed']:
    j=json.loads(op('snapshot','-i','--json'))
    if state=='dismissed':
     done=next(n for n in j['data']['nodes'] if n.get('type')=='Button' and n.get('label')=='Done');op('press','@'+done['ref'],'--settle');j=json.loads(op('snapshot','-i','--json'))
    field=next(n for n in j['data']['nodes'] if n.get('type')=='SecureTextField');assert field['value']=='•'*12,field
    name=f'{phase}-{style}-{size}-{state}';(out/(name+'.json')).write_text(json.dumps(j,indent=2));f=out/(name+'.png');op('screenshot',str(f),'--pixel-density','3');rows.append(dict(file=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),state=state,phase=phase,style=style,size=size,secureValue=field['value']));(p/'settled-secure.json').write_text(json.dumps(rows,indent=2))
 print(phase,'settled secure',flush=True)
subprocess.run(['python3',str(p/'identity.py')],check=True)
