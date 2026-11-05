"""Coarse concurrent CPU scope, not per-sample attribution. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,time,datetime,os
p=pathlib.Path(__file__).parent;rows=[]
while not (p/'awake-process.json').exists():
 raw=subprocess.check_output(['ps','-axo','pid,pcpu,comm'],text=True)
 lines=[l for l in raw.splitlines()[1:] if float(l.split()[1])>=5]
 rows.append(dict(time=datetime.datetime.now(datetime.timezone.utc).isoformat(),load=os.getloadavg(),CPUAtLeast5Percent=lines))
 (p/'awake-concurrent-host-load.json').write_text(json.dumps(rows,indent=2));time.sleep(30)
