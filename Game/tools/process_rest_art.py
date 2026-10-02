"""Crop/nearest/palette/feet alignment of the generated seated pose."""
from pathlib import Path
from PIL import Image
from process_hall_art import key_hall

ART = Path(__file__).resolve().parents[1] / 'assets/chapter1/refined'
image = key_hall(Image.open(ART / 'lin_da_rest_raw.png'))
image = image.crop(image.getbbox())
image = image.resize((round(image.width*62/image.height),62),Image.Resampling.NEAREST)
alpha = image.getchannel('A').point(lambda value: 255 if value>=128 else 0)
image = image.convert('RGB').quantize(colors=32,dither=Image.Dither.NONE).convert('RGBA')
image.putalpha(alpha)
feet = Image.open(ART / 'lin_da/frames/frame_000.png').getbbox()[3]
canvas = Image.new('RGBA',(96,96))
canvas.paste(image,((96-image.width)//2,feet-image.height))
canvas.save(ART / 'lin_da/rest.png')
print('Generated rest pose: 96px source, matching foot anchor, shorter seated body, hard alpha')
