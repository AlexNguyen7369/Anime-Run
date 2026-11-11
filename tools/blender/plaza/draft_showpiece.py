# Spawn showpiece drafts (design doc 4.43, proposed): three layouts with the spawn as a raised landmark. Review renders only,
# no export. Headless:
#   Blender -b --factory-startup --python tools/blender/plaza/draft_showpiece.py -- [A B C]
# Reuses build_plaza (import-safe); writes assets/plaza_draft/Showpiece_<Letter>_<view>.png.
import math
import os
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as P  # noqa: E402

TOP = P.TOP
EXCL_ID = "punch_hero" if os.path.exists(os.path.join(P.CHARS, "punch_hero", "punch_hero.blend")) else "leaf_hero"
OLD_PLOTS = ((-42, -91), (25, -107), (86, -68), (110, 0), (86, 68), (25, 107), (-42, 91))


def to_spawn(x, z):
	r = math.hypot(x, z)
	return (-x / r, -z / r)


def ring(m, r0, r1, z0, z1, material, n=32):
	"""An annulus from r0 to r1, z0 to z1 (Blender local, centred on the origin)."""
	pt = lambda r, k, z: (r * math.cos(k / n * math.tau), r * math.sin(k / n * math.tau), z)
	for k in range(n):
		m.face([pt(r0, k, z1), pt(r1, k, z1), pt(r1, k + 1, z1), pt(r0, k + 1, z1)][::-1], material)
		m.face([pt(r1, k, z0), pt(r1, k + 1, z0), pt(r1, k + 1, z1), pt(r1, k, z1)], material)
		m.face([pt(r0, k + 1, z0), pt(r0, k, z0), pt(r0, k, z1), pt(r0, k + 1, z1)], material)


def showpiece(col, steps, top_r, pedestal_xz):
	"""steps: [(radius, top_y)] bottom up; top_r: the spawn disc radius; pedestal_xz: (x, z, y) of the Saitamo pedestal."""
	m = P.M("Showpiece", P.place(0, 0, 0))
	y0 = 0.0
	for i, (r, y) in enumerate(steps):
		m.cyl(r, y - y0, (0, 0, y0), ("stone", "pave")[i % 2], n=32)
		ring(m, r - 0.6, r, y - 0.05, y + 0.05, "slab")  # step nosing
		y0 = y
	ty = steps[-1][1]
	# Spawn disc: SpawnLocation stays at (0, 0)
	m.cyl(top_r, 0.15, (0, 0, ty), "pave2", n=32)
	ring(m, top_r - 0.5, top_r, ty, ty + 0.2, "neonb")
	ring(m, 3.5, 4.0, ty, ty + 0.2, "gold")
	# Petal moat: inner lip, water, stone rim, 8 bloom jets, 8 small lanterns
	ring(m, top_r, 10.0, ty, ty + 0.45, "stone3")
	ring(m, 10.0, 12.6, ty, ty + 0.25, "water")
	ring(m, 12.6, 13.4, ty, ty + 0.7, "stone2")
	for k in range(8):
		a = k / 8 * math.tau + math.pi / 8
		m.blob(0.55, (11.3 * math.cos(a), 11.3 * math.sin(a), ty + 1.0), ("bloom", "bloom2", "bloom3")[k % 3], squash=1.6)
	m.build(col)
	for k in range(8):
		a = k / 8 * math.tau
		x, z = 13 * math.cos(a), 13 * math.sin(a)
		L = P.stone_lantern(x, z, f"MoatLantern_{k}")
		L.matrix = P.place(x, z, ty + 0.7) @ Matrix.Scale(0.45, 4)
		L.build(col)
	px, pz, py = pedestal_xz
	face = to_spawn(px, pz)
	ped = P.pedestal(0, px, pz, P.EXCLUSIVE[3])
	ped.matrix = P.place(px, pz, py, face)
	ped.build(col)
	P.put_char(col, EXCL_ID, px, py + 2.6, pz, face, P.LEGEND_H, "Exclusive_" + EXCL_ID)


