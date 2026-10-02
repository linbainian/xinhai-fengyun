"""Assemble editable gate/ceremony maps and authored cutscene routes from existing art."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT/'data/chapter1'
NAMES = ['wen_rang','su_wanyan','liu','shen','wen','tang']


def move(actors,seconds,camera,**extra):
    return {'kind':'move','actors':[{'id':name,'path':path,'face':face} for name,path,face in actors],
            'seconds':seconds,'camera':camera,**extra}


def fade(alpha): return {'kind':'fade','alpha':alpha,'seconds':0.28}


def scene(room,positions,camera,caption):
    return {'kind':'scene','room':room,'positions':positions,'camera':camera,'caption':caption}


def main():
    maps = json.loads((DATA/'maps.json').read_text(encoding='utf-8'))
    modules = {e['id']:e for e in json.loads((ROOT/'assets/chapter1/refined/hall/module-manifest.json').read_text(encoding='utf-8'))['modules']}
    def prop(name,x,y,collision=None):
        module = modules[name]
        data = {'nodeName':'Gate_'+name+str(x),'asset':'res://'+module['path'],'size':module['size'],
                'anchor':module['anchor'],'position':[x,y],'module':name,'renderLayer':'background'}
        if collision: data['collision'] = collision
        return data
    gate = {'name':'学院校门','width':30,'height':18,'floor':2,'spawn':[640,820],'cameraOffset':[0,-40],
            'terrain':{'base':[16,17],'zones':[{'rect':[0,0,5,18],'tiles':[18,19]},
                {'rect':[25,0,5,18],'tiles':[18,19]},{'rect':[13,11,4,7],'tiles':[20,21]}]},
            'props':[],'actors':[{'id':'wen_rang','name':'温让','nodeName':'WenRang',
                'character':'wen_rang','asset':'res://assets/chapter1/refined/npcs/frames/frame_000.png',
                'position':[816,832],'size':[48,48]}]}
    for x in [336,528,912,1104]: gate['props'].append(prop('arch_window',x,560))
    gate['props'] += [prop('portal',720,560),prop('column',240,564,[226,24,432,536]),
                     prop('column',1200,564,[804,24,410,536]),prop('gate_left',640,596),prop('gate_right',800,596)]
    for x in [380,1060]:
        gate['props'] += [prop('planter',x,668,[x-50,652,100,16]),prop('streetlamp',x,804,[x-7,794,14,10])]
    gate['entrances'] = [{'id':'academy_gate','position':[720,610],'destination':'auditorium'}]
    gate['walkableZones'] = [{'id':'gate_approach','rect':[672,570,144,258]}]
    maps['gate'] = gate
    ceremony = copy.deepcopy(maps['auditorium'])
    ceremony.update(name='学院大会场·主席台',spawn=[700,760],cameraOffset=[0,-42],actors=[])
    for index,name in enumerate(['liu','shen','wen','tang']):
        ceremony['actors'].append({'id':name,'name':['柳无眠','沈听澜','温若水','唐半夏'][index],
            'nodeName':'Ceremony_'+name,'asset':f'res://assets/chapter1/refined/npcs/frames/frame_{index+2:03d}.png',
            'character':name,'position':[1300,540],'size':[48,48],'hidden':True})
    maps['assembly_stage'] = ceremony
    for data in maps.values():
        for actor in data['actors']:
            for index,name in enumerate(NAMES):
                if actor['asset'].endswith(f'refined/npcs/frames/frame_{index:03d}.png'): actor['character'] = name
    cutscenes = {}
    cutscenes['gate_arrival'] = [move([('player',[[700,720]],[1,0]),('wen_rang',[[752,736]],[-1,0])],
        1.55,[724,590],caption='新海异能学院 · 校门'),{'kind':'wait','seconds':0.25}]
    cutscenes['enter_auditorium'] = [move([('player',[[700,610]],[0,-1]),('wen_rang',[[752,626]],[0,-1])],1.15,[720,620],caption='报到 · 温让同行'),fade(1),
        scene('auditorium',{'player':[720,800],'wen_rang':[666,816]},[720,680],'入学检测 · 报到礼堂'),fade(0),
        move([('player',[[720,610],[700,520]],[0,-1]),('wen_rang',[[666,610],[752,536]],[0,-1])],2.2,[720,480])]
    steps = [move([('player',[[720,520],[720,800]],[0,1]),('wen_rang',[[776,600],[776,816]],[0,1])],2.35,[744,680],caption='检测结束 · 前往大会场'),fade(1),
        scene('assembly_stage',{'player':[700,760],'wen_rang':[752,776]},[720,640],'学院大会场 · 导师见面'),fade(0),
        move([('player',[[700,580]],[0,-1]),('wen_rang',[[752,594]],[0,-1])],1.35,[720,474])]
    for name,x,title,role in [('liu',516,'柳无眠','摸鱼会 · 实战导师'),('shen',648,'沈听澜','幻影阁 · 精神系讲师'),
                            ('wen',792,'温若水','论道斋 · 理论系主任'),('tang',924,'唐半夏','百草堂 · 校医')]:
        steps.append(move([(name,[[1010,540],[720,540],[720,500],[720,415],[x,415]],[0,1])],3.2,[int((x+720)/2),440],name=title,role=role,character=name))
        steps.append({'kind':'wait','seconds':0.45,'camera':[720,440]})
    steps.append({'kind':'wait','seconds':0.45,'camera':[720,454],'caption':'四山头 · 拜山任务开放'})
    cutscenes['test_to_assembly'] = steps
    cutscenes['assembly_to_exhibits'] = [move([('player',[[700,790]],[0,1]),('wen_rang',[[752,806]],[0,1])],1.65,[720,684],caption='大会场 · 前往导师展区'),fade(1),
        scene('plaza',{'player':[720,842],'wen_rang':[666,850]},[720,782],'大会场 · 导师展区'),fade(0),
        {'kind':'wait','seconds':0.4,'camera':[720,770]}]
    cutscenes['su_arrival'] = [move([('player',[[720,842]],[1,0]),('wen_rang',[[666,850]],[1,0])],1.6,[824,806],caption='拜师登记完成'),
        move([('SuWanyanVisitor',[[880,830],[768,838]],[-1,0])],2.9,[748,808],name='苏挽颜',role='隔壁家长大的青梅邻居 · 大二学姐',character='su_wanyan',caption='苏挽颜 · 来访'),
        {'kind':'face','actors':{'player':[1,0],'wen_rang':[1,0],'SuWanyanVisitor':[-1,0]}},
        {'kind':'wait','seconds':0.35,'camera':[736,820]}]
    (DATA/'maps.json').write_text(json.dumps(maps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (DATA/'cutscenes.json').write_text(json.dumps(cutscenes,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Editable academy gate and ceremony stage; five cinematic sequences with authored routes')


if __name__ == '__main__': main()
