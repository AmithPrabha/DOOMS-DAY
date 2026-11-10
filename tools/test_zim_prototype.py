"""Host runtime smoke test, not evidence of iOS/Android physical-device operation."""
import ctypes
import json
from pathlib import Path
import subprocess
from build_zim_prototype import ROOT, APPLE, OUT

def main():
    folder=OUT/'macos-arm64'
    binary=folder/'create_fixture'
    subprocess.run(['xcrun','clang++','-std=c++17','-arch','arm64',
        '-I'+str(APPLE/'macos-arm64_x86_64/Headers'),str(ROOT/'native/zim/fixture.cpp'),
        str(APPLE/'macos-arm64_x86_64/merged.a'),'-lz','-lbz2','-liconv','-o',str(binary)],check=True)
    archive=folder/'fixture.zim'
    subprocess.run([str(binary),str(archive)],check=True)
    library=ctypes.CDLL(str(folder/'libdooms_zim.dylib'))
    request=library.dd_zim_request
    request.argtypes=[ctypes.c_char_p]*3+[ctypes.c_int]*2
    request.restype=ctypes.c_void_p
    release=library.dd_zim_free
    release.argtypes=[ctypes.c_void_p]
    def call(op,arg='',path=archive):
        pointer=request(str(path).encode(),op.encode(),arg.encode(),0,20)
        assert pointer
        try:return json.loads(ctypes.string_at(pointer))
        finally:release(pointer)
    assert call('inspect')['fulltext'] is True
    assert call('inspect')['article_count']==2
    assert call('search','rice')['results'][0]['path']=='rice.html'
    assert 'Brown rice' in call('read','rice.html')['text']
    assert 'error' in call('read','missing.html')
    assert 'error' in call('inspect',path=folder/'missing.zim')
    (OUT/'runtime.json').write_text(json.dumps({'platform':'macOS arm64','status':'passed',
      'checks':['inspect','fulltext search','bounded read','missing entry','missing archive'],
      'device_evidence':False},indent=2)+'\n')
    print('Host native archive smoke checks passed; mobile runtime evidence outstanding.')
if __name__=='__main__':main()
