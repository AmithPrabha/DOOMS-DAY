"""Fetch exact prototype dependencies; verify before extracting. No app linkage."""
import hashlib
import json
import subprocess
import tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
for item in json.loads((ROOT/'native/zim/dependencies.json').read_text())['archives']:
    folder=ROOT/'.tooling/zim'/item['destination'];folder.mkdir(parents=True,exist_ok=True)
    archive=folder/'dependency.tar.gz'
    subprocess.run(['curl','--fail','--location','--retry','3','--continue-at','-',
                    '--output',str(archive),item['url']],check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=item['sha256']:
        raise ValueError(f"Checksum mismatch: {item['destination']}")
    with tarfile.open(archive) as source:source.extractall(folder,filter='data')
print('Verified prototype dependencies extracted; production linkage unchanged.')
