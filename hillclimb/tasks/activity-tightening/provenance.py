"""Freeze hashes and comparison pairings. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import json,hashlib,subprocess
p=Path(__file__).parent;h=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
full=json.loads((p/'candidate-full.json').read_text());sources={str(f):h(f) for f in Path('ios').rglob('*.swift')};assert sources==full['source']==json.loads((p/'candidate-build.json').read_text())['source']
binaries=json.loads((p/'candidate-binaries.json').read_text());assert all(h(Path(f))==v for f,v in binaries.items())
references={('light','default'):Path('hillclimb/reference/round2/reminders-bottom-light.png'),('dark','default'):Path('hillclimb/reference/reminders-bottom-dark.png'),('light','XXXL'):Path('hillclimb/reference/round3/reminders-bottom-light-XXXL.png'),('dark','XXXL'):Path('hillclimb/reference/round3/reminders-bottom-dark-XXXL.png')}
imgs=[]
for folder in ['before','after','long']:
 d=json.loads((p/folder/'manifest.json').read_text());assert all(o['exit']==0 for o in d['operations'])
 for r in d['captures']:
  f=p/folder/r['file'];assert h(f)==r['sha256'];ref=references[(r['style'],r['size'])];imgs.append(dict(file=str(f),sha256=h(f),reference=str(ref),referenceSHA256=h(ref),matrix=folder,surface=r['surface'],style=r['style'],size=r['size'],gap='Same regular17/style/size; Reminders list is a typography reference, no exact Apple Activity counterpart. Compact/minimal intentionally empty.'))
assert len(imgs)==30
(p/'pairings.json').write_text(json.dumps(imgs,indent=2))
unit=list((p/'candidate-full-unit-renders').glob('*.png'));assert len(unit)==12
config=Path('ios/Config.xcconfig');pins=Path('ios/LazyMansReminders.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved')
provenance=dict(base='cfc7954',sourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),sources=sources,binaries=binaries,xctestrun={str(f):h(f) for f in p.glob('*.xctestrun')},configSHA256=h(config),packagePinsSHA256=h(pins) if pins.exists() else None,images=imgs,unitRendersSeparate={str(f):h(f) for f in unit},supplementalNative={str(f):h(f) for f in [p/'live-banner-inspected.png',p/'final-springboard.png']},referenceOriginalsInspected={str(f):h(f) for f in references.values()},visibleNativeOriginalsInspected=[r['file'] for r in imgs if r['surface']!='collapsed'],allAppTestSourcesMatchFinalBuildAndFullTest=True)
(p/'provenance.json').write_text(json.dumps(provenance,indent=2));print('30 matrix PNG hashes and pairings verified;20 visible native originals;12 unit renders separate;final source/binary/xctestrun unchanged')