def altar(col, x, z, face):
	"""Sidekick altar stand-in (built from Parts in game): 3-tier octagon, 4 pillars, a halo."""
	m = P.M("Ctx_SidekickAltar", P.place(x, z, TOP, face))
	for i, w in enumerate((30, 23, 16)):
		m.cyl(w / 2 / math.cos(math.pi / 8), 1.2, (0, 0, i * 1.2), ("stone", "stone2", "stone3")[i], n=8)
	for sx in (-1, 1):
		for sy in (-1, 1):
			m.cyl(0.7, 9, (sx * 5.5, sy * 5.5, 3.6), "verm", n=6)
	m.hoop(4.5, (0, 0, 9.5), 0.5, "sp", n=20)
	m.build(col)


def kept(col, best_roll):
	"""What context() puts in Ctx_Kept, minus the Best Roll and altar (moved per layout)."""
	k = P.M("Ctx_Kept2")
	k.cyl(9, 2, tuple(P.rb(best_roll[0], TOP, best_roll[1])), "ctx", n=16)
	k.box((16, 16, 0.4), tuple(P.rb(P.PAD[0], TOP + 0.2, P.PAD[1])), "pad")
	k.build(col)


def buildings(world, ctx, pos, faces):
	"""Shop, Potions, Market (+ roof sign), Index, Best Roll, Altar at pos[name], fronts toward faces[name]."""
	for title, cloth, goods in (("SHOP", "blue", "crates"), ("POTIONS", "purple", "bottles")):
		x, z = pos[title]
		s = P.stall(x, z, title, cloth, goods)
		s.matrix = P.place(x, z, TOP, faces[title])
		s.build(world)
		mx = P.place(x, z, TOP, faces[title]) @ Matrix.Translation((0, -5.85, 11.2))
		P.add_text(world, title, mx, 1.6 if title == "SHOP" else 1.25, "paper", "Sign_" + title)
	x, z = pos["MARKET"]
	f = faces["MARKET"]
	s = P.market_stall()
	s.matrix = P.place(x, z, TOP, f)
	s.build(world)
	sx, sz = x + f[0] * 3.8, z + f[1] * 3.8
	s = P.market_sign()
	s.matrix = P.place(sx, sz, TOP, f)
	s.build(world)
	P.add_text(world, "MARKET", P.place(sx, sz, TOP, f) @ Matrix.Translation((0, -0.45, P.MARKET_SIGN_Y)), 3.0, "gold", "Sign_Market")
	x, z = pos["INDEX"]
	s = P.index_board()
	s.matrix = P.place(x, z, TOP, faces["INDEX"])
	s.build(world)
	P.add_text(world, "RUNNER INDEX", P.place(x, z, TOP, faces["INDEX"]) @ Matrix.Translation((0, -0.45, 10.6)), 0.85, "verm2", "Sign_Index")
	kept(ctx, pos["BEST_ROLL"])
	altar(ctx, *pos["ALTAR"], faces["ALTAR"])


def fixed(scene, world, ctx):
	"""Everything the same in all drafts: context, floor, path, gate, lanterns, sakura, sky loop, runners, Sensei."""
	P.context(ctx)
	bpy.data.objects.remove(bpy.data.objects["Ctx_Kept"])  # its Best Roll / altar spots move per layout
	P.petals(ctx)
	for m in (P.floor(), P.path(), P.hero_torii(), P.sakura(P.GREAT_SAKURA[0], P.GREAT_SAKURA[1], 20, 44, "GreatSakura"), P.sky_loop()):
		m.build(world)
	for i, t in enumerate((87, 100)):
		for s in (-1, 1):
			x, z = P.along(t, s * 8.6)
			P.stone_lantern(x, z, f"Lantern_{i}_{s}").build(world)
	runners = [(205, "neonb", 0, "leaf_hero"), (20, "neono", 1, "sea_captain"), (95, "neonb", 0, "db_hero")]
	P.trails([(d, c, o) for d, c, o, _ in runners]).build(world)
	for deg, _, _, cid in runners:
		a = math.radians(deg)
		P.put_char(world, cid, 62 * math.cos(a), P.LOOP_H + 0.05, 62 * math.sin(a), (math.sin(a), -math.cos(a)), P.RUNNER_H, f"Runner_{cid}")
	P.put_char(ctx, "leaf_copycat", P.SENSEI[0], TOP + 0.6, P.SENSEI[1], P.ECON_FACE, 5.8, "Ctx_Sensei")
	mx = P.place(P.PAD[0], P.PAD[1], TOP, (-P.AXIS[0], -P.AXIS[1])) @ Matrix.Translation((0, -0.45, 21.6))
	P.add_text(world, "RACE START", mx, 2.4, "gold", "Sign_RaceStart")


