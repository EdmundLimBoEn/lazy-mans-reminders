"""Per-method original and restored native Settings values.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re,subprocess
p=pathlib.Path(__file__).parent;proof=[];labels=['Reduce Motion','Auto-Play Message Effects','Reduce Transparency','Increase Contrast']
for group in ['AccessibilitySettingsUITests','SignInChromeUITests']:
 d=pathlib.Path('/tmp/hillclimb-capacity-density-T-final-'+group)
 r=subprocess.run(['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-capacity-density-T-final.xcresult','--output-path',str(d),'--test-id',group],capture_output=True,text=True);r.check_returncode()
 for test in json.loads((d/'manifest.json').read_text()):
  values={};raw={}
  for a in test['attachments']:
   title=a.get('suggestedHumanReadableName','')
   if not title.startswith('settings-values-'):continue
   text=(d/a['exportedFileName']).read_text();page=re.search(r'page=(.*?) stage=',text).group(1);stage=re.search(r'stage=(\S+)',text).group(1)
   vals={l:re.search(r'^'+re.escape(l)+r'=([01])$',text,re.M).group(1) for l in labels if re.search(r'^'+re.escape(l)+r'=([01])$',text,re.M)}
   values[page+'-'+stage]=vals;raw[page+'-'+stage]=text
  if not values:continue
  original={**values['Motion-original'],**values['Display & Text Size-original']};restored={**values['Motion-restored'],**values['Display & Text Size-restored']};assert all(l in original and l in restored and original[l]==restored[l] for l in labels)
  proof.append(dict(test=test['testIdentifier'],original=original,restored=restored,allFourMatch=True,attachments=values,raw=raw))
assert len(proof)==3
(p/'final-restoration-proof.json').write_text(json.dumps(proof,indent=2));print('All 3 methods restore all 4 original switches at their own teardown')
