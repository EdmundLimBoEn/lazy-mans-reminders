"""Native task evidence, using only the task's pinned device command.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,pathlib,json,hashlib,datetime,struct,re
O=pathlib.Path(__file__).parent/'captures';O.mkdir(exist_ok=True)
C='/Users/limboenedmund/.t3/userdata/device/targets/t3-f9240c589a3a12442f06f839/agent-device'
M=O/'manifest.json'
m=json.loads(M.read_text()) if M.exists() else {'sourceInputHashes':'../final-input-hashes.json','sourceSHA':'aa69cb4f888f2fbd4318f61a7fd03bc86d46d087','sourceBase':'9d484764b5317fe6367411998ef2b6432567f637','device':{'hostId':'local','id':'066ECE57-46B4-414A-B53E-523775329360'},'operations':[],'captures':[]}
def save(): M.write_text(json.dumps(m,indent=2)+'\n')
def run(*args):
 r=subprocess.run([C,*args],capture_output=True,text=True);m['operations'].append({'argv':[C,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save()
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
def settle():run('wait','stable','1000','10000')
def launch(mode,style,size,*extra):
 args=['--hillclimb-demo',mode,'--hillclimb-style',style,'--hillclimb-size',size,*extra]
 run('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in args]);settle()
def geometry():
 tree=run('snapshot','-i')
 match=re.search(r'(\{"[^\n]*fixtureCount[^\n]*\})',tree)
 if not match:raise RuntimeError('No measured native geometry in snapshot')
 return json.loads(match.group(1).replace('\\"','"'))
def shot(name):
 if any(x['file']==name+'.png' for x in m['captures']):return
 settle();(O/(name+'.txt')).write_text(run('snapshot','-i'));(O/(name+'.geometry.json')).write_text(json.dumps(geometry(),indent=2))
 f=O/(name+'.png');run('screenshot',str(f.resolve()),'--pixel-density','3','--normalize-status-bar')
 b=f.read_bytes();m['captures'].append({'file':f.name,'sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'UTC':datetime.datetime.now(datetime.timezone.utc).isoformat()});save();print(name,flush=True)
def bottom():
 run('swipe','180','250','180','550');settle()
 for _ in range(12):
  run('gesture','fling','up','180','650','500');settle();g=geometry()
  row=g.get('00000000-0000-4000-8000-000000000007')
  if row and row[1]>=g['listViewport'][1] and row[1]+row[3]<=g['composer'][1]+.5:return
 raise RuntimeError('Final row did not settle fully above composer')
for style in ['light','dark']:
 run('settings','appearance',style)
 for size in ['default','XXXL']:
  prefix=style+'-'+size
  if any(x['file']==prefix+'-completion-after.png' for x in m['captures']):continue
  run('settings','text-size','extra-extra-extra-large' if size=='XXXL' else 'large')
  launch('long-text' if size=='XXXL' else 'full',style,size);shot(prefix+'-top');bottom();shot(prefix+'-true-bottom-after-pull')
  launch('empty',style,size);shot(prefix+'-guide')
  run('click',"label='New reminder'");run('fill',"label='New reminder'",'Remember the weekly review');shot(prefix+'-nonempty-focused')
  run('click',"label='Done'");shot(prefix+'-nonempty-dismissed');run('click',"label='New reminder'");shot(prefix+'-nonempty-refocused');run('click',"label='Done'")
  launch('full',style,size,'--hillclimb-board-state','error-populated','--hillclimb-board-retry','recover');shot(prefix+'-populated-error');bottom();shot(prefix+'-populated-error-bottom');run('click',"label='Try Again'");shot(prefix+'-retry-recovered')
  launch('long-text',style,size,'--hillclimb-board-interaction','local');shot(prefix+'-completion-before')
  g=geometry();rect=g['text-00000000-0000-4000-8000-000000000001']
  run('click',str(rect[0]+rect[2]/2),str(rect[1]+rect[3]/2));shot(prefix+'-completion-text-tap')
  assert geometry()['boardCompletions'][0]==0
  circle=g['circle-00000000-0000-4000-8000-000000000001']
  run('click',str(circle[0]+1),str(circle[1]+circle[3]/2));shot(prefix+'-completion-after')
  assert geometry()['boardCompletions'][0]==1
run('settings','appearance','light');run('settings','text-size','large')
