"""World 2 Track 1: Devil Hunter Tokyo (Saw Man). Night city of the devil hunters: narrow streets of low apartment
blocks, convenience stores, vending machines, power poles, neon signs with abstract shapes (no text, design doc 5),
and the hunters' headquarters as a tall stepped office tower on the horizon. Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

NAVY, ASPH, CONC, CONC2, BRICK = "14172B", "23252E", "8C8A86", "6C6A70", "7A4A3C"
NEON = ("FF3B6B", "3BE8FF", "FFD23F", "B45CFF", "FF8A2B")
WARM = "FFD9A0"


def build(k):
	# Apartment blocks of 2-5 floors with lit windows, a stair core and rooftop tanks
	for i, floors in enumerate((2, 3, 4, 5)):
		h = floors * 10
		parts = [
			("box", (28, h, 20), (0, h / 2, 0), (CONC, CONC2, BRICK, CONC)[i]),
			("box", (30, 1, 22), (0, h + 0.5, 0), "4A4A52"),
			("cyl", (4, 5, 4), (9, h + 3.5, 4), "9A9EA6", {"seg": 8}),
		]
		for f in range(floors):
			for x in (-9, -3, 3, 9):
				lit = (f * 4 + x + i) % 3 != 0
				parts.append(("box", (4, 4, 0.4), (x, 5 + f * 10, -10.1), WARM if lit else "1C2230", {"emit": 2.5 if lit else 0}))
			parts.append(("box", (26, 0.6, 2), (0, 10 * (f + 1) - 0.5, -11), "5A5C64"))  # balcony ledges
		k.prop("Apartment%d" % floors, parts)
	# Convenience store: glass front, bright interior, a striped band sign (colour bands only)
	k.prop(
		"Konbini",
		[
			("box", (30, 11, 18), (0, 5.5, 0), "E8E8E8"),
			("box", (26, 7, 0.4), (0, 4, -9.1), "F4FAFF", {"emit": 3}),
			("box", (30, 1.4, 0.5), (0, 9.4, -9.3), "2BB673", {"emit": 1.5}),
			("box", (30, 1.0, 0.5), (0, 8.2, -9.3), "FF8A2B", {"emit": 1.5}),
			("box", (30, 0.6, 19), (0, 11.3, 0), "BFBFBF"),
		],
	)
	# Vending machines (pair) and a power pole with crossbars and a transformer
	k.prop(
		"Vending",
		[
			("box", (3.2, 6, 2.6), (-1.8, 3, 0), "D8302F"),
			("box", (2.6, 3.4, 0.2), (-1.8, 3.8, -1.35), "F4FAFF", {"emit": 2}),
			("box", (3.2, 6, 2.6), (1.8, 3, 0), "2F6FD8"),
			("box", (2.6, 3.4, 0.2), (1.8, 3.8, -1.35), "F4FAFF", {"emit": 2}),
		],
	)
	k.prop(
		"Pole",
		[
			("cyl", (1.1, 34, 1.1), (0, 17, 0), "8E8E86", {"seg": 8}),
			("box", (9, 0.5, 0.5), (0, 31, 0), "6E6E66"),
			("box", (7, 0.5, 0.5), (0, 28, 0), "6E6E66"),
			("cyl", (2, 3, 2), (1.6, 25, 0), "7A7E84", {"seg": 8}),
		],
	)
	# Neon sign towers: a dark pole with stacked glowing shapes (abstract: bars, a ring, a diamond)
	for i, c in enumerate(NEON):
		k.prop(
			"Neon%d" % i,
			[
				("box", (1.2, 26, 1.2), (0, 13, 0), "1A1A22"),
				("box", (2.2, 12, 6), (0, 18, -2), "101018"),
				("box", (0.6, 3, 4.4), (-1.2, 21, -2), c, {"emit": 6}),
				("box", (0.6, 1.2, 4.4), (-1.2, 17, -2), NEON[(i + 2) % 5], {"emit": 6}),
				("box", (0.6, 2.2, 2.2), (-1.2, 14, -2), c, {"emit": 6, "rot": (45, 0, 0)}),
			],
		)
	# Street light: arm over the road edge, warm glow
	k.prop(
		"Lamp",
		[
			("cyl", (0.8, 16, 0.8), (0, 8, 0), "3A3C44", {"seg": 8}),
			("box", (0.6, 0.6, 5), (0, 16, -2.5), "3A3C44"),
			("box", (1.6, 0.6, 2.4), (0, 15.6, -5), WARM, {"emit": 8}),
		],
	)
	# The hunters' headquarters: a tall stepped office tower with lit floor bands and a red beacon
	hq = []
	for j, (w, h, y) in enumerate(((80, 70, 35), (60, 60, 100), (42, 50, 155), (24, 20, 190))):
		hq.append(("box", (w, h, w), (0, y, 0), ("5E6270", "565A68", "4E5260", "464A58")[j]))
		for b in range(int(h / 8)):
			hq.append(("box", (w + 0.4, 1.2, w + 0.4), (0, y - h / 2 + 4 + b * 8, 0), "9FC8FF", {"emit": 1.2}))
	hq.append(("ball", (4, 4, 4), (0, 203, 0), "FF2B2B", {"emit": 10}))
	k.prop("HQTower", hq)
	# Distant skyline block (cheap) for the horizon
	k.prop("Skyline", [("box", (60, 120, 60), (0, 60, 0), "1E2232"), ("box", (60.4, 2, 60.4), (0, 90, 0), "3BE8FF", {"emit": 1})])

	k.ground(ASPH, margin=500)
	# Street layer: sidewalk-side props tight to the walls, then the building rows
	k.along(30, (-26, 26), ["Lamp"], jitter=2)
	k.along(90, (-30, 30), ["Vending", "Pole", "Pole"], jitter=6, start=60)
	k.along(48, (-52, 52), ["Apartment2", "Apartment3", "Apartment4", "Apartment5", "Konbini"], jitter=4, start=30)
	k.along(70, (-34, 34), ["Neon0", "Neon1", "Neon2", "Neon3", "Neon4"], jitter=5, start=55)
	k.along(64, (-92, 92), ["Apartment3", "Apartment4", "Apartment5"], jitter=10, start=20)
	k.field(70, ["Skyline"], clearance=170, margin=450, scale=(0.6, 1.6))
	# HQ at the finish side of the plaza, on the horizon from most of the road
	pos, yaw = k.beside(k.length * 0.55, -260)
	k.place("HQTower", pos, yaw)
	k.sky([(0.0, "3A2A5A"), (0.12, "1C1A3A"), (0.5, "0A0C1C"), (1.0, "05060F")], strength=0.9, sun=(0.6, "8FA8FF", 35, 140))
	# A few warm point lights along the road so the street reads at night
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, WARM, energy=60000, radius=6)
		d += 160
