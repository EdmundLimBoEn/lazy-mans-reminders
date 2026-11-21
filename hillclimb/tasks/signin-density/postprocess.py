"""Structured result collection after the single full run. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,time,json
p=pathlib.Path(__file__).parent
while not (p/'full-process.json').exists():time.sleep(15)
for script,args in [('collect.py',['full']),('runtime.py',['full']),('metrics.py',[]),('restoration.py',['full']),('accept.py',[])]:
 r=subprocess.run(['python3',str(p/script),*args],capture_output=True,text=True)
 print(script,'exit',r.returncode, (r.stdout+r.stderr)[-1400:] if r.returncode else '',flush=True)
 if r.returncode:break
