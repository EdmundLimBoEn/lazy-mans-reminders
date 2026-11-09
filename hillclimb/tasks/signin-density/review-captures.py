"""Full-device matching after test ownership ends. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,time,json,subprocess
p=pathlib.Path(__file__).parent
while not (p/'awake-process.json').exists():time.sleep(15)
# Review captures do not convert the failed validation into acceptance.
for phase,app in [('before','/tmp/hillclimb-signin-density-before.app'),('after','/tmp/hillclimb-signin-density-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app')]:
 subprocess.run(['xcrun','simctl','install','8E8380DE-364D-4899-99B8-D15ED0494FFD',app],check=True)
 subprocess.run(['python3',str(p/'manual-matrix.py'),phase],check=True)
subprocess.run(['python3',str(p/'capture.py'),'after'],check=True)

subprocess.run(['python3',str(p/'identity.py')],check=True)
(p/'captures-complete.json').write_text(json.dumps({'complete':True}))
