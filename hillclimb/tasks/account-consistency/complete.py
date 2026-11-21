import pathlib,subprocess,json,hashlib,re
root=pathlib.Path(__file__).resolve().parents[3];out=root/'hillclimb/tasks/account-consistency';bundle='/tmp/notepad-account-j-combined-final.xcresult'
for subcommand in ['summary','tests']:
 p=subprocess.run(['xcrun','xcresulttool','get','test-results',subcommand,'--path',bundle,'--format','json'],capture_output=True,text=True)
 assert p.returncode==0,p.stderr
 (out/f'combined-final-{subcommand}.json').write_text(p.stdout)
s=json.loads((out/'combined-final-summary.json').read_text())
assert s['passedTests']==281 and s['totalTestCount']==281,s
assert s['failedTests']==0 and s['skippedTests']==0 and s['expectedFailures']==0,s
text=(out/'combined-final.txt').read_text()
assert re.search(r'Executed 263 tests, with 0 failures',text)
assert re.search(r'Executed 18 tests, with 0 failures',text)
provenance=json.loads((out/'binary-provenance.json').read_text())
assert all(hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256'] for p in provenance),'Binary inputs changed'
assert hashlib.sha256((out/'generated.xctestrun').read_bytes()).hexdigest()==json.loads((out/'xctestrun-provenance.json').read_text())['sha256']
result={'passed':s['passedTests'],'unit':263,'ui':18,'failed':s['failedTests'],'skipped':s['skippedTests'],'runtimeWarnings':s['runtimeWarnings'],'bundle':bundle,'binaryHashesStillMatch':True,'generatedXctestrunHashMatches':True}
(out/'final-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
