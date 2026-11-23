"""World 2 Track 9: Golden City (Frieren). The fortress city turned to gold by a demon's curse: steep-roofed townhouses,
round towers, trees and frozen people-shaped statues (no faces), all metallic gold, inside a high city wall, under a warm
sunset and a faint barrier dome over the whole city. Landmark: a golden clock tower with an abstract dial (no numerals)
near the finish. No symbols or text (design doc 5). Everything in-house, parts only. Proposed look; the owner approves
the render set (design doc 4.46)."""

import math

GOLD, GOLD2, GOLD3, GOLDD = "E8B84A", "D4A23A", "F4D27A", "9A7424"
SUNSET = "FFB070"


def g(color, rough=0.3):
	return {"metal": 1.0, "rough": rough}


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0, spin=False):
	"""kit.along, but every prop stands on the ground (y = -1) even on ramps, and never near another road stretch."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], abs(o) * 0.9):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw = k.rng.uniform(0, math.tau) if spin else yaw + (math.pi / 2 if off > 0 else -math.pi / 2)  # -Z faces the road, as kit.along
			k.place(k.rng.choice(names), (pos[0], y, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def house(floors, w, body, roof):
	"""A gold townhouse: body, steep gable roof (two wedges), darker window insets on the road side, a chimney."""
	h = floors * 9
	parts = [
		("box", (w, h, 18), (0, h / 2, 0), body, g(body)),
		("wedge", (w + 1, 10, 10), (0, h + 5, -5), roof, g(roof, 0.25)),
		("wedge", (w + 1, 10, 10), (0, h + 5, 5), roof, {"metal": 1.0, "rough": 0.25, "rot": (0, 180, 0)}),
		("box", (3, 8, 3), (w / 2 - 4, h + 6, 3), GOLDD, g(GOLDD)),
		("box", (w + 0.6, 1, 18.6), (0, h, 0), GOLD3, g(GOLD3)),
	]
	for f in range(floors):
		for x in range(-int(w / 2) + 4, int(w / 2) - 2, 6):
			parts.append(("box", (3, 4.5, 0.6), (x + 1, 4.5 + f * 9, -9.1), GOLDD, g(GOLDD, 0.5)))
	parts.append(("box", (5, 7, 0.8), (0, 3.5, -9.2), GOLDD, g(GOLDD, 0.5)))  # door
	return parts


def person(pose):
	"""A frozen townsperson, faceless: legs, torso, head, arms in one of three poses (walk, reach up, carry)."""
	arm_l, arm_r = {0: ((0, 0, 20), (0, 0, -20)), 1: ((0, 0, 160), (0, 0, -150)), 2: ((-70, 0, 0), (-70, 0, 0))}[pose]
	leg_l, leg_r = ((20, 0, 0), (-20, 0, 0)) if pose == 0 else ((0, 0, 0), (0, 0, 0))
	parts = [
		("box", (4, 1.2, 4), (0, 0.6, 0), GOLDD, g(GOLDD)),
		("box", (1.4, 4.6, 1.4), (-0.8, 3.5, 0), GOLD2, {"metal": 1, "rough": 0.3, "rot": leg_l}),
		("box", (1.4, 4.6, 1.4), (0.8, 3.5, 0), GOLD2, {"metal": 1, "rough": 0.3, "rot": leg_r}),
		("box", (3.2, 4.2, 1.8), (0, 7.6, 0), GOLD, g(GOLD)),
		("ball", (2.4, 2.6, 2.4), (0, 10.9, 0), GOLD3, g(GOLD3)),
		("box", (1.1, 4, 1.1), (-2.2, 7.6, 0), GOLD2, {"metal": 1, "rough": 0.3, "rot": arm_l}),
		("box", (1.1, 4, 1.1), (2.2, 7.6, 0), GOLD2, {"metal": 1, "rough": 0.3, "rot": arm_r}),
	]
	if pose == 2:
		parts.append(("box", (3, 2, 2.4), (0, 7.6, -2.6), GOLD3, g(GOLD3)))  # a carried crate
	return parts


def build(k):
	for i, (floors, w) in enumerate(((2, 22), (3, 20), (4, 24), (3, 28))):
		k.prop("House%d" % i, house(floors, w, (GOLD, GOLD2, GOLD, GOLD2)[i], (GOLD3, GOLDD, GOLDD, GOLD3)[i]))
	k.prop(
		"Tower",
		[
			("cyl", (16, 46, 16), (0, 23, 0), GOLD2, {"metal": 1, "rough": 0.3, "seg": 12}),
			("cyl", (18, 3, 18), (0, 47.5, 0), GOLD3, {"metal": 1, "rough": 0.3, "seg": 12}),
			("cone", (19, 22, 19), (0, 60, 0), GOLDD, {"metal": 1, "rough": 0.25, "seg": 12}),
			("box", (3, 6, 0.6), (0, 36, -8), "6A4A14", g("6A4A14", 0.5)),
		],
	)
	for i in range(3):
		k.prop("Person%d" % i, person(i))
	k.prop(
		"Tree",
		[
			("cyl", (2.4, 12, 2.4), (0, 6, 0), GOLDD, {"metal": 1, "rough": 0.4, "seg": 8}),
			("ball", (13, 11, 13), (0, 15, 0), GOLD3, g(GOLD3, 0.35)),
			("ball", (8, 7, 8), (3, 20, 2), GOLD, g(GOLD, 0.35)),
		],
	)
	k.prop(
		"TreeTall",
		[
			("cyl", (2, 10, 2), (0, 5, 0), GOLDD, {"metal": 1, "rough": 0.4, "seg": 8}),
			("cone", (11, 18, 11), (0, 16, 0), GOLD, {"metal": 1, "rough": 0.35, "seg": 8}),
			("cone", (8, 12, 8), (0, 24, 0), GOLD3, {"metal": 1, "rough": 0.35, "seg": 8}),
		],
	)
	k.prop(
		"Lamp",
		[
			("cyl", (0.8, 14, 0.8), (0, 7, 0), GOLDD, {"metal": 1, "rough": 0.3, "seg": 8}),
			("box", (2.2, 3, 2.2), (0, 15, 0), "FFE6A8", {"emit": 4}),
			("cone", (3.2, 2, 3.2), (0, 17.5, 0), GOLDD, {"metal": 1, "rough": 0.3, "seg": 6}),
		],
	)
	k.prop(
		"Fountain",
		[
			("cyl", (18, 2.5, 18), (0, 1.25, 0), GOLD2, {"metal": 1, "rough": 0.3, "seg": 12}),
			("cyl", (3, 8, 3), (0, 6, 0), GOLD, {"metal": 1, "rough": 0.3, "seg": 8}),
			("cyl", (9, 1.2, 9), (0, 9.5, 0), GOLD3, {"metal": 1, "rough": 0.3, "seg": 10}),
			("ball", (3, 3, 3), (0, 11.5, 0), GOLD3, g(GOLD3)),
		],
	)
	# City wall: thick gold rampart with crenellations and a squat turret
	wall = [("box", (92, 30, 10), (0, 15, 0), GOLD2, g(GOLD2, 0.4)), ("cyl", (16, 40, 16), (45, 20, 0), GOLD, {"metal": 1, "rough": 0.35, "seg": 10})]
	for x in range(-42, 40, 8):
		wall.append(("box", (4, 4, 10.6), (x, 32, 0), GOLD3, g(GOLD3, 0.4)))
	k.prop("CityWall", wall)
	# Landmark: the clock tower (lord's tower): stepped square shaft, abstract dial (ring + two hands), spire
	clock = [
		("box", (40, 60, 40), (0, 30, 0), GOLD2, g(GOLD2)),
		("box", (30, 70, 30), (0, 95, 0), GOLD, g(GOLD)),
		("box", (34, 4, 34), (0, 131, 0), GOLD3, g(GOLD3)),
		("box", (24, 26, 24), (0, 146, 0), GOLD2, g(GOLD2)),
		("cone", (30, 50, 30), (0, 184, 0), GOLDD, {"metal": 1, "rough": 0.25, "seg": 4, "rot": (0, 45, 0)}),
		("ball", (5, 5, 5), (0, 211, 0), GOLD3, g(GOLD3, 0.15)),
	]
	for face in range(4):
		a = face * 90
		dx, dz = math.sin(math.radians(a)), -math.cos(math.radians(a))
		c = (dx * 15.4, 110, dz * 15.4)
		clock += [
			("cyl", (20, 0.8, 20), c, "FFF4D0", {"rot": (90, a, 0), "seg": 16, "emit": 0.6}),
			("box", (1.4, 8, 0.6), (c[0] + dx * 0.6, 113, c[2] + dz * 0.6), "5A3C10", {"rot": (0, a, 0)}),
			("box", (6, 1.4, 0.6), (c[0] + dx * 0.6 + 3 * dz * -1, 110, c[2] + dz * 0.6 + 3 * dx), "5A3C10", {"rot": (0, a, 0)}),
		]
	for x in (-22, 22):
		for z in (-22, 22):
			clock.append(("cyl", (8, 70, 8), (x, 35, z), GOLD, {"metal": 1, "rough": 0.3, "seg": 8}))
			clock.append(("cone", (10, 16, 10), (x, 78, z), GOLDD, {"metal": 1, "rough": 0.25, "seg": 8}))
	k.prop("ClockTower", clock)
	# The barrier: a huge faint dome over the whole city
	k.prop("Barrier", [("ball", (2, 2, 2), (0, 0, 0), "FFE9B0", {"alpha": 0.12, "rough": 0.1, "emit": 0.15})])

	k.ground("B8923A", margin=600, rough=0.5)
	ground_along(k, 100, (-26, 26), ["Lamp"], jitter=1)
	ground_along(k, 80, (-30, 30), ["Person0", "Person1", "Person2"], jitter=4, start=50, spin=True)
	ground_along(k, 120, (-36, 36), ["Tree", "TreeTall", "Person0", "Person1"], jitter=4, start=30)
	ground_along(k, 46, (-54, 54), ["House0", "House1", "House2", "House3", "House1"], jitter=3, start=20)
	ground_along(k, 300, (-40, 40), ["Fountain"], jitter=10, start=160)
	ground_along(k, 160, (-84, 84), ["Tower", "House2", "House3", "TreeTall"], jitter=8, start=60)
	ground_along(k, 92, (-150, 150), ["CityWall"], jitter=0, start=10)
	k.field(60, ["Tower", "House2", "House3", "Tree"], clearance=200, margin=300, scale=(0.9, 1.4))
	pos, yaw = k.beside(k.length * 0.95, -160)
	k.place("ClockTower", (pos[0], -1.0, pos[2]), yaw, 1.3)
	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	k.place("Barrier", (c.x, -60, c.z), 0.0, span * 0.85)
	k.sky([(0.0, "FFC890"), (0.06, "FF9A5A"), (0.2, "D07068"), (0.5, "7A4A80"), (1.0, "2A2A5A")], strength=1.1, sun=(3.5, SUNSET, 12, 250))
