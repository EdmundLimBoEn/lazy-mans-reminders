"""Keep native focused proof and structured full evidence; retain raw exports locally.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,shutil
p=pathlib.Path(__file__).parent;external=pathlib.Path('/tmp/hillclimb-r6-recheck-b846a915-exports');external.mkdir(exist_ok=True);records=[]
for d in p.glob('combined-*UITests'):
 for f in d.iterdir():
  if f.suffix not in ['.json','.txt'] or f.stat().st_size>=50_000_000:
   dest=external/d.name/f.name;dest.parent.mkdir(exist_ok=True);records.append(dict(original=str(f),local=str(dest),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),bytes=f.stat().st_size));shutil.move(f,dest)
(p/'external-exports.json').write_text(json.dumps(records,indent=2))
