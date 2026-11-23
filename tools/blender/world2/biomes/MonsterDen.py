"""World 2 Track 8: Monster Den (One Punch). The monsters' underground lair beneath a ruined city: a vast purple-black
cavern with a rock ceiling over long stretches of the road, stalactites, rib-bone bridges over the road, glowing toxic
green pits, rusted pipe runs, crystal and fungus glow, and a stepped shrine over a magma ring as the landmark near the
finish. No symbols or text (design doc 5). Everything in-house, parts only. Proposed look; the owner approves the render
set (design doc 4.46)."""

import math

ROCK, ROCK2, ROCK3, FLOOR = "2A1F33", "3A2A45", "1C1524", "1E1726"
BONE, BONE2 = "E6DCC4", "C8BC9E"
TOXIC, TOXIC2 = "7CFF3A", "B8FF4A"
RUST, RUST2 = "8A4A2A", "5E3A2A"
PURPLE, MAGMA = "B45CFF", "FF6A1A"
CEIL_UNDER = 34  # underside of every overhead piece above the road (rule: >= 14)


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0):
	"""kit.along, but every prop stands on the cavern floor (y = -1) even where the road climbs a ramp."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], abs(o) * 0.9):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw += (math.pi / 2 if off > 0 else -math.pi / 2)  # turn -Z from along the road to face it, as kit.along
			k.place(k.rng.choice(names), (pos[0], y, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def covered(k, d):
	"""The ceiling covers the road except for three open chasm stretches where the purple sky shows through."""
	f = d / k.length
	return not (0.18 < f < 0.26 or 0.47 < f < 0.53 or 0.78 < f < 0.84)


def build(k):
	# Ceiling slab: spans the road, underside CEIL_UNDER above it; stalactites hang only outside the 24-stud lane
	ceil = [
		("box", (220, 14, 66), (0, CEIL_UNDER + 7, 0), ROCK3),
		("box", (60, 10, 50), (-70, CEIL_UNDER + 1, 6), ROCK),
		("box", (50, 8, 40), (75, CEIL_UNDER + 2, -8), ROCK),
		("cone", (40, 22, 30), (-40, CEIL_UNDER + 24, -10), ROCK, {"seg": 6}),
		("cone", (30, 16, 24), (60, CEIL_UNDER + 21, 12), ROCK2, {"seg": 6}),
		("box", (5, 0.6, 50), (10, CEIL_UNDER + 14.2, 0), TOXIC, {"emit": 3, "rot": (0, 20, 0)}),
		("box", (4, 0.6, 40), (-80, CEIL_UNDER + 14.2, 0), PURPLE, {"emit": 3, "rot": (0, -30, 0)}),
	]
	for x, z, h in ((-34, -12, 22), (-48, 14, 30), (36, 10, 26), (54, -18, 34), (-90, -20, 40), (96, 18, 36), (-14, 18, 12)):
		ceil.append(("cone", (6 + h / 4, h, 6 + h / 4), (x, CEIL_UNDER - h / 2 + 1, z), ROCK2, {"rot": (180, 0, 0), "seg": 6}))
	ceil.append(("cone", (6, 14, 6), (8, CEIL_UNDER - 6, 20), ROCK2, {"rot": (180, 0, 0), "seg": 6}))  # short tip above the lane
	k.prop("Ceiling", ceil)
	# Rock pillars rising to the ceiling, and stalagmite clusters
	k.prop(
		"Pillar",
		[
			("cyl", (16, 10, 16), (0, 5, 0), ROCK2, {"seg": 7, "taper": 0.8}),
			("cyl", (12, 16, 12), (0, 18, 0), ROCK, {"seg": 7, "taper": 0.7}),
			("cyl", (9, 14, 9), (0, 33, 0), ROCK2, {"seg": 7, "taper": 1.4}),
			("box", (3, 6, 0.6), (0, 10, -7.6), PURPLE, {"emit": 3}),  # crystal vein
		],
	)
	k.prop(
		"Stalagmites",
		[
			("cone", (10, 22, 10), (0, 11, 0), ROCK2, {"seg": 6}),
			("cone", (7, 14, 7), (7, 7, 3), ROCK, {"seg": 6}),
			("cone", (6, 10, 6), (-6, 5, -2), ROCK3, {"seg": 6}),
		],
	)
	# Toxic pit: a glowing green pool ringed with rocks, bubbles on top
	pit = [("cyl", (30, 0.6, 22), (0, 0.3, 0), TOXIC, {"emit": 4, "seg": 12})]
	for i in range(8):
		a = i * math.tau / 8
		pit.append(("box", (6, 3 + i % 3, 5), (16 * math.cos(a), 1.5, 12 * math.sin(a)), ROCK2, {"rot": (0, math.degrees(a), 0)}))
	for x, z in ((-5, 3), (4, -4), (7, 5)):
		pit.append(("ball", (2.4, 2.4, 2.4), (x, 1, z), TOXIC2, {"emit": 5}))
	k.prop("ToxicPit", pit)
	# Rusted pipe run on stands beside the road, with a valve wheel; and a tall vertical pipe stack
	k.prop(
		"PipeRun",
		[
			("cyl", (3, 46, 3), (0, 7, 0), RUST, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6, "rough": 0.6}),
			("cyl", (2, 46, 2), (0, 4, 3.5), RUST2, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6, "rough": 0.6}),
			("box", (1.4, 7, 8), (-16, 3.5, 1.5), "3A3036"),
			("box", (1.4, 7, 8), (16, 3.5, 1.5), "3A3036"),
			("cyl", (4, 4, 4), (0, 7, 0), RUST2, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6}),
			("cyl", (4, 0.6, 4), (0, 11, 0), "B8B0A8", {"seg": 8, "metal": 0.8}),
		],
	)
	k.prop(
		"PipeStack",
		[
			("cyl", (4, 34, 4), (0, 17, 0), RUST, {"seg": 8, "metal": 0.6, "rough": 0.6}),
			("cyl", (3, 26, 3), (4.5, 13, 1), RUST2, {"seg": 8, "metal": 0.6, "rough": 0.6}),
			("cyl", (5, 1.2, 5), (0, 22, 0), "4A3A30", {"seg": 8}),
			("box", (2, 2, 2), (0, 30, -2.4), TOXIC, {"emit": 4}),
		],
	)
	# Rib-bone bridge over the road: bone legs outside the lane, an arch of bone above CEIL_UNDER - 2 = 16
	bridge = [
		("cyl", (5, 18, 5), (-32, 8, 0), BONE, {"seg": 8, "taper": 0.8}),
		("cyl", (5, 18, 5), (32, 8, 0), BONE, {"seg": 8, "taper": 0.8}),
		("ball", (8, 8, 8), (-32, 18, 0), BONE2),
		("ball", (8, 8, 8), (32, 18, 0), BONE2),
		("box", (60, 4, 10), (0, 20, 0), BONE),
	]
	for x in (-24, -12, 0, 12, 24):
		bridge.append(("ball", (7, 5, 7), (x, 24, 0), BONE2))  # vertebrae on the deck
	for x in (-18, 6, 18):
		bridge.append(("cone", (2.4, 10, 2.4), (x, 27, 0), BONE, {"seg": 6, "rot": (0, 0, 15 if x > 0 else -15)}))
	k.prop("BoneBridge", bridge)
	# Bone heap and rib cage beside the road
	k.prop(
		"Ribs",
		[("cyl", (2.2, 22, 2.2), (0, 9, z), BONE, {"seg": 6, "rot": (0, 0, 25)}) for z in (-9, -3, 3, 9)]
		+ [("cyl", (3, 26, 3), (0, 3, 5), BONE2, {"seg": 6, "rot": (0, 0, 90)}), ("ball", (6, 6, 6), (-3, 3, 14), BONE2)],
	)
	# Glow fungus / crystal cluster (purple and green)
	k.prop(
		"Crystals",
		[
			("cone", (4, 14, 4), (0, 7, 0), PURPLE, {"emit": 4, "seg": 5}),
			("cone", (3, 9, 3), (4, 4.5, 2), PURPLE, {"emit": 4, "seg": 5, "rot": (0, 0, -20)}),
			("cone", (3, 8, 3), (-3, 4, -2), TOXIC2, {"emit": 3, "seg": 5, "rot": (0, 0, 20)}),
		],
	)
	# Road lamp: a rock post with a caged green lamp
	k.prop(
		"Lamp",
		[
			("box", (2, 12, 2), (0, 6, 0), "3A3036"),
			("box", (0.8, 0.8, 4), (0, 12, -2), "3A3036"),
			("ball", (2.6, 2.6, 2.6), (0, 11, -4), TOXIC2, {"emit": 8}),
		],
	)
	# Cavern walls: big rock masses enclosing the road far out
	for i in range(3):
		h = (60, 80, 50)[i]
		k.prop(
			"CaveWall%d" % i,
			[
				("box", (90, h, 50), (0, h / 2, 0), (ROCK, ROCK3, ROCK2)[i]),
				("wedge", (90, 30, 30), (0, 15, -40), (ROCK2, ROCK, ROCK3)[i]),
				("box", (40, h * 0.6, 30), (30, h * 0.8, 10), (ROCK3, ROCK2, ROCK)[i]),
			],
		)
	# Landmark: the deep shrine, a stepped dark pyramid on a magma ring with glowing purple braziers
	shrine = [("cyl", (300, 3, 300), (0, 1.5, 0), MAGMA, {"emit": 6, "seg": 24})]
	for j, (w, h) in enumerate(((220, 26), (170, 24), (120, 22), (76, 20), (40, 18))):
		y = sum(hh for _, hh in ((220, 26), (170, 24), (120, 22), (76, 20), (40, 18))[:j]) + h / 2 + 3
		shrine.append(("box", (w, h, w), (0, y, 0), (ROCK3, ROCK, ROCK3, ROCK, ROCK2)[j]))
	shrine += [
		("box", (16, 30, 16), (0, 128, 0), ROCK3),
		("ball", (14, 14, 14), (0, 150, 0), PURPLE, {"emit": 10}),
		("box", (30, 50, 6), (0, 28, -113), "0A060E"),  # dark doorway
	]
	for x in (-90, 90):
		for z in (-90, 90):
			shrine.append(("cyl", (8, 40, 8), (x, 46, z), ROCK2, {"seg": 8}))
			shrine.append(("ball", (9, 9, 9), (x, 70, z), MAGMA, {"emit": 8}))
	k.prop("Shrine", shrine)

	k.ground(FLOOR, margin=500, rough=0.9)
	# Ceiling over the covered stretches, spaced to its 66-stud depth so it reads as one roof
	d = 30
	while d < k.length - 40:
		if covered(k, d):
			pos, yaw = k.beside(d, 0, 1.0)
			k.place("Ceiling", pos, yaw)
		d += 64
	# Bone bridges inside the open chasm stretches and at intervals elsewhere
	d = 300
	while d < k.length - 200:
		pos, yaw = k.beside(d, 0, 1.0)
		k.place("BoneBridge", pos, yaw)
		d += 520 if covered(k, d) else 160
	ground_along(k, 40, (-26, 26), ["Lamp"], jitter=2)
	ground_along(k, 140, (-34, 34), ["PipeRun", "PipeRun", "PipeStack"], jitter=4, start=70)
	ground_along(k, 110, (-56, 56), ["ToxicPit", "Stalagmites", "Ribs", "Crystals", "Crystals"], jitter=8, start=50)
	ground_along(k, 96, (-82, 82), ["Pillar", "Stalagmites", "PipeStack"], jitter=10, start=20, scale=(0.9, 1.3))
	ground_along(k, 80, (-185, 185), ["CaveWall0", "CaveWall1", "CaveWall2"], jitter=12, start=10, scale=(0.9, 1.3))
	k.field(60, ["CaveWall0", "CaveWall1", "Pillar", "ToxicPit"], clearance=190, margin=450, scale=(0.8, 1.6))
	pos, yaw = k.beside(k.length * 0.93, 280)
	k.place("Shrine", (pos[0], -1.0, pos[2]), yaw)
	k.sky([(0.0, "3A1A4A"), (0.15, "24123A"), (0.5, "120A1C"), (1.0, "07040C")], strength=1.4, sun=(1.6, "C8A0FF", 40, 120))
	# Green-white point lights along the road so it reads under the ceiling
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 24)
		k.light(pos, "D8FFC0" if int(d / 140) % 2 else "E0C8FF", energy=80000, radius=6)
		d += 140
