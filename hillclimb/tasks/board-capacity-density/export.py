"""Task-local native attachment extraction. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,subprocess,sys,shutil
p=pathlib.Path(__file__).parent
name=sys.argv[1]; out=p/(name+'-native'); out.mkdir(exist_ok=True)
subprocess.run(['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-capacity-density-T-'+name+'.xcresult','--output-path',str(out),'--test-id','BoardCapacityPresentationUITests'],check=True)
manifest=json.loads((out/'manifest.json').read_text()); dest=p/(name+'-captures');dest.mkdir(exist_ok=True)
for test in manifest:
 for a in test['attachments']:
  n=a.get('suggestedHumanReadableName','').split('_0_')[0]; f=out/a['exportedFileName']
  if n.startswith('capacity-'):
   suffix='.png' if f.suffix=='.png' else ('.geometry.json' if f.read_text().lstrip().startswith('{') else '.ax.txt')
   shutil.copyfile(f,dest/(n+suffix))
