"""Blender DRAFTS (renders only): market set B with roster characters as its merchants (owner 2026-11-25; WORLD_REDESIGN_SPEC 4.2).

Nothing here ships: no export, no upload, no game data. draft_markets.py, build_plaza.py, plaza_w2.py and build_avatar.py are
imported, never edited; a character is built from its own repo source by build_avatar.placed() exactly as the export does.
A merchant is only placed, scaled whole and its limbs turned about their joints, as RunnerVisual does (Hero, Pose).
Stalls are set B's own geometry. Changed, and only here: the Market sign, a step under each keeper behind a counter, the
draft's own figures (with the goods they held), and the Index keeper's spot (clear of the lectern).
Headless: blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_merchants.py -- [W1 W2] [shot-prefix ...] [--tris] [--alts]
Writes assets/plaza_draft2/markets_roster/<W1|W2>/<piece>_<shot>.jpg (World 1 golden hour, World 2 dusk), and alternates.jpg.
"""

import math
import os
import sys

sys.dont_write_bytecode = True
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import avatar_base  # noqa: E402
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402
import draft_markets as dm  # noqa: E402

bp, pw, K = dm.bp, dm.pw, dm.K
OUT = os.path.join(bp.ROOT, "assets", "plaza_draft2", "markets_roster")
CENTRE = {n: Vector(c) for n, (c, _) in avatar_merge.GROUPS.items()}
BASE = {"Shop": 0.7, "Potions": 0.7, "Market": 0.6}  # the floor the step stands on

# Stall -> character id, where its feet are (stall frame), yaw, whole-rig scale, limb turns {part: XYZ degrees about its joint}.
# Scale 1 is the built rig: head top 5.3, a player's avatar is 5.5 (runners in game are 0.8 of it). All proposed.
CAST = {
	"Shop": ("sea_navigator", (0, -0.55, 1.95), 0, 1.0, {"RightArm": (-62, 14, 0), "LeftArm": (-30, -10, 0)}),
	"Potions": ("leaf_medic", (0, -0.6, 1.95), 0, 1.0, {"RightArm": (-38, 12, 0), "LeftArm": (-58, -12, 0)}),
	"Market": ("ds_flame", (0, -1.2, 1.68), 0, 1.0, {"RightArm": (-40, 34, 0), "LeftArm": (-40, -34, 0)}),
	"Index": ("fr_mage", (-1.6, -2.9, 0.75), -6, 1.0, {"LeftArm": (-26, -8, 0)}),
	"Sensei": ("leaf_copycat", (0, -0.5, 0.65), 0, 0.75, {"RightArm": (10, 8, 0), "LeftArm": (10, -8, 0)}),
}
ALTS = {
	"Shop": ("saw_blood", "sea_cook"), "Potions": ("soul_healer", "fr_staff"), "Market": ("dan_idol", "jk_nails"),
	"Index": ("db_scholar", "punch_cyborg"), "Sensei": ("db_green", "jk_strongest"),
}
_built = {}  # id -> {part: mesh}
_data = build_avatar.load_data()


def load(ids):
	"""Builds each character from its source, keeps the merged meshes. Call before anything else is in the scene."""
	avatar_base.clear_mats()
	for cid in ids:
		root, tris = build_avatar.placed(cid, _data[cid], keep=list(bpy.data.objects))
		assert tris <= build_avatar.TRI_BUDGET
		_built[cid] = {}
		for o in list(root.children):
			name = next(n for n in CENTRE if o.name.startswith(n))
			_built[cid][name] = o.data
			o.data.use_fake_user = True
			bpy.data.objects.remove(o)
		bpy.data.objects.remove(root)


def stand(col, name, cid, matrix, pose):
	"""The character at matrix (feet at its origin, front -Y), limbs turned about their tops, the head about its bottom."""
	obs = []
	for part, me in _built[cid].items():
		o = bpy.data.objects.new(f"{name}_{part}", me)
		joint = Vector((0, 0, -0.65 if part == "Head" else 1.0))
		r = Matrix.Identity(4)
		if part in pose:
			r = Matrix.Rotation(math.radians(pose[part][1]), 4, "Y") @ Matrix.Rotation(math.radians(pose[part][0]), 4, "X")
			r = Matrix.Translation(joint) @ r @ Matrix.Translation(-joint)
		o.matrix_world = matrix @ Matrix.Translation(CENTRE[part]) @ r
		col.objects.link(o)
		obs.append(o)
	return obs


def real(me):
	"""The mesh's faces without the rig's 2 tiny corner triangles."""
	return [p for p in me.polygons if p.area > 5e-5]


