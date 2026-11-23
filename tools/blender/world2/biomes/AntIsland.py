"""World 2 Track 7: Ant Island (Solo Levelup). Rebuilt 2026-11-23 for a closer read of the source, the island raid
against the ant colony (refs and landmark list: docs/world2_refs/AntIsland.md):
- Hallasan (hero, infield): the island's broad green shield volcano with a rocky summit, a crater lake, small parasitic
  cones on its flanks and ant tunnel holes dug into its slopes.
- Nest (hero, dead ahead of the runner at one review point): the colony's giant earthen mound, honeycombed with tunnel
  mouths, chimney spires, a breach crater at the top and pale spiky ants with red eyes on it.
- Chamber (hero, beside the road): the queen's chamber opened up, a dark green cave mouth with stalactites over a floor
  of glowing blue eggs and one big hatched egg.
- Choga / Ruin / Batdam: the abandoned island villages, thatched stone houses with rope-tied roofs, stone gate posts and
  a stone grandfather statue, a ruined concrete coast hotel, and black lava-stone field walls along the road.
- Camp / Ship: the hunters' raid camp (tents, helicopter, floodlights, crates) and the blockade ships ringing the island.
- Mound / Cliff / Brush: ant mounds, basalt column shore cliffs, pines and camellia brush on the overgrown island.
Everything in-house, parts only; generic ant shapes; no crest or text (design doc 5). Proposed look; the owner
approves the render set (design doc 4.46)."""

import math

import bpy

BASALT, BASALT2, BASALT3 = "2E2E32", "3E3E44", "222226"
SOIL, SOIL2, SOIL3 = "7A5E40", "634A32", "8E7250"
HOLE, LIP = "0C0A0C", "54402C"
GRASS, GRASS2, GRASS3 = "4A6A34", "3A5A2C", "6A7A44"
PINE, PINE2, CAMEL, BLOOM = "24402A", "2E5232", "1E3A22", "C42A3A"
THATCH, THATCH2, ROPE = "B49A64", "9A8050", "5A4A32"
ANT, ANT2, EYE = "E4E4EA", "B8B8C4", "E02030"
EGG, EGG2, CAVE, CAVE2 = "4AB8FF", "9ADCFF", "1E2E2A", "2C3E36"
CONC, CONC2, WIN = "8A8679", "6E6A60", "22262C"
OLIVE, OLIVE2, CRATE, STEEL = "4E5A3A", "3E4A2E", "7A6440", "6A7078"
HULL, HULL2 = "6E767E", "4E565E"
OCEAN, SUPPORT, LAMP = "1C4260", "3A2E24", "FFF0D0"


