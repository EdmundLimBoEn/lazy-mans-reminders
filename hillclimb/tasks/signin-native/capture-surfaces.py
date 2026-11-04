"""Pinned native keyboard capture after actual form scroll.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,hashlib,datetime,struct
agent='/Users/limboenedmund/.t3/userdata/device/targets/t3-2075720dbffb9ae0b9c11d28/agent-device'
p=pathlib.Path('hillclimb/tasks/signin-native/surfaces');p.mkdir(parents=True,exist_ok=True)
m={'productionSource':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'testRevision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'validationRevision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'device':{'hostId':'local','id':'8E8380DE-364D-4899-99B8-D15ED0494FFD','os':'iOS 26.2','name':'Hillclimb Auth iPhone 17 Pro'},'hashProof':'../provenance.json','operations':[],'captures':[]}
def run(*args):
 r=subprocess.run([agent,*args],capture_output=True,text=True);m['operations'].append({'command':[agent,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save();r.check_returncode();return r.stdout
def save():(p/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
def stable():run('wait','stable','1000','10000')
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['default','password','inbox','error','loading','enabled']:
   name=f'signin-{style}-{size}-{variant}'
   args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
   values=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size]
   values += ['--hillclimb-signin-appearance','enabled'] if variant=='enabled' else ['--hillclimb-signin-variant',variant]
   for v in values:args+=['--launch-args='+v]
   run(*args);run('settings','appearance',style);run('settings','text-size','large' if size=='default' else 'extra-extra-extra-large');stable()
   tree=run('snapshot','-i');(p/(name+'.txt')).write_text(tree)
   (p/(name+'-geometry.json')).write_text(run('snapshot','-i','--json'));f=p/(name+'.png');run('screenshot',str(f.resolve()),'--pixel-density','3','--normalize-status-bar');b=f.read_bytes();m['captures'].append({'file':f.name,'sha256':hashlib.sha256(b).hexdigest(),'pixels':list(struct.unpack('>II',b[16:24])),'designOnlyInertEnabledStyle':variant=='enabled','providerFlowTested':False,'UTC':datetime.datetime.now(datetime.timezone.utc).isoformat()});save();print(name,flush=True)
