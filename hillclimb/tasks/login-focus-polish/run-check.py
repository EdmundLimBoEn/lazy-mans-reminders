import datetime, gzip, hashlib, json, os, pathlib, subprocess, sys, time
label=sys.argv[1]; command=sys.argv[2:]; out=pathlib.Path(__file__).parent
record={"command":command,"startUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"hostStartLoad":os.getloadavg(),"sourceSHA":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()}
record["sourceHashes"]={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ["ios/App","ios/UITests"] for p in pathlib.Path(folder).rglob("*.swift")}
awake=subprocess.Popen(["/usr/bin/caffeinate","-i"])
try:
 process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 with gzip.open(out/(label+"-output.txt.gz"),"wt") as log:
  for line in process.stdout:
   log.write(line)
   if any(x in line for x in ["Test Case '","Test Suite '","error:","failed", "Executed ","** TEST"]):print(line.rstrip(),flush=True)
 record["exit"]=process.wait()
finally:awake.terminate();awake.wait()
record["endUTC"]=datetime.datetime.now(datetime.timezone.utc).isoformat();record["hostEndLoad"]=os.getloadavg()
(out/(label+"-process.json")).write_text(json.dumps(record,indent=2)+"\n")
sys.exit(record["exit"])
