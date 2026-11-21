"""Summarize executed native assertions and captured labels, not source modifiers.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re
p=pathlib.Path(__file__).parent;d=p/'full-AccountChromeUITests';manifest=json.loads((d/'manifest.json').read_text());original=json.loads((p/'immutable-original.json').read_text())['original'];contrasts=[];paragraphs=[];title=[]
for t in manifest:
 for a in t['attachments']:
  name=a.get('suggestedHumanReadableName','');f=d/a['exportedFileName']
  if '-paragraph-ink_' in name:
   text=f.read_text();ratio=float(re.search(r'contrast=([\d.]+)',text).group(1));assert ratio>=7;contrasts.append(dict(name=name,ratio=ratio))
  elif '-guidance-proof_' in name:
   text=f.read_text();labels=json.loads(re.search(r'labels=(\[.*?\]) frames=',text).group(1));assert ' '.join(labels)==original
   frames={key:list(map(float,values.split(','))) for key,values in re.findall(r'"([^"]+)": \[([^\]]+)\]',text)}
   first=frames['persistence.activity'];second=frames['persistence.background'];gap=second[1]-first[1]-first[3];assert abs(gap-6)<=.5;paragraphs.append(dict(name=name,labels=labels,frames=frames,spacing=gap))
  elif '-title-ink_' in name:
   text=f.read_text();maximum=float(re.search(r'contrast=([\d.]+)',text).group(1));assert maximum<=1.5;title.append(dict(name=name,maximum=maximum))
images=json.loads((p/'full-images.json').read_text());assert len(images)==36;assert all(row['dimensions']==[1206,2622] for row in images);assert len(contrasts)==16;assert len(paragraphs)==8;assert len(title)==8
fullBar=[r for r in json.loads((p/'full-bar-comparison.json').read_text()) if r['phase']=='full']
assert len(fullBar)==8;assert all(r['maximum']<=1.5 and r['over1_5']==0 for r in fullBar)
result=dict(fullNavigationBarMaximum=max(r['maximum'] for r in fullBar),fullNavigationBarSamples=fullBar,finalNativePNGs=36,minimumParagraphContrast=min(r['ratio'] for r in contrasts),maximumNonTitleContrast=max(r['maximum'] for r in title),paragraphs=paragraphs,contrasts=contrasts,titleBands=title,allNativeAssertionsPassed=True,limits=['Native first/final-third ink and geometry checks, plus visual inspection, do not certify every font or accessibility size','Physical haptics, spoken VoiceOver and true locking unobserved'])
(p/'native-gates.json').write_text(json.dumps(result,indent=2));print('Native gates:',result['finalNativePNGs'],result['minimumParagraphContrast'],result['maximumNonTitleContrast'])
