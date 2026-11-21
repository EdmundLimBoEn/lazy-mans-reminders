"""Compare per-method native Settings values, never just final cleanup.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re,sys
p=pathlib.Path(__file__).parent;name=sys.argv[1];d=p/(name+'-AccessibilitySettingsUITests');manifest=json.loads((d/'manifest.json').read_text());proof=[]
labels=['Reduce Motion','Auto-Play Message Effects','Reduce Transparency','Increase Contrast']
if name=='combined':
 extra=p/'combined-SignInChromeUITests'
 manifest += [{**t,'exportDir':str(extra)} for t in json.loads((extra/'manifest.json').read_text())]
for test in manifest:
 values={}
 for a in test['attachments']:
  title=a.get('suggestedHumanReadableName','')
  if not title.startswith('settings-values-'):continue
  text=(pathlib.Path(test.get('exportDir',str(d)))/a['exportedFileName']).read_text();page=re.search(r'page=(.*?) stage=',text).group(1);stage=re.search(r'stage=(\S+)',text).group(1)
  vals={l:re.search(r'^'+re.escape(l)+r'=([01])$',text,re.M).group(1) for l in labels if re.search(r'^'+re.escape(l)+r'=([01])$',text,re.M)}
  values[page+'-'+stage]=vals
 if not values:continue
 original={**values['Motion-original'],**values['Display & Text Size-original']};restored={**values['Motion-restored'],**values['Display & Text Size-restored']}
 assert all(l in original and l in restored and original[l]==restored[l] for l in labels),(test['testIdentifier'],original,restored)
 proof.append(dict(test=test['testIdentifier'],original=original,restored=restored,allFourMatch=True,attachments=values))
assert len(proof)==(3 if name=='combined' else 2)
(p/(name+'-restoration-proof.json')).write_text(json.dumps(proof,indent=2));print(json.dumps(proof,indent=2))
