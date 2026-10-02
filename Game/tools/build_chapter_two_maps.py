"""Assemble distinct service halls and Chapter 2 from independent ImageGen objects."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def main():
    original_path = ROOT/'data/chapter1/maps.json'
    original = json.loads(original_path.read_text(encoding='utf-8'))
    venues = json.loads((ROOT/'assets/venues/manifest.json').read_text(encoding='utf-8'))
    chapter = json.loads((ROOT/'assets/chapter2/manifest.json').read_text(encoding='utf-8'))
    modules = {entry['id']: entry for entry in json.loads((ROOT/'assets/chapter1/refined/hall/module-manifest.json').read_text(encoding='utf-8'))['modules']}

    def prop(asset, x, y, size, collision=None, layer='actors', name='Prop', anchor=None):
        entry = {'asset': asset, 'position': [x,y], 'size': size, 'nodeName': name,
                 'renderLayer': layer, 'occlusionClass': 'low'}
        if collision: entry['collision'] = collision
        if anchor: entry['anchor'] = anchor
        return entry

    def generated(name, x, y, collision=None, layer='actors', bundle=venues):
        info = bundle['objects'][name]
        return prop(info['asset'],x,y,info['size'],collision,layer,name,info['anchor'])

    def module(name, x, y, collision=None, layer='actors'):
        info = modules[name]
        return prop('res://'+info['path'],x,y,info['size'],collision,layer,name,info['anchor'])

    def npc(id, name, asset, x, y, character='', folder='', **extra):
        entry = prop(asset,x,y,[48,48], name=id)
        entry.update(id=id,name=name,**extra)
        if character:
            entry['character'] = character
            if folder: entry['characterFolder'] = folder
        return entry

    def old_npc(id, name, index, x, y, character='', **extra):
        return npc(id,name,f'res://assets/chapter1/refined/npcs/frames/frame_{index:03d}.png',x,y,character,**extra)

    def new_npc(id, name, actor, x, y, **extra):
        return npc(id,name,f'res://assets/chapter2/actors/{actor}/frames/frame_000.png',x,y,actor,'res://assets/chapter2/actors',**extra)

    def staff(id, name, kind, index, x, y, **extra):
        return npc(id,name,f'res://assets/venues/{kind}_people/frames/frame_{index:03d}.png',x,y,**extra)

    def item(id, name, asset, x, y, size, collision=None, **extra):
        entry = prop(asset,x,y,size,collision,name=id)
        entry.update(id=id,name=name,**extra)
        return entry

    def expedition(index, x, y, size=72, collision=None):
        return prop(f'res://assets/chapter2/expedition_props/frames/frame_{index:03d}.png',x,y,[size,size],collision,name=f'expedition_{index}')

    def room(name, floor=1, spawn=None, wall=True):
        result = {'name':name,'width':30,'height':18,'floor':floor,'spawn':spawn or [720,660],
                  'cameraOffset':[0,-44],'props':[],'actors':[], 'art_bundle':'chapter2-playable.1'}
        if wall:
            result['props'].append(generated('academy_wall',720,400,[96,24,1248,372],'background'))
        return result

    # These two rooms have different architecture, floor plans, staff and queues.
    academy = room('学院任务大厅',spawn=[720,630],wall=False)
    academy['terrain'] = {'base':[4,5,6,7], 'zones':[{'rect':[12,9,6,9],'tiles':[16,17]}]}
    academy['props'] = [generated('academy_wall',720,448,[96,24,1248,420],'background'),
                         generated('academy_counter',720,568,[624,548,192,20])]
    academy['props'][1]['size'] = [192,50.5]
    academy['props'] += [module('bench',x,y,[x-65,y-15,130,15]) for x,y in [(280,650),(280,760),(1160,650),(1160,760)]]
    academy['props'] += [module('planter',x,495,[x-50,479,100,16]) for x in [180,1260]]
    academy['actors'] = [staff('task','学院任务管理员 · 学生证登记','academy',0,700,547,interactionPosition=[700,550]),
                         staff('academy_student','等候登记的男同学','academy',1,850,648),
                         staff('academy_club','社团值日生','academy',2,1020,640),
                         staff('academy_worker','校园设施员','academy',3,350,568)]
    academy['entrances'] = [{'id':'student_entrance','position':[720,810]}]
    bureau = room('管理局服务大厅',spawn=[720,660],wall=False)
    bureau['terrain'] = {'base':[25,26,27], 'zones':[{'rect':[13,9,4,9],'tiles':[20,21]}]}
    counter = generated('bureau_counter',720,568,[552,538,336,30])
    counter['size'] = [336,118.5]
    counter['materialShader'] = 'res://assets/venues/bureau_glass.gdshader'
    bureau['props'] = [generated('bureau_wall',720,448,[144,24,1152,420],'background'),counter]
    bureau['props'] += [module('bench',x,732,[x-65,717,130,15]) for x in [240,1200]]
    bureau['props'] += [module('barrier',x,644,[x-66,630,132,14]) for x in [480,960]]
    bureau['props'] += [module('planter',x,500,[x-50,484,100,16]) for x in [180,1260]]
    bureau['actors'] = [staff('reception','管理局受理员 · 签收窗口','bureau',0,690,508,interactionPosition=[690,550]),
                        staff('bureau_guard','入口执勤员','bureau',1,840,760),
                        staff('bureau_civilian','等候办事的市民','bureau',2,1080,650),
                        staff('bureau_records','档案核验员','bureau',3,800,508,interactionPosition=[800,550])]
    bureau['entrances'] = [{'id':'security_entrance','position':[720,810]}]
    original['hall'],original['cbd'] = academy,bureau
    write(original_path,original)

    maps = {}
    dorm = room('宿舍与楼道',spawn=[720,630])
    dorm['props'] += [prop('res://assets/chapter1/bed/runtime.png',450,520,[72,132],[418,406,64,114]),
                      prop('res://assets/chapter1/bed/runtime.png',580,520,[72,132],[548,406,64,114]),
                      module('trial_table',760,470,[722,454,76,16]),module('trial_table',950,470,[912,454,76,16])]
    dorm['actors'] = [old_npc('c2_wen','温让 · 同行与夜谈',0,830,602,'wen_rang'),
                      new_npc('c2_jiang','江北辰 · 同行与夜谈','jiang',1050,630),
                      old_npc('c2_chuxia','林初夏 · 同行与夜谈',7,1140,720),
                      item('c2_notice','复筛通知 · 学生证待办','res://assets/chapter1/props/frames/frame_011.png',760,442,[28,28],interactionPosition=[760,465]),
                      item('c2_sleep','床铺 · 休息到明早','res://assets/chapter1/bed/runtime.png',320,520,[72,132],[288,406,64,114]),
                      item('c2_schedule','课表终端 · 日程安排','res://assets/chapter1/props/frames/frame_010.png',950,442,[48,48],interactionPosition=[950,465])]
    maps['c2_dorm'] = dorm

    clinic = room('医务室 · 异常复筛',spawn=[720,680])
    clinic['terrain'] = {'base':[16,17],'zones':[{'rect':[12,8,6,10],'tiles':[20,21]}]}
    clinic['props'] += [prop('res://assets/chapter1/bed/runtime.png',x,580,[72,132],[x-32,466,64,114]) for x in [240,340]]
    clinic['props'] += [module('trial_table',720,468,[682,452,76,16]),module('trial_table',1070,478,[1032,462,76,16]),
                        prop('res://assets/chapter1/props/frames/frame_005.png',800,460,[60,72],[794,448,12,12])]
    clinic['actors'] = [old_npc('c2_exam','唐半夏 · 异常复筛',5,730,535,'tang'),
                        new_npc('c2_jiang','江北辰 · 等候复筛','jiang',850,596),
                        old_npc('c2_chuxia','林初夏 · 复筛名单',7,610,596),
                        item('c2_list','同批复筛名单','res://assets/chapter1/props/frames/frame_002.png',480,500,[120,120],[436,480,88,20]),
                        item('c2_box','封存箱 · 学院与管理局双章','res://assets/chapter2/expedition_props/frames/frame_000.png',1070,451,[60,60],interactionPosition=[1010,488])]
    maps['c2_infirmary'] = clinic

    classroom = room('教学楼 · 常规课程',spawn=[720,760])
    classroom['terrain'] = {'base':[16,17], 'zones':[{'rect':[12,8,6,10],'tiles':[4,5]}]}
    for x in [400,1040]:
        for y in [550,660,770]: classroom['props'].append(module('trial_table',x,y,[x-38,y-16,76,16]))
    classroom['actors'] = [staff('c2_class','课程助教 · 上午或下午上课','academy',2,720,510),
                           item('c2_schedule','课程板 · 日程安排','res://assets/chapter1/props/frames/frame_002.png',890,470,[96,96])]
    maps['c2_classroom'] = classroom

    training = room('学院训练场 · 基础修炼',floor=2,spawn=[720,700],wall=False)
    training['props'] = [generated('academy_wall',720,380,[96,24,1248,352],'background')]
    training['terrain'] = {'base':[18,19], 'zones':[{'rect':[4,8,22,9],'tiles':[16,17]},{'rect':[12,8,6,9],'tiles':[20,21]}]}
    training['props'] += [module('cone',x,y,[x-8,y-6,16,6]) for x,y in [(480,520),(960,520),(480,670),(960,670)]]
    training['props'] += [module('bench',300,720,[235,705,130,15])]
    training['actors'] = [staff('c2_training','场地值日生 · 基础修炼','academy',1,720,520),
                          item('c2_rest','休息点 · 恢复HP与负荷','res://assets/chapter2/expedition_props/frames/frame_003.png',430,660,[48,48]),
                          old_npc('c2_wen','温让 · 同行',0,1000,720,'wen_rang')]
    maps['c2_training'] = training

    clubs = room('社团活动室',spawn=[720,700])
    clubs['props'] += [module('trial_table',460,540,[422,524,76,16]),module('trial_table',990,540,[952,524,76,16])]
    clubs['props'] += [module('bench',300,710,[235,695,130,15]),module('bench',1140,710,[1075,695,130,15])]
    clubs['actors'] = [staff('c2_club_signup','社团登记员 · 入社选择','academy',2,510,580),
                       staff('c2_club_activity','值日生 · 社团活动','academy',1,910,580),
                       old_npc('c2_wen','温让 · 同行',0,670,660,'wen_rang'),
                       new_npc('c2_jiang','江北辰 · 同行','jiang',1110,600),
                       old_npc('c2_chuxia','林初夏 · 同行',7,330,600)]
    maps['c2_clubs'] = clubs

    port = room('港口 · 小裂隙集合点',floor=0,spawn=[720,730],wall=False)
    port['terrain'] = {'base':[25,26,27], 'zones':[{'rect':[0,0,30,4],'tiles':[22,23]}]}
    port['props'] = [generated('rift_gate',720,450,[675,418,90,32],bundle=chapter)]
    port['props'] += [expedition(0,x,y,96,[x-32,y-26,64,26]) for x,y in [(270,500),(365,500),(270,605),(1130,500),(1215,500)]]
    port['props'] += [expedition(2,x,790,72,[x-20,774,40,16]) for x in [140,1290]]
    port['props'] += [module('barrier',x,585,[x-66,571,132,14]) for x in [560,880]]
    port['props'] += [module('cone',x,650,[x-8,644,16,6]) for x in [570,870]]
    port['actors'] = [new_npc('c2_contact','韩烛 · 管理局协作登记','han',690,535,route='bureau'),
                      new_npc('c2_contact','秦妖妖 · 互助会协作登记','qin',690,535,route='mutual'),
                      item('c2_resupply','急救箱 · 撤回补给','res://assets/chapter2/expedition_props/frames/frame_003.png',1010,690,[64,64])]
    maps['c2_port'] = port

    rift = room('港口小裂隙 · 浅层残骸区',floor=0,spawn=[380,770],wall=False)
    rift['terrain'] = {'base':[22,23,24], 'zones':[{'rect':[6,13,8,5],'tiles':[23,24]},{'rect':[13,10,5,5],'tiles':[23,24]},{'rect':[18,5,7,7],'tiles':[23,24]}]}
    rift['cameraOffset'] = [0,-36]
    rift['props'] = [generated('rift_gate',270,770,[225,738,90,32],bundle=chapter)]
    for x,y,size in [(160,330,144),(410,355,144),(675,350,192),(1260,450,144),(210,580,144),(650,660,144),(900,750,144),(1190,740,144)]:
        rift['props'].append(expedition(1,x,y,size,[x-size*.32,y-size*.26,size*.64,size*.26]))
    rift['props'] += [expedition(0,1130,350,96,[1100,326,60,24])]
    rift['actors'] = [item('c2_entry','入口异兽 · 清理撤离通道','res://assets/chapter2/creatures/frames/frame_000.png',485,655,[72,72],encounter='entry'),
                      item('c2_storm','岩壁掩体 · 灵能风暴','res://assets/chapter2/expedition_props/frames/frame_001.png',745,545,[120,120],[707,514,76,31],interactionPosition=[690,551]),
                      item('c2_final','残骸区异兽 · 清剿','res://assets/chapter2/creatures/frames/frame_002.png',1020,475,[96,96],encounter='final'),
                      item('c2_corpse','异兽尸体 · 三道平行切口','res://assets/chapter2/creatures/frames/frame_003.png',1030,400,[96,96],after_final=True),
                      item('c2_deep','深层方向 · 暂不深入','res://assets/chapter2/expedition_props/frames/frame_001.png',1230,260,[96,96],[1200,238,60,22]),
                      item('c2_retreat','撤离登记 · 返回港口','res://assets/chapter2/expedition_props/frames/frame_003.png',395,760,[48,48]),
                      new_npc('c2_han','韩烛 · 驻守协作','han',1330,580,route='bureau',after_final=True,hidden=True),
                      new_npc('c2_qin','秦妖妖 · 驻守协作','qin',1330,580,route='mutual',after_final=True,hidden=True)]
    maps['c2_rift'] = rift

    bar = room('裂隙猎人酒吧',floor=1,spawn=[720,680])
    bar['props'] += [generated('academy_counter',560,545,[464,525,192,20])]
    bar['props'][-1]['size'] = [192,50.5]
    for x,y in [(1040,530),(1050,700),(380,735)]: bar['props'].append(module('trial_table',x,y,[x-38,y-16,76,16]))
    bar['actors'] = [npc('c2_bar','靳寻 · 吧台','res://assets/chapter2/bar_people/frames/frame_000.png',530,526,interactionPosition=[530,535]),
                     npc('c2_old_hunter','老猎人 · 切口线索','res://assets/chapter2/bar_people/frames/frame_001.png',1090,570),
                     npc('c2_bar_guest_worker','港口工人','res://assets/chapter2/bar_people/frames/frame_002.png',470,665),
                     npc('c2_bar_guest_hunter','等候委托的猎人','res://assets/chapter2/bar_people/frames/frame_003.png',1050,735)]
    maps['c2_bar'] = bar
    write(ROOT/'data/chapter2/maps.json',maps)

    def move(id, path, face=None):
        return {'id':id,'path':path,'face':face or [0,1]}

    def motion(actors, seconds, camera, caption='', **extra):
        return {'kind':'move','actors':actors,'seconds':seconds,'camera':camera,'caption':caption,**extra}

    def fade(alpha): return {'kind':'fade','alpha':alpha,'seconds':0.28}
    def scene(id, positions, camera): return {'kind':'scene','room':id,'positions':positions,'camera':camera}
    def pause(seconds=0.4, **extra): return {'kind':'wait','seconds':seconds,**extra}

    scenes = {
        'c2_notice':[motion([move('player',[[750,615]],[1,0]),move('c2_wen',[[820,615]],[-1,0])],1.1,[780,555],'觉醒历22年 · 01-15 · 复筛通知'),pause(.4)],
        'c2_rescreen':[motion([move('player',[[710,640],[710,575]],[0,-1]),move('c2_jiang',[[825,560]],[-1,0]),move('c2_chuxia',[[605,560]],[1,0])],1.8,[720,495],'医务室 · 同批异常复筛'),pause(.6,name='唐半夏',role='复筛记录归档',character='tang')],
        'c2_seal':[pause(1.15,camera=[1040,470],caption='复筛档案 · 学院与管理局双章封存')],
        'c2_sleep':[fade(1),scene('c2_dorm',{},[720,590]),pause(.35,caption='翌日 · 宿舍'),fade(0)],
        'c2_rift_entry':[fade(1),scene('c2_rift',{'player':[375,805]},[510,640]),fade(0),motion([move('player',[[395,748],[430,735]],[0,-1])],1.2,[565,610],'港口小裂隙 · 浅层'),pause(.4)],
        'c2_storm_shelter':[motion([move('player',[[690,615],[725,600]],[0,-1])],1.1,[740,510],'灵能风暴 · 退入岩壁掩体'),fade(.5),pause(.8),fade(0)],
        'c2_storm_push':[motion([move('player',[[790,610],[875,560]],[1,0])],1.4,[855,490],'灵能风暴 · 负荷持续升高'),fade(.32),pause(.6),fade(0)],
        'c2_leave_rift':[fade(1),scene('c2_port',{'player':[730,640]},[720,520]),fade(0),motion([move('player',[[730,710]],[0,1])],.8,[720,590],'撤出裂隙 · 港口登记点')],
    }
    for route, actor, name in [('bureau','han','韩烛'),('mutual','qin','秦妖妖')]:
        scenes['c2_hunter_'+route] = [motion([move('c2_'+actor,[[1200,580],[1130,565],[1080,550]],[-1,0])],1.8,[1040,450],'清剿结束 · 协作人员抵达',
            name=name,role='管理局驻守队员' if route=='bureau' else '互助会裂隙猎人',portrait=f'res://assets/chapter2/actors/{actor}/frames/frame_000.png'),pause(.4)]
    write(ROOT/'data/chapter2/cutscenes.json',scenes)
    print(f'Built 2 distinct service halls, {len(maps)} Chapter 2 maps and {len(scenes)} cinematics.')


if __name__ == '__main__': main()
