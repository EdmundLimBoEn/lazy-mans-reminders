import pathlib,json,hashlib,subprocess
from PIL import Image
p=pathlib.Path('hillclimb/validation/round6/recheck');sha=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest();freeze=json.loads((p/'freeze.json').read_text());graded=freeze['sourceSHA'];refs=json.loads((p/'reference-integrity.json').read_text());manual=json.loads((p/'manual-native.json').read_text());assert len(manual)==8
cases=[]
for r in manual:
 f=pathlib.Path(r['file']);assert sha(f)==r['sha256'];assert Image.open(f).size==(1206,2622)
 r.update(captureSHA=graded,gradingSourceSHA=graded,binaryIdentity='tested-artifacts.json',dimensions=[1206,2622],pairedReferences=[ref for ref in refs if r['style'] in ref['file']])
 if r['stage']=='bottom':
  nodes=json.loads(f.with_suffix('.ax.json').read_text())['data']['nodes'];links=[n for n in nodes if n.get('label') in ['Privacy','Terms','Support'] and n.get('type') in ['Button','Link']]
  # Snapshot gives native observed frames independently of XCTest assertions.
  assert len(links)==3,links
  assert all(not n['enabled'] for n in links)
  geometry=next(n for n in nodes if n.get('identifier')=='hillclimb.geometry');safe=json.loads(geometry['value'])['safeArea'];safeBottom=safe[1]+safe[3]
  assert all(n['rect']['y']+n['rect']['height']+8<=safeBottom for n in links)
  cases.append(dict(style=r['style'],size=r['size'],safeBottom=safeBottom,links=links))
(p/'manual-native.json').write_text(json.dumps(manual,indent=2));(p/'manual-native-geometry.json').write_text(json.dumps(cases,indent=2))
inspection=json.loads((p/'inspection.json').read_text());inspection['manualInspected']=[dict(file=r['file'],sha256=r['sha256']) for r in manual];inspection['manualMethod']='All8 unretouched full-device native originals opened individually with view_image; device_screenshot also inspected. Last device_screenshot of app redacts some content; pinned full-device originals are the retained supplements. SpringBoard inspected after close.';(p/'inspection.json').write_text(json.dumps(inspection,indent=2))
rest=json.loads((p/'combined-restoration-proof.json').read_text());(p/'handback.json').write_text(json.dumps(dict(hostId='local',deviceID='78F5A64F-7B2E-4562-8EF9-10F3312CC694',session='t3-b9b57eda2b13dcb0599c7976',appearance='light',textSize='large',fourSwitches={'Reduce Motion':'0','Auto-Play Message Effects':'1','Reduce Transparency':'0','Increase Contrast':'0'},restorationProof='combined-restoration-proof.json',allThreeTeardownsMatch=all(r['allFourMatch'] for r in rest),remainingOwnedActivityIDs=[],activityEvidence='activity-cleanup.json',appAndSettingsClosed=True,springBoardScreenshotInspected=True,panelClosed=True,shutdown=False,original17LeftRunning=True,otherSessionsUntouched=True),indent=2))
