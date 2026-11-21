"""Pinned native keyboard capture after actual form scroll.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,hashlib,datetime,struct,argparse
parser=argparse.ArgumentParser();parser.add_argument("--command",required=True);parser.add_argument("--out",required=True,type=pathlib.Path);parser.add_argument("--provenance",type=pathlib.Path);a=parser.parse_args()
agent=a.command
p=a.out;p.mkdir(parents=True,exist_ok=True)
m={'productionSource':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'testRevision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'validationRevision':'Working-tree capture script; retained in the evidence commit','device':{'hostId':'local','id':'78F5A64F-7B2E-4562-8EF9-10F3312CC694','os':'iOS 26.2','name':'Hillclimb iPhone 17 Pro'},'hashProof':str(a.provenance) if a.provenance else None,'operations':[],'captures':[]}
if (p/'manifest.json').exists():m=json.loads((p/'manifest.json').read_text())
def run(*args):
 r=subprocess.run([agent,*args],capture_output=True,text=True);m['operations'].append({'command':[agent,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save();r.check_returncode();return r.stdout
def save():(p/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
def stable():run('wait','stable','1000','10000')
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['keyboard','password-keyboard']:
   name=f'signin-{style}-{size}-{variant}'
   if any(c['file']==name+'.png' for c in m['captures']):continue
   args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
   for v in ['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]:args+=['--launch-args='+v]
   run(*args);run('settings','appearance',style);run('settings','text-size','large' if size=='default' else 'extra-extra-extra-large');run('wait','text','Done','10000');stable()
   before=run('snapshot','-i');(p/(name+'-before.txt')).write_text(before);assert 'Done' in before and '[key]' in before
   run('gesture','pan','201','430','0','-150','600');stable()
   tree=run('snapshot','-i')
   if '[key]' not in tree:
    run('click',"label='Password'" if variant=='password-keyboard' else "label='Email address'");run('wait','text','Done','10000');stable();tree=run('snapshot','-i')
   assert 'Done' in tree and '[key]' in tree,tree
   (p/(name+'.txt')).write_text(tree)
   (p/(name+'-geometry.json')).write_text(run('snapshot','-i','--json'));f=p/(name+'.png');run('screenshot',str(f.resolve()),'--pixel-density','3','--normalize-status-bar');b=f.read_bytes();m['captures'].append({'file':f.name,'sha256':hashlib.sha256(b).hexdigest(),'pixels':list(struct.unpack('>II',b[16:24])),'afterActualScroll':True,'DoneAndRealKeyboardInSnapshot':True,'UTC':datetime.datetime.now(datetime.timezone.utc).isoformat()});save();print(name,flush=True)
