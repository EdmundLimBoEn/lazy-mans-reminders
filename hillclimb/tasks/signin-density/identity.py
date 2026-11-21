"""Frozen tested and installed identities. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,hashlib,subprocess
p=pathlib.Path(__file__).parent;dd=pathlib.Path('/tmp/hillclimb-signin-density-DD');sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
freeze=json.loads((p/'freeze.json').read_text());assert all(sha(pathlib.Path(f))==h for f,h in freeze['hashes'].items())
product=dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app';installed=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container','8E8380DE-364D-4899-99B8-D15ED0494FFD','systems.edmundlim.NotepadHillclimb','app'],text=True).strip())
keys=['LazyMansReminders','LazyMansReminders.debug.dylib','Info.plist','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension.debug.dylib','PlugIns/ReminderWidgetExtension.appex/Info.plist']
rows=[dict(file=k,buildSHA256=sha(product/k),installedSHA256=sha(installed/k)) for k in keys];assert all(r['buildSHA256']==r['installedSHA256'] for r in rows)
(p/'installed-identity.json').write_text(json.dumps(dict(installedPath=str(installed),files=rows,allMatch=True),indent=2))
art={str(f):sha(f) for f in (dd/'Build/Products/Debug-iphonesimulator').rglob('*') if f.is_file() and (f.suffix in ['.dylib','.plist'] or f.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests','ReminderWidgetExtension'])};art.update({str(f):sha(f) for f in (dd/'Build/Products').glob('*.xctestrun')});(p/'tested-artifacts.json').write_text(json.dumps(art,indent=2))
raw=[]
for d in pathlib.Path('/tmp').glob('hillclimb-signin-density-*.xcresult'):
 files=[dict(file=str(f),bytes=f.stat().st_size,sha256=sha(f)) for f in d.rglob('*') if f.is_file()];raw.append(dict(path=str(d),totalBytes=sum(x['bytes'] for x in files),files=files))
(p/'external-xcresults.json').write_text(json.dumps(raw,indent=2))
print('Frozen sources/artifacts and installed binaries match')
