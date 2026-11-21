"""Read only owned demo artifact keys. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,plistlib,json,sys,hashlib
p=pathlib.Path(__file__).parent;device='066ECE57-46B4-414A-B53E-523775329360';bundle='systems.edmundlim.NotepadHillclimb'
root=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,bundle,'data'],text=True).strip());pref=root/'Library/Preferences'/f'{bundle}.plist'
owned=plistlib.loads(pref.read_bytes()).get('hillclimb.activity.ownedIDs',[]) if pref.exists() else []
artifact=root/'Documents/hillclimb-activity.json';r={'device':device,'ownedExactActivityIDs':owned,'artifact':json.loads(artifact.read_text()) if artifact.exists() else None}
(p/('owned-activities-'+sys.argv[1]+'.json')).write_text(json.dumps(r,indent=2));print('Owned exact Activity IDs:',owned)
