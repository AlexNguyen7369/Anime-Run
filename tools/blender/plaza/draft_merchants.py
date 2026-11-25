"""Blender DRAFTS (renders only): market set B with roster characters as its merchants (owner 2026-11-25; WORLD_REDESIGN_SPEC 4.2).

Nothing here ships: no export, no upload, no game data. draft_markets.py, build_plaza.py, plaza_w2.py and build_avatar.py are
imported, never edited; a character is built from its own repo source by build_avatar.placed() exactly as the export does.
A merchant is only placed, scaled whole and its limbs turned about their joints, as RunnerVisual does (Hero, Pose).
Stalls are set B's own geometry. Changed, and only here: the Market sign, a step under each keeper behind a counter, the
draft's own figures (with the goods they held), the Index keeper's spot and lectern, and the loose parts listed in stall().
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

# Stall -> character id, feet (stall frame), yaw, whole-rig scale, limb turns {part: XYZ degrees about its joint} or
# ("rest", outward degrees, height): the arm swings forward until the block hand lies on that height (solved, see rest()).
# Scale 1 is the built rig: head top 5.3, a player's avatar is 5.5 (runners in game are 0.8 of it). All proposed.
HAIL = {"RightArm": (-152, -20, 0), "LeftArm": (14, -16, 0), "RightLeg": (0, 6, 0), "LeftLeg": (0, -6, 0)}  # RunnerVisual.Hero's kind of pose
CAST = {
	"Shop": ("sea_navigator", (0, -0.95, 1.5), 0, 1.0, {"RightArm": ("rest", 24, 3.8), "LeftArm": ("rest", 10, 3.8)}),
	"Potions": ("leaf_medic", (0, -0.6, 1.2), 0, 1.0, {"RightArm": ("rest", 2, 3.66), "LeftArm": ("rest", 2, 3.66)}),
	"Market": ("ds_flame", (0, -1.4, 1.5), 0, 1.0, {"RightArm": ("rest", 16, 3.8), "LeftArm": ("rest", 16, 3.8)}),
	"Index": ("fr_mage", (-3.7, -1.5, 0.75), 4, 1.0, {"LeftArm": ("rest", 4, 3.17), "RightArm": (-8, 4, 0)}),
	"Sensei": ("leaf_copycat", (0, -0.5, 0.65), 0, 0.75, HAIL),
}
SENSEI_TOP = 6.17  # the in-limit height: 6.2 (proposed) is where the floating header starts
ALTS = {
	"Shop": ("saw_blood", "sea_cook"), "Potions": ("soul_healer", "fr_staff"), "Market": ("dan_idol", "jk_nails"),
	"Index": ("db_scholar", "punch_cyborg"), "Sensei": ("db_green", "jk_strongest"),
}
NAMES = {
	"sea_navigator": "Nammi", "leaf_medic": "Sakara", "ds_flame": "Rengoko", "fr_mage": "Frierin", "leaf_copycat": "Kakashe", "saw_blood": "Powah", "sea_cook": "Sanjy",
	"soul_healer": "Orihima", "fr_staff": "Ferne", "dan_idol": "Airah", "jk_nails": "Nobora", "db_scholar": "Gohon", "punch_cyborg": "Genus", "db_green": "Pikolo", "jk_strongest": "Gojio",
}
# an alternate that needs its own place or pose at the stall: (feet, limb turns)
FIT = {
	("Potions", "fr_staff"): ((0, -0.45, 1.2), {"RightArm": (-4, 6, 0), "LeftArm": ("rest", -4, 3.66)}),
	("Potions", "soul_healer"): ((0, -0.45, 1.2), {"RightArm": ("rest", 2, 3.66), "LeftArm": ("rest", -3, 3.66)}),
	("Market", "jk_nails"): ((0, -1.4, 1.5), {"RightArm": (0, 8, 0), "LeftArm": ("rest", 16, 3.8)}),  # her hammer hangs under the right fist
}
ROW = {n: {} for n in ("Shop", "Potions", "Market", "Index")}  # no counter in the row: arms as built
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
		o.matrix_world = matrix @ turn(part, pose.get(part, (0, 0, 0)))
		col.objects.link(o)
		obs.append(o)
	return obs


def rest(cid, part, matrix, spec):
	"""The forward turn that lays the hand's block on spec's height (stall or world frame of matrix)."""
	_, out, top = spec
	out *= -1 if part == "LeftArm" else 1
	me = _built[cid][part]
	pts = [v.co for v in (me.vertices[i] for i in {i for f in real(me) for i in f.vertices}) if abs(v.co.x) < 0.8 and abs(v.co.y) < 0.64 and -1.3 < v.co.z < 0]
	low = lambda deg: min((matrix @ turn(part, (deg, out, 0)) @ v).z for v in pts)
	lo, hi = -100.0, -5.0  # raised, hanging
	if low(hi) > top:
		return (hi, out, 0)
	for _ in range(40):
		mid = (lo + hi) / 2
		lo, hi = (mid, hi) if low(mid) > top + 0.02 else (lo, mid)
	return (lo, out, 0)


def turn(part, deg):
	joint = Vector((0, 0, -0.65 if part == "Head" else 1.0))
	r = Matrix.Rotation(math.radians(deg[2]), 4, "Z") @ Matrix.Rotation(math.radians(deg[1]), 4, "Y") @ Matrix.Rotation(math.radians(deg[0]), 4, "X")
	return Matrix.Translation(CENTRE[part]) @ Matrix.Translation(joint) @ r @ Matrix.Translation(-joint)


def solve(cid, local, pose):
	return {p: rest(cid, p, local, d) if d[0] == "rest" else d for p, d in pose.items()}


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


def shift(m, inside, d):
	for i, v in enumerate(m.v):
		if inside(v):
			m.v[i] = Vector(v) + Vector(d)


def inside_geode(p):
	"""In the Shop geode's hollow (b_shop's inner skin)."""
	t = (p.z - 0.4) / 10.8
	return 0 < t < 1 and p.y > 0.4 and (p.x / 7.9) ** 2 + ((p.y - 0.4) / 4.1) ** 2 < (1 - t * t) * 1.15


def stall(name, fn):
	"""Set B's stall, its loose parts tidied (blind review 2026-11-25)."""
	kept = dm.merchant, K.board, K.taper, K.beam, K.lantern
	taper, beam, lantern = kept[2:]
	dm.merchant = lambda *a, **k: None
	if name == "Market":
		K.board = sign_board
	if name == "Shop":  # shards' feet poked through the shell behind the caskets; the lanterns hung over the keeper's head
		def thin(m, a, b, wa, wb, material, sides=4, roll=None):
			a, b = Vector(a), Vector(b)
			if sides == 5 and material in ("g_blue", "r_rare") and not (abs(a.y + 2.9) < 0.5 and a.z < 5.5):
				d = (b - a).normalized()
				if wb == 0 and inside_geode(b) and a.z > 6:  # the spikes inside the dome
					return
				if wb > 0:
					for _ in range(26):
						if not inside_geode(a) and not inside_geode(a + Vector((0, wa / 2, 0))) and not inside_geode(a + Vector((-math.copysign(wa / 2, a.x), 0, 0))):
							break
						a = a + Vector((math.copysign(0.08, a.x), -0.05, 0)) + d * 0.06
						wa *= 0.93
			taper(m, a, b, wa, wb, material, sides, roll)
		K.taper = thin
		K.lantern = lambda m, c, *r: lantern(m, (math.copysign(6.2, c[0]), -5.0, c[2]), *r)
		def arm(m, a, b, w, material, *r):
			if material == "iron":
				b = (math.copysign(6.2, b[0]), -5.0, b[2])
			beam(m, a, b, w, material, *r)
		K.beam = arm
	if name == "Potions":  # ribs turned half a facet: one each side of the front, not a lone one
		def rib(m, a, b, w, material, *r):
			if material == "verm" and w == 0.3:
				t = Matrix.Rotation(math.pi / 16, 3, "Z") @ Matrix.Diagonal((0.985, 0.985, 1))
				a, b = t @ Vector(a), t @ Vector(b)
			beam(m, a, b, w, material, *r)
		K.beam = rib
	if name == "Market":  # the counter's rings, clear of the keeper from the front and the corner
		to = {-4.8: -5.1, -2.9: 3.35, 4.6: 5.35}
		def moved(f, at):
			def g(m, *a, **k):
				c = a[at]
				if c[0] in to and abs(c[1] + 3.8) < 0.01 and c[2] > 3.75:
					a = a[:at] + ((to[c[0]], c[1], c[2]),) + a[at + 1 :]
				return f(m, *a, **k)
			return g
		base = {n: getattr(bp.M, n) for n in ("hoop", "cyl", "box")}
		K.hoop, K.cyl, K.box = moved(base["hoop"], 1), moved(base["cyl"], 2), moved(base["box"], 1)
	try:
		m, _ = fn()
	finally:
		dm.merchant, K.board, K.taper, K.beam, K.lantern = kept
		for n in ("hoop", "cyl", "box"):  # K inherits these
			if n in K.__dict__:
				delattr(K, n)
	if name == "Index":  # the lectern, off the platform's lip, under the keeper's left hand
		shift(m, lambda v: -7.0 < v[0] < -4.3 and -5.3 < v[1] < -3.2 and v[2] > 2.4, (0, 0, -0.7))
		shift(m, lambda v: -7.0 < v[0] < -4.3 and -5.3 < v[1] < -3.2 and v[2] > 0.19, (3.55, 1.05, 0.45))
	if name in BASE:  # the step the keeper stands on
		x, y, z = CAST[name][1]
		m.box((4.2, 1.5, z - BASE[name] + 0.1), (x, y + 0.5, (z + BASE[name] - 0.1) / 2), "basalt3")
	return m


