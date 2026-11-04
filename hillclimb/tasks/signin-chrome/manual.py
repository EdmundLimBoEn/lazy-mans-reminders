import subprocess,sys,json,pathlib,time
p=pathlib.Path(__file__).parent
cmd=['/Users/limboenedmund/.t3/userdata/device/targets/t3-cb45bb146809a4b03675fe22/agent-device',*sys.argv[1:]]
r=subprocess.run(cmd,capture_output=True,text=True)
with (p/'manual-operations.jsonl').open('a') as f:f.write(json.dumps(dict(time=time.time(),command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr))+'\n')
print(r.stdout,end='');print(r.stderr,end='',file=sys.stderr);sys.exit(r.returncode)
