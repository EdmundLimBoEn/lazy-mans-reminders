"""Public XCTest samples and dispersion. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import json,pathlib,statistics,math
p=pathlib.Path(__file__).parent
raw=json.loads((p/'awake-metrics.json').read_text());rows=[]
for test in raw:
 if 'PerformanceUITests' not in test['testIdentifier']:continue
 for run in test['testRuns']:
  for metric in run['metrics']:
   samples=metric['measurements'];assert len(samples)>=5 and all(math.isfinite(v) and v>=0 for v in samples)
   rows.append(dict(test=test['testIdentifier'],name=metric['displayName'],unit=metric['unitOfMeasurement'],samples=samples,mean=statistics.mean(samples),sampleSD=statistics.stdev(samples),populationSD=statistics.pstdev(samples),populationRSDPercent=100*statistics.pstdev(samples)/statistics.mean(samples) if statistics.mean(samples) else 0,minimum=min(samples),maximum=max(samples),device=run['device']))
assert any('Launch' in r['test'] for r in rows)
assert any('Elapsed' in r['test'] for r in rows)
assert any('Signpost' in r['test'] for r in rows)
assert all(min(r['samples'])>0 for r in rows if 'Launch' in r['test'] or 'Elapsed' in r['test'])
(p/'performance-results.json').write_text(json.dumps(dict(sourceSHA=json.loads((p/'freeze.json').read_text())['sourceSHA'],configuration='Unsigned arm64 Debug, seeded long-text/light/default, private Auth17 iOS26.2/23C54',hostObservations='awake-process.json',framePacingObserved=False,hitchMetricMeasured=False,scrollSignpostReported='Duration only; no frame/hitch data returned by this chosen metric',metrics=rows,scope='Simulator baseline; elapsed transaction metric includes XCTest overhead and quiescence. No invented before baseline, speed threshold or hardware feel claim.'),indent=2));print(json.dumps(rows,indent=2))
