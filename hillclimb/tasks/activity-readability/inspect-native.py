"""Save immutable native hash/provenance list. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,hashlib,json,subprocess
p=pathlib.Path(__file__).parent;device='78F5A64F-7B2E-4562-8EF9-10F3312CC694'
h=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
app=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,'systems.edmundlim.NotepadHillclimb','app'],text=True).strip())
products=pathlib.Path('/tmp/activity-readability-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app')
files=['LazyMansReminders','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension']
binaries={f:{'built':h(products/f),'installed':h(app/f)} for f in files}
assert all(x['built']==x['installed'] for x in binaries.values())
(p/'capture-provenance.json').write_text(json.dumps({'device':device,'hostId':'local','native':{str(f):h(f) for f in (p/'native').rglob('*') if f.is_file()},'installed':binaries,'source':json.load(open(p/'provenance.json'))['sources'],'notes':'Expanded PNGs are unmodified native recording frames extracted at 2s. Notification Center PNGs are pinned command screenshots. No true lock claim. Unit renders stay in rendered-unit.'},indent=2))