def _row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True, skip=()):
	"""Props on the ground beside the road (-Z facing it unless face_road is off), skipping any spot within `clear` of
	another part of the looping road and any span in `skip`."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			dd = d + k.rng.uniform(-jitter, jitter)
			if any(a <= dd <= b for a, b in skip):
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(dd, o)
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def _road_dist(k, x, z):
	step = max(1, len(k.wps) // 600)
	return min(math.hypot(w.x - x, w.z - z) for w in k.wps[::step])


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


def _ant(p, pos, yaw=0.0, s=1.0, tilt=0.0):
	"""A generic giant ant: pale three-part body, spiked back, six legs, mandibles, red eyes. Faces -Z at yaw 0."""
	x0, y0, z0 = pos
	c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

	def at(x, y, z):
		return (x0 + (x * c + z * sn) * s, y0 + y * s, z0 + (-x * sn + z * c) * s)

	o = {"rot": (tilt, yaw, 0)}
	p.append(("ball", (5 * s, 4 * s, 8 * s), at(0, 4.5, 5), ANT2, dict(o, subdiv=1)))
	p.append(("ball", (4 * s, 3.6 * s, 6 * s), at(0, 5, -1.5), ANT, dict(o, subdiv=1)))
	p.append(("ball", (4.4 * s, 3.6 * s, 4.4 * s), at(0, 5.4, -6), ANT, dict(o, subdiv=1)))
	for ex in (-1.1, 1.1):
		p.append(("ball", (1 * s, 1 * s, 1 * s), at(ex, 6.2, -7.8), EYE, {"emit": 6, "subdiv": 1}))
		p.append(("cone", (0.8 * s, 3 * s, 0.8 * s), at(ex * 1.2, 3.8, -9), ANT2, {"seg": 4, "rot": (-80, yaw - ex * 20, 0)}))
		p.append(("box", (0.3 * s, 0.3 * s, 6 * s), at(ex * 1.4, 8.5, -8), ANT2, {"rot": (-40, yaw + ex * 15, 0)}))
	for sp in (-3, -0.5, 2):
		p.append(("cone", (1 * s, 3 * s, 1 * s), at(0, 7, sp), ANT, {"seg": 4, "rot": (tilt, yaw, 0)}))
	for lz in (-3, -1.5, 0):
		for sx in (-1, 1):
			p.append(("box", (7 * s, 0.6 * s, 0.6 * s), at(sx * 4, 5.5, lz), ANT2, {"rot": (0, yaw + lz * 8 * sx, sx * -25)}))
			p.append(("box", (0.6 * s, 6 * s, 0.6 * s), at(sx * 7.6, 2.6, lz * 1.6), ANT2, {"rot": (0, yaw, sx * 12)}))


def _hole(p, pos, r, ang, tilt=-12):
	"""A tunnel mouth on a slope facing outward at azimuth `ang` (radians): raised soil lip, black opening."""
	x, y, z = pos
	yaw = -math.degrees(ang)
	p.append(("cyl", (r * 2.6, 1.6, r * 2.0), (x, y, z), LIP, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))
	p.append(("cyl", (r * 1.8, 1.0, r * 1.3), (x + math.sin(ang) * 0.6, y, z - math.cos(ang) * 0.6), HOLE, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))


def _hallasan(k):
	p = []
	for i, (r, h, col) in enumerate(((760, 70, GRASS2), (600, 80, GRASS), (440, 80, GRASS2), (300, 60, GRASS3), (190, 40, "7E7A60"))):
		y = sum((70, 80, 80, 60, 40)[:i])
		p.append(("cone", (r * 2, h, r * 2), (0, y + h / 2, 0), col, {"seg": 22, "taper": [600, 440, 300, 190, 120][i] / r}))
	top = 330
	p.append(("cyl", (250, 14, 250), (0, top + 7, 0), "8A8478", {"seg": 18, "taper": 0.9}))
	for i in range(12):
		a = i * math.tau / 12
		p.append(("box", (40, 10 + (i * 7 % 5) * 3, 16), (math.sin(a) * 104, top + 18, -math.cos(a) * 104), "9A9488", {"rot": (0, -math.degrees(a), 0)}))
	p.append(("cyl", (170, 2, 170), (0, top + 14.5, 0), "3E8A9A", {"seg": 18, "rough": 0.2, "emit": 0.15}))
	# parasitic cones on the flanks
	for i, (a, rr, h, w) in enumerate(((0.4, 560, 70, 150), (1.6, 620, 50, 120), (2.7, 520, 80, 160), (3.9, 650, 45, 110), (5.0, 560, 65, 140), (5.8, 680, 40, 100))):
		x, z = math.sin(a) * rr, -math.cos(a) * rr
		base_y = 70 * max(0.0, (760 - rr) / 160) * 0.5
		p.append(("cone", (w, h, w), (x, base_y + h / 2, z), (GRASS, GRASS3, GRASS2)[i % 3], {"seg": 12, "taper": 0.45}))
		p.append(("cyl", (w * 0.4, 2, w * 0.4), (x, base_y + h + 0.5, z), GRASS2, {"seg": 10}))
	# ant tunnels dug into the slopes
	for i in range(14):
		a = i * 2.4 + 0.3
		rr = 470 + (i * 53) % 220
		y = 330 * max(0.0, 1 - rr / 760) * 1.05 + 4
		_hole(p, (math.sin(a) * rr, y, -math.cos(a) * rr), 9 + i % 3 * 3, a, -25)
	k.prop("Hallasan", p)


def _nest(k):
	p = []
	for i, (r, h, x, z) in enumerate(((220, 70, 0, 0), (170, 70, 6, 4), (120, 60, -4, -2), (80, 46, 4, 2))):
		y = sum((70, 70, 60, 46)[:i])
		p.append(("cone", (r, h, r), (x, y + h / 2, z), (SOIL, SOIL2, SOIL, SOIL3)[i], {"seg": 14, "taper": (170, 120, 80, 40)[i] / r}))
	# lumps and ridges
	for i in range(16):
		a = i * math.tau / 16 + 0.2
		rr = 70 + (i % 3) * 18
		y = 40 - (rr - 70) * 0.5 + (i % 4) * 10
		p.append(("ball", (40, 30 + i % 3 * 10, 34), (math.sin(a) * rr, y, -math.cos(a) * rr), (SOIL2, SOIL, SOIL3)[i % 3], {"subdiv": 1, "rot": (0, -math.degrees(a), 0)}))
	# chimney spires
	for i, (a, rr, h) in enumerate(((0.8, 60, 90), (2.4, 50, 70), (4.0, 64, 80), (5.3, 40, 110), (3.2, 20, 60))):
		x, z = math.sin(a) * rr, -math.cos(a) * rr
		p.append(("cone", (18, h, 18), (x, 150 + h / 2 - 40, z), SOIL3, {"seg": 8, "taper": 0.25}))
		p.append(("cyl", (5, 2, 5), (x, 150 + h - 40, z), HOLE, {"seg": 6}))
	# breach crater on top, faint blue glow from the chamber far below
	p.append(("cyl", (44, 4, 44), (0, 247, 0), LIP, {"seg": 12}))
	p.append(("cyl", (32, 1, 32), (0, 249.2, 0), "1A3A5A", {"seg": 12, "emit": 1.5}))
	# honeycomb of tunnel mouths in rings
	for ring, (rr, y, n) in enumerate(((100, 22, 10), (76, 82, 8), (52, 140, 6), (30, 190, 4))):
		for i in range(n):
			a = i * math.tau / n + ring * 0.35
			_hole(p, (math.sin(a) * rr, y, -math.cos(a) * rr), (12, 10, 8, 6)[ring], a, -20)
	# pale ants on the mound and at its foot
	for (x, y, z, yaw, s, tilt) in ((-30, 0, -112, 15, 2.4, 0), (40, 0, -104, -30, 2.0, 0), (-60, 60, -60, 40, 1.8, -20), (50, 120, -36, -50, 1.6, -25), (0, 200, -22, 0, 1.4, -30)):
		_ant(p, (x, y, z), yaw, s, tilt)
	k.prop("Nest", p)


def _chamber(k):
	"""The queen's chamber opened up: a cave mouth facing -Z (the road) over a floor of glowing eggs."""
	p = [
		("box", (150, 6, 110), (0, 3, 10), CAVE),
		("box", (120, 60, 6), (0, 30, 58), HOLE),
		("ball", (70, 90, 90), (-70, 40, 20), CAVE2, {"subdiv": 2}),
		("ball", (70, 90, 90), (70, 40, 20), CAVE2, {"subdiv": 2}),
		("ball", (200, 60, 110), (0, 92, 20), CAVE, {"subdiv": 2}),
		("ball", (120, 40, 80), (20, 118, 30), "34483E", {"subdiv": 2}),
		("ball", (50, 34, 40), (-80, 8, -30), CAVE2, {"subdiv": 1}),
		("ball", (40, 26, 30), (84, 6, -28), CAVE2, {"subdiv": 1}),
	]
	for i in range(14):  # stalactites hanging from the lip
		x = -54 + i * 8.3
		h = 10 + (i * 7 % 5) * 5
		p.append(("cone", (5, h, 5), (x, 66 - h / 2, -30 + (i % 3) * 8), CAVE2, {"seg": 6, "rot": (180, 0, 0)}))
	for i in range(6):  # moss streaks
		p.append(("box", (4, 30, 1), (-50 + i * 20, 52, -34 + (i % 2) * 2), "3E6A3A", {"rot": (0, 0, (i - 2.5) * 4)}))
	n = 0
	for gx in range(11):  # the egg floor
		for gz in range(7):
			if (gx * 5 + gz * 3) % 13 == 0:
				continue
			x = -50 + gx * 10 + (gz % 2) * 5
			z = -28 + gz * 10
			s = 6 + ((gx + gz * 2) % 3)
			p.append(("ball", (s, s * 1.4, s), (x, 6 + s * 0.6, z), EGG if n % 4 else EGG2, {"emit": 2.4, "subdiv": 1, "rough": 0.3}))
			n += 1
	# the big hatched egg, shell broken open
	p.append(("cyl", (26, 18, 26), (0, 15, 2), "C8E8FF", {"seg": 10, "taper": 1.2, "emit": 1.2}))
	for i in range(6):
		a = i * math.tau / 6
		p.append(("cone", (8, 12, 3), (math.sin(a) * 14, 29, -math.cos(a) * 14), "C8E8FF", {"seg": 3, "emit": 1.2, "rot": (0, -math.degrees(a), 0)}))
	p.append(("cyl", (22, 1, 22), (0, 24.5, 2), "1A2A3A", {"seg": 10}))
	_ant(p, (40, 6, -10), -30, 1.6)
	k.prop("Chamber", p)


