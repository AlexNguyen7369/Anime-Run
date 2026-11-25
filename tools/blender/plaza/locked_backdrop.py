"""What stands behind the locked Mythic on each approved altar (WORLD_REDESIGN_SPEC 4.2, docs/OWNER_QUESTIONS.md 31): rays from a player's eye
(at the spawn, 40, 25 and 18 studs off, eye 9.9 / 6.5 studs up; straight on and 25 degrees each side) through a disc of 0.42 of the model's size
round the model's spot, on to the locked altar of the approved draft (draft_altar.py concept_b, concept_a; unlit colours). Prints the share of
each surface and its contrast with the approved locked colour. A measuring tool only: there is no contrast limit (owner 2026-11-25,
question 31), and no test reads its output.
Headless: blender -b --factory-startup --python tools/blender/plaza/locked_backdrop.py
"""
import math
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import build_plaza as bp  # noqa: E402
import draft_altar as da  # noqa: E402
import piece_export as pe  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
def Y(h):
    c=[int(h[i:i+2],16)/255 for i in(1,3,5)];l=[x/12.92 if x<=.04045 else((x+.055)/1.055)**2.4 for x in c];return .2126*l[0]+.7152*l[1]+.0722*l[2]
def cr(a,b): x,y=sorted((Y(a),Y(b)));return (y+.05)/(x+.05)
for c,col in(("B","#4A425C"),("A","#847898")):  # the approved locked colours, (74, 66, 92) and (132, 120, 152)
    parts,spot,size,info=da.CONCEPTS[c](True); m=pe.joined("x",[p for p in parts if p.f]); t=BVHTree.FromPolygons(m.v,m.f); sp=Vector(spot); tot=Counter()
    for name,d,z in(("spawn",84,9.9),("40",40,6.5),("25",25,6.5),("18",18,6.5)):
        for ang in(0,-25,25):
            a=math.radians(ang);eye=Vector((math.sin(a)*d,-math.cos(a)*d,z));f=(sp-eye).normalized();r=f.cross(Vector((0,0,1))).normalized();u=r.cross(f);cnt=Counter()
            R=size*.42
            for i in range(-12,13):
                for j in range(-12,13):
                    if i*i+j*j>144: continue
                    p=sp+r*(i/12*R)+u*(j/12*R); dr=(p-eye).normalized(); o=p+dr*(size*.15)
                    h=t.ray_cast(o,dr,300)
                    if h[0] is None: cnt["sky"]+=1
                    else:
                        n=m.mats[m.fm[h[2]]]; cnt[n]+=1
            n=sum(cnt.values()); tot.update({k:v/n for k,v in cnt.items()})
            if ang==0: print("VIEW",c,name,[(k,round(100*v/n)) for k,v in cnt.most_common(9)])
    n=sum(tot.values()); print("ALL",c)
    for k,v in sorted(tot.items(),key=lambda q:-q[1]):
        if v/n<.005: continue
        h=bp.GLOW[k][0] if k in bp.GLOW else bp.PAL.get(k,""); print("   %-8s %4.1f%% %s contrast %s"%(k,100*v/n,h,"%.2f"%cr(col,h) if h else "-"))
