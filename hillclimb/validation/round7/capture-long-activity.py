#!/usr/bin/env python3
"""Round-specific production multiline Activity captures, retaining owned IDs.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,json,pathlib,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--command',required=True);p.add_argument('--out',required=True,type=pathlib.Path);p.add_argument('--device',required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
d=json.loads(pathlib.Path(a.device).read_text());assert d['id']=='78F5A64F-7B2E-4562-8EF9-10F3312CC694'
nav=[]
def run(*args):
 r=subprocess.run([a.command,*args],capture_output=True,text=True);nav.append({'argv':[a.command,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});(a.out/'navigation.json').write_text(json.dumps(nav,indent=2));r.check_returncode()
def capture(surface,style,size):subprocess.run(['python3','scripts/hillclimb/activity-evidence.py','--command',a.command,'--out',str(a.out),'--style',style,'--size',size,'--text','long','--surface',surface],check=True)
for style in ['light']:
 for size in ['default','XXXL']:
  capture('prepare',style,size);time.sleep(3)
  container=subprocess.check_output(['xcrun','simctl','get_app_container',d['id'],'systems.edmundlim.NotepadHillclimb','data'],text=True).strip();record=pathlib.Path(container)/'Documents/hillclimb-activity.json';(a.out/f'pipeline-{style}-{size}.json').write_bytes(record.read_bytes())
  run('open','com.apple.springboard');run('wait','stable','1000','10000');capture('collapsed',style,size);capture('expanded',style,size)
  run('open','com.apple.springboard');run('swipe','180','5','180','650');run('wait','stable','1000','10000');run('snapshot','-i');capture('notification-center',style,size);capture('end',style,size)
run('settings','appearance','light');run('settings','text-size','large')
