"""Summarize executed native assertions and captured labels, not source modifiers.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re
p=pathlib.Path(__file__).parent;d=p/'combined-AccountChromeUITests';manifest=json.loads((d/'manifest.json').read_text());original=json.loads((pathlib.Path('hillclimb/tasks/account-chrome/immutable-original.json')).read_text())['original'];contrasts=[];paragraphs=[];title=[]
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
assert len(contrasts)==16 and len(paragraphs)==8 and len(title)==8
result=dict(minimumParagraphContrast=min(r['ratio'] for r in contrasts),maximumNonTitleContrast=max(r['maximum'] for r in title),paragraphs=paragraphs,contrasts=contrasts,titleBands=title,allExecutedNativeAssertionsPassed=True)
(p/'account-native-gates.json').write_text(json.dumps(result,indent=2));print(result['minimumParagraphContrast'],result['maximumNonTitleContrast'])
