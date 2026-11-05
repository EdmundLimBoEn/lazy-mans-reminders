"""Hash task evidence after capture/inspection/cleanup.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,hashlib,json
p=pathlib.Path(__file__).parent
out=p/'evidence-sha256.json'
paths=[f for f in p.rglob('*') if f.is_file() and f!=out and '__pycache__' not in f.parts]
out.write_text(json.dumps({str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(paths)},indent=2))
print(len(paths),'evidence files hashed')
