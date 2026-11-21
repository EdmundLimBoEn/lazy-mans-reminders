"""Own native Settings values and verified-coordinate toggles.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,sys
p=pathlib.Path(__file__).parent;out=pathlib.Path('hillclimb/rounds/7/settings');out.mkdir(exist_ok=True)
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True);r.check_returncode();assert 'Error (' not in r.stdout+r.stderr,r.stdout+r.stderr;return r.stdout
if sys.argv[1]=='shot':
 name=sys.argv[2];(out/(name+'.txt')).write_text(op('snapshot','-i'));(out/(name+'.json')).write_text(op('snapshot','-i','--json'));f=out/(name+'.png');assert not f.exists();print(op('screenshot',str(f),'--pixel-density','3'))
else:
 label=sys.argv[2];a=json.loads(op('get','attrs','role=switch label="'+label+'"'));r=a['rect'];print(op('press',str(r['x']+r['width']-24),str(r['y']+r['height']/2),'--settle'));print(op('snapshot','-i'))
