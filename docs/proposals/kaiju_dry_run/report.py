import json,sys,collections,os
D=sys.argv[1]
for N in sys.argv[2:]:
    O=D+"/out-"+N; L=lambda f:json.load(open(O+"/"+f+".json")); c,v,p,r=L("cur"),L("vans"),L("pre"),L("r5")
    print("=====",N,"hash",c["hash"],"same as r5",c["hash"]==r["hash"],"tris",c["tris"])
    P=lambda d:sorted(m for n,m in d["inst"] if n=="KaijuCorpse"); print("corpse placements same as r5",P(c)==P(r))
    C=lambda d:collections.Counter((n,tuple(m)) for n,m in d["inst"]); g=lambda x:dict(collections.Counter(k[0] for k,n in x.items() for _ in range(n)))
    print("vs r5 gone",g(C(r)-C(c)),"added",g(C(c)-C(r)),"| vs pre-rework gone",g(C(p)-C(c)),"added",g(C(c)-C(p)))
    print("boxes",c["boxes"],"fill before",len(c["pre"]),"kept",len(c["FILL"]),dict(collections.Counter(f[0] for f in c["FILL"]))); print(sorted(c["FILL"])==sorted(v["FILL"]),"= same fill in the van build")
    for f in sorted(c["FILL"]): print("  keep",f)
    for k in c["kaiju"]: print(" KAIJU",k)
    pv=[m for n,m in p["inst"] if n=="SweeperVan"]
    for x in v["vans"]:
        print(" VAN",x["d"],"dev",round(min(max(abs(a-b) for a,b in zip(x["M"],y)) for y in pv),4),{k:q for k,q in x.items() if k not in("d","M")})
    for x in c["vans"]: print(" CURVAN",x["d"],x["kaiju_tris"],x["fill"],x["other_tracks"])