NAMES = ("SHOP", "POTIONS", "MARKET", "INDEX", "BEST_ROLL", "ALTAR")
LAYOUTS = {
	"A": {
		"steps": [(16, TOP + 0.75), (14.5, TOP + 1.5)],
		"ped": (8.2, 8.8, TOP + 1.5),
		"pos": dict(zip(NAMES, (P.SHOP, P.POTIONS, P.MARKET_STALL, P.INDEX, P.BEST_ROLL, P.SIDEKICK_ALTAR))),
		"faces": dict(zip(NAMES, (P.ECON_FACE,) * 4 + (P.SUMMON_FACE,) * 2)),
		"plot_lanterns": True,
	},
	"B": {
		"steps": [(16, TOP + 0.75), (14.5, TOP + 1.5)],
		"ped": (8.2, 8.8, TOP + 1.5),
		"pos": dict(zip(NAMES, ((-60.0, -2.2), (-40.8, -44.0), (2.2, -60.0), (44.0, -40.8), (60.0, 2.2), (40.8, 44.0)))),
	},
	"C": {
		"steps": [(26, TOP + 0.8), (20, TOP + 1.6), (14, TOP + 2.4)],
		"ped": (11.6, 12.5, TOP + 1.6),
		"pos": dict(zip(NAMES, ((-87.9, -3.3), (-59.9, -64.5), (3.3, -87.9), (64.5, -59.9), (87.9, 3.3), (59.9, 64.5)))),
	},
}


def draft(letter):
	L = LAYOUTS[letter]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	P.SHIP[:] = []
	P.SIGNS[:] = []
	P._mats.clear()
	P._chars.clear()
	scene = bpy.context.scene
	cam = P.setup_world(scene)
	scene.render.image_settings.file_format = "PNG"
	world, ctx = bpy.data.collections.new("Plaza"), bpy.data.collections.new("Context")
	for c in (world, ctx):
		scene.collection.children.link(c)
	fixed(scene, world, ctx)
	showpiece(world, L["steps"], 9.5, L["ped"])
	faces = L.get("faces") or {n: to_spawn(*L["pos"][n]) for n in NAMES}
	buildings(world, ctx, L["pos"], faces)
	if L.get("plot_lanterns"):
		for i, (x, z) in enumerate(OLD_PLOTS):
			a = math.atan2(z, x)
			P.stone_lantern(100 * math.cos(a), 100 * math.sin(a), f"PlotLantern_{i}").build(world)
	print(f"LAYOUT {letter} exclusive={EXCL_ID} pedestal={L['ped']}")
	for n in NAMES:
		print(f"  {n}: pos={tuple(round(v, 1) for v in L['pos'][n])} face={tuple(round(v, 3) for v in faces[n])}")
	back = P.along(-12)
	shots = {
		"top": ((0, 240, 0), (0, 0, 0.01)),
		"spawn": ((back[0], TOP + 7.5, back[1]), (P.PAD[0], TOP + 14, P.PAD[1])),
		"gate_back": ((-104, TOP + 9, 96), (0, TOP + 8, 0)),
	}
	os.makedirs(P.OUT, exist_ok=True)
	for view, (eye, look) in shots.items():
		e, l = P.rb(*eye), P.rb(*look)
		cam.location = e
		cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
		scene.render.filepath = os.path.join(P.OUT, f"Showpiece_{letter}_{view}.png")
		bpy.ops.render.render(write_still=True)
		print("SHOT", scene.render.filepath)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	for letter in argv or sorted(LAYOUTS):
		draft(letter)


if __name__ == "__main__":
	main()
