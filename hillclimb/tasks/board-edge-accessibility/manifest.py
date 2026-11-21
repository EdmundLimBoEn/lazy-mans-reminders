"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import json,hashlib,subprocess,datetime
p=Path('hillclimb/tasks/board-edge-accessibility');dd=Path('/tmp/notepad-board-edge-L-dd')
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
source={str(f):sha(f) for folder in ['ios/App','ios/Shared','ios/Widget','ios/Tests','ios/UITests'] for f in Path(folder).rglob('*.swift')}
products=[f for f in (dd/'Build/Products/Debug-iphonesimulator').rglob('*') if f.is_file() and (f.suffix in ['.dylib'] or f.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests','ReminderWidgetExtension','HillclimbUITests-Runner'])]
runs=list((dd/'Build/Products').glob('*.xctestrun'));assert len(runs)==1
(p/'final.xctestrun').write_bytes(runs[0].read_bytes())
(p/'build-capture-inputs.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'branch':subprocess.check_output(['git','branch','--show-current'],text=True).strip(),'device':{'hostId':'local','id':'066ECE57-46B4-414A-B53E-523775329360','iOS':'26.2','model':'regular iPhone 17 Pro'},'source':source,'binary':{str(f):sha(f) for f in products},'xctestrun':{str(runs[0]):sha(runs[0])},'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2))
(p/'evidence-hashes.json').write_text(json.dumps({str(f.relative_to(p)):sha(f) for f in p.rglob('*') if f.is_file() and f.name!='evidence-hashes.json'},indent=2))
