"""Layout guides only, never game art."""
from pathlib import Path
from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parents[1] / 'assets/chapter1/refined'
for name, rows, cols, w, h in [('structure',4,2,512,256),('props',3,3,384,384),('furniture',3,2,512,256),
                             ('facade_v2',2,2,384,288),('interior_v2',3,3,384,256),('props_v2',3,3,384,384),
                             ('stage_v2',1,3,384,320)]:
    image = Image.new('RGB', (cols*w, rows*h), '#ff00ff')
    draw = ImageDraw.Draw(image)
    for row in range(rows):
        for col in range(cols):
            x, y = col*w, row*h
            draw.rectangle((x+2,y+2,x+w-3,y+h-3), outline='#888888', width=2)
            draw.rectangle((x+24,y+24,x+w-25,y+h-25), outline='#00bbaa', width=2)
            draw.text((x+8,y+8), str(row*cols+col+1), fill='white')
    image.save(ART / f'hall_{name}_guide.png')
