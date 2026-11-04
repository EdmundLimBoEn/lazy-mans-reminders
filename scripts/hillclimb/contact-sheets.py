#!/usr/bin/env python3
"""Inspection thumbnails only; original evidence stays unchanged.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,pathlib
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);a=p.parse_args();out=a.directory/'contact-sheets';out.mkdir(exist_ok=True)
files=[f for f in sorted(a.directory.rglob('*.png')) if 'contact-sheets' not in f.parts and 'rejected' not in f.parts]
for offset in range(0,len(files),12):
 page=Image.new('RGB',(1000,4*460),'#777777');d=ImageDraw.Draw(page)
 for n,f in enumerate(files[offset:offset+12]):
  im=Image.open(f).convert('RGB');im.thumbnail((245,410));x=n%4*250;y=n//4*460;page.paste(im,(x,y));d.text((x,y+412),str(f.relative_to(a.directory))[:36],fill='white');d.text((x,y+427),str(f.relative_to(a.directory))[36:72],fill='white')
 page.save(out/f'page-{offset//12+1:02}.jpg')
print(len(files),'images')
