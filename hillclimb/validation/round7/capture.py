"""Round 7 captures from the worker's exclusive pinned session.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,sys,datetime,os
P=pathlib.Path(__file__).parent
C='/Users/limboenedmund/.t3/userdata/device/targets/t3-23bb48939566ebc32a337197/agent-device'
D=str(P/'device.json');O='hillclimb/rounds/7'
commands={
 'core':['bash','scripts/hillclimb/shots.sh','--round','7','--command',C,'--device',D,'--operations','scripts/hillclimb/operations.example.json'],
 'bottom':['python3','scripts/hillclimb/repair-bottom-captures.py','--round','7','--command',C],
 'extras':['python3','scripts/hillclimb/capture-extras.py','--round','7','--command',C,'--device',D],
 'enabled':['python3','scripts/hillclimb/capture-extras.py','--round','7','--command',C,'--device',D,'--signin-appearance','enabled'],
 'board':['python3','scripts/hillclimb/capture-board.py','--command',C,'--out',O+'/board'],
 'keyboards':['python3','scripts/hillclimb/capture-keyboards.py','--command',C,'--out',O+'/keyboards'],
 'motion':['python3','scripts/hillclimb/capture-motion.py','--command',C,'--out',O+'/motion'],
 'activity':['python3','scripts/hillclimb/capture-activity.py','--command',C,'--device',D,'--out',O+'/activity'],
 'long-activity':['python3',str(P/'capture-long-activity.py'),'--command',C,'--device',D,'--out',O+'/activity-long'],
 'edge':['python3',str(P/'capture-edge.py')],
 'edge-solid':['python3',str(P/'capture-edge.py'),'-solid'],
 'combined-keyboards':['python3',str(P/'capture-combined-keyboards.py')],
}
for configuration in ['normal','combined']:
 commands['signin-chrome-'+configuration]=['python3',str(P/'capture-signin-chrome.py'),configuration]
 commands['paint-'+configuration]=['python3',str(P/'capture-paints.py'),configuration]
commands['account-combined']=['python3','scripts/hillclimb/capture-account.py','--command',C,'--out',O+'/account-combined','guidance']
for mode in ['normal','detents','guidance','errors']:
 commands['account-'+mode]=['python3','scripts/hillclimb/capture-account.py','--command',C,'--out',O+'/account-enabled',mode]
for name in sys.argv[1:]:
 if name in ['edge-solid','account-combined','combined-keyboards','signin-chrome-combined','paint-combined']:
  enabled=json.loads((P/'manual-enabled.json').read_text())
  assert all(enabled[k]=='1' for k in ['Reduce Motion','Reduce Transparency','Increase Contrast']), 'Actual Settings enable proof is required before combined captures'
 cmd=commands[name];print(name,flush=True);start=datetime.datetime.now(datetime.timezone.utc).isoformat();r=subprocess.run(cmd,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',HILLCLIMB_SOURCE_FREEZE=str(pathlib.Path("hillclimb/tasks/login-composition/freeze.json").resolve())))
 file=P/('capture-'+name+'.json');prior=json.loads(file.read_text()) if file.exists() else []
 prior.append(dict(command=cmd,exit=r.returncode,startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat()));file.write_text(json.dumps(prior,indent=2))
 if r.returncode:sys.exit(r.returncode)
