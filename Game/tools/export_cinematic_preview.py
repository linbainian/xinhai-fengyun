"""Export GIF previews from actual Godot GPU captures, preserving nearest-sampled pixels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ORDER = ['gate_arrival','enter_auditorium','test_to_assembly','assembly_to_exhibits','su_arrival']


def main():
    report = json.loads((ROOT/'.dev/chapter1-cinematics-report.json').read_text(encoding='utf-8'))
    assert report['passed']
    data = json.loads((ROOT/'data/chapter1/cutscenes.json').read_text(encoding='utf-8'))
    output = ROOT/'docs/previews'
    output.mkdir(parents=True,exist_ok=True)
    montage, timings = [], []
    captured = {name:[Image.open(ROOT/path.removeprefix('res://')).convert('RGB')
                     for path in report['movie_frames'][name]] for name in ORDER}
    samples = [frame for name in ORDER for frame in captured[name][::12]]
    atlas = Image.new('RGB',(samples[0].width,samples[0].height*len(samples)))
    for index,frame in enumerate(samples): atlas.paste(frame,(0,index*frame.height))
    palette = atlas.quantize(colors=160,dither=Image.Dither.NONE)
    for name in ORDER:
        frames = [frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in captured[name]]
        duration = max(50,round(sum(step.get('seconds',0) for step in data[name])*1000/len(frames)))
        frames[0].save(output/f'{name}.gif',save_all=True,append_images=frames[1:],loop=0,
                       duration=duration,optimize=False,disposal=1)
        montage.extend(frames)
        timings.extend([duration]*len(frames))
    montage[0].save(output/'chapter1-cinematics.gif',save_all=True,append_images=montage[1:],loop=0,
                    duration=timings,optimize=False,disposal=1)
    (output/'cinematics-preview.json').write_text(json.dumps({
        'source':'Actual Godot GPU framebuffer captures; no generated preview backgrounds',
        'report':'.dev/chapter1-cinematics-report.json','frames':len(montage),'order':ORDER,
        'seconds':sum(timings)/1000,'size':list(montage[0].size)},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Actual runtime montage: {len(montage)} frames, {sum(timings)/1000:.2f}s; {output}')


if __name__ == '__main__': main()
