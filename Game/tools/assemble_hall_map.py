"""Assemble a real hall exterior and testing interior from independent generated objects."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/chapter1/refined/hall'
DATA = ROOT / 'data/chapter1/maps.json'


def main():
    maps = json.loads(DATA.read_text(encoding='utf-8'))
    modules = {e['id']:e for e in json.loads((ART/'module-manifest.json').read_text(encoding='utf-8'))['modules']}
    def prop(name,x,y,collision=None,layer='actors',occlusion='low',suffix=''):
        module = modules[name]
        size = module['size']
        anchor = module.get('anchor',[size[0]/2,size[1]])
        entry = {'nodeName':'Hall_'+name+('_'+suffix if suffix else ''),'module':name,
                 'asset':'res://'+module['path'],'position':[x,y],'size':size,'anchor':anchor,
                 'renderLayer':layer,'occlusionClass':occlusion}
        if collision: entry['collision'] = collision
        if occlusion == 'tall':
            entry.update(actorSafeArea=[x-anchor[0],y-anchor[1],size[0],size[1]],occupantPolicy={'mode':'fade','alpha':0.3})
        return entry

    plaza = maps['plaza']
    plaza.update(name='学院大会场展区',width=30,height=20,spawn=[720,842],cameraOffset=[0,-72],art_bundle='chapter1.hall-modules.v2')
    # Roof rim meets a substantial upright facade; its five bays share one baseline.
    props = [prop('dome',720,535,layer='background')]
    for index,x in enumerate([336,528,720,912,1104]):
        props.append(prop('wall' if x==720 else 'arch_window',x,700,
                          [240,24,960,676] if index==0 else None,'background',suffix=str(index)))
    props += [prop('portal',720,700,layer='background'),prop('banner',720,590,layer='background'),
              prop('gate_left',628,712,[615,698,26,14],occlusion='tall'),
              prop('gate_right',812,712,[799,698,26,14],occlusion='tall')]
    # Mentor stations flank the door approach. Flag positions use their actual pole foot.
    for index,(actor,x,flag,flag_x) in enumerate(zip(plaza['actors'],[432,624,816,1008],
                 ['flag_red','flag_gray','flag_teal','flag_silver'],[352,544,896,1088])):
        actor.update(position=[x,764],nodeName='Mentor_'+actor['id'],sceneHook='chapter_story.interact.'+actor['id'])
        props.append(prop(flag,flag_x,792,[flag_x-7,784,14,8],occlusion='tall',suffix=str(index)))
        desk = prop('trial_table',x,806,[x-38,790,76,16],suffix='registration_'+str(index))
        desk['purpose'] = 'mentor_registration'
        props.append(desk)
    for index,(x,trash_x) in enumerate([(144,240),(1296,1200)]):
        props += [prop('planter',x,736,[x-50,720,100,16],suffix=str(index)),
                  prop('bench',x,868,[x-65,853,130,15],suffix=str(index)),
                  prop('trash',trash_x,868,[trash_x-13,856,26,12],suffix=str(index))]
    for index,x in enumerate([580,860]):
        props.append(prop('streetlamp',x,908,[x-7,898,14,10],occlusion='tall',suffix=str(index)))
    for index,x in enumerate([432,1008]):
        props.append(prop('barrier',x,922,[x-66,908,132,14],suffix=str(index)))
    for index,x in enumerate([332,1108]):
        props.append(prop('cone',x,896,[x-8,890,16,6],suffix=str(index)))
    plaza['props'] = props
    plaza['terrain'] = {'base':[16,17],'zones':[
        {'rect':[0,0,5,20],'tiles':[18,19],'surface':'grass'},
        {'rect':[25,0,5,20],'tiles':[18,19],'surface':'grass'},
        {'rect':[5,15,20,2],'tiles':[20,21],'surface':'mentor_forecourt'},
        {'rect':[14,14,2,6],'tiles':[20,21],'surface':'door_approach'}]}
    plaza['walkableZones'] = [{'id':'door_approach','rect':[672,714,96,210]},
                             {'id':'mentor_approaches','rect':[400,806,640,46]}]
    plaza['entrances'] = [{'id':'hall_door','position':[720,716],'destinationUI':'chapter_map'},
                          {'id':'south_approach','position':[720,916],'destinationUI':'chapter_map'}]
    plaza['cameraBounds'] = [0,0,1440,960]

    auditorium = maps['auditorium']
    auditorium.update(width=30,height=18,spawn=[700,520],cameraOffset=[0,-42],art_bundle='chapter1.hall-modules.v2')
    props = []
    for index,x in enumerate([336,528,720,912,1104]):
        props.append(prop('wall' if x==720 else 'arch_window',x,340,
                          [240,24,960,316] if index==0 else None,'background',suffix=str(index)))
    props.append(prop('banner',720,298,layer='background'))
    for index,x in enumerate([240,1200]):
        props.append(prop('column',x,344,[x-14,330,28,14],occlusion='tall',suffix=str(index)))
    for name,x in [('podium_left',528),('podium_middle',720),('podium_right',912)]:
        collision = [432,448,216,12] if name=='podium_left' else [792,448,216,12] if name=='podium_right' else None
        props.append(prop(name,x,460,collision,'background'))
    props.append(prop('stairs',720,500,layer='ground'))
    for side,x in enumerate([228,1212]):
        for row,y in enumerate([580,736]):
            props.append(prop('stand',x,y,[x-138,y-14,276,14],'background',suffix=f'{side}_{row}'))
            for section in range(3):
                rail_x = x+(section-1)*96
                props.append(prop('railing',rail_x,y+8,[rail_x-46,y-2,92,10],suffix=f'{side}_{row}_{section}'))
    for index,x in enumerate([480,960]):
        props.append(prop('bench',x,674,[x-65,659,130,15],suffix=str(index)))
    props += [prop('planter',480,790,[430,774,100,16]),prop('planter',960,790,[910,774,100,16],suffix='right'),
              prop('trash',1080,790,[1067,778,26,12]),
              prop('gate_left',640,828,[627,814,26,14],occlusion='tall'),
              prop('gate_right',800,828,[787,814,26,14],occlusion='tall')]
    for actor in auditorium['actors']:
        if actor['name']=='测试仪':
            module = modules['trial_table']
            actor.update(asset='res://'+module['path'],size=module['size'],anchor=module['anchor'],module='trial_table',
                         position=[790,415],collision=[752,397,76,18],nodeName='TrialInstrument')
        elif actor['id']=='exam': actor.update(position=[650,415],nodeName='ExamOfficer')
        else: actor.update(position=[758,530],nodeName='WenRang')
        actor['sceneHook'] = 'chapter_story.interact.'+actor['id']
    auditorium['props'] = props
    auditorium['terrain'] = {'base':[16,17],'zones':[
        {'rect':[14,9,2,9],'tiles':[20,21],'surface':'central_aisle'},
        {'rect':[9,10,12,2],'tiles':[20,21],'surface':'testing_approach'}]}
    auditorium['walkableZones'] = [{'id':'exam_approaches','rect':[620,463,210,82]},
                                  {'id':'central_aisle','rect':[672,500,96,328]},
                                  {'id':'stage_stairs','rect':[662,458,116,48]}]
    auditorium['entrances'] = [{'id':'south_door','position':[720,824],'destinationUI':'chapter_map'}]
    auditorium['cameraBounds'] = [0,0,1440,864]
    DATA.write_text(json.dumps(maps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Actual-asset composites are inspection artifacts. Runtime never loads them.
    for room in ['plaza','auditorium']:
        data = maps[room]
        image = Image.new('RGBA',(data['width']*48,data['height']*48))
        for y in range(data['height']):
            for x in range(data['width']):
                sources = data['terrain']['base']
                for zone in data['terrain']['zones']:
                    zx,zy,zw,zh = zone['rect']
                    if zx<=x<zx+zw and zy<=y<zy+zh: sources = zone['tiles']
                tile = modules[f'tile_{sources[(x+y*3)%len(sources)]-16:02d}']
                image.paste(Image.open(ROOT/tile['path']),(x*48,y*48))
        entries = list(data['props'])+list(data['actors'])
        entries.append({'asset':'res://assets/chapter1/refined/lin_da/frames/frame_012.png','position':data['spawn'],
                        'size':[48,48],'renderLayer':'actors'})
        priority = {'background':0,'ground':1,'actors':2,'foreground':3}
        entries.sort(key=lambda e:(priority.get(e.get('renderLayer','actors'),2),
                                  e['position'][1] if e.get('renderLayer','actors')=='actors' else 0))
        for entry in entries:
            texture = Image.open(ROOT/entry['asset'].removeprefix('res://')).convert('RGBA')
            texture = texture.resize(tuple(entry['size']),Image.Resampling.NEAREST)
            anchor = entry.get('anchor',[texture.width/2,texture.height])
            x,y = entry['position']
            image.alpha_composite(texture,(round(x-anchor[0]),round(y-anchor[1])))
        image.convert('RGB').save(ART/f'{room}-preview.png')
    print('Hall exterior and testing auditorium rebuilt with actual doorway/stage/aisle geometry and independent objects')


if __name__ == '__main__': main()
