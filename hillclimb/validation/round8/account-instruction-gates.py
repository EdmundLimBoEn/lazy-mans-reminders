"""Verify native helper raster results and original complete instruction strings.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,re,hashlib,ast,subprocess
p=Path('/tmp/hillclimb-focus-round8-account-helper-export');rows=[]
for t in json.loads((p/'manifest.json').read_text()):
 for a in t['attachments']:
  if not a['suggestedHumanReadableName'].endswith('.helper-ink'):continue
  text=(p/a['exportedFileName']).read_text();m=re.fullmatch(r'(light|dark)-(default|XXXL)-(home|lock|widget)\.helper contrast=([\d.]+) frame=(.*)',text.strip());assert m,text
  style,size,kind,ratio,frame=m.groups();frame=ast.literal_eval(frame);ratio=float(ratio);assert ratio>=7,(text,ratio);assert frame[0]>=0 and frame[2]>0 and frame[3]>0 and frame[1]>=116 and frame[1]+frame[3]<=840
  rows.append(dict(style=style,size=size,kind=kind,contrast=ratio,frame=frame,proof=a['exportedFileName'],sha256=hashlib.sha256((p/a['exportedFileName']).read_bytes()).hexdigest()))
assert len(rows)==12
source=Path('ios/App/BoardPersistenceSection.swift').read_text();before=subprocess.check_output(['git','show','21029ed:ios/App/BoardPersistenceSection.swift'],text=True);originals=re.findall(r'Text\("((?:Home Screen:|Lock Screen:)[^"]+)"\)',before);assert len(originals)==2
for original in originals:assert 'instruction("'+original+'",' in source
out=dict(status='passed',nativeSamples=rows,exactOriginalCompleteStrings=originals,minimumContrast=min(r['contrast'] for r in rows),scope='Native existing UI raster checks reexecuted against new prefix styling; full strings compared with frozen prior source. No spoken VoiceOver claim.',sourceSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4')
Path('hillclimb/validation/round8/account-instruction-gates.json').write_text(json.dumps(out,indent=2)+'\n');print(len(rows),'native helpers, contrast>=7, bounds and original strings passed')
