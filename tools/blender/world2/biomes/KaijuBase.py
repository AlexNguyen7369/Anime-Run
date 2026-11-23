"""World 2 Track 5: Kaiju Base (Kaiju No. 8). A kaiju-wrecked Tokyo suburb in late-afternoon orange light, after the
raid on the Defense Force's Tachikawa base: smashed office and apartment blocks, rubble, abandoned cars, evacuation
barricades and cranes in the first half; the base in the second half with its striped perimeter walls, arched hangars,
radar dishes and antenna masts. Landmark: a huge stylized kaiju skeleton (bone and rock, no gore) lying across the
city blocks, and the base's control tower. Everything in-house, parts only; no crest or text (design doc 5).
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

DUST, ASH, CONC, CONC2, RUST = "5E5C58", "4A4A4C", "B8B2A8", "8A9098", "8A5A3A"
BRICK = "9A6A58"
BONE, BONE2, ROCK = "E6DCC4", "C8BCA0", "5C5650"
BASE, BASE2, STRIPE, NAVY = "D8D4CC", "9AA0A6", "FF8A1E", "2E3E58"
WINDOW = "2A2E36"
SUPPORT = "3A3E46"


def row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0)):
	"""k.along on the ground plane, skipping any spot within `clear` of another part of the looping road."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw + (math.pi if off < 0 else 0.0), k.rng.uniform(*scale))
		d += every


def supports(k, color):
	"""Concrete piers under raised road (slopes), so it never floats."""
	k.prop("Pier", [("box", (10, 1, 10), (0, -0.5, 0), color)])
	d = 0.0
	while d < k.length:
		p, _, _ = k.at(d)
		if p.y > 3:
			h = p.y + 0.5  # from the road's top down to the ground at y = -1
			pos, yaw = k.beside(d, 0)
			ob = k.place("Pier", (pos[0], p.y - 0.5, pos[2]), yaw)
			ob.scale = (1, 1, h)
		d += 24


