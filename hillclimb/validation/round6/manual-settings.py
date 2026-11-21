"""Observed native Settings values and exact restoration. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import subprocess,json,sys
p=Path(__file__).parent

def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True);r.check_returncode()
 return r.stdout

def attrs(label):return json.loads(op('get','attrs','role=switch label="'+label+'"'))
def read(labels):return {label:attrs(label)['value'] for label in labels}
def set_value(label,want):
 a=attrs(label)
 if a['value']!=want:
  assert a['hittable'];r=a['rect'];op('press',str(r['x']+r['width']-24),str(r['y']+r['height']/2),'--settle')
 assert attrs(label)['value']==want,(label,attrs(label))
def shot(name):
 r=subprocess.run(['python3',str(p/'settings.py'),'shot',name],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr);r.check_returncode()
 print(name,flush=True)

a=sys.argv[1];motion=['Reduce Motion','Auto-Play Message Effects'];display=['Reduce Transparency','Increase Contrast']
if a=='enable':
 original=read(motion);(p/'manual-originals.json').write_text(json.dumps(original,indent=2));shot('original-motion')
 op('press','role=button label="Accessibility"','--settle');op('press','label="Display & Text Size"','--settle')
 original.update(read(display));(p/'manual-originals.json').write_text(json.dumps(original,indent=2));assert original==dict(zip(motion+display,['0','1','0','0']))
 shot('original-display')
 for label in display:set_value(label,'1')
 enabled=read(display);shot('enabled-display')
 op('press','role=button label="Accessibility"','--settle');op('press','label="Motion"','--settle');set_value('Reduce Motion','1');enabled.update(read(motion));shot('enabled-motion')
 assert all(enabled[l]=='1' for l in ['Reduce Motion',*display]);(p/'manual-enabled.json').write_text(json.dumps(enabled,indent=2));op('close','com.apple.Preferences');print(enabled)
else:
 assert a=='restore';original=json.loads((p/'manual-originals.json').read_text())
 for label in motion:set_value(label,original[label])
 restored=read(motion);shot('restored-motion')
 op('press','role=button label="Accessibility"','--settle');op('press','label="Display & Text Size"','--settle')
 for label in display:set_value(label,original[label])
 restored.update(read(display));shot('restored-display');assert restored==original
 (p/'final-manual-restoration.json').write_text(json.dumps(dict(original=original,restored=restored,allFourMatch=True),indent=2));op('close','com.apple.Preferences');print(restored)
