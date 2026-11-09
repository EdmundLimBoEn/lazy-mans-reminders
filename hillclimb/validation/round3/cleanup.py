"""Close only this worker's apps/session; keep original17 booted.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,json,pathlib
p=pathlib.Path(__file__).parent;agent='/Users/limboenedmund/.t3/userdata/device/targets/t3-d375faee8af31d01dd89e9c3/agent-device';ops=[]
for args in [['settings','appearance','light'],['settings','text-size','large'],['click',"label='Back'"],['snapshot','-i'],['close','com.apple.reminders'],['open','systems.edmundlim.NotepadHillclimb','--relaunch','--launch-args=--hillclimb-demo','--launch-args=empty'],['close','systems.edmundlim.NotepadHillclimb']]:
 r=subprocess.run([agent,*args],capture_output=True,text=True);ops.append({'argv':[agent,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});(p/'handback.json').write_text(json.dumps({'operations':ops,'activityCleanup':'../../rounds/3/activity/cleanup.json','noShutdownRequested':True},indent=2));r.check_returncode();print(r.stdout[-300:],flush=True)
