"""Rebuild the unchanged pre-task app for a fully hashed native witness.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,hashlib,tarfile,io
root=pathlib.Path(__file__).resolve().parents[3];out=root/'hillclimb/tasks/account-chrome';scratch=pathlib.Path('/tmp/account-q-before-source');scratch.mkdir(exist_ok=False)
base=subprocess.check_output(['git','rev-parse','217dd1e^'],text=True,cwd=root).strip();archive=subprocess.check_output(['git','archive',base,'ios'],cwd=root)
with tarfile.open(fileobj=io.BytesIO(archive)) as t:t.extractall(scratch,filter='data')
(scratch/'ios/Config.xcconfig').write_bytes((root/'ios/Config.xcconfig').read_bytes())
s=(root/'ios/UITests/AccountChromeUITests.swift').read_text()
# Observational before-only harness: retain original app, record title pixels and target geometry.
s='\n'.join(line for line in s.splitlines() if 'XCTAssertGreaterThanOrEqual(done.frame.' not in line and 'XCTAssertLessThanOrEqual(maximum, 1.5' not in line)+'\n'
(scratch/'ios/UITests/AccountChromeUITests.swift').write_text(s)
(out/'before-observation-harness.swift').write_text(s)
subprocess.run(['xcodegen','generate','--spec',str(scratch/'ios/project.yml')],check=True)
pins=next((root/'ios/LazyMansReminders.xcodeproj').rglob('Package.resolved'));target=scratch/'ios/LazyMansReminders.xcodeproj'/pins.relative_to(root/'ios/LazyMansReminders.xcodeproj');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pins.read_bytes())
cmd=['xcodebuild','build-for-testing','-project',str(scratch/'ios/LazyMansReminders.xcodeproj'),'-scheme','LazyMansReminders','-configuration','Debug','-derivedDataPath','/tmp/account-q-before-DD','-clonedSourcePackagesDirPath','/tmp/account-q-7e805644-DD/SourcePackages','-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694,arch=arm64','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);messages=[]
for line in p.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED']):messages.append(line.strip());print(line,end='',flush=True)
code=p.wait();(out/'before-witness-build.json').write_text(json.dumps(dict(baseSHA=base,command=cmd,exit=code,source={str(f.relative_to(scratch)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (scratch/'ios').rglob('*.swift')},artifacts={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in pathlib.Path('/tmp/account-q-before-DD/Build/Products').rglob('*') if f.is_file() and (f.suffix in ['.dylib','.xctestrun'] or f.name=='LazyMansReminders')},diagnostics=messages),indent=2));raise SystemExit(code)
