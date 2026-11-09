"""Same-device nearest Details reference, with explicit gaps.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,sys
p=pathlib.Path(__file__).parent;root=p.parents[2];rows=[]
for phase in sys.argv[1:]:
 for row in json.loads((p/(phase+'-images.json')).read_text()):
  name=row['name'];style='dark' if name.startswith('dark') else 'light';size='XXXL' if 'XXXL' in name else 'default'
  ref='hillclimb/reference/'+('round3/reminders-sheet-'+style+'-XXXL.png' if size=='XXXL' else 'reminders-sheet-dark.png' if style=='dark' else 'round2/reminders-sheet-light.png')
  file=root/ref
  rows.append(dict(**row,phase=phase,reference=ref,referenceSHA256=hashlib.sha256(file.read_bytes()).hexdigest(),gaps=['Same original17 Apple Reminders Details, different semantics and shorter content','No medium-detent reference' if 'medium' in name else 'No exact Account/error/guidance counterpart','Notes unavailable']))
(p/'paired-images.json').write_text(json.dumps(rows,indent=2));print(len(rows),'paired native images')
