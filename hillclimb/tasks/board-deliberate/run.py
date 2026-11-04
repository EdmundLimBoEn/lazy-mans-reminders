import subprocess,sys,json,datetime,pathlib
out=pathlib.Path(__file__).parent
name=sys.argv[1];cmd=sys.argv[2:]
r={'command':cmd,'startedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'observations':[]}
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
for line in p.stdout:
 if any(x in line.lower() for x in ['warning:','error:','failed','passed','executed','** test','invalid frame']):
  r['observations'].append(line.rstrip());print(line.rstrip(),flush=True)
r['exit']=p.wait();r['endedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat();(out/(name+'.json')).write_text(json.dumps(r,indent=2)+'\n');sys.exit(r['exit'])
