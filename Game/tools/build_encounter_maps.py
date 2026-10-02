"""Build recruit stalls, separate dorm/corridor, and five character encounters.

Run after the older chapter map builders. All runtime art stays independent from
terrain, people, explicit collision and scene hooks; this tool never edits authors.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def write(path, data):
    (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


INTERIORS = {'dorm', 'c2_dorm', 'corridor', 'cult_library', 'cult_ice_shop'}


def compact_point(point):
    return [720 + (point[0] - 720) / 2, 600 + (point[1] - 600) / 2]


def compact_rect(rect):
    return compact_point(rect[:2]) + [rect[2] / 2, rect[3] / 2]


def compact_entry(entry, person=False):
    entry['position'] = compact_point(entry['position'])
    if not person: entry['size'] = [n / 2 for n in entry['size']]
    for key in ['collision', 'actorSafeArea']:
        if key in entry: entry[key] = compact_rect(entry[key])
    if 'interactionPosition' in entry: entry['interactionPosition'] = compact_point(entry['interactionPosition'])


def compact_room(data):
    """Match furniture and room dimensions to 48px people, without rescaling people."""
    data['spawn'] = compact_point(data['spawn'])
    data.update(cameraOffset=[0, -70], dialogueOffset=[0, 12], cinematicZoom=2)
    for entry in data['props']: compact_entry(entry)
    data['props'][0]['size'][1] /= 2
    for entry in data['props']:
        if entry['nodeName'] in ['library_desk', 'ice_counter']: entry['size'][1] = 30
    for entry in data['actors']:
        person = 'character' in entry or '/encounter_people/' in entry['asset']
        compact_entry(entry, person)
    bounds = compact_rect(data['walkableZones'][0]['rect'])
    left, top, width, height = bounds
    right, bottom = left + width, top + height
    data['blockers'] = [[0, 0, 1440, top], [0, top, left, 864-top],
                        [right, top, 1440-right, 864-top], [left, bottom, width, 864-bottom]]
    data['floorRect'] = bounds
    data['walkableZones'][0]['rect'] = bounds
    wall_height = data['props'][0]['size'][1]
    data['cameraRegion'] = [left, top-wall_height, width, height+wall_height]
    for entry in data['entrances']: entry['position'] = compact_point(entry['position'])
    if 'terrain' in data:
        for zone in data['terrain'].get('zones', []):
            pixel_rect = compact_rect([n*48 for n in zone['rect']])
            zone['rect'] = [round(n/48) for n in pixel_rect]


def compact_sequence(steps, initial_room=''):
    current = initial_room
    for step in steps:
        if step['kind'] == 'scene': current = step['room']
        if current not in INTERIORS or step.get('coordinates') == 'compact-interior.1': continue
        if 'camera' in step: step['camera'] = compact_point(step['camera'])
        if 'positions' in step:
            step['positions'] = {id: compact_point(point) for id, point in step['positions'].items()}
        if step['kind'] == 'move':
            for actor in step['actors']: actor['path'] = [compact_point(point) for point in actor['path']]
        step['coordinates'] = 'compact-interior.1'


def main():
    maps = read('data/chapter1/maps.json')
    second = read('data/chapter2/maps.json')
    art = read('assets/encounters/manifest.json')
    modules = {m['id']: m for m in read('assets/chapter1/refined/hall/module-manifest.json')['modules']}

    def prop(asset, x, y, size, node_name, collision=None, layer='actors', anchor=None, **extra):
        result = {'asset': asset, 'nodeName': node_name, 'position': [x, y], 'size': size,
                  'renderLayer': layer, 'occlusionClass': 'low', **extra}
        if collision: result['collision'] = collision
        if anchor: result['anchor'] = anchor
        return result

    def object(name, x, y, collision=None, layer='actors', suffix='', **extra):
        info = art['objects'][name]
        return prop(info['asset'], x, y, info['size'], name + suffix, collision, layer, info['anchor'], **extra)

    def module(name, x, y, collision=None, layer='actors', suffix=''):
        info = modules[name]
        return prop('res://' + info['path'], x, y, info['size'], name + suffix, collision, layer, info['anchor'])

    def actor(id, name, asset, x, y, character='', folder='', **extra):
        result = prop(asset, x, y, [48, 48], id, id=id, name=name, **extra)
        if character: result.update(character=character, characterFolder=folder or 'res://assets/chapter1/cinematics')
        return result

    def old(id, name, index, x, y, character='', **extra):
        return actor(id, name, f'res://assets/chapter1/refined/npcs/frames/frame_{index:03d}.png', x, y, character, **extra)

    def person(id, name, index, x, y, **extra):
        return actor(id, name, f'res://assets/encounters/encounter_people/frames/frame_{index:03d}.png', x, y, **extra)

    def character(id, name, who, x, y, **extra):
        return actor(id, name, f'res://assets/encounters/actors/{who}/frames/frame_000.png', x, y,
                     who, 'res://assets/encounters/actors', **extra)

    def door(id, name, x, y):
        return prop('res://assets/chapter1/props/frames/frame_011.png', x, y, [20, 20], id,
                    id=id, name=name, hidden=True, interactionPosition=[x, y + 35])

    def room(name, spawn, wall, wall_y, left=144, right=1296):
        return {'name': name, 'width': 30, 'height': 18, 'floor': 1, 'spawn': spawn,
                'cameraOffset': [0, -80], 'dialogueOffset': [0, -75], 'art_bundle': 'encounter-art.1',
                'props': [object(wall, 720, wall_y, layer='background')], 'actors': [],
                'blockers': [[0, 0, 1440, wall_y], [0, wall_y, left, 864 - wall_y],
                             [right, wall_y, 1440 - right, 864 - wall_y]],
                'entrances': [], 'walkableZones': [{'id': 'interior', 'rect': [left, wall_y, right-left, 820-wall_y]}]}

    # Three occupied stands and a continuous walking lane, with a companion exit.
    clubs = {'name': '操场·社团招新', 'width': 30, 'height': 18, 'floor': 2, 'spawn': [640, 690],
             'cameraOffset': [0, -60], 'dialogueOffset': [0, -50], 'art_bundle': 'encounter-art.1',
             'terrain': {'base': [18, 19], 'zones': [{'rect': [3, 6, 24, 10], 'tiles': [16, 17]},
                                                               {'rect': [3, 10, 24, 2], 'tiles': [20, 21]}]},
             'props': [], 'actors': [], 'entrances': [{'id': 'dorm_path', 'position': [720, 800]}]}
    for index, x in enumerate([400, 720, 1040]):
        booth = object('club_booth', x, 470, [x-94, 419, 188, 51], suffix=str(index))
        booth.update(occlusionClass='tall', actorSafeArea=[x-120, 328, 240, 100], occupantPolicy={'mode': 'fade', 'alpha': 0.3})
        clubs['props'].append(booth)
    clubs['actors'] = [person('club_sword', '剑道社学长 · 练习与传单', 2, 400, 520),
                       person('club_element', '元素研究社学姐 · 记录与示范', 3, 720, 520),
                       actor('club_healing', '治愈社学姐 · 急救与值班', 'res://assets/venues/academy_people/frames/frame_002.png', 1040, 520),
                       old('clubs', '温让 · 拿传单 / 一起回宿舍', 0, 660, 620, 'wen_rang'),
                       person('recruit_student_a', '看传单的同学', 3, 470, 605),
                       person('recruit_student_b', '翻看活动表的同学', 2, 1180, 665)]
    clubs['props'] += [module('bench', x, 720, [x-65, 705, 130, 15], suffix=str(x)) for x in [350, 1090]]
    clubs['props'] += [module('planter', x, 575, [x-50, 559, 100, 16], suffix=str(x)) for x in [185, 1255]]
    clubs['props'] += [module('streetlamp', x, 800, [x-7, 790, 14, 10], suffix=str(x)) for x in [190, 1250]]
    clubs['props'].append(prop('res://assets/chapter1/props/frames/frame_010.png', 360, 704, [24, 24], 'RecruitLeaflets'))
    maps['clubs'] = clubs

    def dorm(name, later=False):
        result = room(name, [720, 625], 'dorm_wall', 384, 240, 1200)
        result['props'] += [prop('res://assets/chapter1/bed/runtime.png', x, 560, [72, 132], f'Bed{x}', [x-32, 446, 64, 114]) for x in [480, 950]]
        result['props'] += [module('trial_table', 720, 493, [682, 477, 76, 16]),
                            module('bench', 720, 742, [655, 727, 130, 15]),
                            object('phone', 754, 477, layer='foreground'), object('notebook', 700, 477, layer='foreground')]
        result['actors'] = [old('c2_wen' if later else 'dorm_wen', '温让 · 同寝与夜谈', 0, 820, 625, 'wen_rang'),
                            door('dorm_exit', '房门 · 去共用走廊', 1010, 382)]
        if later:
            result['actors'] += [actor('c2_jiang', '江北辰 · 夜间来访', 'res://assets/chapter2/actors/jiang/frames/frame_000.png', 1100, 630, 'jiang', 'res://assets/chapter2/actors'),
                                  prop('res://assets/chapter1/props/frames/frame_011.png', 720, 474, [28, 28], 'c2_notice', id='c2_notice', name='复筛通知 · 学生证待办', interactionPosition=[720, 535]),
                                  prop('res://assets/chapter1/props/frames/frame_010.png', 690, 474, [26, 26], 'c2_schedule', id='c2_schedule', name='课表终端 · 日程安排', interactionPosition=[690, 535])]
        sleep_id = 'c2_sleep' if later else 'sleep'
        result['actors'].append(prop('res://assets/chapter1/bed/runtime.png', 480, 560, [72, 132], sleep_id,
                                    id=sleep_id, name='床铺 · 休息到明天', hidden=True, interactionPosition=[480, 602]))
        result['entrances'] = [{'id': 'room_door', 'position': [1010, 425], 'destination': 'corridor'}]
        return result

    maps['dorm'] = dorm('男生宿舍·寝室')
    second['c2_dorm'] = dorm('男生宿舍·寝室与课表', True)
    corridor = room('宿舍楼·共用走廊', [720, 505], 'corridor_wall', 432)
    corridor['terrain'] = {'base': [16, 17], 'zones': [{'rect': [3, 10, 24, 3], 'tiles': [20, 21]}]}
    corridor['props'] += [object('corridor_stairs', 1210, 662, [1165, 534, 90, 128]),
                          module('bench', 385, 690, [320, 675, 130, 15]),
                          module('planter', 215, 545, [165, 529, 100, 16]),
                          module('planter', 1120, 488, [1070, 472, 100, 16])]
    corridor['actors'] = [character('chuxia', '林初夏 · 楼梯口', 'chuxia', 1080, 675),
                           door('dorm_enter', '寝室房门 · 回屋', 720, 432)]
    corridor['entrances'] = [{'id': 'room_door', 'position': [720, 470], 'destination': 'dorm'},
                             {'id': 'stair_landing', 'position': [1140, 692]}]
    maps['corridor'] = corridor

    library = room('学院图书馆', [720, 650], 'library_wall', 442)
    library['props'] += [object('library_desk', 1000, 542, [880, 522, 240, 20])]
    library['props'] += [module('trial_table', x, 705, [x-38, 689, 76, 16], suffix=str(x)) for x in [400, 620]]
    library['props'] += [module('bench', x, 755, [x-65, 740, 130, 15], suffix=str(x)) for x in [400, 620]]
    library['props'] += [module('planter', x, 490, [x-50, 474, 100, 16], suffix=str(x)) for x in [225, 1210]]
    library['actors'] = [person('library_daily', '图书管理员 · 借阅台', 1, 1000, 518, interactionPosition=[1000, 565])]
    maps['cult_library'] = library

    shop = room('老街·苏家冰品店', [720, 625], 'ice_shop_wall', 366, 288, 1152)
    shop['props'] += [object('ice_counter', 720, 490, [576, 471, 288, 19])]
    shop['props'] += [module('trial_table', x, 650, [x-38, 634, 76, 16], suffix=str(x)) for x in [470, 990]]
    shop['props'] += [module('bench', x, 709, [x-65, 694, 130, 15], suffix=str(x)) for x in [470, 990]]
    shop['props'] += [module('planter', 1095, 472, [1045, 456, 100, 16])]
    shop['actors'] = [person('ice_shop_daily', '苏父 · 店里帮忙', 0, 790, 456, interactionPosition=[800, 523])]
    maps['cult_ice_shop'] = shop

    # Training uses separate lanes, cones and a resting area; avoid event actors
    # standing on the generic training attendant or the recovery box.
    training = second['c2_training']
    training['dialogueOffset'] = [0, 18]
    for entry in training['actors']:
        if entry['id'] == 'c2_training': entry['position'] = [410, 560]
        if entry['id'] == 'c2_wen': entry['position'] = [1030, 730]
    training['props'] = [p for p in training['props'] if p.get('position') not in [[1100, 650], [1100, 470]]]
    training['props'] += [module('bench', 1100, 650, [1035, 635, 130, 15]),
                           module('barrier', 1100, 470, [1034, 456, 132, 14])]

    # Replace Chuxia appearances in Chapter 2 consistently, while keeping her in
    # the clinic and club where those plot scenes call for her.
    for data in second.values():
        for entry in data.get('actors', []):
            if entry.get('id') == 'c2_chuxia':
                entry.update(asset='res://assets/encounters/actors/chuxia/frames/frame_000.png',
                             character='chuxia', characterFolder='res://assets/encounters/actors')

    for id in INTERIORS:
        compact_room((second if id == 'c2_dorm' else maps)[id])
    write('data/chapter1/maps.json', maps)
    write('data/chapter2/maps.json', second)
    settings = read('data/cultivation/settings.json')
    settings['places']['training'] = {'name': '训练场闲逛', 'room': 'c2_training', 'description': '看对练、到休息区转转\n1行动 · 留意不同日期'}
    settings['places']['dormitory'] = {'name': '宿舍楼道闲逛', 'room': 'corridor', 'description': '回寝室路上遇见同学\n1行动 · 可到楼梯口看看'}
    settings['places']['campus']['description'] = '学院区与图书馆\n1行动 · 新事件随日期开放'
    settings['places']['street']['description'] = '商业街与回家方向的老街\n1行动 · 留意手头资金'
    write('data/cultivation/settings.json', settings)

    existing = [e for e in read('data/cultivation/events.json') if not e.get('character_event')]
    base = {'character_event': True, 'interlude_only': True, 'max_day': 14}
    def event(id, area, name, day, room_id, who, x, y, dialogue, cinematic, **extra):
        result = dict(base, id=id, area=area, name=name, min_day=day, room=room_id,
                      asset=f'res://assets/encounters/actors/{who}/frames/frame_000.png',
                      character=who, characterFolder='res://assets/encounters/actors',
                      position=[x, y], dialogue=dialogue, cinematic=cinematic, **extra)
        return result
    ice = event('street_ice', 'street', '苏挽颜 · 老街冰品店', 6, 'cult_ice_shop', 'su_wanyan', 650, 560,
                'c2_event_ice', 'event_ice_arrival', remove_actors=['ice_shop_daily'],
                partners=[person('growth_partner_father', '苏父 · 擦杯子', 0, 790, 456, interactionPosition=[810, 530])],
                props=[object('ice_bowl', 470, 630, suffix='_event', id='event_ice_bowl'),
                       object('takeaway', 780, 444, layer='foreground', id='event_takeaway', hidden=True)],
                options=[{'label': '用券坐下来吃，多聊两句', 'items': {'coupon': -1}, 'relations': {'su': 2}, 'awakening': 2, 'dialogue': 'c2_event_ice_eat', 'cinematic': 'event_ice_eat'},
                         {'label': '花30元打包一碗给温让', 'money': -30, 'relations': {'wen_rang': 2}, 'dialogue': 'c2_event_ice_takeaway', 'cinematic': 'event_ice_takeaway'}])
    ice.update(asset='res://assets/chapter1/cinematics/su_wanyan/frames/frame_000.png', characterFolder='res://assets/chapter1/cinematics')
    library_event = event('campus_library', 'campus', '白沐瑶 · 抱散的书', 5, 'cult_library', 'bai_muyao', 650, 570,
                  'c2_event_library', 'event_library_arrival',
                  props=[object('books', 675, 590, layer='ground', id='event_books'), object('notebook', 620, 565, id='event_library_notes')],
                  options=[{'label': '帮忙送到借阅台', 'study': 4, 'stats': {'perception': 1}, 'relations': {'bai_muyao': 2}, 'dialogue': 'c2_event_library_carry', 'cinematic': 'event_library_carry'},
                           {'label': '捡起手边两本递还', 'study': 1, 'relations': {'bai_muyao': 1}, 'dialogue': 'c2_event_library_return'}])
    spar = event('training_spar', 'training', '苏晚棠 · 冰雷对练', 10, 'c2_training', 'su_wantang', 880, 590,
                 'c2_event_spar', 'event_spar', face=[-1, 0],
                 partners=[character('growth_partner_bai', '白沐瑶 · 冰墙练习', 'bai_muyao', 650, 550, face=[1, 0])],
                 callback={'requires': 'campus_library', 'dialogue': 'c2_event_spar_known'},
                 options=[{'label': '实话实说：慢了半拍', 'awakening': 3, 'relations': {'bai_muyao': 2, 'su_wantang': 2}, 'dialogue': 'c2_event_spar_honest'},
                          {'label': '打个圆场：挺好的', 'relations': {'bai_muyao': 1, 'su_wantang': 1}, 'dialogue': 'c2_event_spar_polite'}])
    lunch = event('training_lunch', 'training', '苏晚棠 · 午休的加练', 12, 'c2_training', 'su_wantang', 875, 580,
                  'c2_event_lunch', 'event_lunch', requires=['training_spar'],
                  props=[object('phone', 1100, 454, layer='foreground', id='event_lunch_phone'), object('riceball', 1070, 455, layer='foreground', id='event_riceball')],
                  options=[{'label': '留下帮她喊节拍', 'stats': {'agility': 1}, 'awakening': 3, 'relations': {'su_wantang': 3}, 'dialogue': 'c2_event_lunch_count', 'cinematic': 'event_lunch_count'},
                           {'label': '把多带的饭团放下再走', 'relations': {'su_wantang': 2}, 'dialogue': 'c2_event_lunch_food'}])
    flyers = event('dormitory_flyers', 'dormitory', '林初夏 · 楼道传单', 9, 'corridor', 'chuxia', 1040, 665,
                   'c2_event_flyers', 'event_flyers',
                   props=[prop('res://assets/chapter1/props/frames/frame_010.png', 990, 673, [18, 18], 'event_flyer', id='event_flyer')],
                   options=[{'label': '帮她送完这两层', 'study': 3, 'stats': {'perception': 1}, 'relations': {'chuxia': 2}, 'dialogue': 'c2_event_flyers_help', 'cinematic': 'event_flyers_help'},
                            {'label': '只还捡到的那张', 'relations': {'chuxia': 1}, 'study': 1, 'dialogue': 'c2_event_flyers_return'}])
    for entry in [ice, library_event, flyers]:
        entry['position'] = compact_point(entry['position'])
        for partner in entry.get('partners', []): compact_entry(partner, True)
        for item in entry.get('props', []): compact_entry(item)
    write('data/cultivation/events.json', existing + [ice, library_event, spar, lunch, flyers])

    cine = read('data/chapter1/cutscenes.json')
    def move(actors, seconds=1.3, camera=None, **extra):
        result = {'kind': 'move', 'seconds': seconds, 'actors': [{'id': id, 'path': path, 'face': face} for id, path, face in actors], **extra}
        if camera: result['camera'] = camera
        return result
    def scene(room, positions, camera, **extra): return {'kind': 'scene', 'room': room, 'positions': positions, 'camera': camera, **extra}
    def fade(alpha, seconds=0.35, **extra): return {'kind': 'fade', 'alpha': alpha, 'seconds': seconds, **extra}
    cine['hill_to_clubs'] = [fade(1), scene('clubs', {'player': [640, 790], 'clubs': [705, 790]}, [720, 525]),
                            fade(0, caption='01-02 · 午后 · 操场招新'),
                            move([('player', [[640, 630]], [0, -1]), ('clubs', [[705, 630]], [0, -1])], 1.35, [720, 510])]
    cine['clubs_to_dorm'] = [move([('player', [[640, 750]], [0, 1]), ('clubs', [[705, 750]], [0, 1])], 1), fade(1),
                             scene('dorm', {'player': [720, 625], 'dorm_wen': [820, 625]}, [720, 465]),
                             fade(0, caption='01-02 · 晚间 · 同寝宿舍')]
    def to_corridor(later=False):
        return [move([('player', [[1080, 625], [1080, 435], [1010, 435]], [0, -1])], 1.4, [990, 440]), fade(1),
                scene('corridor', {'player': [720, 485]}, [850, 475]), fade(0, caption='宿舍外 · 共用走廊'),
                move([('player', [[800, 570]], [1, 0])], 0.75, [860, 535])]
    def to_dorm(later=False):
        return [fade(1), scene('c2_dorm' if later else 'dorm', {'player': [1010, 430]}, [850, 485]), fade(0, caption='回到寝室'),
                move([('player', [[1080, 435], [1080, 625], [740, 625]], [-1, 0])], 1.35, [790, 505])]
    cine['dorm_to_corridor'] = to_corridor()
    cine['corridor_to_dorm'] = to_dorm()
    cine['chuxia_corridor'] = [move([('player', [[800, 580]], [1, 0]), ('chuxia', [[1010, 655], [870, 580]], [-1, 0])], 1.5, [845, 535],
                                      name='林初夏', role='刚从训练场回来的同届新生', portrait='res://assets/encounters/actors/chuxia/frames/frame_000.png')]
    cine['chuxia_leave'] = [move([('chuxia', [[990, 670], [1135, 695], [1270, 740]], [1, 0])], 1.65, [1080, 615]),
                           {'kind': 'wait', 'camera': [835, 535], 'seconds': 0.4}]
    for id, initial in [('clubs_to_dorm', 'clubs'), ('dorm_to_corridor', 'dorm'),
                        ('corridor_to_dorm', 'corridor'), ('chuxia_corridor', 'corridor'), ('chuxia_leave', 'corridor')]:
        compact_sequence(cine[id], initial)
    write('data/chapter1/cutscenes.json', cine)
    second_cine = read('data/chapter2/cutscenes.json')
    second_cine['c2_dorm_to_corridor'] = to_corridor(True)
    second_cine['c2_corridor_to_dorm'] = to_dorm(True)
    for id, initial in [('c2_notice', 'c2_dorm'), ('c2_sleep', ''),
                        ('c2_dorm_to_corridor', 'c2_dorm'), ('c2_corridor_to_dorm', 'corridor')]:
        compact_sequence(second_cine[id], initial)
    write('data/chapter2/cutscenes.json', second_cine)

    effects = {}
    portrait = lambda who: f'res://assets/encounters/actors/{who}/frames/frame_000.png'
    effects['event_ice_arrival'] = [move([('player', [[750, 555]], [0, -1]), ('growth_event', [[690, 520]], [1, 0])], 1, [720, 470], caption='回家方向的老街 · 苏家冰品店'),
                                    {'kind': 'wait', 'camera': [540, 505], 'seconds': 0.6}]
    effects['event_ice_eat'] = [move([('player', [[550, 600], [550, 683], [500, 683]], [0, -1]),
                                      ('growth_event', [[400, 600], [400, 683], [445, 683]], [0, -1])], 1.25, [480, 570])]
    effects['event_ice_takeaway'] = [{'kind': 'prop', 'id': 'event_takeaway', 'visible': True},
                                   move([('player', [[800, 560]], [0, -1])], 0.8, [770, 490]),
                                   {'kind': 'wait', 'seconds': 0.4}]
    effects['event_library_arrival'] = [move([('player', [[700, 635], [700, 610]], [-1, 0]), ('growth_event', [[650, 590]], [1, 0])], 1, [675, 530],
                                               caption='学院图书馆 · 书从拐角散开'),
                                        {'kind': 'wait', 'camera': [660, 565], 'seconds': 0.55, 'name': '白沐瑶', 'role': '同届新生 · 正抱着借来的书', 'portrait': portrait('bai_muyao')}]
    effects['event_library_carry'] = [{'kind': 'prop', 'id': 'event_books', 'visible': False},
                                      move([('player', [[800, 615], [960, 595]], [0, -1]), ('growth_event', [[770, 590], [900, 585]], [0, -1])], 1.6, [960, 520])]
    def fx(id, folder, frames, x, y, seconds, **extra):
        return {'kind': 'effect', 'id': id, 'folder': f'res://assets/encounters/{folder}/frames', 'frames': frames,
                'position': [x, y], 'size': [128, 128], 'seconds': seconds, **extra}
    effects['event_spar'] = [move([('player', [[770, 650]], [0, -1])], 0.45, [775, 530], caption='训练场 · 冰雷对练'),
                            fx('spar_ice', 'ice_wall_fx', [0, 1], 760, 540, 0.75),
                            fx('spar_bolt', 'lightning_fx', [0, 1, 2, 3], 760, 540, 0.65),
                            fx('spar_ice', 'ice_wall_fx', [2, 3], 760, 540, 0.55),
                            move([('growth_event', [[870, 615], [820, 630]], [-1, 0]), ('growth_partner_bai', [[680, 625]], [1, 0])], 1.1, [775, 565],
                                 name='苏晚棠', role='同届新生 · 雷霆血脉', portrait=portrait('su_wantang'))]
    effects['event_lunch'] = [move([('player', [[805, 660]], [0, -1]), ('growth_event', [[875, 585]], [-1, 0])], 0.8, [930, 540], caption='午休 · 训练场还留着一个人'),
                             {'kind': 'wait', 'seconds': 1.1, 'camera': [1060, 440], 'caption': '手机亮着 · 哥：本周心得发我'},
                             move([('growth_event', [[870, 635]], [-1, 0])], 0.65, [860, 555])]
    effects['event_lunch_count'] = [move([('player', [[770, 625]], [1, 0]), ('growth_event', [[865, 605], [940, 605], [865, 605]], [-1, 0])], 1.6, [870, 525]),
                                   fx('lunch_bolt', 'lightning_fx', [0, 1, 2, 3], 970, 590, 0.5)]
    effects['event_flyers'] = [move([('player', [[910, 660]], [1, 0]), ('growth_event', [[985, 660]], [-1, 0])], 1, [1030, 565], caption='宿舍楼道 · 楼梯口的传单'),
                              {'kind': 'wait', 'seconds': 0.5, 'camera': [1050, 605]}]
    effects['event_flyers_help'] = [{'kind': 'prop', 'id': 'event_flyer', 'visible': False},
                                   move([('player', [[820, 590], [720, 500]], [0, -1]), ('growth_event', [[850, 630], [450, 590], [325, 500]], [0, -1])], 1.8, [650, 480]),
                                   fade(1, caption='送完本层，再沿楼梯去上一层'), fade(0),
                                   move([('player', [[820, 680]], [1, 0]), ('growth_event', [[860, 680]], [-1, 0])], 0.8, [845, 555])]
    for id, initial in [('event_ice_arrival', 'cult_ice_shop'), ('event_ice_eat', 'cult_ice_shop'),
                        ('event_ice_takeaway', 'cult_ice_shop'), ('event_library_arrival', 'cult_library'),
                        ('event_library_carry', 'cult_library'), ('event_flyers', 'corridor'), ('event_flyers_help', 'corridor')]:
        compact_sequence(effects[id], initial)
    # Original six discoveries use a short automatic approach, then their choices.
    all_maps = {**maps, **second}
    for event in existing:
        room = event.get('room', settings['places'][event['area']]['room'])
        data = all_maps[room]
        obstacles = data.get('blockers', []) + [p['collision'] for p in data['props'] + data['actors'] if 'collision' in p]

        def free(x, y):
            return (24 <= x - 9 and x + 9 <= data['width'] * 48 - 24
                    and 24 <= y - 11 and y + 1 <= data['height'] * 48 - 24
                    and not any(x + 9 > a and x - 9 < a + w and y + 1 > b and y - 11 < b + h
                                for a, b, w, h in obstacles))

        x, y = event['position']
        candidates = [(a, b) for a in range(round(x / 12) * 12 - 72, round(x / 12) * 12 + 73, 12)
                      for b in range(round(y / 12) * 12 - 72, round(y / 12) * 12 + 73, 12)
                      if 36 ** 2 <= (a - x) ** 2 + (b - y) ** 2 <= 82 ** 2 and free(a, b)]
        assert candidates, 'No safe encounter staging: ' + event['id']
        end = min(candidates, key=lambda p: (p[0] - (x - 48)) ** 2 + (p[1] - (y + 48)) ** 2)
        start = (end[0], end[1] + 36) if all(free(end[0], end[1] + n) for n in range(0, 37, 3)) else end
        face = [1, 0] if abs(x - end[0]) > abs(y - end[1]) else [0, -1]
        effects['event_' + event['id']] = [
            {'kind': 'fade', 'alpha': 1, 'seconds': 0.15, 'caption': event['name']},
            {'kind': 'scene', 'room': room, 'positions': {'player': list(start)}, 'camera': [x, y - 48], 'seconds': 0},
            {'kind': 'fade', 'alpha': 0, 'seconds': 0.25},
            move([('player', [list(end)], face)], 0.45, [x, y - 48]),
            {'kind': 'wait', 'seconds': 0.25}]
    write('data/cultivation/cutscenes.json', effects)
    print('Maps: occupied recruit stalls, separate bedrooms/corridor, library, family shop and training lanes')
    print('Events: existing six retained + five once-only dated character encounters')


if __name__ == '__main__':
    main()
