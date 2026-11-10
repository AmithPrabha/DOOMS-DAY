"""Compile both flavors, inspect artifacts, and preserve per-platform evidence locally."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from check import ROOT, build_id
from inspect_artifact import inspect

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--platform",choices=["android","ios","all"],default="all")
    args=p.parse_args()
    reports=[]
    for platform in (["android","ios"] if args.platform=="all" else [args.platform]):
        for flavor in ["development","production"]:
            label=f"{platform}-{flavor}"
            log=ROOT/"build"/f"{label}.log"
            log.parent.mkdir(exist_ok=True)
            action="apk" if platform=="android" else "ios-simulator"
            fingerprint=build_id()
            print(f"Building {label} ({fingerprint})…",flush=True)
            with log.open("w") as output:
                result=subprocess.run([sys.executable,"tools/flutter.py",action,flavor],cwd=ROOT,stdout=output,stderr=subprocess.STDOUT)
            if result.returncode:
                print(log.read_text()[-12000:],flush=True)
                return result.returncode
            if platform=="android":
                artifact=ROOT/"build/app/outputs/flutter-apk"/f"app-{flavor}-debug.apk"
            else:
                artifact=ROOT/"build/artifacts"/f"Fieldkit-{flavor}.app"
                if artifact.exists():shutil.rmtree(artifact)
                shutil.copytree(ROOT/"build/ios/iphonesimulator/Runner.app",artifact)
            report=inspect(artifact,flavor)
            report["compiled_build"]=fingerprint
            if report["build"]!=fingerprint:
                report["failures"].append("Native build changed source configuration; rebuild to bind evidence to final source")
                report["status"]="failed"
            (ROOT/"build"/f"inspection-{label}.json").write_text(json.dumps(report,indent=2)+"\n")
            reports.append(report)
            print(f"{label}: {report['status']}; {report['bytes']/1024/1024:.1f} MiB",flush=True)
            if report["failures"]:
                print("\n".join(report["failures"]))
                return 1
    (ROOT/"build/native-builds.json").write_text(json.dumps(reports,indent=2)+"\n")
    return 0

if __name__=="__main__":sys.exit(main())
