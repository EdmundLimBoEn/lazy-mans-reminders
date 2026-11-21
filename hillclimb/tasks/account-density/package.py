"""Keep required originals and compact local artifact identities. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import json,hashlib,gzip
p=Path(__file__).parent;sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();rows=[]
for result in sorted(Path('/tmp').glob('account-r-*.xcresult')):
 files=[{'path':str(f.relative_to(result)),'bytes':f.stat().st_size,'sha256':sha(f)} for f in result.rglob('*') if f.is_file()]
 rows.append({'path':str(result),'files':files})
(p/'external-xcresults.json.gz').write_bytes(gzip.compress(json.dumps(rows,indent=2).encode(),mtime=0))
exports=[]
for d in p.glob('*UITests'):
 if not d.is_dir():continue
 exports += [{'path':str(f.resolve()),'bytes':f.stat().st_size,'sha256':sha(f)} for f in d.rglob('*') if f.is_file()]
for d in [p/'full-AccessibilitySettingsUITests',p/'full-SignInChromeUITests']:
 if d.exists():exports += [{'path':str(f.resolve()),'bytes':f.stat().st_size,'sha256':sha(f)} for f in d.rglob('*') if f.is_file()]
(p/'external-exports.json.gz').write_bytes(gzip.compress(json.dumps(exports,indent=2).encode(),mtime=0))
print(len(rows),'xcresults,',len(exports),'local export files hash-retained')
