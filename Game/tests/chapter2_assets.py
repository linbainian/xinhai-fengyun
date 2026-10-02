"""Verify Chapter 2 text, ImageGen provenance, pixel QC and physical interaction routes."""
import hashlib
import json
import sys
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from import_chapter_two_script import SOURCE, parse
from map_routes import interaction_reachable

checks = []


def expect(condition,message):
    checks.append({'passed':bool(condition),'message':message})
    if not condition: raise AssertionError(message)


def main():
    runtime = json.loads((ROOT/'data/chapter2/dialogues.json').read_text(encoding='utf-8'))
    expect(parse(SOURCE.read_text(encoding='utf-8'))==runtime,'Author manuscript and runtime dialogue agree')
    runtime.update(json.loads((ROOT/'data/cultivation/dialogues.json').read_text(encoding='utf-8')))
    choices = json.loads((ROOT/'data/chapter2/choices.json').read_text(encoding='utf-8'))
    for group, options in choices.items():
        expect(len(options)<=4,'Keyboard-accessible choices: '+group)
        expect(all('label' in entry and 'action' in entry for entry in options),'Complete choice records: '+group)
    sources = runtime_pngs = 0
    for bundle in ['venues','chapter2']:
        manifest = json.loads((ROOT/f'assets/{bundle}/manifest.json').read_text(encoding='utf-8'))
        expect(manifest['source']=='OpenAI built-in ImageGen' and not manifest['third_party_downloads'],'Generated art provenance: '+bundle)
        sources += len(manifest['sources']); runtime_pngs += len(manifest['runtime'])
        for entry in manifest['sources']:
            for path,hash_key in [('path','sha256'),('prompt','prompt_sha256')]:
                expect(hashlib.sha256((ROOT/entry[path]).read_bytes()).hexdigest()==entry[hash_key],'Source provenance: '+entry[path])
        for entry in manifest['runtime']:
            path = ROOT/entry['path']
            expect(hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],'Runtime hash: '+entry['path'])
            pixels = np.array(Image.open(path).convert('RGBA'))
            expect(set(np.unique(pixels[:,:,3]))<={0,255},'Hard pixel alpha: '+entry['path'])
            if '/frames/' in entry['path']:
                expect(pixels.shape[:2]==(96,96),'Uniform 96px frame: '+entry['path'])
                expect(len(np.unique(pixels[pixels[:,:,3]==255,:3],axis=0))<=48,'Limited actor/prop palette: '+entry['path'])
        for path in (ROOT/f'assets/{bundle}').rglob('runtime-qc.json'):
            qc = json.loads(path.read_text(encoding='utf-8'))
            expect(qc['passed'],'Final runtime QC: '+path.relative_to(ROOT).as_posix())
            if '/actors/' in path.as_posix():
                expect(qc['body_height_cv']<=.08 and qc['feet_y_std']==0,'Stable directional body/foot anchors: '+path.parent.name)
    expect(sources==14 and runtime_pngs==79,'14 newly generated sources produce 79 runtime objects/frames/tiles')
    events = json.loads((ROOT/'data/cultivation/events.json').read_text(encoding='utf-8'))
    growth = json.loads((ROOT/'data/cultivation/settings.json').read_text(encoding='utf-8'))
    expect(len(events)==11 and len({event['id'] for event in events})==11,'Six original and five character cultivation encounters')
    for event in events:
        expect(event['dialogue'] in runtime and len(event['options'])==2,'Cultivation dialogue and two outcomes exist: '+event['id'])
        expect((ROOT/event['asset'].removeprefix('res://')).is_file(),'Cultivation encounter sprite exists: '+event['id'])
    all_maps = json.loads((ROOT/'data/chapter1/maps.json').read_text(encoding='utf-8'))
    all_maps.update(json.loads((ROOT/'data/chapter2/maps.json').read_text(encoding='utf-8')))
    for name in ['hall','cbd']+[key for key in all_maps if key.startswith('c2_')]:
        data = all_maps[name]
        blockers = data.get('blockers',[]) + [entry['collision'] for entry in data['props']+data['actors'] if 'collision' in entry]
        def free(px,py):
            return 24<=px-9 and px+9<=data['width']*48-24 and 24<=py-11 and py+1<=data['height']*48-24 and not any(px+9>x and px-9<x+w and py+1>y and py-11<y+h for x,y,w,h in blockers)
        start = tuple(round(value/12) for value in data['spawn'])
        expect(free(start[0]*12,start[1]*12),'Safe spawn: '+name)
        visited = {start}; queue = deque([start])
        while queue:
            x,y = queue.popleft()
            for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if point not in visited and free(point[0]*12,point[1]*12): visited.add(point);queue.append(point)
        for entry in data['props']+data['actors']:
            expect((ROOT/entry['asset'].removeprefix('res://')).is_file(),'Independent runtime object exists: '+name+'/'+entry['nodeName'])
            expect(not entry.get('rotation',0),'Upright object placement: '+name+'/'+entry['nodeName'])
        for actor in data['actors']:
            anchor = actor.get('interactionPosition',actor['position'])
            target = (round(anchor[0]/12),round((anchor[1]+58)/12))
            expect(target in visited,'Player-sized collision route reaches: '+name+'/'+actor['id'])
    for key in ['hall','cbd']:
        expect(len(all_maps[key]['actors'])==4,'Four distinct service-hall staff/visitors: '+key)
    expect({entry['asset'] for entry in all_maps['hall']['actors']}.isdisjoint({entry['asset'] for entry in all_maps['cbd']['actors']}),'Academy and bureau no longer share staff sprites')
    for event in events:
        data = all_maps[event.get('room',growth['places'][event['area']]['room'])]
        blockers = data.get('blockers',[]) + [entry['collision'] for entry in data['props']+data['actors'] if 'collision' in entry]
        def can_stand(px,py):
            return 24<=px-9 and px+9<=data['width']*48-24 and 24<=py-11 and py+1<=data['height']*48-24 and not any(px+9>x and px-9<x+w and py+1>y and py-11<y+h for x,y,w,h in blockers)
        start = tuple(round(value/12) for value in data['spawn'])
        visited = {start}; queue = deque([start])
        while queue:
            x,y=queue.popleft()
            for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if point not in visited and can_stand(point[0]*12,point[1]*12): visited.add(point);queue.append(point)
        encounter = dict(event, id='growth_event')
        actors = [a for a in data['actors'] if a['id'] not in event.get('remove_actors', [])]
        if event['id']=='dormitory_flyers': actors = [a for a in actors if a['id']!='chuxia']
        actors += [encounter] + event.get('partners', [])
        expect(interaction_reachable(data, encounter, visited, actors),'Walkable route exposes cultivation E target: '+event['id'])
    scenes = json.loads((ROOT/'data/chapter2/cutscenes.json').read_text(encoding='utf-8'))
    expect(len(scenes)==12,'Ten plot sequences plus two bedroom/corridor transitions')
    report = {'passed':True,'checks':checks,'sources':sources,'runtime_pngs':runtime_pngs}
    (ROOT/'.dev/chapter2-assets-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(checks)}/{len(checks)} text/art/map checks passed')


if __name__=='__main__': main()
