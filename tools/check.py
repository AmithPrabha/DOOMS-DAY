"""Repository and content validation. Standard library only; no network."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ["en","ar","ml","hi","ta","te","es","fr","ru"]
REVIEW_FIELDS = {"review_status", "translation_review", "reviewer", "reviewed_at", "reviewed_content_sha256"}
def review_digest(article):
    content={k:v for k,v in article.items() if k not in REVIEW_FIELDS}
    return hashlib.sha256(json.dumps(content,sort_keys=True,ensure_ascii=False,
        separators=(",",":")).encode()).hexdigest()
def load(path): return json.loads((ROOT/path).read_text())
def build_id():
    h=hashlib.sha256()
    paths=list((ROOT/"lib").rglob("*.dart"))
    paths+=[ROOT/p for p in ["pubspec.lock","pubspec.yaml",".flutter-version","registry/test_cases.json"]]
    paths+=[p for p in (ROOT/"assets").rglob("*") if p.is_file()]
    paths+=[p for p in (ROOT/"android/app/src").rglob("*") if p.is_file()]
    paths+=[ROOT/p for p in ["android/app/build.gradle.kts","android/settings.gradle.kts",
        "android/gradle.properties","android/gradle/wrapper/gradle-wrapper.properties",
        "ios/Runner.xcodeproj/project.pbxproj","ios/Flutter/Debug.xcconfig","ios/Flutter/Release.xcconfig"]]
    paths+=[p for p in (ROOT/"ios/Runner").rglob("*") if p.is_file() and p.name not in ["GeneratedPluginRegistrant.h","GeneratedPluginRegistrant.m"]]
    for path in sorted(set(paths)):
        h.update(str(path.relative_to(ROOT)).encode()); h.update(path.read_bytes())
    return h.hexdigest()[:16]

def validate_content(data, release=False, root=ROOT, require_languages=True):
    errors=[]; ids=set()
    if data.get("schema_version")!=1: errors.append("Unsupported content schema")
    for a in data.get("articles",[]):
        label=f"{a.get('id')}/{a.get('language')}"
        key=(a.get("id"),a.get("language"))
        if key in ids: errors.append(f"{label}: duplicate identifier")
        ids.add(key)
        for k in ["id","language","title","summary","category","region","sources","license","sections","review_status"]:
            if not a.get(k): errors.append(f"{label}: missing {k}")
        if a.get("language") not in LANGUAGES: errors.append(f"{label}: unsupported language")
        for s in a.get("sources",[]):
            if not s.startswith("https://"): errors.append(f"{label}: source must be HTTPS")
        for s in a.get("sections",[]):
            if not s.get("heading") or not s.get("steps") or not all(isinstance(x,str) and x.strip() for x in s.get("steps",[])):
                errors.append(f"{label}: invalid section")
        for name in a.get("illustrations",[]):
            base=ROOT if name.startswith("assets/") else root
            asset=(base/name).resolve()
            if not asset.is_relative_to(base.resolve()) or not asset.is_file():
                errors.append(f"{label}: missing or unsafe illustration {name}")
        if a.get("food_identification"):
            media=a.get("media",[])
            if not media: errors.append(f"{label}: required food photographs missing")
            for image in media:
                if (image.get("kind")!="photograph" or image.get("ai_generated") is not False
                    or image.get("required") is not True
                    or any(not image.get(k) for k in ["path","caption","attribution","license","source","sha256"])
                    or image.get("path") not in a.get("illustrations",[])):
                    errors.append(f"{label}: invalid identification photograph")
                    continue
                path=(root/image["path"]).resolve()
                if (not path.is_relative_to(root.resolve()) or not path.is_file()
                    or hashlib.sha256(path.read_bytes()).hexdigest()!=image["sha256"]):
                    errors.append(f"{label}: photograph differs from reviewed bytes")
            if release and (a.get("photo_review")!="approved" or a.get("specialist_review")!="approved"
                or any(not str(a.get(key,"")).strip() for key in [
                    "photo_reviewer","photo_reviewed_at","specialist_reviewer",
                    "specialist_reviewed_at","translation_reviewer","translation_reviewed_at"])):
                errors.append(f"{label}: photograph/specialist review incomplete")
        if release:
            for k in ["reviewer","reviewed_at"]:
                if not a.get(k): errors.append(f"{label}: missing independent {k}")
            if a.get("review_status")!="approved" or a.get("translation_review")!="approved":
                errors.append(f"{label}: content/translation review incomplete")
            if "pending" in a.get("license","").lower(): errors.append(f"{label}: rights review incomplete")
            if a.get("reviewed_content_sha256") != review_digest(a):
                errors.append(f"{label}: review does not cover this content version")
    for lang in LANGUAGES if require_languages else []:
        if not any(a.get("language")==lang for a in data.get("articles",[])):
            errors.append(f"{lang}: essential handbook missing")
    return errors

def validate_registry(features, tests):
    errors=[]; test_ids={t["id"] for t in tests}; feature_ids={f["id"] for f in features}
    if len(test_ids)!=len(tests) or len(feature_ids)!=len(features):errors.append("Duplicate registry ID")
    for f in features:
        if not (ROOT/f["source"]).exists():errors.append(f"{f['id']}: missing source")
        if not f["tests"] or any(t not in test_ids for t in f["tests"]):errors.append(f"{f['id']}: missing test mapping")
    for t in tests:
        if not (ROOT/t["source"]).exists():errors.append(f"{t['id']}: missing test source")
        if not t["feature_ids"] or any(f not in feature_ids for f in t["feature_ids"]):errors.append(f"{t['id']}: missing feature mapping")
    return errors

def validate_docs():
    errors=[]
    for file in (ROOT/"docs").glob("*.md"):
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)',file.read_text()):
            if target.startswith(("https://","http://","#")):continue
            path=(file.parent/target.split("#")[0]).resolve()
            if not path.is_relative_to(ROOT) or not path.exists():errors.append(f"{file.name}: broken link {target}")
    return errors

def validate_production_imports():
    visited=set()
    def visit(file):
        if file in visited:return
        visited.add(file)
        for uri in re.findall(r"(?:import|export)\s+'([^']+)'",file.read_text()):
            if uri.startswith("package:fieldkit/"):target=ROOT/"lib"/uri[len("package:fieldkit/"):]
            elif ":" not in uri:target=(file.parent/uri).resolve()
            else:continue
            if target.exists():visit(target)
    visit(ROOT/"lib/main.dart")
    return ["Production imports development tools"] if any("development" in p.parts for p in visited) else []

def check(release=False):
    errors=validate_content(load("assets/content/essential.json"),release)
    errors += validate_content(load("assets/content/practical.json"),release,require_languages=release)
    if release:
        practical=load("assets/content/practical.json")["articles"]
        for language in LANGUAGES:
            if len({a["id"] for a in practical if a["language"]==language}) < 48:
                errors.append(f"{language}: 48 practical guides not delivered")
        for file in (ROOT/"content/food").glob("*.json"):
            if json.loads(file.read_text()).get("status")!="reviewed_and_packaged":
                errors.append(f"{file.stem}: regional food collection not reviewed and packaged")
    strings=load("assets/i18n/en.json")
    for lang in LANGUAGES:
        values=load(f"assets/i18n/{lang}.json")
        if set(values)!=set(strings) or not all(values.values()):errors.append(f"{lang}: missing UI strings")
    manifest=load("assets/fonts/manifest.json")
    for asset in manifest["files"]:
        file=ROOT/"assets/fonts"/asset["file"]
        if not file.exists() or hashlib.sha256(file.read_bytes()).hexdigest()!=asset["sha256"]:
            errors.append(f"Font integrity: {asset['file']}")
    errors+=validate_registry(load("registry/features.json"),load("registry/test_cases.json"))
    errors+=validate_docs()+validate_production_imports()
    return errors

if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--release",action="store_true");args=parser.parse_args()
    errors=check(args.release)
    for e in errors:print("FAIL:",e)
    print(f"{'FAIL' if errors else 'PASS'}: repository checks; build {build_id()}")
    sys.exit(bool(errors))
