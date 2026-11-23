"""World 2 Track 2: Demon King's Castle (Solo Levelup, enemy Barran). The demon castle of the dungeon tower: black stone
ramparts with crenellations, round towers capped by needle spires, torch braziers, glowing red fissures in the dark
ground, floating rock islands carrying small spires, and the castle keep itself as a tiered black fortress with a lit
red gate on the horizon, all under a blood-red sky. The two route slopes are stone stair climbs (filled from the
ground, as TrackBuilder does). No crests, symbols or text (design doc 5). Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

STONE, STONE2, STONE3, SLATE = "3A3346", "4A4258", "28222F", "5A526C"
EMBER, FLAME, BLOOD = "FF4A1C", "FFB347", "C3121E"
DARK = "120F15"


def _fill(k, color):
	"""Stone under the raised road (the game's hill supports), so the stair climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			h = p.y - 0.5 + 1.0
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width - 1, step + 0.5, h)
		d += step


def _grounded(k):
	"""Make k.along place on the ground (y = -1) even where the road climbs, -Z facing the road; returns the original
	beside."""
	orig = k.beside

	def beside(d, off, y=0.0):
		(x, _, z), yaw = orig(d, off, y)
		return (x, -1.0 + y, z), yaw  # kit.along now turns -Z to face the road

	k.beside = beside
	return orig


