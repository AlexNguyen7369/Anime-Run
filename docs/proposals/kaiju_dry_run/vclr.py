import sys; a=sys.argv[sys.argv.index("--")+1:]; R_,S,MOD=a[:3]
sys.path.insert(0,R_+"/tools/blender/world2")
import importlib,importlib.util,biomes,build_track as b
b.OUT=S+"/out"; b.BUILD=S+"/build"; sp=importlib.util.spec_from_file_location("biomes.KaijuBase",MOD); m=importlib.util.module_from_spec(sp)
import export_props as ep; ep.record(); sys.modules["biomes.KaijuBase"]=m; sp.loader.exec_module(m); biomes.KaijuBase=m; importlib.reload=lambda x:x
import clearance; c,f=clearance.check(5); print("VCLR",c,"failures",len(f),[(q[0],round(q[4],1)) for q in f])
import kaiju_reference as r; k=b.run(5,fast=True,render=False); r.fit(k)
