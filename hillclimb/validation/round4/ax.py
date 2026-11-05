"""Bounded native Settings exploration and selected evidence.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,sys,subprocess,json,datetime,hashlib,struct
P=pathlib.Path(__file__).parent;O=pathlib.Path('hillclimb/rounds/4/accessibility');O.mkdir(parents=True,exist_ok=True);M=O/'manifest.json';C='/Users/limboenedmund/.t3/userdata/device/targets/t3-caa222dd4a63ee4f2b92619f/agent-device';m=json.loads(M.read_text()) if M.exists() else dict(sourceSHA=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),operations=[],captures=[])
def save():M.write_text(json.dumps(m,indent=2))
def run(*args):
 r=subprocess.run([C,*args],capture_output=True,text=True);m['operations'].append(dict(argv=[C,*args],UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit=r.returncode,stdout=r.stdout,stderr=r.stderr));save();print(r.stdout,r.stderr);r.check_returncode();return r.stdout
if sys.argv[1]=='shot':
 name=sys.argv[2];f=O/(name+'.png');assert not f.exists();run('wait','stable','1000','10000');(O/(name+'.txt')).write_text(run('snapshot','-i'));(O/(name+'.json')).write_text(run('snapshot','-i','--json'));run('screenshot',str(f.resolve()),'--pixel-density','3');b=f.read_bytes();m['captures'].append(dict(file=f.name,sha256=hashlib.sha256(b).hexdigest(),dimensions=list(struct.unpack('>II',b[16:24]))));save()
else:run(*sys.argv[1:])
