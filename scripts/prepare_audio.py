import json,concurrent.futures,time
from urllib.request import Request,urlopen
from pathlib import Path
catalog=json.loads(Path('www/catalog.json').read_text())
folder=Path('www/audio');folder.mkdir(exist_ok=True)
def check(t):
 url=t['url']
 for attempt in range(3):
  try:
   req=Request(url,headers={'Range':'bytes=0-8191','User-Agent':'Anashidi/2.0'})
   with urlopen(req,timeout=40) as r:
    mime=r.headers.get('Content-Type','');sample=r.read(8192)
    if r.status not in (200,206) or ('audio' not in mime and 'octet-stream' not in mime) or len(sample)<100:raise ValueError('Not audio: '+mime)
   return {'id':t['id'],'status':'ok','content_type':mime}
  except Exception as e:
   if attempt==2:return {'id':t['id'],'status':'failed','error':str(e)}
   time.sleep(2)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:results=list(pool.map(check,catalog))
Path('source-check.json').write_text(json.dumps(results,indent=2))
failed=[r for r in results if r['status']!='ok']
print('Verified:',len(results)-len(failed),'/',len(results),flush=True)
if failed:print(failed,flush=True)
# Include one surah and three complete nasheeds for immediate offline playback.
for t in catalog:
 if t['id'] not in ('q001','n-rahman','n-rattel','n-insan'):continue
 print('Bundling',t['id'],flush=True)
 with urlopen(t['url'],timeout=90) as r:
  data=r.read()
 if len(data)<10000:raise RuntimeError('Incomplete audio '+t['id'])
 (folder/(t['id']+'.mp3')).write_bytes(data)
if failed:raise RuntimeError('Source validation failed. See source-check.json')
