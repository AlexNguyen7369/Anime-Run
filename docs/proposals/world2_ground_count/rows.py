"""Built rows after every in-game drop, whose ground they stand on, rule (a)/(b). -> rows.pkl, tables on stdout"""
import sys,os,re,json,pickle,math; S=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(S,"tree/tools/blender/world2"))
import numpy as np, export_props as ep, chain
meta=json.load(open(S+"/mesh/meta.json")); kept={};built={}
for l in open(S+"/h2.log"):
    if l.startswith("DUMP "):
        _,tag,n,b,ks=(l.rstrip("\n").split(" ")+[""])[:5]; (kept if tag=="kept" else built)[int(n)]={int(x) for x in ks.split(",") if x}
A,B,O=[],[],[]
for t in chain.build():
    w=np.array(t["Waypoints"])[:,[0,2]]; A.append(w[:-1]);B.append(w[1:]);O+= [t["Number"]]*(len(w)-1)
A=np.concatenate(A);D=np.concatenate(B)-A;O=np.array(O);D2=np.maximum((D**2).sum(1),1e-9)
def pertrack(q):
    """(m,10) distance to each track's centre line"""
    q=np.asarray(q,float);out=np.empty((len(q),10))
    for i in range(0,len(q),1500):
        p=q[i:i+1500,None]; t=np.clip(((p-A)*D).sum(2)/D2,0,1); d=((p-A-t[...,None]*D)**2).sum(2)
        for n in range(1,11): out[i:i+1500,n-1]=d[:,O==n].min(1)
    return np.sqrt(out)
def foot(T):
    """xz samples of triangles every <=10 studs (vertices included), deduped on a 2-stud grid"""
    P=T[:,:,[0,2]]; L=max(1,0); res=[P.reshape(-1,2)]
    e=np.max([np.linalg.norm(P[:,i]-P[:,(i+1)%3],axis=1) for i in range(3)],0); ns=np.ceil(e/10).astype(int)
    for k in np.unique(ns):
        if k<2: continue
        uv=np.array([(i/k,j/k) for i in range(k+1) for j in range(k+1-i)]); Q=P[ns==k]
        res.append((Q[:,None,0]+uv[None,:,:1]*(Q[:,None,1]-Q[:,None,0])+uv[None,:,1:]*(Q[:,None,2]-Q[:,None,0])).reshape(-1,2))
    r=np.concatenate(res); _,ix=np.unique(np.round(r/2).astype(int),axis=0,return_index=True); return r[ix]
EPS=.05; rows=[]; ties=0
for n in range(1,11):
    b=meta[str(n)]["biome"]; hero=set(meta[str(n)]["heroes"]); origin,yaw=ep.origins()[n]
    src=open(ep.THEMES+"/"+b+"Draft.luau").read(); ms=np.load(S+"/mesh/%d.npz"%n)
    body=src[src.index("\tPlaced = {"):src.index("\tHeroes = ")]; rr=list(re.finditer(r'\{\s*"(\w+)",([^{}]*?)\}',body)); done=set(); tot=0
    for i,m in enumerate(rr,1):
        g=re.search(r"Group = (\d+)",m.group(2)); wh=re.search(r"Whole = v\(([^)]*)\)",m.group(2))
        if g:
            if g.group(1) in done: continue
            done.add(g.group(1))
        tot+=1; inb=i in built[n]; ink=i in kept[n]
        name=re.sub(r"_p\d+$","",m.group(1)) if g else m.group(1)
        raw=re.sub(r"Whole = v\([^)]*\)|Group = \d+","",m.group(2)); st=re.search(r"v\(([^)]*)\)",raw); nums=[float(x) for x in re.sub(r"v\([^)]*\)","",raw).split(",") if x.strip()]
        # X Y Z Yaw Scale RX RZ [Stretch]
        sc=np.array([float(x) for x in st.group(1).split(",")]) if st else np.array([nums[4]]*3)
        rx,rz=(nums[5],nums[6]) if len(nums)>6 else (0,0)
        pos=np.array([float(x) for x in wh.group(1).split(",")]) if wh else np.array(nums[:3])
        R=np.array(ep.yaw_rot(yaw))@np.array(ep.from_euler_yxz(rx,nums[3],rz))
        rows.append(dict(t=n,i=i,name=name,hero=name in hero,built=inb,kept=ink,pos=np.array(ep.to_world(origin,yaw,pos)),R=R,sc=sc))
    print("ROWS",n,b,"draft rows",len(rr),"whole",tot,"built",sum(r["built"] for r in rows if r["t"]==n),"kept",sum(r["kept"] for r in rows if r["t"]==n))
K=[r for r in rows if r["kept"]]
d=pertrack([r["pos"][[0,2]] for r in K])
cache={}
for r,dd in zip(K,d):
    own=dd[r["t"]-1]; r["a"]=bool(own>dd.min()+EPS); r["owner"]=int(dd.argmin())+1 if r["a"] else r["t"]
    r["tie"]=int((dd<dd.min()+EPS).sum()>1)
    T=cache.setdefault(r["t"],np.load(S+"/mesh/%d.npz"%r["t"]))[r["name"]].astype(float)
    W=(T*r["sc"])@r["R"].T+r["pos"]; r["lo"],r["hi"]=W.reshape(-1,3).min(0),W.reshape(-1,3).max(0)
    f=foot(W); fd=pertrack(f); ow=fd[:,r["t"]-1]; bad=ow>fd.min(1)+EPS
    r["b"]=bool(bad.any()); r["share"]=float(bad.mean())
    r["bown"]=sorted({int(x)+1 for x in fd[bad].argmin(1)}) if bad.any() else []
    r["plaza_a"]=bool(math.hypot(r["pos"][0],r["pos"][2])<=ep.PLAZA_ZONE); r["plaza_b"]=bool((np.hypot(f[:,0],f[:,1])<=ep.PLAZA_ZONE).any())
pickle.dump(K,open(S+"/rows.pkl","wb"))
from collections import Counter,defaultdict
print("\nTRACK built a(heroes) b(heroes) b>=50%share | plaza a,b | tie | owners of a")
for n in range(1,11):
    k=[r for r in K if r["t"]==n];a=[r for r in k if r["a"]];b=[r for r in k if r["b"]]
    print(n,meta[str(n)]["biome"],len(k),len(a),sum(r["hero"] for r in a),len(b),sum(r["hero"] for r in b),sum(r["share"]>=.5 for r in k),"|",sum(r["plaza_a"] for r in k),sum(r["plaza_b"] for r in k),sum(r["plaza_a"] and r["a"] for r in k),"|",sum(r["tie"] for r in k),"|",dict(sorted(Counter(r["owner"] for r in a).items())))
print("ALL",len(K),sum(r["a"] for r in K),sum(r["b"] for r in K),"plaza",sum(r["plaza_a"] for r in K),sum(r["plaza_b"] for r in K))
for n in range(1,11):
    print("TYPES",n,"prop built/a/b/plazaA [owners a]")
    by=defaultdict(list)
    for r in K:
        if r["t"]==n: by[r["name"]].append(r)
    for nm,v in sorted(by.items(),key=lambda q:-sum(r["b"] for r in q[1])):
        print("  %s%s %d/%d/%d/%d %s"%(nm,"*" if v[0]["hero"] else "",len(v),sum(r["a"] for r in v),sum(r["b"] for r in v),sum(r["plaza_a"] for r in v),dict(sorted(Counter(r["owner"] for r in v if r["a"]).items()))))
