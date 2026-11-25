import os,pickle,json,math; S=os.path.dirname(os.path.abspath(__file__))
import numpy as np
from collections import Counter
K=pickle.load(open(S+"/rows.pkl","rb")); meta=json.load(open(S+"/mesh/meta.json"))
P=[p for q in range(4) for p in pickle.load(open(S+"/pairs%d.pkl"%q,"rb"))]
print("pairs",len(P),"surface",sum(p[2]==1 for p in P),"enclosed",sum(p[2]==2 for p in P))
def cont(alive):
    L=[p for p in P if alive[p[0]] and alive[p[1]]]; s={x for p in L for x in p[:2]}
    return L,s
base=np.ones(len(K),bool); ra=np.array([not r["a"] for r in K]); rb=np.array([not r["b"] for r in K])
H=np.array([r["hero"] for r in K])
V={"before":base,"a all":ra,"a keep heroes":ra|H,"b all":rb,"b keep heroes":rb|H,"b>=50%":np.array([r["share"]<.5 for r in K])}
print("CONTACT props touching another track's prop, per track (pairs)")
for nm,al in V.items():
    L,s=cont(al); print(nm,"built",int(al.sum()),"pairs",len(L),[ "T%d %d/%d"%(n,sum(K[i]["t"]==n for i in s),sum(al[i] and K[i]["t"]==n for i in range(len(K)))) for n in range(1,11)])
for n in (1,6):
    for nm in ("before","a all","b all"):
        L,_=cont(V[nm]); c=Counter()
        for i,j,_h in L:
            if n in(K[i]["t"],K[j]["t"]):
                x,y=(i,j) if K[i]["t"]==n else (j,i); c[(K[x]["name"],"T%d %s"%(K[y]["t"],K[y]["name"]))]+=1
        print("T%d %s pairs %d"%(n,nm,sum(c.values())),c.most_common(9))
print("COST share of own props; heroes; run views: own in frame <=1024 studs, lost a, lost b, lost angular weight a/b %; other tracks' props in frame, lost a")
lo=np.array([r["lo"] for r in K]);hi=np.array([r["hi"] for r in K]);c=(lo+hi)/2;diag=np.linalg.norm(hi-lo,axis=1);t=np.array([r["t"] for r in K])
tv=math.tan(math.radians(35))
def seen(eye,look):
    F=(look-eye)/np.linalg.norm(look-eye);r=np.cross(F,(0,1,0));r/=np.linalg.norm(r);u=np.cross(r,F)
    o=np.zeros(len(K),bool)
    for f in [(0,0,0)]+[(a,b,d) for a in(-1,1) for b in(-1,1) for d in(-1,1)]:
        v=c+(hi-lo)/2*np.array(f)-eye;z=v@F;ok=z>1;zz=np.where(ok,z,1)
        o|=ok&(np.abs(v@r/zz)<=tv*16/9)&(np.abs(v@u/zz)<=tv)
    return o&(np.linalg.norm(c-eye,axis=1)<=1024)
for n in range(1,11):
    own=t==n; print("T%d %s lost a %.1f%% (%d) b %.1f%% (%d)"%(n,meta[str(n)]["biome"],100*(~ra[own]).mean(),(~ra[own]).sum(),100*(~rb[own]).mean(),(~rb[own]).sum()))
    for f,e,l in meta[str(n)]["views"]:
        e,l=np.array(e),np.array(l);s=seen(e,l);q=s&own;w=(diag/np.maximum(np.linalg.norm(c-e,axis=1),20))**2
        pc=lambda m:100*w[q&m].sum()/max(w[q].sum(),1e-9)
        print("   %.2f own %d lost a %d (w %.0f%%) b %d (w %.0f%%) | others %d lost a %d b %d"%(f,q.sum(),(q&~ra).sum(),pc(~ra),(q&~rb).sum(),pc(~rb),(s&~own).sum(),(s&~own&~ra).sum(),(s&~own&~rb).sum()))
print("HEROES built on other ground (a):")
for r in K:
    if r["hero"] and r["a"] and r["name"] not in("FleshWall","Hand"): print("  T%d %s owner T%d at %s share %.2f"%(r["t"],r["name"],r["owner"],r["pos"].round(),r["share"]))
# heroes reached only by few built rows: hero types left with zero under each rule
for nm in("a all","b all"):
    for n in range(1,11):
        for h in meta[str(n)]["heroes"]:
            k=[i for i in range(len(K)) if t[i]==n and K[i]["name"]==h]
            if k and not any(V[nm][i] for i in k): print("  GONE under",nm,"T%d %s (%d built)"%(n,h,len(k)))
for n in range(1,11):
    z=[r["t"] for r in K if r["plaza_a"]]
print("plaza rows by track",Counter(z))
