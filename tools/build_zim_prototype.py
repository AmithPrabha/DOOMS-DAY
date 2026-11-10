"""Build isolated native probes; never edits app signing or links release builds.
Requires official archives unpacked under .tooling/zim (see native/zim/README.md).
"""
import json
import hashlib
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/zim-prototype'
APPLE=ROOT/'.tooling/zim/apple/libkiwix_xcframework-14.2.1-2/lib/CoreKiwix.xcframework'
ANDROID=ROOT/'.tooling/zim/android/libzim_android-arm64-9.8.2-1'
SOURCE=ROOT/'native/zim/bridge.cpp'
def run(command): subprocess.run([str(x) for x in command],check=True,cwd=ROOT)
def main():
    artifacts=[]
    for target,sdk,triple,slice_name in [
        ('macos-arm64','macosx','arm64-apple-macos13','macos-arm64_x86_64'),
        ('ios-arm64','iphoneos','arm64-apple-ios15','ios-arm64'),
        ('ios-simulator-arm64','iphonesimulator','arm64-apple-ios15-simulator','ios-arm64_x86_64-simulator'),
    ]:
        folder=OUT/target; folder.mkdir(parents=True,exist_ok=True)
        library=folder/'libdooms_zim.dylib'
        sysroot=subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip()
        run(['xcrun','--sdk',sdk,'clang++','-std=c++17','-dynamiclib','-fPIC',
             '-target',triple,'-isysroot',sysroot,'-I'+str(APPLE/slice_name/'Headers'),
             SOURCE,APPLE/slice_name/'merged.a','-lz','-lbz2','-liconv','-o',library])
        artifacts.append(library)
    ndk=ROOT/'.tooling/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin'
    folder=OUT/'android-arm64';folder.mkdir(parents=True,exist_ok=True)
    library=folder/'libdooms_zim.so'
    run([ndk/'aarch64-linux-android24-clang++','-std=c++17','-shared','-fPIC',
         '-Wl,-z,max-page-size=16384','-I'+str(ANDROID/'include'),SOURCE,
         '-L'+str(ANDROID/'lib/aarch64-linux-android'),'-lzim','-o',library])
    artifacts.append(library)
    report={'status':'compiled_not_device_verified','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'artifacts':[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in artifacts]}
    (OUT/'build.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Native probes compiled. Runtime, distribution and licensing gates remain open.')
if __name__=='__main__':main()
