"""Ordinary-fixture full-device supplements, never the failed paint fixture.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,hashlib
p=pathlib.Path(__file__).parent; out=p/'manual-native';out.mkdir(exist_ok=True);records=[]
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
  args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password']
  op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+a for a in args]);op('wait','stable','1000','10000')
  for stage in ['initial','bottom']:
   if stage=='bottom':
    op('gesture','pan','201','745','0','-520','600');op('gesture','pan','201','745','0','-520','600');op('wait','stable','1000','10000')
   name=f'{style}-{size}-{stage}';tree=op('snapshot','-i','--json');(out/(name+'.ax.json')).write_text(tree)
   file=out/(name+'.png');assert not file.exists();op('screenshot',str(file),'--pixel-density','3')
   records.append(dict(file=str(file),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),style=style,size=size,stage=stage,ordinary=True,actualPan=stage=='bottom',launchArguments=args))
   (p/'manual-native.json').write_text(json.dumps(records,indent=2))
  print(style,size,flush=True)
