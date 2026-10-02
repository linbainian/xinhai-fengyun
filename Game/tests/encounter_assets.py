"""Check encounter authors, generated sources, pixel frames and furnished routes."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from map_routes import can_stand, reachable, interaction_reachable

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from import_encounter_script import SOURCE, parse

checks = []


def read(path):
    return json.loads((ROOT/path).read_text(encoding='utf-8'))


def expect(condition, message):
    checks.append({'passed': bool(condition), 'message': message})
    if not condition: raise AssertionError(message)


def main():
    dialogue = read('data/cultivation/dialogues.json')
    expect(parse(SOURCE.read_text(encoding='utf-8')) == dialogue, 'Independent encounter author and runtime agree')
    expect(len(dialogue) == 19 and sum(map(len, dialogue.values())) == 115, '19 scene blocks and 115 revised authored lines')
    manifest = read('assets/encounters/manifest.json')
    expect(manifest['source'] == 'OpenAI built-in ImageGen' and not manifest['third_party_downloads'], 'Original generated art with retained prompts')
    expect(len(manifest['sources']) == 11, 'Eleven independently generated source images')
    for source in manifest['sources']:
        for path, key in [('path', 'sha256'), ('prompt', 'prompt_sha256')]:
            expect(hashlib.sha256((ROOT/source[path]).read_bytes()).hexdigest() == source[key], 'Source provenance: '+source[path])
    for entry in manifest['runtime']:
        path = ROOT/entry['path']
        expect(hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], 'Runtime hash: '+entry['path'])
        pixels = np.array(Image.open(path).convert('RGBA'))
        expect(set(np.unique(pixels[:, :, 3])) <= {0, 255}, 'Binary pixel alpha: '+entry['path'])
        if '/frames/' in entry['path']:
            effect = '_fx/' in entry['path']
            expect(pixels.shape[:2] == ((128, 128) if effect else (96, 96)), 'Shared frame dimensions: '+entry['path'])
            expect(len(np.unique(pixels[pixels[:, :, 3] == 255, :3], axis=0)) <= 48, 'Limited frame palette: '+entry['path'])
    for who in ['bai_muyao', 'su_wantang', 'chuxia']:
        qc = read('assets/encounters/actors/'+who+'/runtime-qc.json')
        expect(qc['passed'] and qc['body_height_cv'] <= .08 and qc['feet_y_std'] == 0, 'Stable direction sizes and feet: '+who)
        files = [ROOT/f'assets/encounters/actors/{who}/frames/frame_{n:03d}.png' for n in range(16)]
        expect(all(p.is_file() for p in files), 'Complete 16-frame character: '+who)
        for direction in range(4):
            expect(len({hashlib.sha256(p.read_bytes()).hexdigest() for p in files[direction*4:direction*4+4]}) >= 3, 'Three actual walking poses: '+who+'/'+str(direction))
    maps = read('data/chapter1/maps.json'); maps.update(read('data/chapter2/maps.json'))
    for name in ['clubs', 'dorm', 'c2_dorm', 'corridor', 'cult_library', 'cult_ice_shop']:
        data = maps[name]
        expect(can_stand(data, *data['spawn']), 'Safe furnished entrance: '+name)
        visited = reachable(data)
        for actor in data['actors']:
            expect(interaction_reachable(data, actor, visited), 'Physical route exposes nearest E target: '+name+'/'+actor['id'])
        for item in data['props'] + data['actors']:
            expect((ROOT/item['asset'].removeprefix('res://')).is_file() and not item.get('rotation', 0), 'Independent upright resource: '+name+'/'+item['nodeName'])
        if name != 'clubs':
            expect('blockers' in data and 'floorRect' in data and 'cameraRegion' in data, 'Separate interior floor, structure and camera: '+name)
    expect(all(a['id'] not in ['chuxia', 'c2_chuxia'] for id in ['dorm', 'c2_dorm'] for a in maps[id]['actors']), 'Chuxia appears outside both bedrooms')
    events = read('data/cultivation/events.json')
    expect(len(events) == 11 and len({e['id'] for e in events}) == 11, 'Six old events retained alongside five new events')
    scenes = read('data/cultivation/cutscenes.json')
    expect(len(scenes) == 16, 'Eleven automatic entrances plus five choice performances')
    for event in [e for e in events if not e.get('character_event')]:
        sequence = scenes['event_' + event['id']]
        room = next(s['room'] for s in sequence if s['kind'] == 'scene')
        data = maps[room]
        previous = next(s['positions']['player'] for s in sequence if s['kind'] == 'scene')
        expect(can_stand(data, *previous), 'Safe automatic original encounter staging: ' + event['id'])
        for step in sequence:
            if step['kind'] != 'move': continue
            for actor in step['actors']:
                for point in actor['path']:
                    for fraction in np.linspace(0, 1, 41):
                        expect(can_stand(data, *[previous[n]+(point[n]-previous[n])*fraction for n in [0, 1]]),
                               'Collision-free automatic approach: ' + event['id'])
                    previous = point
    for event in [e for e in events if e.get('character_event')]:
        data = maps[event['room']]
        props = event.get('props', [])
        actors = [a for a in data['actors'] if a['id'] not in event.get('remove_actors', [])]
        if event['id'] == 'dormitory_flyers': actors = [a for a in actors if a['id'] != 'chuxia']
        lead = dict(event, id='growth_event')
        actors += [lead] + event.get('partners', [])
        expect(interaction_reachable(data, lead, reachable(data, props), actors), 'Actual encounter can be approached: '+event['id'])
        expect(event['max_day'] == 14 and event['interlude_only'] and len(event['options']) == 2, 'Optional, once-only January encounter: '+event['id'])
        expect(event['cinematic'] in scenes and event['dialogue'] in dialogue, 'Entrance and authored dialogue: '+event['id'])
        for option in event['options']:
            expect(option['dialogue'] in dialogue and option.get('cinematic', event['cinematic']) in scenes, 'Result dialogue and performance: '+option['label'])
        positions = {a['id']: a['position'][:] for a in actors}; positions['player'] = data['spawn'][:]
        intro_end = {}
        for sequence in [event['cinematic']] + [o['cinematic'] for o in event['options'] if 'cinematic' in o]:
            if intro_end: positions = {id: point[:] for id, point in intro_end.items()}
            for step in scenes[sequence]:
                for move in step.get('actors', []) if step['kind'] == 'move' else []:
                    expect(move['id'] in positions, 'Present actor in event path: '+sequence+'/'+move['id'])
                    previous = positions[move['id']]
                    for point in move['path']:
                        for fraction in np.linspace(0, 1, 41):
                            sample = [previous[n]+(point[n]-previous[n])*fraction for n in [0, 1]]
                            expect(can_stand(data, *sample, props), 'Collision-free animation path: '+sequence+'/'+move['id'])
                        previous = point
                    positions[move['id']] = previous
            if sequence == event['cinematic']: intro_end = {id: point[:] for id, point in positions.items()}
    report = {'passed': True, 'checks': checks, 'sources': len(manifest['sources']), 'runtime_pngs': len(manifest['runtime'])}
    (ROOT/'.dev/encounters-assets-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{len(checks)}/{len(checks)} encounter text/art/path checks passed; {len(manifest["runtime"])} runtime PNGs')


if __name__ == '__main__': main()
