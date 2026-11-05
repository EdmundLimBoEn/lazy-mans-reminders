#!/usr/bin/env bash
# Repeatable native project-runner capture; no manual device-driver commands.
# Written by gpt-6.1-sol in Codex on behalf of Edmund.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
python3 - "$@" <<'PY'
import argparse,datetime,hashlib,json,pathlib,plistlib,re,subprocess
p=argparse.ArgumentParser(description='Re-shoot seeded native states with project XCTest on original17. Build the exact frozen source first.')
p.add_argument('--xctestrun',required=True,type=pathlib.Path)
p.add_argument('--output',required=True,type=pathlib.Path,help='New output directory; existing results are never overwritten')
p.add_argument('--recordings',action='store_true',help='Keep automatic native movies as well as named screenshots; requires several GiB')
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False);a.xctestrun=a.xctestrun.resolve();config=plistlib.loads(a.xctestrun.read_bytes());run=a.xctestrun
assert 'HillclimbUITests' in config and config['HillclimbUITests']['IsUITestBundle']
if a.recordings:
 config['HillclimbUITests']['SystemAttachmentLifetime']='keepAlways'
 # Keep the copy beside the generated file so __TESTROOT__ still resolves correctly.
 run=a.xctestrun.with_name(a.xctestrun.stem+'-hillclimb-recordings.xctestrun')
 if run.exists():raise SystemExit('Recording configuration already exists; choose fresh DerivedData')
 run.write_bytes(plistlib.dumps(config))
selectors=[]
for source in sorted(pathlib.Path('ios/UITests').glob('*.swift')):
 text=source.read_text();group=re.search(r'final class (\w+)',text).group(1)
 selectors.extend('-only-testing:HillclimbUITests/'+group+'/'+name for name in re.findall(r'    func (test\w+)\(',text))
assert len(selectors)>=61
command=['xcodebuild','test-without-building','-xctestrun',str(run),'-destination','id=78F5A64F-7B2E-4562-8EF9-10F3312CC694','-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-resultBundlePath',str(a.output/'screens.xcresult')]+selectors
proof={'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'startedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':command,'generatedXctestrunSHA256':hashlib.sha256(a.xctestrun.read_bytes()).hexdigest(),'executedXctestrunSHA256':hashlib.sha256(run.read_bytes()).hexdigest(),'selectors':selectors,'device':'Hillclimb iPhone17Pro / iOS26.2 / original17','scope':'Offline seeded board, bottom/pull, composer, Account detents/expanded states, sign-in empty/filled/loading/error/first focus/refocus, normal+combined settings, native Activity. No live authentication. Unit renders are separate.'}
record=a.output/'capture-command.json';record.write_text(json.dumps(proof,indent=2)+'\n');result=subprocess.run(command);proof['testExit']=result.returncode
for label,pattern in [('png','*.png'),('text','*.txt'),('helper','*.helper'),('footer','*.footer')]:
 argv=['xcrun','xcresulttool','export','attachments','--path',str(a.output/'screens.xcresult'),'--filter',pattern,'--output-path',str(a.output/label)]
 proof.setdefault('exports',[]).append({'command':argv,'exit':subprocess.run(argv).returncode})
proof['endedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat();record.write_text(json.dumps(proof,indent=2)+'\n');raise SystemExit(result.returncode)
PY
