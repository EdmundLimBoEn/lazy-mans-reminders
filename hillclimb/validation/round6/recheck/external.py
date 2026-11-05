"""Retain full local results without committing large runner recordings.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib
p=pathlib.Path(__file__).parent;sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest(); rows=[]
for name in ['focused','attempt-short','combined']:
 d=pathlib.Path('/tmp/hillclimb-r6-recheck-b846a915-'+name+'.xcresult')
 if not (d/'Info.plist').exists():continue
 files=[dict(file=str(f),bytes=f.stat().st_size,sha256=sha(f)) for f in d.rglob('*') if f.is_file()];rows.append(dict(path=str(d),totalBytes=sum(f['bytes'] for f in files),files=files))
(p/'external-xcresults.json').write_text(json.dumps(rows,indent=2))
