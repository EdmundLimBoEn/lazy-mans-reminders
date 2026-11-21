"""Only this task's pinned device command. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,datetime,sys,hashlib
p=pathlib.Path(__file__).parent
command='/Users/limboenedmund/.t3/userdata/device/targets/t3-016b7667478b6f251b147cff/agent-device'
path=p/'manual-operations.json';records=json.loads(path.read_text()) if path.exists() else []
args=sys.argv[1:];start=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=subprocess.run([command,*args],capture_output=True,text=True)
entry=dict(command=[command,*args],startedUTC=start,exit=r.returncode,stdout=r.stdout,stderr=r.stderr)
if args and args[0]=='screenshot' and r.returncode==0:
 f=pathlib.Path(args[1]);entry['sha256']=hashlib.sha256(f.read_bytes()).hexdigest()
records.append(entry);path.write_text(json.dumps(records,indent=2));print(r.stdout,end='');print(r.stderr,end='',file=sys.stderr);sys.exit(r.returncode)
