import subprocess, pathlib, json, time, hashlib, shutil, sys
root=pathlib.Path(__file__).resolve().parents[3]
out=root/'hillclimb/tasks/account-consistency'
dd=pathlib.Path('/tmp/notepad-account-j-dd')
def run(name, args):
    start=time.time()
    p=subprocess.run(args, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (out/(name+'.txt')).write_text(p.stdout)
    (out/(name+'.json')).write_text(json.dumps(dict(argv=args,exit=p.returncode,elapsed=time.time()-start),indent=2))
    print(name, p.returncode, p.stdout[-3000:],flush=True)
    return p.returncode
if sys.argv[1]=='build':
    if not dd.exists():
        dd.mkdir()
        shutil.copytree('/tmp/notepad-round3-recheck-86f22b1d-dd/SourcePackages',dd/'SourcePackages',symlinks=True)
    sys.exit(run('build', ['xcodebuild','build-for-testing','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-configuration','Debug','-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694,arch=arm64','-derivedDataPath',str(dd),'-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']))
else:
    xct=list((dd/'Build/Products').glob('*.xctestrun'))
    assert len(xct)==1
    (out/'xctestrun-provenance.json').write_text(json.dumps({'path':str(xct[0]),'sha256':hashlib.sha256(xct[0].read_bytes()).hexdigest()},indent=2))
    args=['xcodebuild','test-without-building','-xctestrun',str(xct[0]),'-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694,arch=arm64','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','180','-maximum-test-execution-time-allowance','240','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath','/tmp/notepad-account-j-'+sys.argv[1]+'.xcresult','CODE_SIGNING_ALLOWED=NO']
    if not sys.argv[1].startswith('combined'): args+=['-only-testing:HillclimbUITests/AccountPresentationTests']
    sys.exit(run(sys.argv[1],args))
