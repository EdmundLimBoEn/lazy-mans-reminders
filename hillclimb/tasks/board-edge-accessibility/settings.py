"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,sys,pathlib,json,datetime
p=pathlib.Path(__file__).parent;f=p/'settings-operations.json';ops=json.loads(f.read_text()) if f.exists() else [];cmd='/Users/limboenedmund/.t3/userdata/device/targets/t3-a803bea57ca3e1602b21f618/agent-device'
def run(args):
 r=subprocess.run([cmd,*args],capture_output=True,text=True);ops.append(dict(command=[cmd,*args],utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit=r.returncode,stdout=r.stdout,stderr=r.stderr));f.write_text(json.dumps(ops,indent=2));print(r.stdout,r.stderr);r.check_returncode();return r.stdout
if sys.argv[1]=='shot':
 name=sys.argv[2];(p/(name+'.txt')).write_text(run(['snapshot','-i']));(p/(name+'.json')).write_text(run(['snapshot','-i','--json']));run(['screenshot',str(p/(name+'.png')),'--pixel-density','3'])
else:run(sys.argv[1:])
