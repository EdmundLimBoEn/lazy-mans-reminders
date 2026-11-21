"""Pinned native captures. Written by gpt-6.1-sol in Codex on behalf of Edmund"""
import subprocess,json,pathlib,hashlib,datetime,sys
p=pathlib.Path(__file__).resolve().parent/'settled'
p.mkdir(exist_ok=True)
agent='/Users/limboenedmund/.t3/userdata/device/targets/t3-400cf86c1a8a9a773f0d3cc1/agent-device'
manifest={'device':{'hostId':'local','id':'8E8380DE-364D-4899-99B8-D15ED0494FFD','name':'Hillclimb Auth iPhone 17 Pro','model':'iPhone 17 Pro','runtime':'iOS 26.2 (23C54)','physical':False},'source_sha':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_hashes':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for d in ['ios/App','ios/Shared','ios/UITests','ios/Tests'] for f in pathlib.Path(d).glob('*.swift')},'binary_sha256':hashlib.sha256(pathlib.Path('/tmp/notepad-keyboard-recovery-dd/Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders').read_bytes()).hexdigest(),'git_status':subprocess.check_output(['git','status','--short'],text=True),'agent':agent,'captures':[],'operations':[]}
if (p/'manifest.json').exists(): manifest=json.loads((p/'manifest.json').read_text())
retry_next = bool(manifest['operations'] and manifest['operations'][-1]['exit'])
def run(args):
 r=subprocess.run([agent]+args,capture_output=True,text=True);manifest['operations'].append({'argv':[agent]+args,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});(p/'manifest.json').write_text(json.dumps(manifest,indent=2));print(args[0],r.returncode,flush=True)
 if r.returncode: raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['keyboard','password-keyboard','loading','inbox','error']:
   name=f'signin-{style}-{size}-{variant}'
   if any(c['name']==name for c in manifest['captures']): continue
   args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
   for v in ['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]:args+=['--launch-args='+v]
   if retry_next:
    args+=['--debug']; retry_next=False
   run(args)
   if 'keyboard' in variant: run(['wait','text','Done','10000'])
   run(['wait','stable','1000','10000'])
   tree=run(['snapshot','-i']);(p/(name+'.txt')).write_text(tree)
   image=p/(name+'.png');run(['screenshot',str(image),'--pixel-density','3'])
   manifest['captures'].append({'name':name,'file':image.name,'sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'time':datetime.datetime.now(datetime.timezone.utc).isoformat()})
   (p/'manifest.json').write_text(json.dumps(manifest,indent=2))
# Leave the last captured state open for device_screenshot inspection; cleanup is recorded separately.
