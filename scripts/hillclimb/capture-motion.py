"""Native simulator recordings, with no inference about physical frame pacing.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import argparse,pathlib,subprocess,json,hashlib,struct,time
p=argparse.ArgumentParser();p.add_argument('--command',required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
m={'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'operations':[],'captures':[]}
def run(*args):
 r=subprocess.run([a.command,*args],capture_output=True,text=True);m['operations'].append(dict(argv=[a.command,*args],exit=r.returncode,stdout=r.stdout,stderr=r.stderr));save();r.check_returncode();return r.stdout
def save():(a.out/'manifest.json').write_text(json.dumps(m,indent=2))
def stable():run('wait','stable','1000','10000')
def launch(mode,style,size,*extra):
 run('settings','appearance',style);run('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
 run('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in ['--hillclimb-demo',mode,'--hillclimb-style',style,'--hillclimb-size',size,*extra]]);stable()
def shot(name):
 stable();f=a.out/(name+'.png');assert not f.exists();(a.out/(name+'.txt')).write_text(run('snapshot','-i'));run('screenshot',str(f.resolve()),'--pixel-density','3');b=f.read_bytes();m['captures'].append(dict(file=f.name,sha256=hashlib.sha256(b).hexdigest(),dimensions=list(struct.unpack('>II',b[16:24]))));save()
launch('empty','light','default');video=a.out/'composer-light-default.mp4';assert not video.exists();run('record','start','--scope','device','--hide-touches',str(video.resolve()))
try:
 run('click',"label='New reminder'");run('fill',"label='New reminder'",'Remember the weekly review');shot('composer-light-default-focused');run('click',"label='Done'");shot('composer-light-default-dismissed');run('click',"label='New reminder'");shot('composer-light-default-refocused');run('click',"label='Done'")
finally:run('record','stop')
launch('account','dark','XXXL','--hillclimb-account-appearance','enabled');video=a.out/'account-dark-XXXL-scroll.mp4';assert not video.exists();run('record','start','--scope','device','--hide-touches',str(video.resolve()))
try:
 run('press','role=button label="Add a lasting widget"','--settle');run('scroll','bottom','--settle');shot('account-dark-XXXL-lower');run('scroll','top','--settle');stable()
finally:run('record','stop')
run('settings','appearance','light');run('settings','text-size','large')