def place_keeper(col, name, m, cid, at=None, pose=None, k=None):
	_c, at0, yaw, k0, pose0 = CAST[name]
	fit = FIT.get((name, cid), (None, None))
	at, pose, k = at or fit[0] or at0, pose or fit[1] or pose0, k or k0
	if name == "Sensei" and k == k0:  # as tall as the limit allows
		top = max((turn(p, (0, 0, 0)) @ v.co).z for p, me in _built[cid].items() for f in real(me) for v in (me.vertices[i] for i in f.vertices))
		k = min(1.0, (SENSEI_TOP - at[2]) / top)
	local = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4)
	obs = stand(col, f"{name}_{cid}", cid, m.matrix @ local, solve(cid, local, pose))
	bpy.context.view_layer.update()
	print(f"  {name} {cid} scale {k:.2f}")
	return obs


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
	live = {}
	print(f"TRIS {key}: tris, w x d x h studs")
	for name, (pos, face, _a, fb, top) in dm.PIECES.items():
		m = stall(name, fb)
		m.build(world)
		w, d, h, _ = dm.size(m)
		print(f"  {m.name}: {dm.mtris(m)} tris, {w:.1f} x {d:.1f} x {h:.1f}")
		dm.check(m, m.name, top)
		cid = CAST[name][0]
		obs = place_keeper(world, name, m, cid)
		live[name] = (m, obs)
		tris, hi = collide(f"{name} {cid}", obs, m)
		print(f"  {name} together: {dm.mtris(m) + tris} tris")
		if name == "Sensei" and hi > 6.2:
			print(f"CHECK Sensei figure: FAIL top {hi:.2f} over 6.2")
		if name == "Market":  # render context: the game's own sign text, at its own spot
			mt = bp.place(bp.MARKET[0], bp.MARKET[1], bp.TOP, bp.MARKET_FACE) @ Matrix.Translation((0, -0.38, bp.MARKET_SIGN_Y))
			bp.add_text(ctx, "MARKET", mt, 2.2, "white", "Ctx_SignText")
		dm.header_mark(ctx, name)
		dm.player("Player_" + name, bp.place(*pos, bp.TOP, face), {"Index": (6.5, -8.5, 0), "Sensei": (5.6, 2.4, 0), "Market": (8.0, -9.5, 0)}.get(name, (5.6, -8.0, 0)), 200).build(ctx)
		p = Vector((face[0], face[1])) * 9  # one lamp level a world, at one distance from every keeper (render only, tuned on skin)
		pw.point(ctx, (pos[0] + p.x, bp.TOP + 8, pos[1] + p.y), *(("#F2E8FF", 1500) if key == "W2" else ("#FFE2C0", 2000)), 3)
	return world, live


