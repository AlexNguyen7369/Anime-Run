import sys; a=sys.argv[sys.argv.index("--")+1:]
sys.path.insert(0,a[0]+"/tools/blender/world2")
import build_track as b; b.OUT=a[1]+"/out"; b.BUILD=a[1]+"/build"
import clearance; sys.argv=["x","--","5"]; clearance.main()
