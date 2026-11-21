"""Keep native required matrix in Git; retain duplicate exports/results locally by hash.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,gzip,shutil,struct
p=pathlib.Path(__file__).parent;local=pathlib.Path('/tmp/hillclimb-round6-65d9521e-retained');local.mkdir(exist_ok=True);rows=[]
for directory in p.iterdir():
 if directory.is_dir() and (directory.name.startswith('combined-') or directory.name.endswith('-settings')):
  for f in directory.glob('*.png'):
   b=f.read_bytes();dest=local/'duplicate-native-exports'/directory.name/f.name;dest.parent.mkdir(parents=True,exist_ok=True);assert not dest.exists();f.rename(dest)
   rows.append(dict(originalExport=str(f),retainedPath=str(dest),sha256=hashlib.sha256(b).hexdigest(),dimensions=list(struct.unpack('>II',b[16:24])),reason='Raw XCTest native export; required review states copied byte-identically into rounds/6. Does not increase distinct-state count.'))
for f in p.glob('*runtime-log.json'):
 b=f.read_bytes();z=f.with_suffix(f.suffix+'.gz')
 if z.exists():assert gzip.decompress(z.read_bytes())==b
 else:z.write_bytes(gzip.compress(b,mtime=0))
 dest=local/'runtime-raw'/f.name;dest.parent.mkdir(parents=True,exist_ok=True);assert not dest.exists();f.rename(dest);rows.append(dict(originalExport=str(f),retainedPath=str(dest),sha256=hashlib.sha256(b).hexdigest(),committedGzip=str(z),reason='Lossless gzip of structured runtime events; original retained locally'))
(p/'external-export-artifacts.json').write_text(json.dumps(rows,indent=2));print(len(rows),'duplicate/log originals retained locally')
results=[]
for r in sorted(pathlib.Path('/tmp').glob('hillclimb-round6-65d9521e-*.xcresult')):
 files=[]
 for f in sorted(r.rglob('*')):
  if f.is_file():files.append(dict(file=str(f.relative_to(r)),bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
 digest=hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest();results.append(dict(path=str(r),files=files,fileManifestSHA256=digest,totalBytes=sum(x['bytes'] for x in files)))
(p/'external-xcresults.json').write_text(json.dumps(results,indent=2));print(len(results),'xcresult originals retained, including interrupted omission run')
