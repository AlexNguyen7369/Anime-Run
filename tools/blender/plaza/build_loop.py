"""The sky loop with its posts at the fuller layout's places (build_plaza.LOOP_POSTS): SkyLoop. Its row's Posts are
measured on the mesh (the black feet, degrees in the world (x, z) plane from +x), without the arch's two at the path.
Headless: blender -b --factory-startup --python tools/blender/plaza/build_loop.py -- [--check]
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as bp  # noqa: E402
import piece_export  # noqa: E402

if __name__ == "__main__":
	m = bp.sky_loop(bp.LOOP_POSTS)
	feet = {}
	for f, fm in zip(m.f, m.fm):
		if m.mats[fm] == "black" and len(f) == 8:  # a foot's top and bottom
			c = sum((m.v[k] for k in f), m.v[f[0]] * 0) / len(f)
			feet[round(math.degrees(math.atan2(-c.y, c.x)) % 360, 1)] = math.hypot(c.x, c.y)
	arch = [math.degrees(math.atan2(z, x)) % 360 for x, z in (bp.along(62, s * 10.5) for s in (-1, 1))]
	posts = sorted(round(a) for a, r in feet.items() if abs(r - 62) < 0.1 and all(abs(a - b) > 1 for b in arch))
	assert posts == sorted(bp.LOOP_POSTS), (posts, feet)
	out = piece_export.run("loop", [("SkyLoop", m)])
	out["SkyLoop"]["Posts"] = posts
	with open(os.path.join(piece_export.OUT, "loop.json"), "w") as f:
		json.dump(out, f, indent=1)
	print("POSTS", posts)
