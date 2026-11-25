# blender -b --factory-startup --python probe.py -- <repo copy> <scratch out> <json out> [module file] [--vans]
import sys; a=sys.argv[sys.argv.index("--")+1:]; R_,S,OUT=a[:3]; mod=next((x for x in a[3:] if not x.startswith("--")),None); VANS="--vans" in a
W=R_+"/tools/blender/world2"; sys.path.insert(0,W)
import bpy,json,hashlib,collections,numpy as np,build_track as b,kit,importlib.util,clearance,export_props as ep
from mathutils.bvhtree import BVHTree
assert b.ROOT.startswith(R_) and ep.THEMES.startswith(R_),(b.ROOT,ep.THEMES)
b.OUT=S+"/out"; b.BUILD=S+"/build"
src=open(mod or W+"/biomes/KaijuBase.py").read()
if VANS:
    new="vans = [(740, -40), (780, -40), (820, -40), (865, -40), (2375, -40), (2415, -40), (2455, -40), (2500, -40)]"
    old="vans = [(470, -40), (515, -40), (560, -40), (640, -40), (2520, -40), (2565, -40), (2610, -40), (2660, -40)]"
    assert src.count(new)==1 and src.count('fixed = ("Wall",')==1
    src=src.replace(new,old).replace('fixed = ("Wall",','fixed = ("SweeperVan", "Wall",')
mp=S+"/mod_%s.py"%hashlib.md5(OUT.encode()).hexdigest()[:8]; open(mp,"w").write(src)
sp=importlib.util.spec_from_file_location("m",mp); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
res={}
pre=[]
if hasattr(m,"cut_fill"):
    real=m.cut_fill
    def cf(k,label,boxes):
        bpy.context.view_layer.update()
        res["boxes"]=dict(sorted(collections.Counter(q[3] for q in boxes).items()))
        for ob in k.fill:
            bx=m.instance_box(ob); hits=collections.Counter()
            for bc,bR,bh,t,nm in boxes:
                if ep.obb_overlap(*bx,bc,bR,bh): hits["T%d %s"%(t,nm)]+=1
            pre.append([ob.data.name.split("KaijuBase_")[-1],round(ob.location.x,1),round(-ob.location.y,1),dict(hits)])
        real(k,label,boxes)
    m.cut_fill=cf
bpy.ops.wm.read_homefile(use_empty=True); tr=b.load_chain()[5]; b.setup(True); k=kit.Kit(tr,"KaijuBase"); k.road(tr["Palette"]); m.build(k); bpy.context.view_layer.update()
res["origins"]={n:[list(map(float,o)),float(y)] for n,(o,y) in ep.origins().items()}
res["pre"]=pre; res["FILL"]=[[n,round(x,1),round(z,1)] for x,z,n in getattr(m,"FILL",[])]
M=lambda o:[round(v,3) for r in o.matrix_world for v in r]
ms=[o for o in k.col.objects if o.type=="MESH" and o.data.name.startswith("W2_")]
res["inst"]=[[o.data.name.split("KaijuBase_")[-1],M(o)] for o in ms]
me=k.props["KaijuCorpse"].data; h=hashlib.sha256()
co=np.empty(len(me.vertices)*3,np.float32); me.vertices.foreach_get("co",co); h.update(co.tobytes())
for p in me.polygons: h.update(repr((tuple(p.vertices),p.material_index,p.use_smooth)).encode())
h.update(repr([tuple(round(x,6) for x in next(n for n in q.node_tree.nodes if n.type=="BSDF_PRINCIPLED").inputs["Base Color"].default_value) for q in me.materials]).encode())
res["hash"]=h.hexdigest(); me.calc_loop_triangles(); res["tris"]=len(me.loop_triangles)
json.dump(res,open(OUT,"w"))
if not hasattr(m,"instance_box"): sys.exit()
boxes=m.other_draft_boxes()
def hits(o):
    bx=m.instance_box(o); c=collections.Counter()
    for bc,bR,bh,t,nm in boxes:
        if ep.obb_overlap(*bx,bc,bR,bh): c[(t,nm)]+=1
    return c
def wt(o):
    t=ep.local_tris(o.data,(0,0,0)); A=np.array(o.matrix_world); q=np.stack((t[...,0],-t[...,2],t[...,1]),-1)@A[:3,:3].T+A[:3,3]; return np.stack((q[...,0],q[...,2],-q[...,1]),-1)
def bvh(T): return BVHTree.FromPolygons([tuple(v) for v in T.reshape(-1,3)],[(3*i,3*i+1,3*i+2) for i in range(len(T))])
K=[o for o in ms if o.data.name.endswith("_KaijuCorpse")]; res["kaiju"]=[]
for o in K:
    c=hits(o); t=collections.Counter()
    for (n,_),v in c.items(): t[n]+=v
    res["kaiju"].append([[round(v) for v in o.location],sum(t.values()),dict(sorted(t.items())),{"T%d %s"%q:v for q,v in sorted(c.items())}])
KB=[bvh(wt(o)) for o in K]; corr=clearance.corridors(b.load_chain().values()); w=np.array([(p.x,p.z) for p in k.wps])
res["vans"]=[]
for o in [o for o in ms if o.data.name.endswith("_SweeperVan")]:
    T=wt(o); B=bvh(T); d=np.hypot(w[:,0]-o.location.x,w[:,1]+o.location.y); bx=m.instance_box(o)
    res["vans"].append(dict(d=round(float(k._cum[int(d.argmin())])),M=M(o),kaiju_tris=[len(B.overlap(q)) for q in KB],kaiju_box=[bool(ep.obb_overlap(*bx,*m.instance_box(q))) for q in K],
      road_min=round(float(np.sqrt(((T.reshape(-1,3)[:,None,[0,2]]-w[None])**2).sum(2)).min()),1),corr=sorted(int(x) for x in clearance.intrudes(T,corr)),
      fill=[[q.data.name.split("KaijuBase_")[-1],round(q.location.x,1),round(-q.location.y,1)] for q in k.fill if B.overlap(bvh(wt(q)))],
      other_tracks={"T%d %s"%q:v for q,v in hits(o).items()}))
json.dump(res,open(OUT,"w")); print("PROBE OK",OUT)
