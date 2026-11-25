import sys,os; S=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(S,"tree/tools/blender/world2"))
import numpy as np, export_props as ep, build_track as bt, importlib, json
meta={}
for n in range(1,11):
    k=bt.run(n,render=False,fast=True); d={}
    for p in k.props:
        if p in ep.ROAD: continue
        me=k.props[p].data; me.calc_loop_triangles(); lo,hi=ep.bounds(me)
        d[ep.RENAME.get(p,p)]=ep.local_tris(me,((lo[0]+hi[0])/2,lo[1],(lo[2]+hi[2])/2)).astype("f4")
    np.savez(S+"/mesh/%d.npz"%n,**d)
    m=importlib.import_module("biomes."+k.biome)
    v=[]
    for f in (.06,.33,.62,.9):
        p,r,t=k.at(k.length*f); lane=np.array((p.x+r.x*10,p.y,p.z+r.z*10)); fw=np.array((t.x,0,t.z))
        v.append([f,list(lane-fw*14+(0,8,0)),list(lane+fw*70+(0,4,0))])
    meta[n]=dict(biome=k.biome,heroes=[ep.RENAME.get(h,h) for h in getattr(m,"MODEL_SHOTS",())],views=v)
json.dump(meta,open(S+"/mesh/meta.json","w"),default=float); print("DUMPDONE")