def body(obs):
	vs, fs = [], []
	for o in obs:
		for p in real(o.data):
			fs.append([len(vs) + i for i in range(len(p.vertices))])
			vs += [o.matrix_world @ o.data.vertices[i].co for i in p.vertices]
	return vs, fs


def collide(name, obs, m):
	"""Reports where the figure cuts its stall, in the stall's frame."""
	bv, bf = body(obs)
	inv = m.matrix.inverted()
	lv = [inv @ v for v in bv]
	tree = BVHTree.FromPolygons(bv, bf)
	stall = BVHTree.FromPolygons([m.matrix @ v for v in m.v], m.f)
	by = {}
	for a, b in tree.overlap(stall):
		c = sum((lv[i] for i in bf[a]), Vector()) / len(bf[a])
		mt = m.mats[m.fm[b]]
		if c.z > 0.05 + min(v.z for v in lv):  # the soles stand on their floor
			by.setdefault(mt, []).append(c)
	lo = [min(v[i] for v in lv) for i in range(3)]
	hi = [max(v[i] for v in lv) for i in range(3)]
	tris = sum(len(o.data.polygons) for o in obs)
	print(f"  {name}: {tris} tris, {hi[0] - lo[0]:.1f} x {hi[1] - lo[1]:.1f} x {hi[2] - lo[2]:.1f}, top {hi[2]:.2f} over the floor")
	print(f"CLIP {name}:", "none" if not by else "; ".join(f"{k} x{len(v)} near {tuple(round(q, 1) for q in v[0])}" for k, v in by.items()))
	return tris, hi[2]


def sign_board(m, x, y, z, w, h, face="black", frame="gold"):
	"""The Market sign (16 x 4.1, same place and size): vermilion rim, gold frame, a lit silk field, an aura ring at each end."""
	m.box((w, 0.4, h), (x, y, z), "verm")
	m.box((w - 0.4, 0.48, h - 0.4), (x, y, z), "gold")
	m.box((w - 0.8, 0.54, h - 0.8), (x, y, z), "g_amber")
	m.box((w - 1.1, 0.6, h - 1.1), (x, y, z), "silk2")
	for s in (-1, 1):
		m.box((0.3, 0.62, h - 1.1), (x + s * (w / 2 - 3.1), y, z), "gold")
		m.hoop(0.95, (x + s * (w / 2 - 1.8), y - 0.38, z), 0.22, "lampw", n=14)
		m.gem((x + s * (w / 2 - 1.8), y - 0.42, z), 0.32, 0.42, 0.42, "g_amber", 4)


def stall(name, fn):
	old_m, old_b = dm.merchant, K.board
	dm.merchant = lambda *a, **k: None
	if name == "Market":
		K.board = sign_board
	try:
		m, _ = fn()
	finally:
		dm.merchant, K.board = old_m, old_b
	if name in BASE:  # the step the keeper stands on, so the hands clear the counter
		x, y, z = CAST[name][1]
		m.box((4.4, 1.9, z - BASE[name] + 0.1), (x, y + 0.25, (z + BASE[name] - 0.1) / 2), "basalt3")
	return m


def build(key, scene, v):
	world = bpy.data.collections.new("Plaza")
	ctx = bpy.data.collections.new("Context")
	for c in (world, ctx):
		scene.collection.children.link(c)
	bp.context(ctx)
	bpy.data.objects.remove(bpy.data.objects["Sensei_Dais"])
	for m in [bp.floor(), bp.path(), bp.showpiece(), bp.hero_torii(), bp.sky_loop(), bp.sakura(*bp.GREAT_SAKURA, 20, 44, "GreatSakura"), pw.world_gate()]:
		m.build(ctx)
	for i, t in enumerate((87, 100)):
		for s in (-1, 1):
			bp.stone_lantern(*bp.along(t, s * 8.6), f"Lantern_{i}_{s}").build(ctx)
	bp.pedestal(bp.PEDESTAL[0], bp.PEDESTAL[1], bp.PEDESTAL[2], "so", bp.EXCLUSIVE_FACE).build(ctx)
	if key == "W2":
		pw.sky(scene, v)
		for m in pw.accents() + [pw.rift(v)] + pw.islands():
			m.build(ctx)
	else:
		bp.petals(ctx)
	bp.rng.seed(11)  # draft_markets' own seed: the same stalls as approved
	dm.MAX_TRIS.update(B_Market=4500, B_Shop=4500, B_Potions=4500)  # the rubric's building limit (proposed)
	print(f"TRIS {key}: tris, w x d x h studs")
	for name, (pos, face, _a, fb, top) in dm.PIECES.items():
		m = stall(name, fb)
		m.build(world)
		w, d, h, _ = dm.size(m)
		print(f"  {m.name}: {dm.mtris(m)} tris, {w:.1f} x {d:.1f} x {h:.1f}")
		dm.check(m, m.name, top)
		cid, at, yaw, k, pose = CAST[name]
		mx = m.matrix @ Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4)
		obs = stand(world, name + "_" + cid, cid, mx, pose)
		bpy.context.view_layer.update()
		tris, hi = collide(f"{name} {cid}", obs, m)
		print(f"  {name} together: {dm.mtris(m) + tris} tris")
		if name == "Sensei" and hi > 6.2:
			print(f"CHECK Sensei figure: FAIL top {hi:.2f} over 6.2")
		if name == "Market":  # render context: the game's own sign text, at its own spot
			mt = bp.place(bp.MARKET[0], bp.MARKET[1], bp.TOP, bp.MARKET_FACE) @ Matrix.Translation((0, -0.38, bp.MARKET_SIGN_Y))
			bp.add_text(ctx, "MARKET", mt, 2.2, "white", "Ctx_SignText")
		dm.header_mark(ctx, name)
		dm.player("Player_" + name, bp.place(*pos, bp.TOP, face), {"Index": (6.5, -8.5, 0), "Sensei": (5.6, 2.4, 0), "Market": (8.0, -9.5, 0)}.get(name, (5.6, -8.0, 0)), 200).build(ctx)
		p = Vector((face[0], face[1])) * 6
		pw.point(ctx, (pos[0] + p.x, bp.TOP + 7, pos[1] + p.y), "#E8D8FF" if key == "W2" else "#FFC58A", (800 if name == "Index" else 1800) if key == "W2" else (90 if name == "Index" else 350), 3)  # white clothes in the open


