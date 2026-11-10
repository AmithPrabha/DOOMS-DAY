"""Run real suites and store build-specific outcomes. Never fabricate device evidence."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from check import ROOT, build_id, load

def main():
    flutter=shutil.which("flutter") or str(ROOT/".tooling/flutter/bin/flutter")
    (ROOT/"build").mkdir(exist_ok=True)
    python=subprocess.run([sys.executable,"-m","unittest","discover","-s","tools","-p","test_tools.py","-v"],
        cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (ROOT/"build/python-tests.txt").write_text(python.stdout);print(python.stdout)
    process=subprocess.run([flutter,"test","--no-pub","--reporter","json"],cwd=ROOT,text=True,stdout=subprocess.PIPE)
    (ROOT/"build/flutter-tests.ndjson").write_text(process.stdout)
    names={};observed={}
    for line in process.stdout.splitlines():
        try:e=json.loads(line)
        except json.JSONDecodeError:continue
        if e.get("type")=="testStart":names[e["test"]["id"]]=e["test"]["name"]
        if e.get("type")=="testDone" and not e.get("hidden"):
            for id in re.findall(r"\[(T\d+)\]",names.get(e["testID"],"")):
                status="not_run" if e.get("skipped") else "passed" if e.get("result")=="success" else "failed"
                previous=observed.get(id)
                observed[id]="failed" if "failed" in [previous,status] else "not_run" if "not_run" in [previous,status] else status
    for id in re.findall(r"test_(T\d+)_\w+.*? \.\.\. ok",python.stdout):
        if observed.get(id)!="failed":observed[id]="passed"
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    results=[]
    for case in load("registry/test_cases.json"):
        status=observed.get(case["id"],"not_run")
        if case["type"] in ["manual","mixed","deferred"]:status="not_run"
        results.append({"id":case["id"],"status":status,"platform":sys.platform,
            "automated_status":observed.get(case["id"],"not_run"),
            "at":now,"evidence":"build/flutter-tests.ndjson; build/python-tests.txt" if case["id"] in observed else "No evidence recorded"})
    (ROOT/"registry/results.json").write_text(json.dumps(
        {"build":build_id(),"generated_at":now,"results":results},indent=2)+"\n")
    from docs import generate
    generate()
    print(f"Results saved. Flutter exit={process.returncode}; Python exit={python.returncode}")
    return process.returncode or python.returncode
if __name__=="__main__":sys.exit(main())
