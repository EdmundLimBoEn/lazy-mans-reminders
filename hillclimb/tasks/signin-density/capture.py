"""Pinned full-device supplements. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,sys,json,hashlib
p=pathlib.Path(__file__).parent;phase=sys.argv[1];out=p/(phase+'-manual');out.mkdir(exist_ok=True)
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode: print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
rows=[]
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['password','password-keyboard']:
   args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+a for a in args]);op('wait','stable','1000','10000')
   states=['initial','bottom'] if variant=='password' else ['focused']
   for state in states:
    if state=='bottom':op('gesture','pan','201','745','0','-520','600');op('gesture','pan','201','745','0','-520','600');op('wait','stable','1000','10000')
    name=f'{style}-{size}-{state}';tree=op('snapshot','-i','--json');(out/(name+'.json')).write_text(tree)
    file=out/(name+'.png');op('screenshot',str(file),'--pixel-density','3');rows.append(dict(file=str(file),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),arguments=args,state=state))
    (p/(phase+'-manual.json')).write_text(json.dumps(rows,indent=2))
  print(phase,style,size,flush=True)
