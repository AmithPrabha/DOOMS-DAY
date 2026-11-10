"""Inspect compiled development/production APK or simulator app without executing it."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import zipfile
from check import build_id

def elf_alignment(data):
    if data[:4]!=b"\x7fELF" or data[4]!=2:
        return {"applicable":False,"reason":"Not a 64-bit ELF"}
    order="<" if data[5]==1 else ">"
    offset=struct.unpack_from(order+"Q",data,32)[0]
    size,count=struct.unpack_from(order+"HH",data,54)
    loads=[]
    for index in range(count):
        values=struct.unpack_from(order+"IIQQQQQQ",data,offset+index*size)
        if values[0]==1:
            loads.append({"alignment":values[7],"aligned_16kb":values[7]>=16384 and values[2]%16384==values[3]%16384})
    return {"applicable":True,"load_segments":loads,"passed":bool(loads) and all(p["aligned_16kb"] for p in loads)}

def inspect(path,flavor):
    path=Path(path)
    if path.is_dir():
        files={str(p.relative_to(path)):p.read_bytes() for p in path.rglob("*") if p.is_file()}
    else:
        with zipfile.ZipFile(path) as archive:
            files={name:archive.read(name) for name in archive.namelist() if not name.endswith("/")}
    registry=any(name.endswith("registry/test_cases.json") for name in files)
    dev_code=any(marker in data for name,data in files.items() if name.endswith("kernel_blob.bin")
                 for marker in [b"package:fieldkit/development/",b"package:fieldkit/main_development.dart"])
    failures=[]
    if flavor=="production" and (registry or dev_code):failures.append("Development registry or code found in production artifact")
    if flavor=="development" and not registry:failures.append("Development test registry missing")
    native={name:elf_alignment(data) for name,data in files.items() if name.endswith(".so")}
    for name,result in native.items():
        if result["applicable"] and not result["passed"]:failures.append(f"64-bit ELF 16 KB alignment failed: {name}")
    info=plistlib.loads(files["Info.plist"]) if "Info.plist" in files else {}
    return {"build":build_id(),"flavor":flavor,"artifact":str(path),
        "bytes":path.stat().st_size if path.is_file() else sum(len(v) for v in files.values()),
        "sha256":hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None,
        "bundle_id":info.get("CFBundleIdentifier"),"development_registry":registry,
        "development_kernel_code":dev_code,"native_libraries":native,
        "privacy_manifests":[name for name in files if name.endswith("PrivacyInfo.xcprivacy")],
        "failures":failures,"status":"failed" if failures else "passed",
        "limits":"Static inspection only. Debug size is not store-download size. No runtime, sensor, map or medical verification."}

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("path");p.add_argument("--flavor",required=True,choices=["development","production"])
    p.add_argument("--output",required=True,type=Path);args=p.parse_args()
    report=inspect(args.path,args.flavor)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(f"{report['status']}: {args.path}; {report['bytes']/1024/1024:.1f} MiB; {args.output}")
    for failure in report["failures"]:print(failure)
    raise SystemExit(bool(report["failures"]))
