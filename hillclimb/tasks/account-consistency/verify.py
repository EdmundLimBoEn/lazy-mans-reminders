import pathlib, subprocess, hashlib, json, re, collections, math
root=pathlib.Path(__file__).resolve().parents[3]
out=root/'hillclimb/tasks/account-consistency'
owned=['ios/App/AccountView.swift','ios/App/BoardPersistenceSection.swift']
literals=lambda s:set(re.findall(r'"(?:[^"\\]|\\.)*"',s))
old=set().union(*(literals(subprocess.check_output(['git','show','9d48476:'+p],text=True,cwd=root)) for p in owned))
new=set().union(*(literals((root/p).read_text()) for p in owned+['ios/App/AccountErrorAnnouncementPolicy.swift']))
missing=sorted(old-new)
inputs=json.loads((out/'source-final.json').read_text())
mismatch=[p for p,h in inputs.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=h]
result={'base':'9d48476','originalSwiftStringLiterals':len(old),'missingOriginalLiterals':missing,'sourceInputCount':len(inputs),'sourceHashMismatches':mismatch}
(out/'source-verification.json').write_text(json.dumps(result,indent=2))
assert not missing,missing
assert not mismatch,mismatch
print(json.dumps(result))
