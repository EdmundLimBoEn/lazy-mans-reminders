"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,hashlib
p=pathlib.Path(__file__).parent
config=pathlib.Path('ios/Config.example.xcconfig').read_text().replace('YOUR_APPLE_TEAM_ID','').replace('systems.edmundlim.LazyMansReminders','systems.edmundlim.NotepadHillclimb')
pathlib.Path('ios/Config.xcconfig').write_text(config)
records=[]
for cmd in [['xcodegen','generate','--spec','ios/project.yml'],['xcodebuild','-resolvePackageDependencies','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-derivedDataPath','/tmp/hillclimb-r6-recheck-b846a915-DD']]:
 r=subprocess.run(cmd,capture_output=True,text=True); records.append(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));(p/'setup.json').write_text(json.dumps(records,indent=2));r.check_returncode()
