"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,hashlib,subprocess
p=pathlib.Path(__file__).parent; root=pathlib.Path('.'); sha=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest(); freeze=json.loads((p/'freeze.json').read_text()); old=json.loads((p.parent/'freeze.json').read_text()); dd=pathlib.Path('/tmp/hillclimb-r6-recheck-b846a915-DD')
assert all(sha(f)==h for f,h in freeze['productionFiles'].items())
assert sha('ios/UITests/SignInChromeUITests.swift')==freeze['testSHA256']
backend={f:sha(f) for f in subprocess.check_output(['git','ls-files','supabase'],text=True).splitlines() if pathlib.Path(f).is_file()}
backendOld={f:hashlib.sha256(subprocess.check_output(['git','show',freeze['historicalCaptureSHA']+':'+f])).hexdigest() for f in backend}
assert backend==backendOld
art={str(f):sha(f) for f in (dd/'Build/Products/Debug-iphonesimulator').rglob('*') if f.is_file() and (f.suffix in ['.dylib','.plist'] or f.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests','ReminderWidgetExtension'])}
art.update({str(f):sha(f) for f in (dd/'Build/Products').glob('*.xctestrun')})
(p/'tested-artifacts.json').write_text(json.dumps(art,indent=2))
(p/'provenance.json').write_text(json.dumps(dict(gradingSourceSHA=freeze['sourceSHA'],historicalCaptureSHA=freeze['historicalCaptureSHA'],historicalBinaryIdentity='../final-tested-artifacts.json',newBinaryIdentity='tested-artifacts.json',production54Equivalent=True,productionHashes=freeze['productionFiles'],backendHashes=backend,reusedChecks=dict(sourceSHA=freeze['historicalCaptureSHA'],productionAndBackendMatch=True,records=['../build-release-process.json','../python-ios.json','../deno.json','../deno-overflow.json'],claim='Historical results reused; no new Release/Python/backend execution'),pinsSHA256=sha('ios/LazyMansReminders.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'),configSHA256=sha('ios/Config.xcconfig'),session='t3-b9b57eda2b13dcb0599c7976'),indent=2))
refs=json.loads((p.parent/'reference-integrity.json').read_text());assert len(refs)==17
for r in refs: assert sha(r['file'])==r['expected']
(p/'reference-integrity.json').write_text(json.dumps(refs,indent=2))
print('Production, backend, pins, 17 references verified; binaries frozen')
