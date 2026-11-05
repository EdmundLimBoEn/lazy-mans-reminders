import pathlib, subprocess, json, hashlib, time, sys, argparse, re
parser=argparse.ArgumentParser();parser.add_argument("--command",required=True);parser.add_argument("--out",required=True,type=pathlib.Path);parser.add_argument("mode",choices=["normal","detents","guidance","errors"]);a=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[2]
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
command=a.command
manifest={'device':{'hostId':'local','id':'78F5A64F-7B2E-4562-8EF9-10F3312CC694'},'command':command,'sourceInputs':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'operations':[],'images':[]}
manifestpath=out/('captures-'+a.mode+'.json')
if manifestpath.exists():manifest=json.loads(manifestpath.read_text())
def op(*args):
    p=subprocess.run([command,*args],capture_output=True,text=True)
    manifest['operations'].append(dict(argv=[command,*args],exit=p.returncode,stdout=p.stdout,stderr=p.stderr,time=time.time()))
    manifestpath.write_text(json.dumps(manifest,indent=2))
    if p.returncode: raise RuntimeError(p.stdout+p.stderr)
    return p.stdout
def refresh_visible_row():
    op('scroll','top','--settle')
    for _ in range(12):
        snapshot=op('snapshot','-i')
        refs=re.findall(r'^(@e\d+(?:~s\d+)?) \[[^]]+\] "Refresh Board Now"',snapshot,re.M)
        for ref in refs:
            attrs=json.loads(op('get','attrs',ref))
            if attrs.get('hittable'):
                op('press',ref,'--settle')
                return
        op('scroll','down','0.15','--settle')
    raise RuntimeError('Refresh Board Now not hittable after bounded settled scrolling')
def open_fixture(style,size,state=None):
    op('settings','appearance',style)
    op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
    args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
    launch=['--hillclimb-demo','account','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-account-appearance','enabled']
    if state: launch+=['--hillclimb-account-state',state]
    for value in launch: args+=['--launch-args='+value]
    return op(*args)
def shot(name):
    op('wait','stable','1000','10000')
    op('snapshot')
    geometry=op('get','attrs','id="account.geometry"')
    p=out/'screens'/f'{name}.png';p.parent.mkdir(exist_ok=True)
    if p.exists(): return
    op('screenshot',str(p),'--pixel-density','3')
    manifest['images'].append(dict(path=str(p.relative_to(root)),geometry=geometry,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    manifestpath.write_text(json.dumps(manifest,indent=2))
    print(name,flush=True)
if a.mode=='normal':
    for style in ['light','dark']:
        for size in ['default','XXXL']:
            prefix=f'{a.mode}-{style}-{size}'
            print(open_fixture(style,size),flush=True)
            shot(prefix+'-large-top')
            op('press','role=button label="Add a lasting widget"','--settle')
            shot(prefix+'-expanded-top')
            op('scroll','down','0.5','--settle')
            shot(prefix+'-expanded-guidance')
            op('scroll','bottom','--settle')
            shot(prefix+'-expanded-lower')
elif a.mode=='detents':
    for style in ['light','dark']:
        for size in ['default','XXXL']:
            for expanded in [False,True]:
                print(open_fixture(style,size),flush=True)
                prefix=f'detents-{style}-{size}-'+('expanded' if expanded else 'normal')
                if expanded: op('press','role=button label="Add a lasting widget"','--settle')
                op('gesture','pan','201','69','0','377','700')
                shot(prefix+'-medium-top')
                op('scroll','bottom','--settle')
                shot(prefix+'-medium-lower')
elif a.mode=='guidance':
    for style in ['light','dark']:
        for size in ['default','XXXL']:
            print(open_fixture(style,size),flush=True)
            op('scroll','down','0.4','--settle')
            shot(f'normal3-{style}-{size}-persistence-centered')
elif a.mode=='errors':
    for style in ['light','dark']:
        for size in ['default','XXXL']:
            for state in ['error','refresh-error']:
                prefix=f'{state}-{style}-{size}'
                if (out/'screens'/f'{prefix}-medium-lower.png').exists(): continue
                print(open_fixture(style,size,state),flush=True)
                shot(prefix+'-initial')
                refresh_visible_row()
                shot(prefix+'-recovered')
                op('press','label="Refresh Board Now"','--settle')
                shot(prefix+'-reappeared')
                op('gesture','pan','201','69','0','377','700')
                shot(prefix+'-medium-reappeared')
                refresh_visible_row()
                shot(prefix+'-medium-recovered')
                op('scroll','bottom','--settle')
                shot(prefix+'-medium-lower')