def build(k):
	# Smashed blocks: office and apartment boxes with dark window bands and a broken, slanted top
	for i, (w, h) in enumerate(((26, 30), (30, 44), (22, 56), (34, 24))):
		parts = [("box", (w, h, 22), (0, h / 2, 0), (CONC, CONC2, BRICK, CONC2)[i])]
		for f in range(int(h / 8)):
			parts.append(("box", (w - 4, 2.6, 0.4), (0, 5 + f * 8, -11.1), WINDOW))
		parts.append(("wedge", (w * 0.6, 10, 22), (-w * 0.2, h + 5, 0), (CONC, CONC2, CONC, CONC2)[i], {"rot": (0, 90, 0)}))
		parts.append(("box", (8, 6, 8), (w * 0.3, h + 1, 3), ROCK, {"rot": (14, 30, 18)}))
		parts.append(("box", (w * 0.5, 10, 2), (w * 0.25, h - 8, -11.5), ASH, {"rot": (0, 0, 25)}))  # torn facade slab
		k.prop("Ruin%d" % i, parts)
	# Collapsed block: a stub with slabs leaning on it
	k.prop(
		"Collapsed",
		[
			("box", (28, 12, 20), (0, 6, 0), CONC2),
			("box", (30, 2, 18), (-4, 14, 2), CONC, {"rot": (0, 0, 20)}),
			("box", (24, 2, 16), (6, 10, -4), CONC, {"rot": (12, 20, -28)}),
			("box", (10, 6, 10), (12, 3, -10), ROCK, {"rot": (0, 35, 10)}),
		],
	)
	k.prop(
		"Rubble",
		[
			("box", (7, 4, 6), (0, 2, 0), ROCK, {"rot": (0, 20, 8)}),
			("box", (5, 3, 5), (4, 1.5, 3), CONC2, {"rot": (12, 50, 0)}),
			("box", (4, 2.5, 4), (-4, 1.2, 2), DUST, {"rot": (0, 70, -10)}),
			("box", (8, 1, 1), (1, 3.4, -1), RUST, {"rot": (0, 30, 30), "metal": 0.6}),
		],
	)
	for i, c in enumerate(("D8302F", "E8E8E8", "2F6FD8")):
		k.prop(
			"Car%d" % i,
			[
				("box", (7, 2.6, 14), (0, 1.9, 0), c, {"rot": (0, 0, 6 * (i - 1))}),
				("box", (6, 2.2, 7), (0, 4.2, 0.5), "3A4250", {"rot": (0, 0, 6 * (i - 1))}),
				("cyl", (2.6, 1.2, 2.6), (-3.4, 1.3, -4.5), "1A1A1A", {"rot": (0, 0, 90), "seg": 8}),
				("cyl", (2.6, 1.2, 2.6), (3.4, 1.3, -4.5), "1A1A1A", {"rot": (0, 0, 90), "seg": 8}),
				("cyl", (2.6, 1.2, 2.6), (-3.4, 1.3, 4.5), "1A1A1A", {"rot": (0, 0, 90), "seg": 8}),
			],
		)
	k.prop(
		"Barricade",
		[
			("box", (12, 1.6, 0.6), (0, 3, 0), STRIPE, {"emit": 0.4}),
			("box", (12, 1.6, 0.6), (0, 5, 0), "F4F0E8"),
			("box", (0.6, 6, 2), (-5, 3, 0), "3A3E46"),
			("box", (0.6, 6, 2), (5, 3, 0), "3A3E46"),
			("cone", (2, 3, 2), (8, 1.5, 0), STRIPE, {"seg": 8}),
		],
	)
	# Construction / salvage crane: lattice tower, jib and counterweight
	crane = [("box", (6, 2, 6), (0, 1, 0), "4A4E56")]
	for y in range(0, 70, 10):
		crane.append(("box", (3, 10, 3), (0, 6 + y, 0), "F2B51E", {"metal": 0.3}))
		crane.append(("box", (3.6, 0.6, 3.6), (0, 11 + y, 0), "C8901A"))
	crane += [
		("box", (4, 4, 5), (0, 78, 0), "E8E8E8"),
		("box", (60, 2, 2), (18, 81, 0), "F2B51E", {"metal": 0.3}),
		("box", (8, 4, 4), (-12, 79, 0), ASH),
		("box", (0.4, 30, 0.4), (40, 66, 0), "30343C"),
		("box", (3, 2, 3), (40, 50, 0), "30343C"),
	]
	k.prop("Crane", crane)
	k.prop(
		"Pole",
		[
			("cyl", (1.1, 30, 1.1), (0, 15, 0), "8E8E86", {"seg": 8, "rot": (0, 0, 8)}),
			("box", (8, 0.5, 0.5), (2, 28, 0), "6E6E66", {"rot": (0, 0, 8)}),
		],
	)
	# Defense Force base: striped perimeter wall, arched hangar, radar dish, antenna mast, barracks
	k.prop(
		"BaseWall",
		[
			("box", (28, 12, 3), (0, 6, 0), BASE),
			("box", (28.4, 2, 3.4), (0, 8, 0), NAVY),
			("box", (28.4, 0.8, 3.4), (0, 10, 0), STRIPE, {"emit": 0.3}),
			("box", (28, 2, 4), (0, 12.5, 0), BASE2),
			("box", (3, 16, 3), (14, 8, 0), BASE2),
		],
	)
	k.prop(
		"Hangar",
		[
			("cyl", (56, 60, 56), (0, 0, 0), "8C949C", {"rot": (90, 0, 0), "seg": 14, "metal": 0.4, "rough": 0.5}),
			("box", (58, 2, 62), (0, 0, 0), "5A5E66"),
			("box", (36, 20, 1), (0, 10, -30.6), "3A3E46"),
			("box", (36, 1.2, 1.2), (0, 21, -30.8), STRIPE, {"emit": 0.6}),
		],
	)
	k.prop(
		"Radar",
		[
			("box", (12, 10, 12), (0, 5, 0), BASE),
			("cyl", (3, 14, 3), (0, 17, 0), BASE2, {"seg": 8}),
			("cyl", (22, 3, 22), (0, 26, -3), "E8ECF0", {"rot": (-55, 0, 0), "seg": 16, "taper": 0.25}),
			("box", (1, 10, 1), (0, 29, -7), BASE2, {"rot": (-55, 0, 0)}),
			("ball", (2, 2, 2), (0, 33, -10), "FF3B2B", {"emit": 4}),
		],
	)
	mast = [("box", (8, 2, 8), (0, 1, 0), "4A4E56")]
	for j, y in enumerate(range(0, 90, 15)):
		s = 5 - j * 0.6
		mast.append(("box", (s, 15, s), (0, 8.5 + y, 0), ("E8E8E8", "E04A2A")[j % 2]))
	mast += [("box", (10, 0.6, 0.6), (0, 70, 0), "9AA0A6"), ("box", (0.6, 0.6, 10), (0, 80, 0), "9AA0A6")]
	mast.append(("ball", (2, 2, 2), (0, 94, 0), "FF2B2B", {"emit": 8}))
	k.prop("Mast", mast)
	k.prop(
		"Barracks",
		[
			("box", (40, 12, 20), (0, 6, 0), BASE),
			("box", (42, 1, 22), (0, 12.5, 0), BASE2),
			("box", (40.2, 1.2, 20.2), (0, 3, 0), NAVY),
		]
		+ [("box", (4, 3, 0.4), (x, 8, -10.1), "9FC8FF", {"emit": 0.6}) for x in (-14, -7, 0, 7, 14)],
	)
	# The base's control tower (landmark): tall shaft, wide glazed cab, antennae, orange stripe
	tower = [
		("box", (40, 20, 40), (0, 10, 0), BASE),
		("box", (40.4, 2, 40.4), (0, 16, 0), STRIPE, {"emit": 0.4}),
		("box", (18, 80, 18), (0, 60, 0), BASE),
		("box", (18.4, 3, 18.4), (0, 70, 0), NAVY),
		("cyl", (36, 12, 36), (0, 106, 0), "8FD0FF", {"seg": 12, "emit": 0.8, "rough": 0.2}),
		("cyl", (40, 3, 40), (0, 113.5, 0), NAVY, {"seg": 12}),
		("cyl", (40, 2, 40), (0, 99, 0), NAVY, {"seg": 12}),
		("box", (1, 26, 1), (6, 128, 0), "D8D8D8"),
		("box", (1, 18, 1), (-6, 124, 4), "D8D8D8"),
		("ball", (2.4, 2.4, 2.4), (6, 142, 0), "FF2B2B", {"emit": 10}),
	]
	k.prop("ControlTower", tower)
	# Kaiju skeleton (landmark): spine of vertebrae, arched ribs, a horned skull and splayed limb bones, half sunk in
	# rock, stylized and bleached (no gore). Local +X is head to tail.
	sk = []
	for i in range(14):
		x = -70 + i * 11
		y = 16 + 22 * math.sin(math.pi * (i + 2) / 17)
		sk.append(("box", (8, 7, 8), (x, y, 0), BONE, {"rot": (0, 0, 10 * math.cos(i))}))
		sk.append(("wedge", (3, 8, 6), (x, y + 7, 0), BONE2, {"rot": (0, 90, 0)}))
		if 1 <= i <= 8:
			for s in (-1, 1):
				r = 22 - abs(i - 4) * 2
				sk.append(("box", (3, r, 3), (x, y - 2, s * r * 0.45), BONE, {"rot": (s * 62, 0, 0)}))
				sk.append(("box", (3, r * 0.9, 3), (x, y - r * 0.55, s * r * 0.95), BONE2, {"rot": (-s * 12, 0, 0)}))
	sk += [
		("box", (34, 18, 22), (-92, 22, 0), BONE, {"rot": (0, 0, -12)}),  # skull
		("wedge", (22, 10, 20), (-112, 15, 0), BONE2, {"rot": (0, -90, 0)}),  # snout
		("box", (26, 5, 18), (-104, 6, 0), BONE2, {"rot": (0, 0, 14)}),  # jaw
		("box", (6, 6, 1), (-96, 25, -11.4), "2A2420"),  # eye socket
		("box", (6, 6, 1), (-96, 25, 11.4), "2A2420"),
		("cone", (6, 22, 6), (-84, 38, -8), BONE2, {"rot": (-20, 0, 25), "seg": 8}),  # horns
		("cone", (6, 22, 6), (-84, 38, 8), BONE2, {"rot": (20, 0, 25), "seg": 8}),
	]
	for i in range(8):  # tail
		sk.append(("box", (7 - i * 0.6, 6 - i * 0.5, 7 - i * 0.6), (84 + i * 9, 12 - i * 1.3, 4 * math.sin(i * 0.8)), BONE))
	for x, s in ((-40, 1), (-40, -1), (30, 1), (30, -1)):  # limbs
		sk.append(("cyl", (5, 34, 5), (x, 14, s * 26), BONE, {"rot": (s * 60, 0, 0), "seg": 8}))
		sk.append(("box", (10, 4, 12), (x, 2, s * 40), BONE2))
	for x, z, s in ((-60, 18, 14), (-10, -24, 18), (40, 20, 16), (70, -14, 12), (-100, -18, 12), (10, 30, 10)):
		sk.append(("box", (s, s * 0.6, s), (x, s * 0.25, z), ROCK, {"rot": (8, x % 60, 6)}))
	k.prop("KaijuSkeleton", sk)
	# Distant wrecked skyline
	k.prop("Skyline", [("box", (50, 90, 50), (0, 45, 0), "5A5250"), ("wedge", (50, 24, 50), (0, 102, 0), "5A5250")])
	k.prop(
		"Smoke",
		[
			("box", (20, 8, 20), (0, 4, 0), ROCK, {"rot": (0, 20, 6)}),
			("ball", (26, 30, 26), (0, 18, 0), "4A4646"),
			("ball", (34, 36, 34), (6, 44, 4), "5E5856"),
			("ball", (40, 34, 40), (14, 74, 8), "746C68"),
		],
	)

	k.ground(DUST, margin=500)
	supports(k, SUPPORT)
	city, base = k.length * 0.55, k.length * 0.6
	ruins = ["Ruin0", "Ruin1", "Ruin2", "Ruin3", "Collapsed", "Collapsed"]
	# City half: debris and cars by the walls, ruined blocks behind, cranes clearing the wreckage
	row(k, 34, (-28, 28), ["Rubble", "Rubble", "Car0", "Car1", "Car2", "Pole"], 26, jitter=4, end=city)
	row(k, 140, (-30, 30), ["Barricade"], 27, jitter=10, start=90, end=city)
	row(k, 46, (-58, 58), ruins, 50, jitter=6, end=city)
	row(k, 60, (-100, 100), ruins + ["Rubble"], 88, jitter=12, end=city, scale=(0.9, 1.3))
	row(k, 420, (-82, 82), ["Crane"], 30, jitter=20, start=200, end=city)
	# Base half: barricades, a striped perimeter wall line, hangars, radar and masts inside
	row(k, 120, (-28, 28), ["Barricade", "Rubble"], 26, jitter=6, start=base)
	row(k, 40, (-40, 40), ["BaseWall"], 30, start=base)
	row(k, 90, (-90, 90), ["Hangar", "Barracks", "Barracks"], 60, jitter=8, start=base + 20)
	row(k, 180, (-62, 62), ["Radar", "Mast"], 50, jitter=10, start=base + 50)
	row(k, 70, (-140, 140), ["Barracks", "Hangar", "Rubble"], 110, jitter=12, start=base)
	k.field(90, ["Skyline", "Skyline", "Ruin1", "Ruin2"], clearance=170, margin=450, scale=(0.7, 1.5))
	k.field(26, ["Smoke"], clearance=120, margin=200, scale=(0.8, 1.6))
	# Landmarks: the skeleton across the blocks a third of the way in, the control tower over the base
	for f, off, s in ((0.3, -135, 1.5), (0.12, 150, 1.1)):  # lying parallel to the road, ribs toward it
		pos, yaw = k.beside(k.length * f, off)
		if k.clear_of_road(pos[0], pos[2], 120):
			k.place("KaijuSkeleton", (pos[0], -1.0, pos[2]), yaw + math.pi / 2, s)
	pos, yaw = k.beside(k.length * 0.78, 210)
	k.place("ControlTower", (pos[0], -1.0, pos[2]), yaw)
	# Late afternoon: low orange sun, warm haze at the horizon
	k.sky(
		[(0.0, "FFC890"), (0.03, "F2A070"), (0.1, "A8A8C0"), (0.3, "6A86C0"), (1.0, "4A64A8")],
		strength=0.8,
		sun=(4.5, "FFB878", 14, 235),
	)
