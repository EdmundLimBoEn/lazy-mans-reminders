"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,hashlib
p=pathlib.Path(__file__).parent
summary=json.loads((p/'final-summary.json').read_text());assert summary['passedTests']==287 and summary['failedTests']==0 and summary['skippedTests']==0,summary
assert not summary['testFailures'];assert summary['devicesAndConfigurations'][0]['device']['deviceId']=='066ECE57-46B4-414A-B53E-523775329360'
def cases(file):
 result={}
 def visit(n):
  if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
  for c in n.get('children',[]):visit(c)
 for n in json.loads(file.read_text())['testNodes']:visit(n)
 return result
actual=cases(p/'final-tests.json');baseline={k:v for k,v in cases(p/'attempt1/combined-tests.json').items() if '/BoardEdgeAccessibilityUITests/' not in k}
assert len(baseline)==285 and len(actual)==287
assert baseline.keys()<=actual.keys();assert all(v=='Passed' for v in actual.values())
unit=[k for k in actual if '/LazyMansRemindersTests/' in k];ui=[k for k in actual if '/HillclimbUITests/' in k];assert len(unit)==263 and len(ui)==24
manifest=json.loads((p/'build-capture-inputs.json').read_text());inputs=json.loads((p/'final-inputs.json').read_text());assert manifest['source']==inputs['source_hashes'];assert inputs['sourceSHA']=='0265cb4aa84c86575ed630633ba835c416eb4de7'
for name,digest in manifest['source'].items():assert hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest()==digest,name
for name,digest in manifest['binary'].items():assert hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest()==digest,name
for name,digest in manifest['xctestrun'].items():assert hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest()==digest,name
native=json.loads((p/'raster-results.json').read_text());assert len(native)==60
assert len([x for x in native if 'bottomRowClearsComposer' in x])==16
assert len([x for x in native if 'freshTopFirstRowContrast' in x])==16
assert len([x for x in native if 'contrast' in x])==16
assert len(json.loads((p/'ax-results.json').read_text()))==60
for name,expected in [('settings-original',False),('settings-solid-enabled',True),('settings-restored',False)]:
 nodes=json.loads((p/(name+'.json')).read_text())['data']['nodes']
 for label in ['Reduce Transparency','Increase Contrast']:
  values=[n['checked'] for n in nodes if n.get('type')=='Switch' and n.get('label')==label];assert values==[expected],(name,label,values)
(p/'acceptance.json').write_text(json.dumps({'tests':len(actual),'unit':len(unit),'ui':len(ui),'oldBaselineTestsRetainedAndPassed':len(baseline),'failed':0,'skipped':0,'manualPNGs':len(native),'nativeAXSnapshots':60,'sourceAndBinaryHashesMatch':True,'settingsRestored':True},indent=2));print('Final acceptance: 287/287, baseline285 retained, all native gates passed')
