"""Validate captured native values/raster measurements independently of typing intent.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,re,ast,sys
p=pathlib.Path(__file__).parent;packet=sys.argv[1] if len(sys.argv)>1 else 'full';d=p/packet;password=[];title=[];footer=[];loading=[];initial=[]
for t in json.loads((d/'manifest.json').read_text()):
 for a in t['attachments']:
  name=a['suggestedHumanReadableName'];f=d/a['exportedFileName']
  if f.suffix!='.txt':continue
  txt=f.read_text();first=txt.splitlines()[0]
  if name.startswith('chrome-password-') and '-geometry' in name:
   rows=[line for line in txt.splitlines() if 'SecureTextField,' in line]
   assert len(rows)==1,(name,rows)
   value=re.search(r'value: ([^,\n]+)',rows[0]).group(1)
   assert value=='•'*12,(name,value)
   frame=ast.literal_eval(re.search(r'field=(\([^)]*\))',first).group(1));assert frame[3]>=44
   ink=int(re.search(r'ink=(\d+)',first).group(1));assert ink>100
   password.append(dict(name=name,secureValueLength=len(value),fieldFrame=frame,labelInk=ink))
  elif name.startswith('chrome-title-band'):
   contrast=float(re.search(r'maxNonTitleContrast=([\d.]+)',txt).group(1));assert contrast<=1.5
   title.append(dict(name=name,measurement=first,maxContrast=contrast))
  elif name.startswith('chrome-footer-') and 'bottom-geometry' in name:
   bottom=float(re.search(r'safeBottom=([\d.]+)',first).group(1));frames=ast.literal_eval(first.split('links=')[1]);assert len(frames)==3
   clearances=[bottom-y-h for x,y,w,h in frames];assert min(clearances)>=8
   footer.append(dict(name=name,safeBottom=bottom,frames=frames,clearances=clearances))
  elif name.startswith('chrome-footer-') and 'initial-geometry' in name:
   rows=[line.strip() for line in txt.splitlines() if any("label: '"+label+"'" in line for label in ['Privacy','Terms','Support'])]
   frames=[list(map(float,re.search(r'\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}',row).groups())) for row in rows]
   initial.append(dict(name=name,nativeLinkAXRows=rows,framesRoundedByXCTest=frames))
  elif name.startswith('chrome-loading-') and '-geometry' in name:
   ink=int(re.search(r'titleInk=(\d+)',first).group(1));assert ink>100;loading.append(dict(name=name,titleInk=ink))
for item in initial:
 match=next(x for x in footer if x['name'].split('-bottom')[0]==item['name'].split('-initial')[0])
 item['safeBottom']=match['safeBottom'];item['safeBottomOrigin']='matching native bottom sample, same fixture style/size and keyboard-absent window'
 item['clearances']=[match['safeBottom']-y-h for x,y,w,h in item['framesRoundedByXCTest']]
assert len(password)==16 and len(title)==16 and len(footer)==4 and len(initial)==4 and len(loading)==36
(p/('native-gates.json' if packet=='full' else packet+'-native-gates.json')).write_text(json.dumps(dict(password=password,title=title,footer=footer,initial=initial,loading=loading,summary=dict(populatedPasswordStates=16,titleBands=16,maxNonTitleContrast=max(x['maxContrast'] for x in title),legalLinks=12,minSafeBottomClearance=min(c for x in footer for c in x['clearances']),loadingSamples=36,minAppleInk=min(x['titleInk'] for x in loading))),indent=2))
print('Native AX:16 populated states;16 title bands;12 legal links;36 Apple loading samples')
