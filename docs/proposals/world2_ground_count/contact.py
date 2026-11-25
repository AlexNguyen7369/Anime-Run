"""Mesh contacts (triangle intersection, or one mesh inside the other) between built props of different tracks. -> pairs.pkl"""
import os,pickle,sys; S=os.path.dirname(os.path.abspath(__file__))
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils import Vector
part,parts=[int(x) for x in sys.argv[sys.argv.index("--")+1:]]
K=pickle.load(open(S+"/rows.pkl","rb")); M={n:dict(np.load(S+"/mesh/%d.npz"%n)) for n in range(1,11)}
lo=np.array([r["lo"] for r in K]);hi=np.array([r["hi"] for r in K]);t=np.array([r["t"] for r in K])
def W(i):
    r=K[i]; return (M[r["t"]][r["name"]].astype(float)*r["sc"])@r["R"].T+r["pos"]
def bvh(T): return BVHTree.FromPolygons(T.reshape(-1,3).tolist(),np.arange(len(T)*3).reshape(-1,3).tolist())
DIR=[Vector(v).normalized() for v in((.31,.9,.17),(-.7,.5,.41),(.2,.6,-.77))]
def inside(pt,b):
    c=0
    for d in DIR:
        h=b.ray_cast(Vector(pt),d)
        c+= h[0] is not None and h[1].dot(d)>0
    return c==3
out=[];cand=0
for i in range(part,len(K),parts):
    js=np.nonzero((np.arange(len(K))>i)&(t!=t[i])&np.all(lo<=hi[i],1)&np.all(hi>=lo[i],1))[0]
    if not len(js): continue
    A=W(i);al,ah=A.min(1),A.max(1);fullA=None
    for j in js:
        cand+=1; l=np.maximum(lo[i],lo[j]);h=np.minimum(hi[i],hi[j])
        B=W(j);bl,bh=B.min(1),B.max(1)
        a=A[np.all(al<=h,1)&np.all(ah>=l,1)];b=B[np.all(bl<=h,1)&np.all(bh>=l,1)]
        hit=0
        if len(a) and len(b) and bvh(a).overlap(bvh(b)): hit=1
        if not hit:
            if np.all(lo[i]>=lo[j]) and np.all(hi[i]<=hi[j]) and inside(A[0].mean(0),bvh(B)): hit=2
            elif np.all(lo[j]>=lo[i]) and np.all(hi[j]<=hi[i]):
                fullA=fullA or bvh(A)
                if inside(B[0].mean(0),fullA): hit=2
        if hit: out.append((i,int(j),hit))
pickle.dump(out,open(S+"/pairs%d.pkl"%part,"wb")); print("PART",part,"cand",cand,"hits",len(out))
