"""Actual full-suite and source-integrity gate. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import json,pathlib,hashlib,re
p=pathlib.Path(__file__).parent;s=json.loads((p/'final-summary.json').read_text());proc=json.loads((p/'final-process.json').read_text())
assert proc['exit']==0 and s['passedTests']==291 and s['failedTests']==0 and s['skippedTests']==0 and s['expectedFailures']==0
lines=proc['observations'];unit=sum("Test Case '-[LazyMansRemindersTests." in x and ']\' passed' in x for x in lines);ui=sum("Test Case '-[HillclimbUITests." in x and ']\' passed' in x for x in lines)
assert (unit,ui)==(263,28),(unit,ui)
inputs=json.loads((p/'final-inputs.json').read_text());changed=[f for f,h in inputs['hashes'].items() if hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()!=h]
assert not changed,changed
r=json.loads((p/'raster-results.json').read_text());assert len(r['samples'])==44 and r['minimum']>=4.5
out=dict(passedTests=s['passedTests'],unit=unit,UI=ui,failed=s['failedTests'],skipped=s['skippedTests'],sourceSHA=inputs['sourceSHA'],unchangedInputHashes=True,nativeRasterSamples=len(r['samples']),minimumNativeContrast=r['minimum'],result='passed')
(p/'gates.json').write_text(json.dumps(out,indent=2));print(out)
