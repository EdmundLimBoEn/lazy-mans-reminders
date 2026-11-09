"""Hash exact final build and test inputs.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import hashlib,json,shutil,subprocess
p=Path(__file__).parent
paths=[*Path('ios/App').rglob('*.swift'),*Path('ios/Shared').glob('*.swift'),*Path('ios/Widget').glob('*.swift'),*Path('ios/Tests').glob('*.swift'),*Path('ios/UITests').glob('*.swift')]
run=next(Path('/tmp/hillclimb-O-signin-DD/Build/Products').glob('*.xctestrun'));shutil.copyfile(run,p/'generated.xctestrun');paths.append(run)
for x in Path('/tmp/hillclimb-O-signin-DD/Build/Products/Debug-iphonesimulator').rglob('*'):
 if x.is_file() and (x.name.endswith('.dylib') or x.name in ['LazyMansReminders','LazyMansRemindersTests','HillclimbUITests','HillclimbUITests-Runner']):paths.append(x)
paths += [Path('ios/Config.xcconfig'),Path('ios/LazyMansReminders.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'),Path('ios/LazyMansReminders.xcodeproj/project.pbxproj')]
(p/'final-inputs.json').write_text(json.dumps({str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths if x.exists()},indent=2))
(p/'source-freeze.json').write_text(json.dumps({str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths if str(x).endswith('.swift')},indent=2))
(p/'source-commit.txt').write_text(subprocess.check_output(['git','rev-parse','HEAD'],text=True))
