# Contact sheet of drafts: python cast_sheet.py <out.png> <id> ... (needs Pillow; run from the repo root).
import sys
from PIL import Image, ImageDraw
out, *ids = sys.argv[1:]
W=260; cols=2; n=len(ids); rows=-(-n//cols)
im=Image.new("RGB",(W*4*cols,(W+18)*rows),"#22242e"); d=ImageDraw.Draw(im)
for i,c in enumerate(ids):
    x0=(i%cols)*W*4; y0=(i//cols)*(W+18)
    d.text((x0+6,y0+3),c,fill="white")
    for j,p in enumerate(("portrait","head","review/front","review/three_quarter")):
        try:
            a=Image.open(f"assets/characters_avatar/{c}/{p}.png").convert("RGBA"); a.thumbnail((W,W))
            im.paste(a,(x0+j*W+(W-a.width)//2,y0+18+(W-a.height)//2),a)
        except FileNotFoundError: d.text((x0+j*W+60,y0+120),"MISSING",fill="red")
im.save(out)
