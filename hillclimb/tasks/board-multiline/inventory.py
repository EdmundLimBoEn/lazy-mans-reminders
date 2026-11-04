#!/usr/bin/env python3
import hashlib, json, pathlib, subprocess
from PIL import Image
out=pathlib.Path(__file__).resolve().parent
root=out.parents[2]
source=subprocess.check_output(['git','rev-parse','1add78a'],cwd=root,text=True).strip()
files=[]
for folder in ['retry-final','final2-attachments','final2-dark-bottom','final2-light-XXXL-bottom','final2-light-bottom']:
    for path in sorted((out/folder).glob('*.png')):
        with Image.open(path) as im: size=im.size
        files.append(dict(path=str(path.relative_to(out)),width=size[0],height=size[1],sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(out/'inventory-final2.json').write_text(json.dumps(dict(sourceSHA=source,hostId='local',deviceId='066ECE57-46B4-414A-B53E-523775329360',runtime='iOS 26.2 (23C54)',captures=files),indent=2)+'\n')
print('Final-source PNGs:',len(files))
