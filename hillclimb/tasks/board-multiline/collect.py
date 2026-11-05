#!/usr/bin/env python3
import json, pathlib, subprocess, sys
out=pathlib.Path(__file__).resolve().parent
result=sys.argv[1] if len(sys.argv)>1 else '/tmp/notepad-board-e-final.xcresult'
suffix=sys.argv[2] if len(sys.argv)>2 else 'final'
for name,subcommand in [('summary-'+suffix,'summary'),('tests-'+suffix,'tests')]:
    value=subprocess.check_output(['xcrun','xcresulttool','get','test-results',subcommand,'--path',result,'--compact'],text=True)
    (out/(name+'.json')).write_text(value)
tests=json.loads((out/('tests-'+suffix+'.json')).read_text())
counts={}
def walk(node,target=None):
    if isinstance(node,dict):
        if node.get('nodeType')=='Test Plan' or node.get('nodeType')=='Unit test bundle' or node.get('nodeType')=='UI test bundle':
            target=node.get('name',target)
        if node.get('nodeType')=='Test Case':
            key=(target or '')+':'+node.get('result','unknown')
            counts[key]=counts.get(key,0)+1
        for child in node.get('children',[]):walk(child,target)
    elif isinstance(node,list):
        for child in node:walk(child,target)
walk(tests.get('testNodes',tests))
(out/('counts-'+suffix+'.json')).write_text(json.dumps(counts,indent=2)+'\n')
print((out/('summary-'+suffix+'.json')).read_text())
