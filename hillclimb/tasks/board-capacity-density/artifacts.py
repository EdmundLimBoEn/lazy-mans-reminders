"""Bind source, build, installed app, pins and native captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,hashlib,json,subprocess,shutil
p=pathlib.Path(__file__).parent;dd=pathlib.Path('/tmp/hillclimb-capacity-density-T-DD');sha=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
f=json.loads((p/'freeze.json').read_text());assert all(sha(k)==v for k,v in f['sourceHashes'].items());assert sha('ios/Config.xcconfig')==f['configSHA256'];pins=pathlib.Path('ios/LazyMansReminders.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved');assert sha(pins)==f['pinsSHA256'];shutil.copyfile(pins,p/'Package.resolved')
art={str(x):sha(x) for x in (dd/'Build/Products/Debug-iphonesimulator').rglob('*') if x.is_file() and (x.suffix in ['.dylib','.plist'] or x.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests','ReminderWidgetExtension'])};runs=list((dd/'Build/Products').glob('*.xctestrun'));assert len(runs)==1;art[str(runs[0])]=sha(runs[0]);shutil.copyfile(runs[0],p/'generated.xctestrun');assert not (p/'tested-artifacts.json').exists() or json.loads((p/'tested-artifacts.json').read_text())==art, 'Built artifact changed after final freeze'
(p/'tested-artifacts.json').write_text(json.dumps(art,indent=2))
if (p/'final-summary.json').exists():
 installed=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container','066ECE57-46B4-414A-B53E-523775329360','systems.edmundlim.NotepadHillclimb','app'],text=True).strip());app=dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app';matches=[]
 for rel in ['LazyMansReminders','LazyMansReminders.debug.dylib','__preview.dylib','Info.plist','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension.debug.dylib']:
  a=sha(app/rel);b=sha(installed/rel);assert a==b;matches.append(dict(file=rel,tested=a,installed=b))
 (p/'installed-identity.json').write_text(json.dumps(dict(installedPath=str(installed),matches=matches),indent=2))
print('Frozen source/config/pins and build identities verified')