def tag(cam, text):
	"""A caption in front of the camera (sheets only)."""
	cu = bpy.data.curves.new("Tag", "FONT")
	cu.body, cu.align_x, cu.size = text, "CENTER", 0.09
	mt = bpy.data.materials.new("Tag")
	mt.use_nodes = True
	b = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (0, 0, 0, 1)
	b.inputs["Emission Color"].default_value = (1, 1, 1, 1)
	b.inputs["Emission Strength"].default_value = 1
	cu.materials.append(mt)
	o = bpy.data.objects.new("Tag", cu)
	h = 2 * math.tan(cam.data.angle_y / 2)
	o.scale = (h * 0.75,) * 3
	o.parent, o.location = cam, (0, -h * 0.47, -1)
	bpy.context.scene.collection.objects.link(o)
	return o


def sheet(names, out, cols):
	"""Renders beside each other, half size each, from files in bp.OUT; the singles are removed."""
	import numpy as np
	ims = []
	for n in names:
		f = os.path.join(bp.OUT, n + ".jpg")
		im = bpy.data.images.load(f)
		w, h = im.size
		ims.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4))
		bpy.data.images.remove(im)
		os.remove(f)
	h, w = ims[0].shape[:2]
	rows = -(-len(ims) // cols)
	big = np.ones((rows * h, cols * w, 4), dtype=np.float32)
	for i, p in enumerate(ims):
		y = (rows - 1 - i // cols) * h
		big[y : y + h, (i % cols) * w : (i % cols) * w + w] = p
	o = bpy.data.images.new("sheet", cols * w, rows * h)
	o.pixels = big.ravel()
	o.filepath_raw, o.file_format = os.path.join(OUT, out + ".jpg"), "JPEG"
	o.save()
	bpy.data.images.remove(o)


def swap(world, live, name, cid, **kw):
	m, obs = live[name]
	for o in obs:
		bpy.data.objects.remove(o)
	obs = place_keeper(world, name, m, cid, **kw)
	collide(f"{name} {cid}", obs, m)
	live[name] = (m, obs)


def shot_list():
	shots = dm.shots("B")
	pos, face = dm.PIECES["Sensei"][:2]  # seen from the front: draft_markets' cameras look from his left
	for name, side, fwd, up, fov in (("Sensei_1front", 3.2, 11.0, 4.8, 48), ("Sensei_3close", 2.4, 7.5, 5.0, 46)):
		e = dm.world_at(pos, face, side, fwd)
		shots[name] = ((e[0], bp.TOP + up, e[1]), (pos[0], bp.TOP + 3.6, pos[1]), fov)
	pos, face = dm.PIECES["Index"][:2]
	c, e = dm.world_at(pos, face, -3.0, 2.0), dm.world_at(pos, face, -1.0, 11.0)
	shots["Index_3close"] = ((e[0], bp.TOP + 5.6, e[1]), (c[0], bp.TOP + 3.8, c[1]), 46)
	return shots


def extras(key, cam, scene, world, live):
	"""Owner options and the alternates, each at its stall."""
	shots = shot_list()
	take = lambda n, out, text: (lambda t: (bp.shoot(cam, shots[n][0], shots[n][1], out, shots[n][2]), bpy.data.objects.remove(t)))(cap(n, text))
	def cap(n, text):
		cam.data.angle_y = math.radians(shots[n][2])
		return tag(cam, text)
	for n in ("1front", "2three_quarter", "3close", "4from_spawn"):  # Gohon, a World 1 character, at the Index
		if n == "1front":
			swap(world, live, "Index", "db_scholar")
		s = shots["Index_" + n]
		bp.shoot(cam, s[0], s[1], "IndexGohon_" + n, s[2])
	# Sensei: in the limit, at scale 1 with the header raised, and Pikolo in the limit
	rows = []
	head = bpy.data.objects["Ctx_Header_Sensei"]
	for out, cid, k, up in (("a", "leaf_copycat", None, 0), ("b", "leaf_copycat", 1.0, 1.9), ("c", "db_green", None, 0), ("d", "db_green", 1.0, 0.9)):
		swap(world, live, "Sensei", cid, k=k)
		head.location.z += up
		what = "in today's limit" if not k else f"OWNER OPTION: scale 1.0, header raised {up}"
		for n in ("1front", "3close"):
			rows.append(f"_s_{out}_{n}")
			take("Sensei_" + n, rows[-1], f"{NAMES[cid]}: {what}")
		head.location.z -= up
	scene.render.resolution_x, scene.render.resolution_y = 1280, 720
	sheet(rows, f"sensei_options_{key}", 2)
	scene.render.resolution_x, scene.render.resolution_y = 960, 540
	for name, alts in ALTS.items():
		rows = []
		for cid in (CAST[name][0],) + alts:
			swap(world, live, name, cid)
			rows.append("_a_" + cid)
			take(name + "_3close", rows[-1], f"{name}: {NAMES[cid]}" + (" (pick)" if cid == CAST[name][0] else " (alternate)"))
		sheet(rows, f"alternates_{name}_{key}", 3)
	scene.render.resolution_x, scene.render.resolution_y = 1280, 720


def alternates(cam, scene):
	"""The 10 alternates, two rows, each named with its stall."""
	col = bpy.data.collections.new("Alts")
	scene.collection.children.link(col)
	base = bp.place(600, 600, 900, (0, 1))
	g = K("Ctx_Alts", base)
	g.box((80, 1, 60), (0, 4, 0), "basalt2")
	g.build(col)
	for i, (cid, st) in enumerate([(c, n) for n, t in ALTS.items() for c in t]):
		x, z = (i % 5 - 2) * 5.6, 1.6 if i < 5 else -7.6
		g = K(f"Ctx_Plinth{i}", base)
		g.box((5.0, 3, 0.3), (x, 0, z - 0.15), "basalt")
		g.build(col)
		stand(col, f"Alt_{i}", cid, base @ Matrix.Translation((x, 0, z)) @ Matrix.Rotation(math.radians(-14), 4, "Z"), {})
		cu = bpy.data.curves.new("AltName", "FONT")
		cu.body, cu.align_x, cu.size = f"{NAMES[cid]}\n{st}", "CENTER", 0.8
		cu.materials.append(bp.mat("paper"))
		o = bpy.data.objects.new("AltName", cu)
		o.matrix_world = base @ Matrix.Translation((x, -1.55, z - 1.0)) @ Matrix.Rotation(math.pi / 2, 4, "X")
		o.visible_shadow = False
		col.objects.link(o)
	for lx in (-12, 0, 12):
		pw.point(col, (600 + lx, 903, 618), "#FFF6EC", 2400, 6)
	bp.shoot(cam, (600, 899.2, 634), (600, 898.9, 600), "alternates", 33)
	scene.collection.children.unlink(col)


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
		world, live = build(key, scene, v)
		if key == "W1":  # render only: the golden-hour sun alone clips white clothes and skin
			scene.objects["Sun"].data.energy = 1.0
			scene.view_settings.exposure = -0.2
		if "--tris" in argv:
			continue
		bp.OUT = os.path.join(OUT, key)
		os.makedirs(bp.OUT, exist_ok=True)
		shots = shot_list()
		for name, s in shots.items():
			if name == "ring_full" or (want and not any(name.startswith(x) or name.endswith(x) for x in want)):
				continue
			if s:
				bp.shoot(cam, s[0], s[1], name, s[2])
			else:
				row(key, cam, scene, name, [(c[0], ROW.get(n, c[4]), c[3]) for n, c in CAST.items()], 4.6, 40, 22)
		if "--alts" in argv:
			extras(key, cam, scene, world, live)
			bp.OUT = OUT
			if key == keys[0]:
				alternates(cam, scene)


if __name__ == "__main__":
	main()