def row(key, cam, scene, name, groups, gap, fov, dist):
	"""Characters in a row beside the 5.5-stud player, at stall scale and pose."""
	col = bpy.data.collections.new("Row")
	scene.collection.children.link(col)
	base = bp.place(600, 600, 900, (0, 1))
	g = K("Ctx_Line", base)
	g.box((160, 90, 1), (0, -25, -0.5), "stone" if key == "W1" else "basalt2")
	g.box((160, 1, 40), (0, 9, 10), "plaster2" if key == "W1" else "basalt")
	g.build(col)
	n = len(groups) + 1
	x = lambda i: (i - (n - 1) / 2) * gap
	dm.player("Line_Player", base, (x(0), 0, 0), 0).build(col)
	for i, (cid, pose, k) in enumerate(groups):
		stand(col, f"Line_{i}", cid, base @ Matrix.Translation((x(i + 1), 0, 0)) @ Matrix.Rotation(math.radians(-8), 4, "Z") @ Matrix.Scale(k, 4), pose)
	for lx in (-8, 8):
		pw.point(col, (600 + lx, 912, 622), "#FFF0E0", 3500 if key == "W1" else 14000, 4)
	bp.shoot(cam, (600, 904.4, 600 + dist), (600, 902.8, 600), name, fov)
	scene.collection.children.unlink(col)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	keys = [a for a in argv if a in ("W1", "W2")] or ["W1", "W2"]
	want = [a for a in argv if a not in ("W1", "W2") and not a.startswith("--")]
	for key in keys:
		v = dm.reset("B" if key == "W2" else "W1")
		ids = [c[0] for c in CAST.values()]
		_built.clear()
		load(ids + ([a for t in ALTS.values() for a in t] if "--alts" in argv else []))
		scene = bpy.context.scene
		cam = bp.setup_world(scene)
		dm.engine(scene)
		build(key, scene, v)
		if "--tris" in argv:
			continue
		bp.OUT = os.path.join(OUT, key)
		os.makedirs(bp.OUT, exist_ok=True)
		shots = dm.shots("B")
		pos, face = dm.PIECES["Sensei"][:2]  # seen from the front: draft_markets' cameras look from his left
		for name, side, fwd, up, fov in (("Sensei_1front", 2.0, 11.5, 4.6, 48), ("Sensei_3close", 1.6, 7.5, 5.0, 46)):
			e = dm.world_at(pos, face, side, fwd)
			shots[name] = ((e[0], bp.TOP + up, e[1]), (pos[0], bp.TOP + 3.5, pos[1]), fov)
		for name, s in shots.items():
			if name == "ring_full" or (want and not any(name.startswith(x) or name.endswith(x) for x in want)):
				continue
			if s:
				bp.shoot(cam, s[0], s[1], name, s[2])
			else:
				row(key, cam, scene, name, [(c[0], c[4], c[3]) for c in CAST.values()], 4.6, 40, 22)
		if "--alts" in argv:
			bp.OUT = OUT
			row(key, cam, scene, "alternates", [(a, {}, 1.0) for t in ALTS.values() for a in t], 4.8, 32, 56)


if __name__ == "__main__":
	main()
