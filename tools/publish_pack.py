"""Build a deterministic data-only ZIP and catalog entry, without uploading."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile
from check import validate_content

def build(source, output, id, version, language, kind, url, draft=False):
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,79}",id) or ".." in id or id=="essential":
        raise ValueError("Invalid pack identifier")
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,79}",version) or ".." in version:
        raise ValueError("Invalid version")
    source=Path(source).resolve();output=Path(output).resolve()
    if output.is_relative_to(source):raise ValueError("Output must be outside source")
    files={}
    allowed={".json",".svg",".png",".webp",".jpg",".pmtiles",".pbf"}
    for path in sorted(source.rglob("*")):
        if path.is_symlink():raise ValueError("Symlinks forbidden")
        if not path.is_file() or path.name=="manifest.json":continue
        if path.suffix not in allowed:raise ValueError(f"Unsupported file: {path}")
        files[path.relative_to(source).as_posix()]=path.read_bytes()
    if kind=="content":
        articles=json.loads(files["articles.json"])
        # Bundled assets may be referenced without redistribution.
        from check import ROOT
        for a in articles:
            for asset in a.get("illustrations",[]):
                if asset.startswith("assets/") and not (ROOT/asset).exists():raise ValueError(f"Missing bundled image: {asset}")
            if a.get("language")!=language:raise ValueError("Pack language mismatch")
            if not draft and (a.get("review_status")!="approved" or a.get("translation_review")!="approved" or
                              not a.get("reviewer") or not a.get("reviewed_at") or "pending" in a.get("license","")):
                raise ValueError("Independent review and source rights approval required")
        # Full record validation, with bundled assets resolved against repository.
        errors=validate_content({"schema_version":1,"articles":articles},release=not draft,root=source)
        errors=[e for e in errors if not e.endswith("essential handbook missing")]
        if errors:raise ValueError("\n".join(errors))
    elif kind=="map":
        if "map.pmtiles" not in files or "style.json" not in files:raise ValueError("Map archive and style required")
        if len(files["map.pmtiles"])<127 or not files["map.pmtiles"].startswith(b"PMTiles"+bytes([3])):
            raise ValueError("PMTiles v3 archive required")
        style=json.loads(files["style.json"])
        if style.get("version")!=8:raise ValueError("MapLibre style version 8 required")
        for v in style["sources"].values():
            if v.get("url")!="pmtiles://map.pmtiles" or not v.get("attribution"):raise ValueError("Local attributed sources required")
    else:raise ValueError("Unknown pack kind")
    manifest={"schema_version":1,"id":id,"version":version,"language":language,"kind":kind,
        "files":{name:hashlib.sha256(data).hexdigest() for name,data in files.items()}}
    if kind=="map":
        manifest["bounds"]=[v/1e7 for v in struct.unpack_from("<iiii",files["map.pmtiles"],102)]
        manifest["min_zoom"]=files["map.pmtiles"][100]
        manifest["max_zoom"]=files["map.pmtiles"][101]
    files["manifest.json"]=(json.dumps(manifest,sort_keys=True)+"\n").encode()
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,"w",compression=zipfile.ZIP_STORED) as z:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED
            z.writestr(info,data)
    entry=dict(id=id,title=id.replace("-"," ").title(),version=version,language=language,kind=kind,
        url=url,sha256=hashlib.sha256(output.read_bytes()).hexdigest(),download_bytes=output.stat().st_size,
        installed_bytes=sum(map(len,files.values())),description="Draft fixture" if draft else "Reviewed offline pack")
    output.with_suffix(".catalog.json").write_text(json.dumps(entry,indent=2)+"\n")
    return entry

if __name__=="__main__":
    p=argparse.ArgumentParser()
    for name in ["source","output","id","version","language","kind","url"]:p.add_argument("--"+name,required=True)
    p.add_argument("--draft",action="store_true")
    args=p.parse_args();build(**vars(args))
