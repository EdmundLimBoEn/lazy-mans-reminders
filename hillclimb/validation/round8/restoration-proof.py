"""Check each Settings-changing method independently, including the new focus matrix.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser();p.add_argument('--export',default='/tmp/hillclimb-focus-round8-proof-export');p.add_argument('--output',default='hillclimb/validation/round8/historical-restoration-proof.json');p.add_argument('--expected',type=int,default=5);a=p.parse_args();d=Path(a.export);labels=['Reduce Motion','Auto-Play Message Effects','Reduce Transparency','Increase Contrast'];proof=[]
for test in json.loads((d/'manifest.json').read_text()):
 values={}
 for item in test['attachments']:
  if not item['suggestedHumanReadableName'].startswith('settings-values-'):continue
  f=d/item['exportedFileName'];text=f.read_text();page=re.search(r'page=(.*?) stage=',text).group(1);stage=re.search(r'stage=(\S+)',text).group(1);values[page+'-'+stage]={label:re.search(r'^'+re.escape(label)+r'=([01])$',text,re.M).group(1) for label in labels if re.search(r'^'+re.escape(label)+r'=([01])$',text,re.M)}
 if not values:continue
 original={**values['Motion-original'],**values['Display & Text Size-original']};restored={**values['Motion-restored'],**values['Display & Text Size-restored']};assert all(label in original and label in restored and original[label]==restored[label] for label in labels),(test['testIdentifier'],values)
 proof.append(dict(test=test['testIdentifier'],original=original,restored=restored,allFourMatch=True,stages=values))
assert len(proof)==a.expected,len(proof)
Path(a.output).write_text(json.dumps(proof,indent=2)+'\n');print(len(proof),'Settings methods each restored all four originals')
