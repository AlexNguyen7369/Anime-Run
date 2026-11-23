"""World 2 Track 7: Ant Island (Solo Levelup). The volcanic island of the ant raid: black basalt ground and hexagonal
basalt columns, dry yellow grass, giant ant hive mounds and dark tunnel mouths with a faint purple glow, a dark ocean
all around, and a dormant volcano cone as the landmark, under an ominous purple-grey sky. Everything in-house, parts
only; no crest or text (design doc 5). Proposed look; the owner approves the render set (design doc 4.46)."""

import math

BASALT, BASALT2, BASALT3 = "2A2A2E", "3A3A40", "1E1E22"
SOIL, SOIL2 = "2C2A2E", "4A3E34"
HIVE, HIVE2 = "5E4A3A", "4A3A2C"
GRASS, GRASS2 = "B8A060", "8E7E4A"
GLOW, HOLE = "8A3AC8", "100C14"
OCEAN = "14202E"
SUPPORT = "3A2E24"
LAMP = "D8C8FF"


def row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True):
	"""k.along on the ground plane, skipping any spot within `clear` of another part of the looping road."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			yaw = yaw + (math.pi if off < 0 else 0.0) if face_road else k.rng.uniform(0, math.tau)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def supports(k, color):
	"""Basalt piers under raised road (slopes), so it never floats."""
	k.prop("Pier", [("cyl", (10, 1, 10), (0, -0.5, 0), color, {"seg": 6})])
	d = 0.0
	while d < k.length:
		p, _, _ = k.at(d)
		if p.y > 3:
			pos, yaw = k.beside(d, 0)
			ob = k.place("Pier", (pos[0], p.y - 0.5, pos[2]), yaw)
			ob.scale = (1, 1, p.y + 0.5)  # from the road's top down to the ground at y = -1
		d += 24


def build(k):
	# Hexagonal basalt column clusters
	for i in range(3):
		parts = []
		for j in range(5 + i):
			a = j * 2.4
			r = 0 if j == 0 else 3.6 + (j % 2) * 2
			h = 14 + 9 * i - j * 2.2
			parts.append(("cyl", (4.4, h, 4.4), (r * math.cos(a), h / 2, r * math.sin(a)), (BASALT, BASALT2, BASALT3)[j % 3], {"seg": 6, "rough": 0.6}))
		k.prop("Basalt%d" % i, parts)
	k.prop(
		"Boulder",
		[
			("ball", (10, 6, 8), (0, 2, 0), BASALT2, {"rot": (0, 30, 8)}),
			("ball", (6, 4, 6), (5, 1.5, 3), BASALT),
		],
	)
	k.prop(
		"DryGrass",
		[
			("cone", (3, 4.5, 3), (0, 2.2, 0), GRASS, {"seg": 5}),
			("cone", (2.4, 3.4, 2.4), (2, 1.7, 1), GRASS2, {"seg": 5, "rot": (0, 0, -18)}),
			("cone", (2.4, 3.8, 2.4), (-2, 1.9, -0.6), GRASS, {"seg": 5, "rot": (0, 0, 18)}),
		],
	)
	k.prop("GrassPatch", [("cyl", (40, 0.6, 28), (0, 0.3, 0), GRASS2, {"seg": 7}), ("cyl", (22, 0.8, 16), (8, 0.4, 4), GRASS, {"seg": 6})])
	# Giant ant hive mounds: lumpy earthen cones with dark entrance holes, a faint purple glow inside
	for i, (r, h) in enumerate(((40, 34), (60, 50))):
		parts = [
			("cone", (r, h, r), (0, h / 2, 0), HIVE, {"seg": 10, "taper": 0.3}),
			("cone", (r * 0.55, h * 0.8, r * 0.55), (r * 0.3, h * 0.4, r * 0.15), HIVE2, {"seg": 8, "taper": 0.25}),
			("cone", (r * 0.45, h * 0.6, r * 0.45), (-r * 0.32, h * 0.3, -r * 0.1), HIVE2, {"seg": 8, "taper": 0.3}),
			("cyl", (r * 0.32, 3, r * 0.32), (0, h + 1, 0), HOLE, {"seg": 8}),
			("ball", (r * 0.2, r * 0.1, r * 0.2), (0, h + 2, 0), GLOW, {"emit": 1.2}),
		]
		for a in (0.3, 2.2, 4.2):
			y = h * 0.28
			rr = r * 0.39
			parts.append(("box", (r * 0.14, r * 0.12, 1.2), (rr * math.sin(a), y, -rr * math.cos(a)), HOLE, {"rot": (-30, -math.degrees(a), 0)}))
		k.prop("Hive%d" % i, parts)
	# Ant spires: tall thin earthen towers
	k.prop(
		"Spire",
		[
			("cone", (10, 40, 10), (0, 20, 0), HIVE2, {"seg": 7, "taper": 0.15}),
			("cone", (6, 26, 6), (4, 13, 2), HIVE, {"seg": 6, "taper": 0.1}),
			("cone", (14, 6, 14), (0, 3, 0), SOIL2, {"seg": 7, "taper": 0.6}),
		],
	)
	# Tunnel mouth: a rocky arch with a black, faintly glowing opening facing the road
	k.prop(
		"Tunnel",
		[
			("ball", (40, 26, 30), (0, 6, 6), BASALT2),
			("ball", (24, 18, 20), (-14, 4, 10), BASALT),
			("cyl", (20, 1, 20), (0, 8, -7.4), HOLE, {"rot": (90, 0, 0), "seg": 10}),
			("cyl", (14, 0.4, 14), (0, 8, -8), "2A1440", {"rot": (90, 0, 0), "seg": 10, "emit": 1.2}),
			("box", (20, 2, 10), (0, 0, -10), SOIL),
		],
	)
	# Cliff chunks that break the island's straight shore line
	k.prop(
		"Cliff",
		[
			("cyl", (60, 14, 60), (0, 3, 0), BASALT, {"seg": 6}),
			("cyl", (36, 22, 36), (12, 8, 8), BASALT2, {"seg": 6}),
			("cyl", (28, 18, 28), (-16, 6, -10), BASALT3, {"seg": 6}),
		],
	)
	# Dormant volcano (landmark): broad cone, dark crater lip, dim glow deep inside
	vol = [
		("cone", (900, 360, 900), (0, 180, 0), "36302E", {"seg": 18, "taper": 0.22}),
		("cone", (560, 260, 560), (60, 130, 40), "2C2826", {"seg": 12, "taper": 0.3}),
		("cyl", (210, 6, 210), (0, 361, 0), BASALT3, {"seg": 14}),
		("cyl", (150, 4, 150), (0, 363, 0), "3A1A48", {"seg": 14, "emit": 0.8}),
	]
	for j in range(6):  # grass skirts round the foot
		a = j * math.tau / 6
		vol.append(("cone", (180, 30, 180), (420 * math.sin(a), 10, -420 * math.cos(a)), GRASS2, {"seg": 8, "taper": 0.5}))
	k.prop("Volcano", vol)

	# Island of dark soil on a dark ocean; basalt cliffs break the shore
	k.ground(OCEAN, margin=2200, rough=0.55, y=-4.0)
	k.ground(SOIL, margin=380)
	supports(k, SUPPORT)
	lo, hi = k.lo, k.hi
	for x0, z0, x1, z1 in (
		(lo.x - 380, lo.z - 380, hi.x + 380, lo.z - 380),
		(lo.x - 380, hi.z + 380, hi.x + 380, hi.z + 380),
		(lo.x - 380, lo.z - 380, lo.x - 380, hi.z + 380),
		(hi.x + 380, lo.z - 380, hi.x + 380, hi.z + 380),
	):
		n = int(math.hypot(x1 - x0, z1 - z0) / 70)
		for i in range(n + 1):
			t = i / n
			k.place("Cliff", (x0 + (x1 - x0) * t, -4.0, z0 + (z1 - z0) * t), k.rng.uniform(0, math.tau), k.rng.uniform(0.9, 1.6))
	# Road edge: dry grass and boulders; then basalt clusters; then hives, spires and tunnel mouths
	row(k, 22, (-30, 30), ["DryGrass", "DryGrass", "Boulder"], 26, jitter=4, scale=(1.2, 2.0), face_road=False)
	k.field(220, ["GrassPatch"], clearance=50, margin=330, scale=(0.8, 2.2))
	row(k, 60, (-44, 44), ["Basalt0", "Basalt1", "Basalt2", "DryGrass"], 36, jitter=10, face_road=False)
	row(k, 190, (-85, 85), ["Hive0", "Hive1", "Spire", "Spire"], 64, jitter=24, scale=(0.9, 1.4), face_road=False)
	row(k, 260, (-58, 58), ["Tunnel"], 40, jitter=20, start=120)
	k.field(260, ["DryGrass", "Boulder", "Basalt0", "Basalt1", "Basalt2"], clearance=60, margin=330, scale=(1.0, 2.0))
	k.field(70, ["Hive0", "Hive1", "Spire"], clearance=110, margin=300, scale=(1.0, 2.0))
	# Volcano: in the infield if it fits, else on the horizon beyond the shore
	cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
	if k.clear_of_road(cx, cz, 680):
		k.place("Volcano", (cx, -1.0, cz), 0.4, 1.35)
	else:
		pos, yaw = k.beside(k.length * 0.5, -900)
		k.place("Volcano", (pos[0], -4.0, pos[2]), yaw)
	# Ominous purple-grey overcast; dim sun, so cool lamps along the road keep it readable
	k.sky([(0.0, "8A7A96"), (0.04, "6A5A80"), (0.14, "4A3E62"), (1.0, "1E1830")], strength=0.9, sun=(2.2, "E0D0FF", 30, 200))
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, LAMP, energy=40000, radius=8)
		d += 180
