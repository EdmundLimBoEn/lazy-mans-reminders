import pathlib,json,hashlib,collections,shutil,subprocess
from PIL import Image,ImageDraw
root=pathlib.Path(__file__).resolve().parents[3];out=root/'hillclimb/tasks/account-consistency'
source=json.loads((out/'source-final.json').read_text())
accepted=[];historical=[];operations=[]
for name in ['normal3','detents','errors','guidance']:
    m=json.loads((out/f'captures-{name}.json').read_text())
    assert m['sourceInputs']==source,(name,'Wrong source inputs')
    assert all(op['exit']==0 for op in m['operations']),(name,'Failed operation')
    for r in m['images']:
        p=root/r['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
        with Image.open(p) as image: assert image.size==(1206,2622)
        accepted.append(dict(path=r['path'],sha256=r['sha256'],manifest=f'captures-{name}.json',dimensions=[1206,2622]))
    operations+=m['operations']
assert len(accepted)==84,len(accepted)
for name in ['light-default-normal','normal','normal2']:
    m=json.loads((out/f'captures-{name}.json').read_text())
    for r in m['images']:
        p=root/r['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'];historical.append(r['path'])
(out/'inventory.json').write_text(json.dumps({'base':'9d484764b5317fe6367411998ef2b6432567f637','sourceInputs':source,'acceptedImages':accepted,'historicalImages':historical,'acceptedOperationCount':len(operations)},indent=2))
for offset in range(0,len(accepted),12):
    records=accepted[offset:offset+12];sheet=Image.new('RGB',(4*240,3*560),'#cccccc');draw=ImageDraw.Draw(sheet)
    for i,r in enumerate(records):
        im=Image.open(root/r['path']).convert('RGB');im.thumbnail((230,510));x=(i%4)*240;y=(i//4)*560;sheet.paste(im,(x,y));name=pathlib.Path(r['path']).stem
        for line in range(0,len(name),32):draw.text((x+2,y+512+line//32*12),name[line:line+32],fill='black')
    sheet.save(out/f'inspection-{offset//12+1:02}.jpg',quality=90)
print(len(accepted),'final images,',len(historical),'historical images,',len(operations),'successful final capture operations')
products=pathlib.Path('/tmp/notepad-account-j-dd/Build/Products/Debug-iphonesimulator')
paths=[products/'LazyMansReminders.app/LazyMansReminders',products/'LazyMansReminders.app/PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension',products/'LazyMansReminders.app/PlugIns/LazyMansRemindersTests.xctest/LazyMansRemindersTests',products/'HillclimbUITests-Runner.app/PlugIns/HillclimbUITests.xctest/HillclimbUITests']+list((products/'LazyMansReminders.app').glob('*.dylib'))
(out/'binary-provenance.json').write_text(json.dumps([dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),architectures=subprocess.check_output(['lipo','-archs',str(p)],text=True).strip()) for p in paths],indent=2))
xct=json.loads((out/'xctestrun-provenance.json').read_text());shutil.copy2(xct['path'],out/'generated.xctestrun')
