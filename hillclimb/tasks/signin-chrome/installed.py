"""Read only this isolated app's installed artifacts and owned Activity IDs.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import subprocess,pathlib,plistlib,hashlib,json
p=pathlib.Path(__file__).parent;device='8E8380DE-364D-4899-99B8-D15ED0494FFD';bundle='systems.edmundlim.NotepadHillclimb';commands=[]
def container(kind):
 cmd=['xcrun','simctl','get_app_container',device,bundle,kind];r=subprocess.run(cmd,capture_output=True,text=True);commands.append(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));r.check_returncode();return pathlib.Path(r.stdout.strip())
app=container('app');data=container('data');built=pathlib.Path('/tmp/hillclimb-O-signin-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app');hashes={}
for name in ['LazyMansReminders','LazyMansReminders.debug.dylib']:
 a=hashlib.sha256((app/name).read_bytes()).hexdigest();b=hashlib.sha256((built/name).read_bytes()).hexdigest();assert a==b;hashes[name]=dict(installed=a,built=b,match=True)
prefs=data/'Library/Preferences'/f'{bundle}.plist';owned=plistlib.loads(prefs.read_bytes()).get('hillclimb.activity.ownedIDs',[]) if prefs.exists() else []
(p/'installed-binary-match.json').write_text(json.dumps(dict(commands=commands,hashes=hashes,remainingOwnedActivityIDs=owned,app=str(app),data=str(data)),indent=2));print('Installed binary/dylib match; own Activity IDs:',owned)
