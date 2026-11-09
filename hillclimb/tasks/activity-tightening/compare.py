"""Compare actual recognized glyphs; labels/source alone never pass the word gate.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib
p=Path(__file__).parent
before=json.loads((p/'before-native-gates.json').read_text());after=json.loads((p/'after-native-gates.json').read_text());records=[]
for a,b in zip(before,after):
 assert a['file']==b['file'] and a['originals']==b['originals'] and a['hidden']==b['hidden']
 rows=[]
 for x,y in zip(a['rows'],b['rows']):
  old,new=x['text'],y['text']
  if old.startswith('Demo '):
   # OCR spells the visible ellipsis as three periods on this runtime.
   prefix=old[:-3] if old.endswith('...') else old[:-1] if old.endswith('…') else old
   preserves=new.startswith(prefix)
   gain=preserves and len(new.rstrip('.…'))>len(old.rstrip('.…'))
   assert preserves,(a['file'],old,new)
  else:
   preserves=old==new;gain=False;assert preserves
  rows.append(dict(before=old,after=new,preservesRecognizedContent=preserves,readableCharacterGain=gain,beforeInkBox=x['inkBox'],afterInkBox=y['inkBox']))
 records.append(dict(file=a['file'],rows=rows))
(p/'comparison.json').write_text(json.dumps(dict(rows=records,anyReadableGain=any(r['readableCharacterGain'] for f in records for r in f['rows']),basis='Vision OCR from actual native captures; original-resolution manual inspection required separately'),indent=2))
print(json.dumps(records,indent=2))
