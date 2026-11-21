"""Index actual project XCTest screen attachments separately from unit rasters.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import argparse,json,hashlib,shutil,struct,re
p=argparse.ArgumentParser();p.add_argument('--main-export',default='/tmp/hillclimb-focus-round8-native-export');p.add_argument('--main-source',default='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4');p.add_argument('--destination',default='hillclimb/rounds/8');args=p.parse_args();out=Path(args.destination);rows=[];units=[]
def ingest(folder,revision,supplement=False,helper=False):
 folder=Path(folder)
 for t in json.loads((folder/'manifest.json').read_text()):
  for a in t['attachments']:
   f=folder/a['exportedFileName'];n=a['suggestedHumanReadableName'];unit='/LazyMansRemindersTests/' in t['testIdentifierURL']
   with f.open('rb') as stream: header=stream.read(8)
   if header!=b'\x89PNG\r\n\x1a\n':continue
   if supplement and '-ink_' not in n:continue
   group=t['testIdentifier'].split('/')[0]
   target=out/('unit-rendered' if unit else 'native')/group/(f.name if f.suffix=='.png' else f.name+'.png');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,target);raw=target.read_bytes();dims=list(struct.unpack('>II',raw[16:24]));assert dims==[1206,2622] or unit,(n,dims)
   secure=not unit and any(k in n.lower() for k in ['keyboard','focused','first-focus']) and 'dismissed' not in n.lower()
   r=dict(imageSet='instruction-helper-raster' if helper else 'main',file=str(target.relative_to(out)),attachmentName=n,rawExport=str(f),testIdentifier=t['testIdentifier'],testIdentifierURL=t['testIdentifierURL'],timestamp=a.get('timestamp'),sha256=hashlib.sha256(raw).hexdigest(),dimensions=dims,acquisition='Unit ImageRenderer' if unit else 'Native project XCTest screenshot attachment',acquisitionSourceSHA=revision,gradedSourceSHA='20ae77e29019444a499e9e47c98d6b656ef56819',appProductionSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',binaryProof='../../tasks/login-focus-polish/measured-heading-tested-binaries.json',protectedPartial=secure,appearance='dark' if 'dark' in n.lower() or 'Dark' in t['testIdentifier'] else 'light' if 'light' in n.lower() else 'see method/configuration',textSize='XXXL' if 'XXXL' in n or 'XXXL' in t['testIdentifier'] else 'default or method-specific',configuration='Actual combined system settings' if 'Combined' in t['testIdentifier'] or 'combined' in n else 'Original system settings; app-local style/type overrides except actual system Activity appearance/size',sourceBinding='Production and binaries byte-identical across46c1 andfc08b41; measured-heading and bounded-matrix test changes only')
   (units if unit else rows).append(r)
ingest(args.main_export,args.main_source)
ingest('/tmp/hillclimb-focus-round8-heading-export','fc08b417d9a38d79c726678048100362ccfaf1ec',True)
ingest('/tmp/hillclimb-focus-round8-account-helper-export','46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',helper=True)
for recordFile,kind in [('activity-video-artifacts.json','Activity'),('keyboard-video-frames.json','Keyboard')]:
 for v in json.loads((Path('hillclimb/validation/round8')/recordFile).read_text()):
  f=Path(v['frame'] if kind=='Activity' else v['file']);b=f.read_bytes();rows.append(dict(imageSet='video-witness',file=str(f.relative_to(out)),attachmentName=f.stem,sha256=hashlib.sha256(b).hexdigest(),dimensions=list(struct.unpack('>II',b[16:24])),testIdentifier=v.get('sourceAcquisitionTest',v.get('testIdentifier')),acquisition='Unmodified native recorded frame; '+('2s relative to normalized clip playback' if kind=='Activity' else 'timestamp-aligned firstfocus/refocus witness'),acquisitionSourceSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',gradedSourceSHA='20ae77e29019444a499e9e47c98d6b656ef56819',binaryProof='../../tasks/login-focus-polish/measured-heading-tested-binaries.json',sourceVideoSHA256=v.get('sha256') if kind=='Activity' else v['sourceVideoSHA256'],sourceVideo=v['file'] if kind=='Activity' else v['sourceVideo'],protectedPartial=False,appearance='dark' if 'dark' in f.name else 'light',textSize='XXXL' if 'XXXL' in f.name else 'default',configuration='Actual combined system switches' if 'combined' in f.name else 'Original system switches; actual system Activity size/appearance',sourceBinding='Production and binaries unchanged; test-only measured-heading correction',inspection='Parent inspected native frame; full keyboard visible for keyboard witness; no true lock or frame pacing claim'))
assert len({r['file'] for r in rows})==len(rows)
(out/'inventory.json').write_text(json.dumps(dict(source_sha='20ae77e29019444a499e9e47c98d6b656ef56819',app_source_sha='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',countMeaning='File acquisitions, including repeated stress samples; not unique screens or quality votes',images=rows,unitRenderedExcluded=len(units),remainingGaps=['No true lock, physical haptics, spoken VoiceOver, AX1–AX5 or live authentication evidence','Protected keyboard stills are partial; actual video frames are separately labeled','No Notes reference or exact Apple auth/Activity/capacity/combined-settings counterpart']),indent=2)+'\n')
(out/'native-acquisition-inventory.json').write_text((out/'inventory.json').read_text())
(out/'unit-rendered-inventory.json').write_text(json.dumps(units,indent=2)+'\n');print(len(rows),'native screen acquisitions;',len(units),'unit renders separate')
