"""Check author/runtime agreement, protected imports, alpha, provenance and critical map routes."""
import hashlib
import json
import re
from collections import deque
import sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from import_chapter_script import load_data, parse_script, parse_tutorial_text, AUTHOR_SCRIPT, READING_DELAY
from export_chapter_script import render_script

checks = []
def expect(condition, message):
    checks.append({'passed':bool(condition),'message':message})
    if not condition: raise AssertionError(message)


def main():
    dialogue,choices,settings = load_data()
    source = AUTHOR_SCRIPT.read_text(encoding='utf-8-sig')
    expect(parse_script(source,dialogue,choices,settings)==(dialogue,choices),'Edited author Markdown matches all runtime dialogue/choices/events')
    expect(parse_script(render_script(),dialogue,choices,settings)==(dialogue,choices),'Export -> import round trip is lossless, including dynamic rewards')
    tutorial = json.loads((ROOT/'data/chapter1/tutorial_text.json').read_text(encoding='utf-8'))
    expect(parse_tutorial_text(source)==tutorial==parse_tutorial_text(render_script()),'All 19 tutorial dialogue/system fields match author and exported Markdown')
    for damaged in [re.sub(r'\[演出：[^\]\n]*仪器停顿0\.5秒[^\]\n]*\]','',source),source.replace('### 片段 `arrival`','### 片段 `unknown`'),source+'\n### 片段 `arrival`\n']:
        try: parse_script(damaged,dialogue,choices,settings)
        except ValueError: protected = True
        else: protected = False
        expect(protected,'Reject malformed IDs, missing events or duplicate blocks before writing')
    manifest = json.loads((ROOT/'assets/chapter1/manifest.json').read_text(encoding='utf-8'))
    for item in manifest['sources']:
        expect((ROOT/item['prompt']).is_file(),'Prompt exists: '+item['path'])
        expect(hashlib.sha256((ROOT/item['path']).read_bytes()).hexdigest()==item['sha256'],'Source hash: '+item['path'])
    for item in manifest['refined_runtime']:
        path = ROOT/item['path']
        expect(hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],'Runtime hash: '+item['path'])
        image = Image.open(path)
        if 'frames' in path.parts:
            expect(image.size==(96,96),'96px source frame: '+path.name)
        if image.mode=='RGBA':
            p = np.array(image)
            expect(set(np.unique(p[:,:,3]))=={0,255},'Hard alpha/no antialiased edge: '+path.name)
    cinematic = json.loads((ROOT/'assets/chapter1/cinematics/manifest.json').read_text(encoding='utf-8'))
    expect(len(cinematic['sources'])==6 and len(cinematic['runtime'])==96,'Six actors have complete four-direction 16-frame walking sheets')
    for item in cinematic['sources']:
        for path_key,hash_key in [('path','sha256'),('prompt','prompt_sha256')]:
            expect(hashlib.sha256((ROOT/item[path_key]).read_bytes()).hexdigest()==item[hash_key],'Cinematic provenance: '+item[path_key])
        qc = json.loads((ROOT/item['qc']).read_text(encoding='utf-8'))
        expect(qc['passed'] and qc['body_height_cv']<=0.08 and qc['feet_y_std']<=0.05,'Final directional frame scale and foot anchors: '+item['character'])
    for item in cinematic['runtime']:
        path = ROOT/item['path']
        image = Image.open(path).convert('RGBA')
        pixels = np.array(image)
        expect(hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'] and image.size==(96,96),'Directional frame hash/size: '+item['path'])
        expect(set(np.unique(pixels[:,:,3]))=={0,255} and len(np.unique(pixels[pixels[:,:,3]==255,:3],axis=0))<=48,'Directional hard alpha and limited palette: '+item['path'])
    maps = json.loads((ROOT/'data/chapter1/maps.json').read_text(encoding='utf-8'))
    hall = json.loads((ROOT/'assets/chapter1/refined/hall/module-manifest.json').read_text(encoding='utf-8'))
    names = {e['id'] for e in hall['modules']}
    expected = {'dome','wall','arch_window','portal','column','gate_left','gate_right','podium_left','podium_middle','podium_right',
                'trial_table','stand','railing','stairs','flag_red','flag_gray','flag_teal','flag_silver','banner',
                'streetlamp','planter','bench','trash','cone','barrier'} | {f'tile_{i:02d}' for i in range(6)}
    expect(names==expected,'Complete requested component list plus central door: 25 objects + six tiles')
    used = set()
    for room in ['plaza','auditorium']:
        data = maps[room]
        expect('background' not in data and 'terrain' in data,'Editable tile/object map, no baked runtime background: '+room)
        for entry in data['props']+data['actors']:
            expect((ROOT/entry['asset'].removeprefix('res://')).is_file(),'Referenced object exists: '+entry.get('nodeName',''))
            used.add(entry.get('module',''))
            if entry.get('occlusionClass')=='tall':
                expect('actorSafeArea' in entry and entry.get('occupantPolicy',{}).get('mode')=='fade','Tall prop has actor-safe fade policy')
            if 'collision' in entry:
                x,y,w,h = entry['collision']
                expect(x>=0 and y>=0 and x+w<=data['width']*48 and y+h<=data['height']*48,'Collision stays inside room')
        blockers = [e['collision'] for e in data['props']+data['actors'] if 'collision' in e]
        points = [data['spawn']]+[[a['position'][0],a['position'][1]+58] for a in data['actors']]
        for px,py in points:
            blocked = any(px+9>x and px-9<x+w and py+1>y and py-11<y+h for x,y,w,h in blockers)
            expect(not blocked,'Player spawn/interaction approach is unobstructed: '+room+str([px,py]))
        # Flood-fill player-sized feet, proving every approach belongs to the spawn's
        # navigable area; a clear point alone can still be stranded behind a barrier.
        def free(px,py):
            return 24<=px-9 and px+9<=data['width']*48-24 and 24<=py-11 and py+1<=data['height']*48-24 and not any(px+9>x and px-9<x+w and py+1>y and py-11<y+h for x,y,w,h in blockers)
        start = tuple(round(value/6) for value in data['spawn'])
        visited = {start}
        queue = deque([start])
        while queue:
            cx,cy = queue.popleft()
            for nx,ny in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]:
                if (nx,ny) not in visited and free(nx*6,ny*6):
                    visited.add((nx,ny)); queue.append((nx,ny))
        for point in points:
            expect(tuple(round(value/6) for value in point) in visited,'Interaction route connects to the spawn: '+room+str(point))
    expect(expected-{f'tile_{i:02d}' for i in range(6)} <= used,'Every requested object is actually placed in playable rooms')
    report = {'passed':True,'checks':checks,'sources':len(manifest['sources'])+len(cinematic['sources']),
              'runtime_pngs':len(manifest['refined_runtime'])+len(cinematic['runtime'])}
    (ROOT/'.dev/chapter1-assets-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(checks)}/{len(checks)} text/asset/map checks passed')


if __name__ == '__main__': main()
