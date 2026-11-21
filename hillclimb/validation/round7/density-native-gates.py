"""Summarize native attachment measurements from the completed combined run.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,re
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');rhythm=[];helpers=[];layouts=[];groups=[]
def text(group):
 d=t/('full-v2-'+group)
 for test in json.loads((d/'manifest.json').read_text()):
  for a in test['attachments']:
   f=d/a['exportedFileName']
   if f.suffix=='.txt':yield a['suggestedHumanReadableName'],f.read_text(),str(f)
for name,s,f in text('AccountDensityUITests'):
 if '-section-rhythm' in name:
  gap=float(re.search(r'gap=([\d.]+)',s)[1]);boundary=float(re.search(r'boundary=([\d.]+)',s)[1]);assert gap>=16 and boundary>=16;rhythm.append(dict(name=name,gap=gap,boundary=boundary,raw=f))
 if 'contrast=' in s:
  c=float(re.search(r'contrast=([\d.]+)',s)[1]);assert c>=7;helpers.append(dict(name=name,contrast=c,raw=f))
for name,s,f in text('BoardCapacityDensityUITests'):
 if not name.startswith('density-layout-'):continue
 baseline=float(re.search(r'baselineFooterHeight=([\d.]+)',s)[1]);actual=float(re.search(r'actualFooterHeight=([\d.]+)',s)[1]);assert abs(baseline-actual-16)<=1e-9;layouts.append(dict(name=name,baseline=baseline,actual=actual,savedPoints=baseline-actual,nativeMeasurement=s,raw=f))
for name,s,f in text('SignInDensityUITests'):
 if not name.startswith('density-gaps-'):continue
 g=json.loads(s);gaps={}
 for a,b,expected in [('emailHeading','emailHelper',8),('emailHelper','emailField',8),('passwordHeading','passwordField',8),('passwordField','passwordHelper',8),('emailGroup','passwordGroup',20),('passwordGroup','actionGroup',20)]:
  v=g[b][1]-g[a][1]-g[a][3];assert abs(v-expected)<=1e-9;gaps[a+'→'+b]=v
 assert g['emailField'][3]>=44 and g['passwordField'][3]>=44
 groups.append(dict(name=name,frames=g,gaps=gaps,raw=f))
assert len(rhythm)==4 and len(helpers)==24 and len(layouts)==4 and len(groups)==4
result=dict(account=dict(rhythm=rhythm,helperInk=helpers,minimumHelperContrast=min(v['contrast'] for v in helpers)),capacity=layouts,signin=groups,frozenRTByteProof=str(t/'frozen-RT.json'),sourceIdentity=json.loads((t/'freeze.json').read_text())['sourceIdentity'])
(p/'density-native-gates.json').write_text(json.dumps(result,indent=2));print('Native R/T/S measurements verified')
