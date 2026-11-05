"""Owned original17 native matrix. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,json,pathlib,datetime
p=pathlib.Path(__file__).parent
cmd=['python3',(str(p/'capture-long.py') if len(__import__('sys').argv)>2 else 'scripts/hillclimb/capture-activity.py'),'--command',json.load(open(p/'device.json'))['command'],'--device',str(p/'device.json'),'--out',str(p/__import__('sys').argv[1])]
record={'command':cmd,'startUTC':datetime.datetime.now(datetime.timezone.utc).isoformat()}
r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
record.update(exit=r.returncode,output=r.stdout,endUTC=datetime.datetime.now(datetime.timezone.utc).isoformat());(p/(__import__('sys').argv[1]+'-capture-run.json')).write_text(json.dumps(record,indent=2));print(r.stdout[-4000:]);raise SystemExit(r.returncode)
