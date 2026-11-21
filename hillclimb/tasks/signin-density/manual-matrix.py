"""Complete native before/after matrix, no screenshot edits. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,sys,json,hashlib
p=pathlib.Path(__file__).parent;phase=sys.argv[1];out=p/(phase+'-complete');out.mkdir(exist_ok=True);rows=[]
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
def tree():return json.loads(op('snapshot','-i','--json'))
def snap(style,size,state,args):
 name=f'{style}-{size}-{state}';j=tree();(out/(name+'.json')).write_text(json.dumps(j,indent=2));f=out/(name+'.png');assert not f.exists();op('screenshot',str(f),'--pixel-density','3');rows.append(dict(file=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),arguments=args,state=state,fullDevice=True));(p/(phase+'-complete.json')).write_text(json.dumps(rows,indent=2))
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['default','password','loading','error','inbox','password-keyboard','enabled-paint','enabled-default']:
   args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password' if variant=='enabled-paint' else 'default' if variant=='enabled-default' else variant]
   if variant in ['enabled-paint','enabled-default']:args+=['--hillclimb-signin-appearance','enabled']
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+a for a in args]);op('wait','stable','1000','10000');snap(style,size,variant,args)
   if variant=='password-keyboard':
    j=tree();node=next(n for n in j['data']['nodes'] if n.get('type')=='SecureTextField');op('fill','@'+node['ref'],'offline-only','--settle');snap(style,size,'populated-focused',args)
    j=tree();node=next(n for n in j['data']['nodes'] if n.get('label')=='Done' and n.get('type')=='Button');op('press','@'+node['ref'],'--settle');snap(style,size,'populated-dismissed',args)
    op('gesture','pan','201','745','0','-520','600');op('gesture','pan','201','745','0','-520','600');op('wait','stable','1000','10000');snap(style,size,'legal-bottom',args)
  print(phase,style,size,flush=True)
