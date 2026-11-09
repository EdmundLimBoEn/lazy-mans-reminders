"""Round 4 captures from the worker's exclusive pinned session.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,sys,datetime
P=pathlib.Path(__file__).parent
C='/Users/limboenedmund/.t3/userdata/device/targets/t3-caa222dd4a63ee4f2b92619f/agent-device'
D=str(P/'device.json');O='hillclimb/rounds/4'
commands={
 'core':['bash','scripts/hillclimb/shots.sh','--round','4','--command',C,'--device',D,'--operations','scripts/hillclimb/operations.example.json'],
 'bottom':['python3','scripts/hillclimb/repair-bottom-captures.py','--round','4','--command',C],
 'extras':['python3','scripts/hillclimb/capture-extras.py','--round','4','--command',C,'--device',D],
 'enabled':['python3','scripts/hillclimb/capture-extras.py','--round','4','--command',C,'--device',D,'--signin-appearance','enabled'],
 'board':['python3','scripts/hillclimb/capture-board.py','--command',C,'--out',O+'/board'],
 'keyboards':['python3','scripts/hillclimb/capture-keyboards.py','--command',C,'--out',O+'/keyboards'],
 'activity':['python3','scripts/hillclimb/capture-activity.py','--command',C,'--device',D,'--out',O+'/activity'],
}
for mode in ['normal','detents','guidance','errors']:
 commands['account-'+mode]=['python3','scripts/hillclimb/capture-account.py','--command',C,'--out',O+'/account-enabled',mode]
for name in sys.argv[1:]:
 cmd=commands[name];print(name,flush=True);start=datetime.datetime.now(datetime.timezone.utc).isoformat();r=subprocess.run(cmd)
 file=P/('capture-'+name+'.json');prior=json.loads(file.read_text()) if file.exists() else []
 prior.append(dict(command=cmd,exit=r.returncode,startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat()));file.write_text(json.dumps(prior,indent=2))
 if r.returncode:sys.exit(r.returncode)
