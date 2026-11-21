"""Native enabled-inert legal footer after real pan, separate from launch-bottom fixture.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import json,subprocess,pathlib
p=pathlib.Path(__file__).parent;out=pathlib.Path('hillclimb/rounds/6/signin-legal-pan');out.mkdir(exist_ok=True);cases=[]
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True)
 r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  name=f'{style}-{size}-enabled-after-real-pan';op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
  args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password','--hillclimb-signin-appearance','enabled']
  op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in args]);op('wait','stable','1000','10000');op('snapshot','-i')
  op('gesture','pan','201','745','0','-420','600');op('wait','stable','1000','10000')
  tree=json.loads(op('snapshot','-i','--json'));(out/(name+'.ax.json')).write_text(json.dumps(tree,indent=2))
  nodes=tree['data']['nodes'];export=next(n for n in nodes if n.get('identifier')=='hillclimb.geometry');geometry=json.loads(export['value']);safe=geometry['safeArea'];bottom=safe[1]+safe[3]
  links={label:json.loads(op('get','attrs','label="'+label+'"')) for label in ['Privacy','Terms','Support']}
  for a in links.values():
   assert a['hittable'] and a['enabled'];r=a['rect'];assert r['y']+r['height']+8<=bottom
  f=out/(name+'.png');assert not f.exists();op('screenshot',str(f),'--pixel-density','3')
  cases.append(dict(file=str(f),style=style,size=size,links=links,safeBottom=bottom,realPan=True,enabledInert=True,launchBottomArgument=False));(p/'legal-pan-geometry.json').write_text(json.dumps(cases,indent=2));print(name,flush=True)
assert len(cases)==4
