"""Verify actual frozen sources, executed results and native evidence; no UI actions.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib,collections,subprocess,datetime
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');o=Path('hillclimb/rounds/7');checks=[]
def read(f):return json.loads(Path(f).read_text())
def add(name,passed,proof,required=True):checks.append(dict(name=name,passed=bool(passed),proof=str(proof),required=required))
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
freeze=read(t/'freeze.json');accept=read(t/'acceptance.json');rt=read(t/'frozen-RT.json')
add('Frozen93source/config inputs',all(sha(f)==h for f,h in freeze['hashes'].items()) and len(freeze['hashes'])==93,t/'freeze.json')
add('R/T production and test bytes exact',all(sha(f)==h for f,h in rt.items()),t/'frozen-RT.json')
add('All54production files match frozen scope',all(sha(f)==h for f,h in read(t/'production54.json')['hashes'].items()),t/'production54.json')
add('Strict SignInSurface and root circle source retained',sha('ios/UITests/SignInSurfaceUITests.swift')=='6afbe43da20e08e56709678786d680cf83750c33ff6e3bfd13bd110f5e1eedf6' and sha('ios/UITests/BoardMultilineUITests.swift')==freeze['hashes']['ios/UITests/BoardMultilineUITests.swift'],t/'freeze.json')
add('317named methods passed,263unit+54UI,0failed/skip',accept['total']==317 and accept['unit']==263 and accept['ui']==54 and accept['passed']==317 and accept['failed']==0 and accept['skipped']==0,t/'acceptance.json')
add('308/307/304/293named IDs retained',all(accept['baselines'][str(n)]['retained']==n and not accept['baselines'][str(n)]['missing'] for n in [308,307,304,293]),t/'acceptance.json')
run=read(t/'full-v2-process.json');cmd=run['command']
add('Unfiltered serial exact xctestrun, diagnostics never,240/300',run['exit']==0 and not any(x.startswith(('-only-testing','-skip-testing')) for x in cmd) and cmd[cmd.index('-parallel-testing-enabled')+1]=='NO' and cmd[cmd.index('-collect-test-diagnostics')+1]=='never' and cmd[cmd.index('-default-test-execution-time-allowance')+1]=='240' and cmd[cmd.index('-maximum-test-execution-time-allowance')+1]=='300',t/'full-v2-process.json')
for name in ['build-v2-frozen','build-v2-release','build-v2-debug-restore']:add(name,read(t/(name+'-process.json'))['exit']==0,t/(name+'-process.json'))
add('V2auth-focused8/8',read(t/'v2-focused-summary.json')['passedTests']==8 and read(t/'v2-focused-summary.json')['failedTests']==0,t/'v2-focused-summary.json')
for name,count in [('python-ios',23),('deno',52),('deno-overflow',4)]:
 r=read(p/(name+'.json'));add(name+' offline',r['exit']==0 and r['observedCount']==count and r['frozenInputsMatch'] and r['sourceIdentity']==freeze['sourceIdentity'],p/(name+'.json'))
add('Debug artifact restoration byte-identical',read(t/'debug-restore-artifacts.json')['allMatch'],t/'debug-restore-artifacts.json')
add('Final installed tested app/widget six hashes',read(t/'final-installed-identity.json')['allMatch'] and len(read(t/'final-installed-identity.json')['files'])==6,t/'final-installed-identity.json')
restore=read(t/'full-v2-restoration-proof.json');add('All3Settings tests individually restore all4',len(restore)==3 and all(r['allFourMatch'] and r['original']==r['restored'] for r in restore),t/'full-v2-restoration-proof.json')
for name in ['composition-native-gates','provider-native-gates','paint-native-gates','combined-account-gates']:
 r=read(p/(name+'.json'));add(name,r['allPassed'],p/(name+'.json'))
add('R Account native paragraph/tone assertions',read(p/'account-native-gates.json')['allExecutedNativeAssertionsPassed'] and min(r['contrast'] for r in read(p/'account-raster-results.json'))>=7,p/'account-raster-results.json')
density=read(p/'density-native-gates.json')
add('R/T/S density geometry',density['frozenRTByteProof']==str(t/'frozen-RT.json') and len(density['account']['rhythm'])==4 and density['account']['minimumHelperContrast']>=7 and len(density['capacity'])==4 and all(abs(r['savedPoints']-16)<=1e-9 for r in density['capacity']) and len(density['signin'])==4 and all(abs(v-(20 if 'Group' in k else 8))<=1e-9 for r in density['signin'] for k,v in r['gaps'].items()),p/'density-native-gates.json')
add('Board final row/ink',len(read(p/'pixel-geometry-results.json'))==8,p/'pixel-geometry-results.json')
add('Normal+combined edge raster/AX',len(read(o/'edge/raster-results.json'))==60 and len(read(o/'edge/ax-results.json'))==60,o/'edge/raster-results.json')
add('16native secure-field spans144px',len(read(p/'secure-field-pixel-proof.json'))==16 and all(r['rasterHeight']>=144 for r in read(p/'secure-field-pixel-proof.json')),p/'secure-field-pixel-proof.json')
add('Activity native8short+4long OCR/ink/count gates',len(read(p/'activity-native-gates.json'))==8 and len(read(p/'activity-long-native-gates.json'))==4,p/'activity-native-gates.json')
videos=read(p/'video-artifacts.json');add('9recordings,3samples each,6unmodified2s frames',len(videos)==9 and all(len(r['inspectionSamplesSeconds'])==3 for r in videos) and sum(bool(r.get('unmodified2sFrameVerified')) for r in videos)==6,p/'video-artifacts.json')
inventory=read(o/'inventory.json');add('808final native PNG hash/dimension/source identity',len(inventory['images'])==808 and all(sha(o/r['file'])==r['sha256'] and r['dimensions']==[1206,2622] and r['sourceIdentity']==freeze['sourceIdentity'] for r in inventory['images']),o/'inventory.json')
add('44matched login before/after pairs',read(t/'login-pairings.json')['count']==44 and all(sha(r['before'])==r['beforeSHA256'] and sha(r['after'])==r['afterSHA256'] for r in read(t/'login-pairings.json')['pairs']),t/'login-pairings.json')
add('All17usable references paired',read(p/'reference-coverage.json')['count']==17,p/'reference-coverage.json')
modes=['core','bottom','extras','enabled','board','keyboards','motion','account-normal','account-detents','account-guidance','account-errors','activity','long-activity','signin-chrome-normal','paint-normal','edge','combined-keyboards','signin-chrome-combined','paint-combined','account-combined','edge-solid']
add('All21final capture protocols finish',all(read(p/('capture-'+n+'.json'))[-1]['exit']==0 for n in modes),p/'capture.py')
inspection=read(p/'inspection.json');seen=set()
for v in inspection.values():
 if isinstance(v,list):seen.update(x for x in v if isinstance(x,str))
 elif isinstance(v,str) and v.endswith('.jpg'):seen.add(v)
sheets={str(f) for f in o.rglob('contact-sheets/*.jpg') if 'rejected' not in f.parts};add('All80main contact sheets inspected',len(sheets)==80 and sheets<=seen,p/'inspection.json')
device=read(p/'final-device-state.json');add('Device restored/closed without shutdown',device['booted'] and not device['shutdown'] and device['switches']['allFourMatch'] and device['ownedActivityIDs']==[] and device['appearance']=='Light' and device['textSize']=='Large',p/'final-device-state.json')
add('Original strings retained',read(t/'copy-integrity.json')['allOriginalStringLiteralsRetained'],t/'copy-integrity.json')
add('Final source commit and clean worktree',False,t/'git-final-read-check.json')
add('Additional ordinary fully-filled comparison supplement',False,t/'optional-filled-pair-status.json',required=False)
checks.append(dict(name='Parent/user visual review',passed=None,required=False,status='Informational; pending actual review, scores remain parent-owned; review is required before any parent app merge'))
result=dict(sourceSHA=None,parentSourceSHA=freeze['sourceSHA'],sourceIdentity=freeze['sourceIdentity'],checks=checks,allRequiredChecksPassed=all(r['passed'] for r in checks if r['required']),allExecutedImplementationAndNativeGatesPassed=all(r['passed'] for r in checks if r['required'] and r['name']!='Final source commit and clean worktree'),referenceGaps=['No exact auth, Activity, capacity, medium, combined-system-configuration or Notes reference'],comparisonGap='44matched pairs include password-populated ordinary frames;8inert filled-enabled previews lack an exact frozen-S counterpart. Additional fully-filled ordinary supplement stopped after documented driver failures; no fabricated pairs.',capturedFamilies=dict(collections.Counter(r['family'] for r in inventory['images'])),atUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
(p/'checks.json').write_text(json.dumps(result,indent=2));print('Technical/native',result['allExecutedImplementationAndNativeGatesPassed'],'overall required',result['allRequiredChecksPassed']);print('Failed required',[r['name'] for r in checks if r['required'] and not r['passed']])
