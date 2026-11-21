"""Copy review originals from native XCTest attachments; raw exports stay local.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,subprocess,re,hashlib,struct,shutil,gzip
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');out=Path('hillclimb/rounds/7');rows=[];commands=[];externals=[]
assert (t/'full-v2-process.json').exists()
for f in sorted(Path('ios/UITests').glob('*.swift')):
 group=re.search(r'class (\w+)',f.read_text()).group(1)
 d=t/('full-v2-'+group)
 if not (d/'manifest.json').exists():
  d=Path('/tmp/hillclimb-login-U-full-v2-export')/group
  cmd=['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-login-U-full-v2.xcresult','--output-path',str(d),'--test-id',group]
  r=subprocess.run(cmd,capture_output=True,text=True);commands.append(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));(p/'export-commands.json').write_text(json.dumps(commands,indent=2));r.check_returncode()
 for test in json.loads((d/'manifest.json').read_text()):
  for a in test['attachments']:
   raw=d/a['exportedFileName'];h=hashlib.sha256(raw.read_bytes()).hexdigest();externals.append(dict(path=str(raw.resolve()),sha256=h,bytes=raw.stat().st_size))
   if raw.suffix!='.png':continue
   name=a['suggestedHumanReadableName']
   if name.startswith('chrome-loading-') and '-2.0' not in name:continue
   safe=re.sub(r'[^A-Za-z0-9._-]', '-', name)
   dest=out/('new-'+group)/(safe+'--'+raw.name);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(raw,dest);b=dest.read_bytes()
   rows.append(dict(file=str(dest),attachmentName=name,testIdentifier=test['testIdentifier'],rawExport=str(raw.resolve()),sha256=h,dimensions=struct.unpack('>II',b[16:24]),acquisition='XCTest native screenshot attachment',protectedPartial=('settings' not in name.lower()) and (any(v in name.lower() for v in ['password','populated']) or ('CombinedSettingsPopulatedPassword' in test['testIdentifier'])),sourceIdentity=json.loads((t/'freeze.json').read_text())['sourceIdentity'],binaryProof=str(t/'tested-artifacts.json')))
 print(group,flush=True)
(p/'xctest-native-inventory.json').write_text(json.dumps(rows,indent=2))
metadata={}
for row in rows:
 name=row['attachmentName'];system='settings' in name.lower();combined='Combined' in row['testIdentifier'];style='dark' if 'dark' in name.lower() or 'Dark' in row['testIdentifier'] else 'light';size='XXXL' if 'XXXL' in name or 'XXXL' in row['testIdentifier'] else 'default'
 metadata[str(Path(row['file']).relative_to(out))]=dict(appearance=style,size='system-unlabelled' if system else size,configuration='Native Settings stage proof; values are recorded at each original/enabled/restored stage' if system else 'Actual combined system switches' if combined else 'Original system switches; app-local style/type overrides as named',protectedPartial=row['protectedPartial'],sourceIdentity=row['sourceIdentity'])
(out/'native-metadata.json').write_text(json.dumps(metadata,indent=2))
with gzip.open(p/'external-attachment-exports.json.gz','wt') as stream:json.dump(externals,stream)
print(len(rows),'selected native PNG review originals; loading repeats remain raw')
