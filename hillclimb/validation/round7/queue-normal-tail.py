"""Continue the one serial capture window after its existing owned process.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,time,os,subprocess
p=Path(__file__).parent
first=['core','bottom','extras','enabled','board','keyboards','motion','account-normal','account-detents','account-guidance','account-errors','activity']
while not (p/'capture-activity.json').exists():
 for name in first:
  f=p/('capture-'+name+'.json')
  if f.exists():assert json.loads(f.read_text())[-1]['exit']==0,(name,'prior capture failed; no automatic retry')
 try:os.kill(78643,0)
 except ProcessLookupError:raise RuntimeError('Initial capture process ended before the final Activity proof; stop the queue')
 time.sleep(15)
assert all(json.loads((p/('capture-'+name+'.json')).read_text())[-1]['exit']==0 for name in first)
print('Initial serial capture batch completed; starting normal supplements',flush=True)
r=subprocess.run(['python3',str(p/'capture.py'),'long-activity','signin-chrome-normal','paint-normal','edge'])
raise SystemExit(r.returncode)
