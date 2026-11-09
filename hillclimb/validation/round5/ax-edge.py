"""Native AX-tree gate. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import json,pathlib
p=pathlib.Path("hillclimb/rounds/5/edge");results=[]
for f in sorted(p.glob('captures*/*.ax.json')):
 nodes=json.loads(f.read_text())['data']['nodes'];paragraphs=[n for n in nodes if n['type']=='StaticText' and n.get('label','').startswith('Demo ')];assert not paragraphs,(f,paragraphs)
 buttons=[n for n in nodes if n['type']=='Button' and n.get('label','').startswith('Demo ')]
 labels=[n['label'].strip() for n in buttons];assert len(labels)==len(set(labels)),f
 for label in labels:
  grips=[n for n in nodes if n.get('label','').strip()=='Reorder '+label];assert len(grips)==1,(f,label)
 first=[n for n in buttons if n['label'].startswith('Demo 1:')]
 if 'completion-before' in f.name or 'completion-text-tap' in f.name:assert len(first)==1,f
 if 'completion-circle-edge' in f.name:assert len(first)==0,f
 results.append({'file':str(f),'readingButtons':len(buttons),'staticParagraphStops':len(paragraphs),'uniqueFullLabels':True,'reorderLeafPerVisibleReminder':True})
assert len(results)>=36
(p/'ax-results.json').write_text(json.dumps(results,indent=2));print('Native AX snapshots passed:',len(results))
