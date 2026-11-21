"""Compare each method's original switches with native restored values.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re
p=pathlib.Path(__file__).parent;proof=[]
entries=[(d,t) for d in [p/'full',p/'full-settings'] for t in json.loads((d/'manifest.json').read_text())]
for d,test in entries:
 values={}; originals={}
 for a in test['attachments']:
  title=a.get('suggestedHumanReadableName','')
  if title.startswith('settings-values-'):
   txt=(d/a['exportedFileName']).read_text();page=re.search(r'page=(.*?) stage=',txt).group(1);stage=re.search(r'stage=(\S+)',txt).group(1)
   vals={l:re.search('^'+re.escape(l)+r'=([01])$',txt,re.M).group(1) for l in ['Reduce Motion','Auto-Play Message Effects','Reduce Transparency','Increase Contrast'] if re.search('^'+re.escape(l)+r'=([01])$',txt,re.M)}
   values[page+'-'+stage]=vals
  if title.startswith('chrome-settings-'):
   txt=(d/a['exportedFileName']).read_text()
   for label,boolean in re.findall(r'"([^"]+)": (true|false)',txt.splitlines()[0]):originals[label]='1' if boolean=='true' else '0'
   if '-restored' in title:
    for label in ['Reduce Motion','Auto-Play Message Effects','Reduce Transparency','Increase Contrast']:
     m=re.search(r'Switch,.*label: \''+re.escape(label)+r"', value: ([01])",txt)
     if m: values[label]=m.group(1)
 if 'Motion-original' in values:
  original={**values['Motion-original'],**values['Display & Text Size-original']};restored={**values['Motion-restored'],**values['Display & Text Size-restored']}
  assert len(original)==4 and original==restored
  proof.append(dict(test=test['testIdentifier'],original=original,restored=restored))
 elif originals:
  assert len(originals)==4 and originals==values,(originals,values)
  proof.append(dict(test=test['testIdentifier'],original=originals,restored=values))
assert len(proof)==3
(p/'restoration-proof.json').write_text(json.dumps(proof,indent=2));print('Three methods restored all four originals')
