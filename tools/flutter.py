"""Run/build with the right flavor, entrypoint, local toolchain and evidence ID."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from check import ROOT, build_id

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=["run","apk","ios-simulator","appbundle","ipa"])
    parser.add_argument("flavor",choices=["development","production"],default="development",nargs="?")
    args,extra=parser.parse_known_args()
    if args.action in ["appbundle","ipa"]:
        if args.flavor!="production":parser.error("Store artifacts require production flavor")
        if subprocess.run([sys.executable,str(ROOT/"tools/release.py")],cwd=ROOT).returncode:
            return 1
    sdk=ROOT/".tooling/flutter/bin/flutter"
    flutter=str(sdk) if sdk.exists() else shutil.which("flutter")
    if not flutter:parser.error("Install the pinned Flutter SDK first")
    env=os.environ.copy()
    java=sorted((ROOT/".tooling/jdk").glob("jdk-21*/Contents/Home"),reverse=True)
    if java:env["JAVA_HOME"]=str(java[0])
    android=ROOT/".tooling/android-sdk"
    if android.exists():
        env["ANDROID_HOME"]=str(android)
        env["ANDROID_USER_HOME"]=str(ROOT/".tooling/android-user")
        env["GRADLE_USER_HOME"]=str(ROOT/".tooling/gradle")
    action={"run":["run"],"apk":["build","apk","--debug"],
        "ios-simulator":["build","ios","--simulator","--debug"],
        "appbundle":["build","appbundle","--release"],"ipa":["build","ipa","--release"]}[args.action]
    target="lib/main_development.dart" if args.flavor=="development" else "lib/main.dart"
    command=[flutter,*action,"--flavor",args.flavor,"-t",target,f"--dart-define=BUILD_ID={build_id()}",*extra]
    return subprocess.run(command,cwd=ROOT,env=env).returncode
if __name__=="__main__":sys.exit(main())
