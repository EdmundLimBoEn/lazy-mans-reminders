"""Export structured final XCTest evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,subprocess,hashlib,shutil,sys
p=pathlib.Path(__file__).parent;bundle='/tmp/hillclimb-round6-65d9521e-combined.xcresult';records=[]
for name in ['SignInChromeUITests','AccountChromeUITests','BoardCapacityPresentationUITests','ActivityNativeLayoutTests','BoardEdgeAccessibilityUITests','BoardMultilineUITests','ErrorContrastUITests','SignInSurfaceUITests']:
 dest=p/('combined-'+name)
 cmd=['xcrun','xcresulttool','export','attachments','--path',bundle,'--output-path',str(dest),'--test-id',name]
 r=subprocess.run(cmd,capture_output=True,text=True);records.append(dict(command=cmd,exit=r.returncode,stderr=r.stderr));(p/'attachment-exports.json').write_text(json.dumps(records,indent=2));r.check_returncode()
 if name in ['SignInChromeUITests','AccountChromeUITests','BoardCapacityPresentationUITests']:
  out=pathlib.Path('hillclimb/rounds/6/new-'+name);out.mkdir(exist_ok=True)
  for test in json.loads((dest/'manifest.json').read_text()):
   for a in test['attachments']:
    f=dest/a['exportedFileName']
    if f.suffix=='.png':
     title=a['suggestedHumanReadableName']
     if pathlib.Path(title).suffix!='.png':title += '.png'
     shutil.copyfile(f,out/title)
 print(name,flush=True)
