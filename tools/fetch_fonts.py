"""Fetch pinned Google Fonts assets. Run explicitly; never during app startup."""
import hashlib
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
FONTS = {
    "NotoSans": ("notosans", "NotoSans[wdth,wght].ttf"),
    "NotoSansArabic": ("notosansarabic", "NotoSansArabic[wdth,wght].ttf"),
    "NotoSansDevanagari": ("notosansdevanagari", "NotoSansDevanagari[wdth,wght].ttf"),
    "NotoSansMalayalam": ("notosansmalayalam", "NotoSansMalayalam[wdth,wght].ttf"),
    "NotoSansTamil": ("notosanstamil", "NotoSansTamil[wdth,wght].ttf"),
    "NotoSansTelugu": ("notosanstelugu", "NotoSansTelugu[wdth,wght].ttf"),
}

def main():
    from urllib.parse import quote
    def fetch(url):
        return subprocess.check_output(["curl", "-fsSL", "--max-time", "90", url])
    revision = json.loads(fetch("https://api.github.com/repos/google/fonts/commits/main"))["sha"]
    entries = []
    for family, (directory, name) in FONTS.items():
        base = f"https://raw.githubusercontent.com/google/fonts/{revision}/ofl/{directory}/"
        for filename, target in [(name, f"{family}.ttf"), ("OFL.txt", f"{family}-OFL.txt")]:
            data = fetch(base + quote(filename))
            (ROOT / "assets/fonts" / target).write_bytes(data)
            entries.append({"file": target, "source": base + quote(filename),
                            "sha256": hashlib.sha256(data).hexdigest()})
    (ROOT / "assets/fonts/manifest.json").write_text(json.dumps(
        {"revision": revision, "files": entries}, indent=2) + "\n")

if __name__ == "__main__":
    main()