def _village(k):
	# Choga: stone-walled thatched house, rope-tied roof, olle yard wall, stone gate posts, a stone grandfather statue
	p = [("box", (28, 1, 18), (0, 0.5, 4), "5A5040")]
	for i in range(20):  # lumpy basalt walls
		side = i % 4
		t = (i // 4) / 5
		if side < 2:
			x, z, w, d = -13 + t * 26 + 2.6, (-5 if side == 0 else 13), 5.4, 2.4
		else:
			x, z, w, d = (-13 if side == 2 else 13), -5 + t * 18 + 1.8, 2.4, 3.8
		if side == 0 and 2 <= i // 4 <= 3:
			continue  # doorway
		p.append(("box", (w, 9 + (i % 3) * 0.8, d), (x, 5, z), (BASALT, BASALT2, BASALT3)[i % 3], {"rot": (0, (i % 5) - 2, 0)}))
	p.append(("box", (6, 8, 0.6), (-1, 4.5, -5.2), "4A3A28"))
	p.append(("box", (30, 3, 21), (0, 10.5, 4), THATCH2))
	p.append(("ball", (30, 10, 21), (0, 12, 4), THATCH, {"subdiv": 2, "smooth": True}))
	for j in range(5):  # rope grid laid over the roof
		x = -11 + j * 5.5
		h = 4.9 * math.sqrt(max(0.0, 1 - (x / 15) ** 2))
		p.append(("box", (0.5, 0.5, 21.4 * math.sqrt(max(0.1, 1 - (x / 15) ** 2))), (x, 12 + h, 4), ROPE))
	for j in range(4):
		z = -3 + j * 4.6
		h = 4.9 * math.sqrt(max(0.0, 1 - ((z - 4) / 10.5) ** 2))
		p.append(("box", (30.4 * math.sqrt(max(0.1, 1 - ((z - 4) / 10.5) ** 2)), 0.5, 0.5), (0, 12 + h, z), ROPE))
	p.append(("box", (7, 1.2, 7), (8, 15.6, 2), HOLE, {"rot": (8, 20, 4)}))  # a collapsed patch of roof
	for i in range(9):  # olle yard wall
		x = -22 + i * 5.5
		if 3 <= i <= 4:
			continue
		p.append(("box", (5, 4 + (i % 3), 2.4), (x, 2.2, -18), (BASALT2, BASALT, BASALT3)[i % 3], {"rot": (0, (i % 3) * 3 - 3, 0)}))
	for x in (-6, 2):  # jeongnang gate: stone posts and wooden bars
		p.append(("box", (1.8, 7, 1.8), (x, 3.5, -18), BASALT2))
	for y in (2.4, 4.0, 5.6):
		p.append(("cyl", (0.7, 9, 0.7), (-2, y, -18.3), "6A5036", {"seg": 6, "rot": (0, 0, 90)}))
	sx = -9.5  # stone grandfather statue beside the gate
	p += [
		("box", (3.2, 1, 3.2), (sx, 0.5, -20), BASALT2),
		("cyl", (3, 7, 2.6), (sx, 4.5, -20), BASALT, {"seg": 8}),
		("ball", (3, 3.6, 3), (sx, 9.6, -20), BASALT, {"subdiv": 1}),
		("cyl", (3.8, 0.5, 3.8), (sx, 11.2, -20), BASALT2, {"seg": 8}),
		("ball", (2.6, 2.2, 2.6), (sx, 12, -20), BASALT2, {"subdiv": 1}),
		("ball", (0.9, 0.9, 0.6), (sx - 0.7, 10, -21.4), BASALT3, {"subdiv": 1}),
		("ball", (0.9, 0.9, 0.6), (sx + 0.7, 10, -21.4), BASALT3, {"subdiv": 1}),
		("box", (3.2, 0.7, 0.6), (sx, 6, -21.4), BASALT3),
	]
	for bx, bz in ((16, -10), (-18, 10), (18, 14)):
		p.append(("ball", (7, 6, 7), (bx, 3, bz), CAMEL, {"subdiv": 1}))
		p.append(("ball", (1, 1, 1), (bx + 2, 5, bz - 3), BLOOM, {"subdiv": 1}))
	k.prop("Choga", p)
	# Ruin: abandoned concrete coast hotel, window grid, collapsed corner, rebar, vines, an ant hole in front
	p = [
		("box", (44, 40, 22), (0, 20, 0), CONC),
		("box", (20, 10, 22), (-12, 45, 0), CONC),
		("box", (46, 1.2, 24), (0, 40, 0), CONC2),
		("box", (20, 3, 14), (16, 2, -14), CONC2, {"rot": (20, 15, 8)}),
		("box", (14, 2, 10), (20, 9, -10), CONC2, {"rot": (0, 0, 40)}),
	]
	for f in range(4):
		p.append(("box", (45, 1, 23), (0, 10 * f + 0.5, 0), CONC2))
		for c in range(6):
			x = -18.5 + c * 7.4
			if f >= 2 and c >= 4:
				continue  # collapsed corner
			p.append(("box", (4.4, 5.5, 0.6), (x, 10 * f + 5.5, -11.1), WIN))
	p.append(("box", (16, 20, 22.4), (14, 30, 0), HOLE))
	for i in range(4):
		p.append(("box", (0.5, 10 + i * 2, 0.5), (8 + i * 3, 42 + i, -6 + i * 3), "6A4A3A", {"rot": (0, 0, -15 + i * 10)}))
	for i in range(5):  # vines
		p.append(("box", (3, 14 + i * 4, 0.8), (-20 + i * 7, 40 - (14 + i * 4) / 2, -11.6), "3E6A34"))
	_hole(p, (-6, 1, -22), 6, 0, -70)
	k.prop("Ruin", p)
	# Batdam: black lava-stone field wall with gaps
	p = []
	for i in range(18):
		x = -18 + i * 2.1
		h = 2.4 + (i * 7 % 4) * 0.6
		p.append(("box", (2.4, h, 2.2), (x, h / 2, (i % 2) * 0.4), (BASALT, BASALT2, BASALT3)[i % 3], {"rot": (i * 11 % 15, i * 23 % 40, i * 7 % 12)}))
		if i % 3 != 1:
			p.append(("box", (2.0, 1.8, 2.0), (x + 0.9, h + 0.9, 0), (BASALT2, BASALT3, BASALT)[i % 3], {"rot": (i * 13 % 20, i * 31 % 45, i * 5 % 15)}))
	k.prop("Batdam", p)


def _camp(k):
	"""The hunters' raid camp, laid out to face -Z (the road)."""
	p = [("box", (70, 0.4, 50), (0, 0.2, 0), "6A5E48")]
	for x, z, w, d in ((-22, 6, 14, 18), (-4, 8, 14, 18), (20, 12, 22, 26)):  # tents with gable roofs
		p.append(("box", (w, 5, d), (x, 2.5, z), OLIVE))
		p.append(("wedge", (w / 2, 4, d), (x - w / 4, 7, z), OLIVE2, {"rot": (0, 90, 0)}))
		p.append(("wedge", (w / 2, 4, d), (x + w / 4, 7, z), OLIVE2, {"rot": (0, -90, 0)}))
		p.append(("box", (3, 4, 0.3), (x, 2, z - d / 2 - 0.1), "1A1E14"))
	# helicopter on a pad
	hx, hz = -14, -14
	p += [
		("cyl", (16, 0.3, 16), (hx, 0.4, hz), "4A4A44", {"seg": 12}),
		("ball", (6, 5.5, 13), (hx, 4.6, hz), "3E4636", {"subdiv": 2, "smooth": True}),
		("ball", (4.4, 2.6, 4), (hx, 5.4, hz - 5.2), "7A9AA8", {"subdiv": 1, "rough": 0.2}),
		("cyl", (1.6, 14, 1.6), (hx, 5.4, hz + 12), "3E4636", {"seg": 6, "rot": (90, 0, 0)}),
		("box", (0.4, 4, 3), (hx, 7, hz + 18.6), "3E4636"),
		("cyl", (0.6, 1.4, 0.6), (hx, 8, hz), STEEL, {"seg": 6}),
		("box", (26, 0.3, 1.2), (hx, 8.8, hz), "202020", {"rot": (0, 30, 0)}),
		("box", (26, 0.3, 1.2), (hx, 8.8, hz), "202020", {"rot": (0, -60, 0)}),
		("box", (0.5, 0.5, 13), (hx - 3, 0.9, hz), STEEL),
		("box", (0.5, 0.5, 13), (hx + 3, 0.9, hz), STEEL),
	]
	for lx in (-30, 30):  # floodlight masts
		p += [
			("cyl", (0.8, 18, 0.8), (lx, 9, -18), STEEL, {"seg": 6}),
			("box", (5, 2.4, 1.6), (lx, 18.5, -18.4), STEEL),
			("box", (4.4, 1.8, 0.4), (lx, 18.5, -19.3), LAMP, {"emit": 6}),
		]
	for i in range(7):  # supply crates and sandbags
		p.append(("box", (3.6, 3.2, 3.6), (8 + (i % 4) * 4, 1.6 + (i // 4) * 3.2, -12), CRATE, {"rot": (0, (i * 13) % 20, 0)}))
	for i in range(9):
		p.append(("cyl", (4, 1.4, 2.2), (-33 + i * 4.2, 0.9 + (i % 2) * 1.2, -24), "8A7A58", {"seg": 6, "rot": (0, 0, 90), "smooth": True}))
	p += [("box", (9, 5, 5), (26, 3.2, -14), OLIVE2), ("box", (4, 3, 5), (31.5, 2.6, -14), OLIVE), ("box", (14, 0.6, 0.6), (0, 0.8, -24), STEEL)]
	k.prop("Camp", p)
	# Ship of the blockade: grey hull with a raked bow, bridge, mast, a gun turret
	k.prop(
		"Ship",
		[
			("box", (18, 10, 90), (0, 3, 0), HULL2),
			("cone", (18, 10, 24), (0, 3, -56), HULL2, {"seg": 4, "taper": 0.0, "rot": (-90, 45, 0)}),
			("box", (18.4, 1, 90), (0, 8.5, 0), HULL),
			("box", (12, 10, 22), (0, 14, 8), HULL),
			("box", (10, 5, 12), (0, 21.5, 4), HULL),
			("box", (10.2, 1.4, 0.4), (0, 22, -2.2), "1A2028"),
			("cyl", (1, 22, 1), (0, 32, 8), STEEL, {"seg": 6}),
			("box", (8, 0.6, 0.6), (0, 38, 8), STEEL),
			("cyl", (6, 3, 6), (0, 10.5, -24), HULL, {"seg": 10}),
			("cyl", (0.8, 9, 0.8), (0, 11.5, -29), HULL2, {"seg": 6, "rot": (90, 0, 0)}),
			("box", (6, 6, 8), (0, 12, 26), HULL),
		],
	)


def _nature(k):
	# Mound: ant mound with tunnel mouths and a pale ant on it
	p = [
		("cone", (56, 30, 56), (0, 15, 0), SOIL, {"seg": 10, "taper": 0.3}),
		("cone", (28, 24, 28), (14, 12, 8), SOIL2, {"seg": 8, "taper": 0.25}),
		("cone", (10, 22, 10), (-6, 38, 2), SOIL3, {"seg": 6, "taper": 0.2}),
	]
	for i in range(4):
		a = i * math.tau / 4 + 0.4
		_hole(p, (math.sin(a) * 20, 9, -math.cos(a) * 20), 4.5, a, -25)
	_ant(p, (-14, 0, -30), 20, 1.3)
	k.prop("Mound", p)
	# Cliff: basalt column shore cliff (hexagonal joints) on a rock foot
	p = [
		("cone", (90, 30, 76), (0, 13, 8), BASALT3, {"seg": 7, "taper": 0.45}),
		("cone", (50, 22, 44), (-18, 24, 14), "3A4A30", {"seg": 6, "taper": 0.4}),
	]
	for i in range(18):  # column joints stepping down to the sea on the -Z side
		a = i * 2.4
		r = 4 + (i % 6) * 4.6
		x, z = math.cos(a) * r, -abs(math.sin(a)) * r - 10
		h = 24 + z * 0.5 + (i % 3) * 3
		p.append(("cyl", (6, h, 6), (x, h / 2, z), (BASALT, BASALT2, BASALT3)[i % 3], {"seg": 6, "rough": 0.6}))
	k.prop("Cliff", p)
	# Brush: an island pine, camellia bushes with red blooms, tall grass
	p = [
		("cyl", (1.8, 22, 1.8), (0, 11, 0), "4A3A2A", {"seg": 6, "rot": (0, 0, 6)}),
		("cone", (16, 10, 16), (1.4, 18, 0), PINE, {"seg": 7}),
		("cone", (12, 9, 12), (2, 24, 0), PINE2, {"seg": 7}),
		("cone", (7, 7, 7), (2.4, 29, 0), PINE, {"seg": 7}),
		("ball", (10, 8, 9), (8, 4, 4), CAMEL, {"subdiv": 1}),
		("ball", (8, 7, 8), (-7, 3.5, 5), CAMEL, {"subdiv": 1}),
	]
	for bx, by, bz in ((6, 6.5, 0.4), (10, 6, 2), (-8, 5.5, 2), (-5, 6, 7)):
		p.append(("ball", (1.2, 1.2, 1.2), (bx, by, bz), BLOOM, {"subdiv": 1}))
	for i in range(5):
		a = i * 1.3
		p.append(("cone", (2.6, 5, 2.6), (math.cos(a) * 9 - 2, 2.5, math.sin(a) * 6 - 6), GRASS3, {"seg": 5}))
	k.prop("Brush", p)


def build(k):
	_hallasan(k)
	_nest(k)
	_chamber(k)
	_village(k)
	_camp(k)
	_nature(k)

	# Green island on the sea; basalt column cliffs break the shore; blockade ships ring it
	k.ground(OCEAN, margin=2400, rough=0.75, y=-4.0)
	k.ground("435E30", margin=380)
	supports(k, SUPPORT)
	lo, hi = k.lo, k.hi
	for x0, z0, x1, z1 in (
		(lo.x - 380, lo.z - 380, hi.x + 380, lo.z - 380),
		(lo.x - 380, hi.z + 380, hi.x + 380, hi.z + 380),
		(lo.x - 380, lo.z - 380, lo.x - 380, hi.z + 380),
		(hi.x + 380, lo.z - 380, hi.x + 380, hi.z + 380),
	):
		n = int(math.hypot(x1 - x0, z1 - z0) / 60)
		for i in range(n + 1):
			t = i / n
			x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			out = math.atan2(-(x - (lo.x + hi.x) / 2), -(z - (lo.z + hi.z) / 2))  # -Z (the column steps) toward the sea
			k.place("Cliff", (x, -4.0, z), out + k.rng.uniform(-0.4, 0.4), k.rng.uniform(1.0, 1.6))
	cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
	rad = max(hi.x - lo.x, hi.z - lo.z) / 2 + 900
	for i in range(22):
		a = i * math.tau / 22 + k.rng.uniform(-0.05, 0.05)
		k.place("Ship", (cx + math.cos(a) * rad, -4.0, cz + math.sin(a) * rad), -a + k.rng.uniform(-0.3, 0.3), k.rng.uniform(1.4, 2.0))
	L = k.length
	# Hero placements first so the scatter can keep clear of them
	best, bd = None, 0.0
	for i in range(31):
		for j in range(31):
			x = lo.x + (hi.x - lo.x) * i / 30
			z = lo.z + (hi.z - lo.z) * j / 30
			dd = _road_dist(k, x, z)
			if dd > bd:
				best, bd = (x, z), dd
	hs = max(0.4, min(1.2, (bd - 60) / 760))
	k.place("Hallasan", (best[0], -1.0, best[1]), 0.4, hs)
	print("HALLASAN at", (round(best[0]), round(best[1])), "clear", round(bd), "scale", round(hs, 2))
	keep = [(best[0], best[1], 760 * hs + 20)]
	nest = None
	for f in (0.33, 0.9, 0.62):
		p, right, t = k.at(L * f)
		for D in range(220, 1200, 20):
			x, z = p.x + right.x * 10 + t.x * D, p.z + right.z * 10 + t.z * D
			if _road_dist(k, x, z) >= 140 and all(math.hypot(x - a, z - b) > r + 120 for a, b, r in keep):
				if nest is None or D < nest[0]:
					nest = (D, x, z, f)
				break
	if nest:
		k.place("Nest", (nest[1], -1.0, nest[2]), k.rng.uniform(0, math.tau), 1.0)
		keep.append((nest[1], nest[2], 130))
		print("NEST at", (round(nest[1]), round(nest[2])), "ahead of shot", nest[3], "by", nest[0])
	cd = L * 0.06 + 110
	chamber = None
	for side in (-1, 1):
		(x, _, z), yaw = k.beside(cd, side * 100)
		if k.clear_of_road(x, z, 95) and all(math.hypot(x - a, z - b) > r + 80 for a, b, r in keep):
			k.place("Chamber", (x, -1.0, z), yaw + (math.pi / 2 if side > 0 else -math.pi / 2))
			keep.append((x, z, 110))
			chamber = (x, z)
			print("CHAMBER at", (round(x), round(z)), "side", side)
			break
	camps = []
	d = 300.0
	while d < L - 200:
		for side in (-1, 1):
			(x, _, z), yaw = k.beside(d, side * 64)
			if k.clear_of_road(x, z, 58) and all(math.hypot(x - a, z - b) > r + 40 for a, b, r in keep):
				k.place("Camp", (x, -1.0, z), yaw + (math.pi / 2 if side > 0 else -math.pi / 2))
				keep.append((x, z, 50))
				camps.append(d)
				break
		d += 700
	skip = tuple((c - 45, c + 45) for c in camps) + ((cd - 80, cd + 80),)
	# Road edge: lava-stone field walls and brush; then villages, ruins and mounds; then scatter over the island
	_row(k, 40, (-32, 32), ["Batdam"], 30, jitter=2, skip=skip)
	_row(k, 34, (-46, 46), ["Brush"], 40, jitter=4, face_road=False, scale=(0.9, 1.2), skip=skip)
	_row(k, 150, (-70, 70), ["Choga", "Choga", "Ruin"], 60, jitter=20, skip=skip)
	_row(k, 230, (-110, 110), ["Mound", "Ruin", "Choga"], 90, jitter=30, scale=(1.0, 1.6), skip=skip)
	k.field(240, ["Brush"], clearance=60, margin=330, scale=(1.0, 2.2))
	k.field(60, ["Mound"], clearance=110, margin=300, scale=(1.2, 2.4))
	k.field(50, ["Choga", "Ruin", "Batdam"], clearance=100, margin=300, scale=(1.0, 1.4))
	# keep the hero footprints clear of scatter
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("Brush", "Mound", "Choga", "Ruin", "Batdam"):
			lx, lz = ob.location.x, -ob.location.y
			if any(math.hypot(lx - a, lz - b) < r for a, b, r in keep):
				bpy.data.objects.remove(ob)
				k.instances -= 1
	# Overcast island daylight, a little ominous; cool lamps along the road, blue glow in the chamber
	k.sky([(0.0, "A8B4BE"), (0.05, "8C9CAE"), (0.25, "6A7E96"), (1.0, "3A4A62")], strength=1.0, sun=(3.2, "FFF0DC", 34, 200))
	d = 40
	while d < L:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, LAMP, energy=30000, radius=8)
		d += 220
	if chamber:
		k.light((chamber[0], 30, chamber[1]), "4AB8FF", energy=200000, radius=20)
