import sys
finalPhase=sys.argv[1] if len(sys.argv)>1 else "full"
"""Executed native Account comparisons. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,re,hashlib
p=pathlib.Path(__file__).parent
result={}
for phase in ['before',finalPhase]:
 d=p/(phase+'-AccountChromeUITests'); m=json.loads((d/'manifest.json').read_text()); rows=[]
 for t in m:
  for a in t['attachments']:
   f=d/a['exportedFileName'];n=a.get('suggestedHumanReadableName','')
   if '-paragraph-ink_' in n:
    ratio=float(re.search(r'contrast=([\d.]+)',f.read_text())[1]);assert ratio>=7;rows.append(dict(name=n,contrast=ratio))
 result[phase]={'paragraphInk':rows,'minimumContrast':min(r['contrast'] for r in rows)}
(p/'native-comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
# Guidance copy and geometry are asserted on-device by unchanged Chrome methods.
original=json.loads((p.parent/'account-chrome/immutable-original.json').read_text())['original']
paragraphs=[];title=[]
for phase in ['before',finalPhase]:
 d=p/(phase+'-AccountChromeUITests')
 for t in json.loads((d/'manifest.json').read_text()):
  for a in t['attachments']:
   f=d/a['exportedFileName'];name=a.get('suggestedHumanReadableName','')
   if '-guidance-proof_' in name:
    s=f.read_text();labels=json.loads(re.search(r'labels=(\[.*?\]) frames=',s)[1]);assert ' '.join(labels)==original
    frames={k:list(map(float,v.split(','))) for k,v in re.findall(r'"([^"]+)": \[([^\]]+)\]',s)}
    first=frames['persistence.activity'];second=frames['persistence.background'];whole=frames['persistence.footer'];gap=second[1]-first[1]-first[3]
    assert abs(gap-6)<=.5 and abs(whole[3]-first[3]-second[3]-6)<=1
    paragraphs.append(dict(phase=phase,name=name,labels=labels,frames=frames,gap=gap))
   if '-title-ink_' in name:
    s=f.read_text();maximum=float(re.search(r'contrast=([\d.]+)',s)[1]);assert maximum<=1.5;title.append(dict(phase=phase,name=name,maximum=maximum))
assert len(paragraphs)==16 and len(title)==16
result['paragraphs']=paragraphs;result['titleBands']=title
(p/'native-comparison.json').write_text(json.dumps(result,indent=2))
