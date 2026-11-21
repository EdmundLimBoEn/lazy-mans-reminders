import json,pathlib,subprocess,time
root=pathlib.Path(__file__).resolve().parents[3];out=root/'hillclimb/tasks/account-consistency'
command=json.loads((out/'setup.json').read_text())['agentDevice']['command']
operations=[]
args=['open','systems.edmundlim.NotepadHillclimb','--relaunch']
for value in ['--hillclimb-demo','account','--hillclimb-style','light','--hillclimb-size','default']:args+=['--launch-args='+value]
for action in [args,['settings','appearance','light'],['settings','text-size','large'],['close','systems.edmundlim.NotepadHillclimb']]:
 p=subprocess.run([command,*action],capture_output=True,text=True)
 operations.append({'argv':[command,*action],'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'time':time.time()})
 (out/'cleanup.json').write_text(json.dumps({'operations':operations,'createdActivityIDs':[],'clearedActivityIDs':[],'shutdownRequested':False},indent=2))
 print(p.stdout,p.stderr,flush=True)
 if p.returncode:raise RuntimeError('Stop and follow the tool error advice once')
