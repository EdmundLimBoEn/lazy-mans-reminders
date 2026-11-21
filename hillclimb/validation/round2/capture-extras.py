"""Fresh offline round2 captures. Written by gpt-6.1-sol in Codex on behalf of Edmund"""
import subprocess,json,pathlib,time,hashlib,struct
A='/Users/limboenedmund/.t3/userdata/device/targets/t3-575f6498c28b7806ff449831/agent-device'
O=pathlib.Path('hillclimb/rounds/2/extras'); O.mkdir(parents=True,exist_ok=True)
P=O/'manifest.json'
m=json.loads(P.read_text()) if P.exists() else {'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'captures':[],'operations':[],'settle_seconds':3}
def save(): P.write_text(json.dumps(m,indent=2)+'\n')
def run(*args):
 r=subprocess.run([A,*args],capture_output=True,text=True);m['operations'].append({'argv':[A,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save(); print(r.stdout[-500:],flush=True);r.check_returncode()
def launch(state,style,size,variant=None):
 args=['open','systems.edmundlim.NotepadHillclimb','--relaunch','--launch-args=--hillclimb-demo','--launch-args='+state,'--launch-args=--hillclimb-style','--launch-args='+style,'--launch-args=--hillclimb-size','--launch-args='+size]
 if variant: args+=['--launch-args=--hillclimb-signin-variant','--launch-args='+variant]
 run(*args);time.sleep(3)
def shot(name):
 p=O/(name+'.png');run('screenshot',str(p.resolve()),'--pixel-density','3','--normalize-status-bar');b=p.read_bytes();m['captures'].append({'file':p.name,'status':'captured','sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24]))});save()
for style in ('light','dark'):
 run('settings','appearance',style)
 for variant in ('default','password-keyboard','error','inbox'):
  launch('signin',style,'XXXL',variant);shot('signin-'+style+'-XXXL-'+variant)
 for state in ('empty','composer'):
  launch(state,style,'XXXL')
  if state=='composer':run('click',"label='New reminder'");time.sleep(3)
  shot(state+'-'+style+'-XXXL')
 for size in ('default','XXXL'):
  run('settings','text-size','extra-extra-extra-large' if size=='XXXL' else 'large')
  launch('account',style,size)
  if size=='XXXL':
   shot('account-'+style+'-'+size+'-large-top');run('swipe','201','780','201','240','--count','8','--pause-ms','300');time.sleep(3);shot('account-'+style+'-'+size+'-large-lower');launch('account',style,size)
  run('gesture','pan','201','69','0','355','600');time.sleep(3);shot('account-'+style+'-'+size+'-medium-top')
