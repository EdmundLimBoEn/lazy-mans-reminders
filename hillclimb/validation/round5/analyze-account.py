"""Fresh Account native raster measurements.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,collections,math,sys,re
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[3]
out=root/'hillclimb/rounds/5/account-enabled'
def luminance(rgb):
    v=[c/255 for c in rgb]
    v=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v]
    return sum(c*w for c,w in zip(v,[.2126,.7152,.0722]))
def contrast(a,b):
    x,y=sorted([luminance(a),luminance(b)])
    return (y+.05)/(x+.05)
results=[]
alignments=[]
for manifestpath in out.glob('captures-*.json'):
    if 'normal' not in manifestpath.name and 'guidance' not in manifestpath.name: continue
    for record in json.loads(manifestpath.read_text())['images']:
        attrs=json.loads(record['geometry'])
        # The device CLI wraps accessibility attributes in its result envelope.
        def values(obj):
            if isinstance(obj,dict):
                for k,v in obj.items():
                    if k=='value' and isinstance(v,str):
                        try:
                            parsed=json.loads(v)
                            if isinstance(parsed,dict) and any('.footer' in k or '.helper' in k for k in parsed): return parsed
                        except (ValueError,TypeError):
                            recovered={k:json.loads('['+a+']') for k,a in re.findall(r'"([^"\\]+)":\[([^\]]+)\]',v)}
                            if recovered: return recovered
                    found=values(v)
                    if found: return found
            elif isinstance(obj,list):
                for v in obj:
                    found=values(v)
                    if found: return found
            return None
        frames=values(attrs)
        if not frames: raise RuntimeError('No native frame data '+record['path'])
        image=Image.open(root/record['path']).convert('RGB')
        assert image.size==(1206,2622),image.size
        if all(k in frames for k in ["Delete Account….title", "Send Feedback.title"]):
            delete,feedback=frames["Delete Account….title"],frames["Send Feedback.title"]
            if all(170<f[1] and f[1]+f[3]<830 for f in [delete,feedback]):
                assert abs(delete[0]-feedback[0])<=.5
                ink_bounds={}
                for key,frame in [("delete",delete),("feedback",feedback)]:
                    x,y,w,h=frame
                    hits=[]
                    for py in range(math.ceil(y*3),math.floor((y+h)*3)):
                        for px in range(math.ceil(x*3),math.floor((x+w)*3)):
                            r,g,b=image.getpixel((px,py))
                            if (max(r,g,b)<100 if "-light-" in record["path"] else min(r,g,b)>210):
                                hits.append(px)
                    assert len(hits)>30,(record["path"],key,"No title ink")
                    ink_bounds[key]=min(hits)/3
                assert abs(ink_bounds["delete"]-ink_bounds["feedback"])<=2
                alignments.append(dict(path=record["path"],titleFrames={"delete":delete,"feedback":feedback},firstSolidInkX=ink_bounds))
        for key,frame in frames.items():
            if not (key.endswith('.footer') or key.endswith('.helper')): continue
            x,y,w,h=frame
            if y<170 or y+h>840 or w<10 or h<8: continue
            crop=(math.ceil(x*3),math.ceil(y*3),math.floor((x+w)*3),math.floor((y+h)*3))
            colors=collections.Counter(image.crop(crop).getdata())
            bg=colors.most_common(1)[0][0]
            # Solid neutral glyph pixels exclude low-contrast antialias edges.
            candidates=[(rgb,count) for rgb,count in colors.items() if max(rgb)-min(rgb)<=12 and abs(luminance(rgb)-luminance(bg))>.25 and count>=12]
            assert candidates,(record['path'],key,'No solid ink')
            ink,count=max(candidates,key=lambda pair:pair[1])
            ratio=contrast(ink,bg)
            results.append(dict(path=record['path'],key=key,frame=frame,crop=crop,background=bg,ink=ink,solidPixels=count,contrast=ratio))

(pathlib.Path(__file__).parent/'account-pixel-alignment.json').write_text(json.dumps(alignments,indent=2))

(pathlib.Path(__file__).parent/'account-raster-results.json').write_text(json.dumps(results,indent=2))
assert len(alignments)>=4,'Require actual title ink in both styles and sizes'
assert results,'Zero raster checks is not a pass'
coverage=collections.defaultdict(set)
for result in results:
    coverage[result['key']].add(tuple(pathlib.Path(result['path']).stem.split('-')[1:3]))
expected={(style,size) for style in ['light','dark'] for size in ['default','XXXL']}
for key in ['notifications.footer','persistence.footer','home.helper','lock.helper','widget.helper','delete.footer','feedback.footer','version.footer']:
    assert coverage[key]==expected,(key,coverage[key])
(pathlib.Path(__file__).parent/'account-raster-coverage.json').write_text(json.dumps({k:sorted(v) for k,v in coverage.items()},indent=2))
assert all(r['contrast']>=4.5 for r in results),[(r['path'],r['key'],r['contrast']) for r in results if r['contrast']<4.5]
print(len(results),'native helper/footer checks passed; minimum',min(r['contrast'] for r in results))
