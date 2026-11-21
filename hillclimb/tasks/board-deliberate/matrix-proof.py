"""Verify all eight fresh focus cases and their independent edge taps.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import json,pathlib,subprocess
O=pathlib.Path(__file__).parent;proof=[]
def titles(v):
 if isinstance(v,dict):
  if 'title' in v:yield v['title']
  for c in v.values():yield from titles(c)
 elif isinstance(v,list):
  for c in v:yield from titles(c)
for name in ['combined','keyboard1','keyboard2','keyboard3']:
 path=O/f'{name}-keyboard-activities.json'
 if not path.exists():path.write_text(subprocess.check_output(['xcrun','xcresulttool','get','test-results','activities','--path',f'/tmp/notepad-board-h-{name}.xcresult','--test-id','SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances()'],text=True))
 cases=[]
 for title in titles(json.loads(path.read_text())):
  if title.startswith("Added attachment named 'signin-"):cases.append({'capture':title,'doneEdgeTaps':[],'alternateEdgeTaps':[]})
  elif cases and 'Tap "Done" Button[0.95, 0.50]' == title:cases[-1]['doneEdgeTaps'].append(title)
  elif cases and title.startswith('Tap "Use ') and title.endswith('Button[0.05, 0.50]'):cases[-1]['alternateEdgeTaps'].append(title)
 assert len(cases)==8 and all(c['doneEdgeTaps'] and c['alternateEdgeTaps'] for c in cases),(name,cases)
 proof.append({'run':name,'cases':cases,'completed':8})
(O/'matrix-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print('32 complete cases; 24 in three fresh repeats plus 8 combined')
