"""Select distinct review states; retain every native acquisition separately.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,re,collections
p=Path('hillclimb/rounds/8');rawPath=p/'native-acquisition-inventory.json';data=json.loads((rawPath if rawPath.exists() else p/'inventory.json').read_text());rows=data['images'];selected=[];excluded=[]
for r in rows:
 cls=r['testIdentifier'].split('/')[0];n=r['attachmentName'].split('_0_')[0];lower=n.lower();reason=None
 if cls in ['BoardMultilineUITests','BoardEdgeAccessibilityUITests']:
  flags=re.search(r'-(false|true)-(false|true)(?:-\d+)?$',n)
  if flags:r['appearance']='dark' if flags[1]=='true' else 'light';r['textSize']='XXXL' if flags[2]=='true' else 'default'
 if cls=='HillclimbUITests':
  r['appearance']='dark' if 'Dark' in r['testIdentifier'] else 'light'
  if 'XXXL' in r['testIdentifier']:r['textSize']='XXXL'
  elif 'Dark' not in r['testIdentifier']:r['textSize']='default'
 if cls=='BoardCapacityPresentationUITests':reason='Same capacity states retained from BoardCapacityDensityUITests; assertions still required'
 elif cls=='SignInDensityUITests' and not lower.endswith('-inbox'):reason='Equivalent login form states retained from composition/loading/Chrome matrices'
 elif cls=='SignInSurfaceUITests' and ('-keyboard' not in lower or '-password-' in lower):reason='Equivalent enabled form state or full password movie witness retained'
 elif cls=='HillclimbCaptureUITests' and ('canonical-account-' in lower or 'canonical-signin-' in lower):reason='Enabled-style Account/SignIn states retained from dedicated matrices'
 elif cls=='ActivityCaptureUITests' and r.get('imageSet')!='video-witness' and '-island' in lower:reason='Unmodified2s expanded-Island movie frame retained for matching configuration'
 elif cls=='AccessibilitySettingsUITests':
  if 'settings' in lower and 'combined-settings-signin' not in lower:reason='Native Settings stage proof; retained outside app design matrix'
  elif lower.startswith('combined-settings-signin'):reason='Equivalent full-screen keyboard witness retained'
  elif '-password-keyboard' in lower:reason='Full native secure-keyboard movie witness retained'
 elif cls=='ErrorContrastUITests' and not lower.startswith('signin-'):reason='Equivalent Account errors retained from AccountChrome matrix; raster assertions still required'
 elif cls=='SignInChromeUITests':
  if r.get('imageSet')!='video-witness' and lower.startswith('first-focus-'):reason='Equivalent complete native keyboard movie witness retained'
  elif lower.startswith('chrome-footer-'):reason='Equivalent actual legal-footer gesture states retained'
 if reason:excluded.append(dict(r,canonicalExclusion=reason))
 else:selected.append(r)
dark=sorted([r for r in rows if r['testIdentifier'].startswith('HillclimbUITests/testDark')],key=lambda r:r['timestamp'])
assert len(dark)==2
for r,size in zip(dark,['default','XXXL']):r['textSize']=size
for r in rows:
 if r.get('textSize')=='default or method-specific':r['textSize']='default'
raw=dict(data,images=rows,count=len(rows),disposition='All native acquisitions, including stress repetitions, Settings proofs and protected partial views')
(p/'native-acquisition-inventory.json').write_text(json.dumps(raw,indent=2)+'\n')
data.update(images=selected,count=len(selected),canonicalSelection='Explicit state selection; repeated acquisitions and Settings bookkeeping remain in native-acquisition-inventory.json. No extra score credit for file count.',excludedAcquisitions=excluded)
(p/'inventory.json').write_text(json.dumps(data,indent=2)+'\n')
Path('hillclimb/validation/round8/canonical-selection.json').write_text(json.dumps(dict(selected=len(selected),allNativeAcquisitions=len(rows),excluded=len(excluded),selectedByClass=dict(collections.Counter(r['testIdentifier'].split('/')[0] for r in selected)),reasonCounts=dict(collections.Counter(r['canonicalExclusion'] for r in excluded))),indent=2)+'\n')
print(len(selected),'canonical;',len(rows),'native acquisitions retained')
