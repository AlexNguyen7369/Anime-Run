"""Runs the committed planner unmodified (tree/ = 5747dda6) and logs, per find_spot call, why the approved placement fails and the nearest legal spot
(find_spot with ctx props emptied: every count 0, so sorted by distance alone). blender -b --factory-startup --python plan_wrap.py -- <n>"""
import sys, os, json, math
S=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(S,"tree/tools/blender/world2"))
import export_props as ep
n=int(sys.argv[sys.argv.index("--")+1]); orig=ep.find_spot; out=[]
def wrap(local,origin,yaw,pos,e,sc,ctx,exempt,why=None):
    import numpy as np
    w0={}; ok0=ep.rules_ok(local,origin,yaw,pos,e,sc,ctx,exempt,w0)
    w0z={}; nz=dict(ctx,zone=None); okz=ep.rules_ok(local,origin,yaw,pos,e,sc,nz,exempt,w0z)
    w={}; r=orig(local,origin,yaw,pos,e,sc,ctx,exempt,w)
    near=orig(local,origin,yaw,pos,e,sc,dict(ctx,props=[]),exempt) if r else None
    cnt=lambda p: ep.props_overlap(local,origin,yaw,p,e,sc,ctx) if p else None
    d=dict(pos=pos,e=e,sc=sc,fails=w0,fails_without_zone=w0z,planner=r,grid_fails=w,nearest=near and near[0],
        planner_studs=r and math.dist(pos,r[0]),nearest_studs=near and math.dist(pos,near[0]),
        overlap_from=cnt(pos),overlap_planner=cnt(r and r[0]),overlap_nearest=cnt(near and near[0]),
        pos_w=ep.to_world(origin,yaw,pos),nearest_w=near and ep.to_world(origin,yaw,near[0]),ntris=len(local))
    print("SPOT",n,json.dumps(d),flush=True); out.append(d); return r
ep.find_spot=wrap
ep.export(n,glb=False,plan=True,zone=2)
json.dump(out,open(S+"/plan/spots%d.json"%n,"w"))
print("PLANDONE",n,flush=True)
