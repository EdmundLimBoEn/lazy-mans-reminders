"""Validate the exact round8 evidence contract without changing scores.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,re,statistics,sys
r=Path('hillclimb/rounds/8');categories=re.findall(r'^\d+\. (.+)$',Path('hillclimb/rubric.md').read_text(),re.M);assert len(categories)==30
inventory=json.loads((r/'inventory.json').read_text());screens={x['file'] for x in inventory['images']};refs={Path(x).resolve() for x in json.loads(Path('hillclimb/validation/round8/reference-pairings.json').read_text())['usedReferencePaths']};checks=json.loads((r/'checks.json').read_text());assert checks['allRequiredChecksPassed']
rows=[]
for model in sys.argv[1:] or ['gpt-6.1-sol','gpt-6-astra']:
 p=r/f'scores-{model}.json';d=json.loads(p.read_text());c=d['categories'];assert len(c)==30 and {x['name'] for x in c}==set(categories)
 assert d['model']==model and d['round']==8 and d['source_sha']==checks['source_sha'] and d['sourceIdentity']==checks['sourceIdentity']
 assert len(d['screenshots'])==len(set(d['screenshots']))==332 and set(d['screenshots'])==screens
 assert len(d['references'])==len(set(d['references']))==17 and {(r/x).resolve() for x in d['references']}==refs
 assert all((r/x).is_file() for x in d['screenshots']+d['references'])
 v=[x['score'] for x in c];assert all(type(x) in (int,float) and 1<=x<=10 for x in v);assert d['overall']==round(statistics.mean(v),2)
 assert all(x.get('rationale') and x.get('screenshot_assessment') and x.get('source_assessment') for x in c)
 assert (r/f'scores-{model}.md').is_file()
 rows.append({'model':model,'overall':d['overall'],'minimum':min(v),'categories':30,'screenshots':332,'references':17,'sourceSHA':d['source_sha']})
print(json.dumps(rows,indent=2))
