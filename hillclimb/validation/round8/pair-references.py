"""Closest available Apple states, with every semantic/configuration gap explicit.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib
p=Path('hillclimb/rounds/8');rows=json.loads((p/'inventory.json').read_text())['images'];refs=json.loads(Path('hillclimb/validation/round7/reference-inventory.json').read_text());pairs=[];used=set()
for x in refs:assert hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256']
for r in rows:
 n=r['attachmentName'].lower();t=r['testIdentifier'];style=r['appearance'];size=r['textSize'];assert style in ['light','dark'] and size in ['default','XXXL'],r
 family='Account' if 'Account' in t or 'account' in n else 'Sign In' if any(s in t for s in ['SignIn','Login']) or 'signin' in n else 'Activity' if 'Activity' in t else 'Board'
 state='sheet' if family=='Account' else 'compose' if any(s in n for s in ['composer','keyboard','focus']) else 'bottom' if any(s in n for s in ['bottom','pull','final-ink']) else 'empty' if 'empty' in n and family=='Board' else 'top'
 available=[x for x in refs if x['metadata']['appearance']==style and x['metadata']['state']==state];best=next((x for x in available if ('XXXL' in x['path'])==(size=='XXXL')),available[0] if available else next(x for x in refs if x['metadata']['state']=='empty'))
 gaps=[]
 if family in ['Sign In','Activity']:gaps.append('No semantic Apple counterpart; closest typography/spacing comparison only')
 if 'combined' in n or 'Combined' in t:gaps.append('No matching combined-accessibility-settings reference')
 if family=='Account' and 'medium' in n:gaps.append('No exact medium-detent counterpart')
 if ('XXXL' in best['path'])!=(size=='XXXL'):gaps.append('Text-size mismatch')
 if best['metadata']['appearance']!=style:gaps.append('Appearance mismatch')
 if 'capacity' in n:gaps.append('No exact capacity-state counterpart')
 used.add(best['path']);pairs.append(dict(screen=r['file'],family=family,appearance=style,textSize=size,reference='../../'+best['path'].removeprefix('hillclimb/'),referenceSHA256=best['sha256'],relationship='Closest native Reminders '+state+' state',gaps=gaps))
assert len(used)==17
Path('hillclimb/validation/round8/reference-pairings.json').write_text(json.dumps(dict(pairs=pairs,references=refs,usedReferencePaths=sorted(used),gaps=['Notes unavailable','No exact auth, Activity, capacity, medium-detent or combined-accessibility counterpart']),indent=2)+'\n');print(len(pairs),'canonical pairs, all17usable references')
