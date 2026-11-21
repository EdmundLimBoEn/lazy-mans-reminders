"""Owned pinned UI command journal. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,datetime,sys
p=pathlib.Path(__file__).parent
cmd=['/Users/limboenedmund/.t3/userdata/device/targets/t3-970bc9edde073e3960a1f725/agent-device',*sys.argv[1:]]
r=subprocess.run(cmd,capture_output=True,text=True)
with (p/'manual-operations.jsonl').open('a') as f:f.write(json.dumps(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr,time=datetime.datetime.now(datetime.timezone.utc).isoformat()))+'\n')
print(r.stdout or r.stderr);sys.exit(r.returncode)