def build(k):
	# Rampart: a black wall run with merlons and red arrow slits, faced to the road
	parts = [("box", (40, 16, 8), (0, 8, 0), STONE), ("box", (42, 1.5, 9), (0, 16.5, 0), SLATE)]
	for x in range(-18, 20, 6):
		parts.append(("box", (3.4, 3.5, 8.6), (x, 19, 0), STONE2))
	for x in (-12, 0, 12):
		parts.append(("box", (1, 4, 0.4), (x, 10, -4.1), BLOOD, {"emit": 3}))
	k.prop("Rampart", parts)
	# Round towers with a needle spire and slit windows (two heights)
	for name, h in (("TowerLow", 34), ("TowerTall", 52)):
		parts = [
			("cyl", (14, h, 14), (0, h / 2, 0), STONE2, {"seg": 12}),
			("cyl", (16, 2, 16), (0, h + 1, 0), SLATE, {"seg": 12}),
			("cone", (15, h * 0.7, 15), (0, h + 2 + h * 0.35, 0), STONE3, {"seg": 12}),
			("ball", (1.6, 1.6, 1.6), (0, h + 2 + h * 0.7, 0), BLOOD, {"emit": 6}),
		]
		for y in range(10, h - 4, 10):
			parts.append(("box", (1.2, 4, 0.6), (0, y, -7), EMBER, {"emit": 4}))
		k.prop(name, parts)
	# Torch brazier on a stone post
	k.prop(
		"Torch",
		[
			("box", (2.4, 9, 2.4), (0, 4.5, 0), STONE2),
			("cyl", (4, 1.6, 4), (0, 9.8, 0), "4A4452", {"seg": 8, "taper": 1.4}),
			("cone", (2.8, 4.5, 2.8), (0, 12.6, 0), FLAME, {"seg": 6, "emit": 8}),
			("cone", (1.6, 3, 1.6), (0, 13.6, 0), "FFF0B0", {"seg": 6, "emit": 10}),
		],
	)
	# Gothic obelisk: tapered black shaft with a red core line
	k.prop(
		"Obelisk",
		[
			("box", (8, 3, 8), (0, 1.5, 0), SLATE),
			("cone", (6, 36, 6), (0, 21, 0), STONE3, {"seg": 4, "taper": 0.25}),
			("box", (0.6, 20, 6.2), (0, 15, 0), BLOOD, {"emit": 2.5, "rot": (0, 45, 0)}),
		],
	)
	# Jagged black rock and a ground fissure glowing red
	k.prop("Rock", [("cone", (16, 14, 14), (0, 6, 0), STONE, {"seg": 5, "taper": 0.3}), ("cone", (9, 10, 9), (6, 4, 3), STONE2, {"seg": 5, "taper": 0.2})])
	k.prop("Fissure", [("box", (3, 0.3, 40), (0, 0.15, 0), EMBER, {"emit": 5}), ("box", (2, 0.3, 18), (6, 0.15, 14), BLOOD, {"emit": 5, "rot": (0, 35, 0)})])
	# Floating spire island: an upside-down rock cone with a small tower and spire on top
	k.prop(
		"Island",
		[
			("cone", (40, 34, 40), (0, -17, 0), STONE, {"seg": 7, "rot": (180, 0, 0)}),
			("cyl", (42, 3, 42), (0, 1.5, 0), STONE2, {"seg": 7}),
			("cyl", (10, 24, 10), (4, 15, 2), STONE2, {"seg": 10}),
			("cone", (11, 20, 11), (4, 37, 2), STONE3, {"seg": 10}),
			("cone", (6, 14, 6), (-10, 10, -6), STONE3, {"seg": 6}),
			("ball", (1.4, 1.4, 1.4), (4, 47.5, 2), BLOOD, {"emit": 6}),
		],
	)
	# The Demon King's Castle keep: tiered black fortress, ring of spire towers, a central needle and a red gate
	keep = [
		("box", (220, 10, 160), (0, 5, 0), SLATE),
		("box", (180, 60, 120), (0, 40, 0), STONE),
		("box", (120, 60, 84), (0, 100, 0), STONE2),
		("box", (70, 60, 50), (0, 160, 0), STONE),
		("cone", (54, 120, 54), (0, 250, 0), STONE3, {"seg": 8}),
		("ball", (8, 8, 8), (0, 312, 0), BLOOD, {"emit": 10}),
		("box", (40, 44, 2), (0, 32, -60.5), BLOOD, {"emit": 4}),  # gate glow
		("box", (52, 6, 4), (0, 57, -61), SLATE),
	]
	for x, z, h in ((-90, -60, 110), (90, -60, 110), (-90, 60, 110), (90, 60, 110), (-60, -42, 150), (60, -42, 150), (-35, -25, 200), (35, -25, 200)):
		keep.append(("cyl", (22, h, 22), (x, h / 2, z), STONE2, {"seg": 10}))
		keep.append(("cone", (24, h * 0.55, 24), (x, h + h * 0.275, z), STONE3, {"seg": 10}))
		keep.append(("ball", (3, 3, 3), (x, h + h * 0.55 + 1, z), BLOOD, {"emit": 8}))
	for tier, (w, y, z) in enumerate(((180, 70, 60), (120, 130, 42), (70, 190, 25))):
		for j in range(-2, 3):
			keep.append(("box", (3, 10, 1), (j * w / 6, y - 20, -z - 0.6), EMBER, {"emit": 4}))
	k.prop("Keep", keep)
	k.prop("Spire", [("cyl", (24, 90, 24), (0, 45, 0), STONE3, {"seg": 8}), ("cone", (26, 70, 26), (0, 125, 0), STONE, {"seg": 8})])

	k.ground("1F1A24", margin=550)
	_fill(k, "2A2530")
	orig = _grounded(k)
	k.along(36, (-27, 27), ["Torch"], jitter=1)
	k.along(44, (-46, 46), ["Rampart"], jitter=0, start=30)
	k.along(132, (-68, 68), ["TowerLow", "TowerTall", "TowerLow"], jitter=8, start=60)
	k.along(160, (-32, 32), ["Obelisk"], jitter=2, start=75)
	k.along(54, (-95, 95), ["Rock", "TowerLow", "Rock", "Obelisk"], jitter=18, start=20, face_road=False)
	k.beside = orig
	k.field(70, ["Fissure"], clearance=60, margin=300)
	k.field(60, ["Rock", "Obelisk"], clearance=120, margin=450, scale=(0.8, 2.2))
	k.field(26, ["Spire"], clearance=220, margin=500, scale=(0.7, 1.5))
	# Floating islands above the scenery, never over the road
	placed, tries = 0, 0
	while placed < 34 and tries < 1000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 400, k.hi.x + 400)
		z = k.rng.uniform(k.lo.z - 400, k.hi.z + 400)
		if k.clear_of_road(x, z, 70):
			k.place("Island", (x, k.rng.uniform(70, 170), z), k.rng.uniform(0, math.tau), k.rng.uniform(0.6, 1.4))
			placed += 1
	pos, yaw = k.beside(k.length * 0.5, -330)
	k.place("Keep", (pos[0], -1.0, pos[2]), yaw)
	k.sky([(0.0, "FF3A1E"), (0.1, "B3121C"), (0.4, "5A0810"), (1.0, "1A0306")], strength=0.7, sun=(2.6, "EAD6FF", 32, 210))
	# Ember-red lamps along the road so it reads in the red dusk
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, "FF8A5A", energy=50000, radius=6)
		d += 160
