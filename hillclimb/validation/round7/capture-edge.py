"""Owned pinned device operations only. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,json,pathlib,re,datetime,sys
p=pathlib.Path('hillclimb/rounds/7/edge');p.mkdir(parents=True,exist_ok=True);suffix=sys.argv[1] if len(sys.argv)>1 else '';dest=p/('captures'+suffix);dest.mkdir(exist_ok=True)
cmd='/Users/limboenedmund/.t3/userdata/device/targets/t3-23bb48939566ebc32a337197/agent-device'
operations=[]
def run(*args):
 r=subprocess.run([cmd,*args],capture_output=True,text=True);operations.append({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':[cmd,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});(p/('capture-operations'+suffix+'.json')).write_text(json.dumps(operations,indent=2));assert r.returncode==0,r.stdout+r.stderr;return r.stdout
def shot(name,kind,dark,probe=None):
 snapshot=run('snapshot','-i');(dest/(name+'.ax.json')).write_text(run('snapshot','-i','--json'));(dest/(name+'.txt')).write_text(snapshot)
 # Geometry is a JSON accessibility value printed as a quoted JSON object by snapshot.
 line=next(x for x in snapshot.splitlines() if 'listViewport' in x or ('authState' in x and 'safeArea' in x))
 raw=line[line.index('{'):line.rindex('}')+1];g=json.loads(raw)
 run('screenshot',str(dest/(name+'.png')),'--pixel-density','3');(dest/(name+'.json')).write_text(json.dumps({'geometry':g,'kind':kind,'dark':dark,'probe':probe},indent=2));return g
for dark in [False,True]:
 for xxxl in [False,True]:
  for state in ['normal','error-populated','loading','error-empty']:
   name=f'{"dark" if dark else "light"}-{"XXXL" if xxxl else "default"}-{state}'
   args=['--hillclimb-demo','full' if state in ['normal','error-populated'] else 'empty','--hillclimb-style','dark' if dark else 'light','--hillclimb-size','XXXL' if xxxl else 'default']
   if state!='normal':args+=['--hillclimb-board-state',state]
   launch=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
   for arg in args:launch+=['--launch-args',arg]
   run(*launch)
   g=shot(name+'-top','top' if state in ['normal','error-populated'] else 'diagnostic',dark,'loadingLabel' if state=='loading' else 'errorDescription')
   if state in ['normal','error-populated']:
    x,y,w,h=g['listViewport'];mid=str(x+w/2)
    run('swipe',mid,str(y+h*.25),mid,str(y+h*.65));run('swipe',mid,str(y+h*.8),mid,str(y+h*.2),'--count','8','--pause-ms','350')
    shot(name+'-bottom','bottom',dark)

if suffix: sys.exit(0)
for dark in [False,True]:
 for xxxl in [False,True]:
  name=f'{"dark" if dark else "light"}-{"XXXL" if xxxl else "default"}-completion'
  args=['--hillclimb-demo','long-text','--hillclimb-style','dark' if dark else 'light','--hillclimb-size','XXXL' if xxxl else 'default','--hillclimb-board-interaction','local']
  launch=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
  for arg in args:launch+=['--launch-args',arg]
  run(*launch);g=shot(name+'-before','completion',dark)
  x,y,w,h=g['text-00000000-0000-4000-8000-000000000001']
  run('press',str(x+w/2),str(y+h/2));g=shot(name+'-text-tap','completion',dark);assert g['boardCompletions'][0]==0
  x,y,w,h=g['circle-00000000-0000-4000-8000-000000000001']
  run('press',str(x+w*.03),str(y+h/2));g=shot(name+'-circle-edge','completion',dark);assert g['boardCompletions'][0]==1
