"""World 2 Track 9: Golden City (Frieren, Golden Land arc). Reference notes: docs/world2_refs/GoldenCity.md.

The fortress city of Weise after the Sage turned it to gold: a dense stone city of three- to five-storey ashlar
townhouses with regular window grids and low hipped roofs, paved squares with planters and covered wagons, two rings
of towering walls with slender cone-roofed round towers, the lord's estate in the centre (a tall hipped-roof manor
ringed by spired turrets), all of it solid metallic gold; townspeople frozen mid-step; the golden forest beyond the
walls; the Great Barrier as a faint smooth dome over everything; a warm sunset. Landmarks:
- Palace: the lord's estate (hero). - ClockTower: the city church with its belfry clock (hero; abstract dial, plain
  tick bars, no numerals). - CityWall: wall run with a round tower and tall cone roof. - Barrier: the dome.
- House / Block / TowerHouse: the ashlar townhouses. - People: frozen townsfolk. - Wagon: a frozen covered wagon.
No symbols or text (design doc 5). Everything in-house, parts only. Proposed look; the owner approves the render set
(design doc 4.46). Budget (BIOME_ENVIRONMENT_SPEC 4.5): 12 meshes, 3 hero (Palace, ClockTower, Barrier)."""

import math

GOLD, GOLD2, GOLD3, GOLDD, GOLDW = "E8B84A", "D4A23A", "F6D67C", "B07A22", "5A3E10"
SUNSET = "FFB070"
SQ2 = math.sqrt(2)


def g(rough=0.32, **o):
	return dict({"metal": 1.0, "rough": rough}, **o)


# --- local part helpers ---
def gable(w, d, h, y, color, x=0.0, z=0.0, o=0.0, rough=0.5):
	"""Gable roof, ridge along X, eaves at height y, overhang o. Roofs are a less mirror-like gold so they keep their
	colour instead of reflecting the violet upper sky."""
	return [
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z - d / 4 - o / 2), color, g(rough, metal=0.6)),
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z + d / 4 + o / 2), color, g(rough, metal=0.6, rot=(0, 180, 0))),
	]


def pyramid(s, h, pos, color, rough=0.5):
	return [("cone", (s * SQ2, h, s * SQ2), (pos[0], pos[1] + h / 2, pos[2]), color, g(rough, metal=0.6, seg=4, rot=(0, 45, 0)))]


def hip(w, d, h, y, color, x=0.0, z=0.0):
	"""Hipped roof over a w x d block (w >= d): a gable of length w - d capped by two square pyramids."""
	p = gable(w - d, d, h, y, color, x, z) if w > d else []
	for dx in ((-(w - d) / 2, (w - d) / 2) if w > d else (0,)):
		p += pyramid(d, h, (x + dx, y, z), color)
	return p


def windows(face, w, y0, floors, fh, cols, depth, arch_top=False):
	"""Window grid on one face of a w-wide block (face: 'front' -Z, 'left' -X, 'right' +X). Each window is a dark
	recessed pane, a sill and a lintel; the top floor gets round heads when arch_top."""
	p = []
	step = w / cols
	for f in range(floors):
		y = y0 + f * fh + fh * 0.55
		for c in range(cols):
			u = -w / 2 + step * (c + 0.5)
			parts = [
				("box", (2.6, 4.6, 0.6), (u, y, 0), GOLDW, g(0.55)),
				("box", (3.8, 0.6, 1.0), (u, y - 2.6, -0.2), GOLD3, g()),
				("box", (3.6, 0.8, 0.8), (u, y + 2.7, -0.1), GOLD3, g()),
			]
			if arch_top and f == floors - 1:
				parts[2] = ("cyl", (2.6, 0.6, 2.6), (u, y + 2.3, 0), GOLDW, g(0.55, rot=(90, 0, 0), seg=8))
			for shape, size, (a, b, c2), col, o in parts:
				if face == "front":
					p.append((shape, size, (a, b, -depth / 2 - 0.2 + c2), col, o))
				else:
					s = -1 if face == "left" else 1
					o2 = dict(o)
					r = o2.get("rot", (0, 0, 0))
					o2["rot"] = (r[0], r[1] + 90, r[2])
					p.append((shape, size, (s * (depth / 2 + 0.2 - c2), b, a), col, o2))
	return p


def courses(w, d, ys, color=GOLD3):
	"""String courses and a cornice: thin projecting bands round a w x d block at heights ys."""
	return [("box", (w + 1.0, 0.9, d + 1.0), (0, y, 0), color, g()) for y in ys]


def turret(x, z, y0, dia, h, cone_h, seg=10):
	"""Slender round turret: shaft, corbel band, tall cone spire and a ball finial."""
	return [
		("cyl", (dia, h, dia), (x, y0 + h / 2, z), GOLD, g(seg=seg)),
		("cyl", (dia * 1.18, 2.2, dia * 1.18), (x, y0 + h - 1.1, z), GOLD3, g(seg=seg)),
		("cone", (dia * 1.3, cone_h, dia * 1.3), (x, y0 + h + cone_h / 2, z), GOLDD, g(0.45, metal=0.6, seg=seg)),
		("ball", (dia * 0.22, dia * 0.22, dia * 0.22), (x, y0 + h + cone_h + dia * 0.08, z), GOLD3, g(0.15, subdiv=1)),
		("box", (1.6, 4.4, 0.8), (x, y0 + h * 0.7, z - dia / 2), GOLDW, g(0.55)),
	]


class RoadGrid:
	"""Fast "is this spot clear of every road stretch" lookup: waypoints bucketed on a coarse grid (kit.clear_of_road
	scans the whole polyline per call, too slow for thousands of city-fill tries)."""

	def __init__(self, k, cell=100.0):
		self.cell, self.b = cell, {}
		for w in k.wps:
			self.b.setdefault((int(w.x // cell), int(w.z // cell)), []).append((w.x, w.z))

	def clear(self, x, z, r):
		c, n = self.cell, int(r // self.cell) + 1
		cx, cz = int(x // c), int(z // c)
		for i in range(cx - n, cx + n + 1):
			for j in range(cz - n, cz + n + 1):
				for px, pz in self.b.get((i, j), ()):
					if (px - x) ** 2 + (pz - z) ** 2 <= r * r:
						return False
		return True


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), spin=False, clear=None):
	"""kit.along, but every prop stands on the ground (y = -1) even on ramps, and never near another road stretch."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], (clear or abs(o) * 0.9)):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw = k.rng.uniform(0, math.tau) if spin else yaw + (math.pi / 2 if off > 0 else -math.pi / 2)  # -Z faces the road
			k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


# --- props ---
def house():
	"""Three-storey ashlar townhouse: plinth, string courses, cornice, low hipped roof, 4x3 window grid on the street
	face and 2x3 on the sides, arched door with steps, two chimneys."""
	W, D, F, FH = 30, 20, 3, 9
	H = F * FH + 2
	p = [("box", (W, H, D), (0, H / 2, 0), GOLD, g()), ("box", (W + 1.4, 2, D + 1.4), (0, 1, 0), GOLD2, g())]
	p += courses(W, D, (2 + FH, 2 + 2 * FH, H + 0.4))
	p += hip(W + 1, D + 1, 9, H + 0.8, GOLDD)
	p += windows("front", W, 2, F, FH, 4, D)
	p += windows("left", D, 2, F, FH, 2, W)
	p += windows("right", D, 2, F, FH, 2, W)
	p += [
		("box", (4.6, 7, 0.8), (0, 4.5, -D / 2 - 0.2), GOLDW, g(0.55)),
		("cyl", (4.6, 0.8, 4.6), (0, 8, -D / 2 - 0.2), GOLDW, g(0.55, rot=(90, 0, 0), seg=10)),
		("box", (7, 1, 3), (0, 0.5, -D / 2 - 1.5), GOLD2, g()),
		("box", (2.6, 8, 2.6), (-9, H + 6, 4), GOLD2, g()),
		("box", (2.6, 8, 2.6), (9, H + 6, -4), GOLD2, g()),
	]
	for x in (-W / 2, W / 2):  # quoins
		for f in range(F):
			p.append(("box", (1.2, FH - 1, D + 0.8), (x, 2 + f * FH + FH / 2, 0), GOLD3, g()))
	return p


def block():
	"""Four-storey merchant block (wide, like the long buildings on the market square): gable roof with three
	dormers, 6x4 window grid with round-headed top floor, ground-floor arcade of shop arches, corner pilasters."""
	W, D, F, FH = 46, 24, 4, 9
	H = F * FH + 2
	p = [("box", (W, H, D), (0, H / 2, 0), GOLD2, g()), ("box", (W + 1.4, 2, D + 1.4), (0, 1, 0), GOLDD, g())]
	p += courses(W, D, (2 + FH, H + 0.4))
	p += gable(W, D + 1, 11, H + 0.8, GOLDD, o=1)
	for x in (-14, 0, 14):  # dormers
		p += [("box", (5, 5, 4), (x, H + 3.5, -D / 2 + 3), GOLD, g()), ("box", (3, 3, 0.6), (x, H + 3.3, -D / 2 + 0.8), GOLDW, g(0.55))]
		p += [(s, sz, (a + x, b, c - D / 2 + 3), col, o) for s, sz, (a, b, c), col, o in gable(5, 4, 2.6, H + 6, GOLDD, o=0.4)]
	p += windows("front", W, 2 + FH, F - 1, FH, 6, D, arch_top=True)
	p += windows("left", D, 2 + FH, F - 1, FH, 3, W)
	p += windows("right", D, 2 + FH, F - 1, FH, 3, W)
	for i in range(5):  # ground-floor shop arches
		x = -W / 2 + W / 5 * (i + 0.5)
		p += [("box", (6, 5, 0.8), (x, 4.5, -D / 2 - 0.2), GOLDW, g(0.55)), ("cyl", (6, 0.8, 6), (x, 7, -D / 2 - 0.2), GOLDW, g(0.55, rot=(90, 0, 0), seg=10))]
	for x in (-W / 2, W / 2):
		p.append(("box", (1.6, H, D + 1.0), (x, H / 2, 0), GOLD3, g()))
	return p


def tower_house():
	"""Narrow five-storey tower house with a steep pyramid roof (the tall square houses among the blocks), arched
	windows, corner quoins and a lantern finial."""
	W, D, F, FH = 18, 18, 5, 9
	H = F * FH + 2
	p = [("box", (W, H, D), (0, H / 2, 0), GOLD, g()), ("box", (W + 1.4, 2, D + 1.4), (0, 1, 0), GOLD2, g())]
	p += courses(W, D, (2 + FH, 2 + 3 * FH, H + 0.4))
	p += pyramid(W + 2, 18, (0, H + 0.8, 0), GOLDD)
	p += [("cyl", (1.2, 4, 1.2), (0, H + 20, 0), GOLD3, g(seg=6)), ("ball", (2, 2, 2), (0, H + 22.5, 0), GOLD3, g(0.15, subdiv=1))]
	p += windows("front", W, 2, F, FH, 2, D, arch_top=True)
	p += windows("left", D, 2, F, FH, 2, W, arch_top=True)
	p += windows("right", D, 2, F, FH, 2, W, arch_top=True)
	for x in (-W / 2, W / 2):
		for f in range(F):
			p.append(("box", (1.2, FH - 1, D + 0.8), (x, 2 + f * FH + FH / 2, 0), GOLD3, g()))
	return p


def city_wall():
	"""A 130-stud run of the towering city wall: battered plinth, ashlar courses, crenellated walk, a round tower at
	one end with a corbel band and a tall slender cone roof (the walls' signature), arrow slits."""
	L, H, T = 130, 46, 12
	p = [
		("box", (L, H, T), (0, H / 2, 0), GOLD2, g(0.4)),
		("box", (L, 8, T + 4), (0, 4, 0), GOLDD, g(0.4)),
		("box", (L + 0.4, 1.6, T + 1.6), (0, H - 0.8, 0), GOLD3, g()),
	]
	for y in (16, 30):
		p.append(("box", (L, 0.6, T + 0.4), (0, y, 0), GOLD, g()))
	for i in range(int(L // 6)):
		x = -L / 2 + 3 + i * 6
		p.append(("box", (3.4, 4, T), (x, H + 2, 0), GOLD3, g(0.4)))
	for x in range(-50, 51, 20):
		p.append(("box", (1.6, 6, 0.8), (x, 34, -T / 2 - 0.2), GOLDW, g(0.55)))
	p += turret(L / 2, 0, 0, 30, 70, 54, seg=14)
	p += [("box", (2, 6, 0.8), (L / 2 + 15 * math.sin(a), y, -15 * math.cos(a)), GOLDW, g(0.55, rot=(0, -math.degrees(a), 0))) for a in (-0.6, 0.6) for y in (30, 48)]
	return p


def palace():
	"""Hero: the lord's estate in the centre: a walled court with corner turrets and a gate, the tall manor (central
	pavilion with a steep hipped roof and pediment gable, two lower wings), dormers, chimneys, a ring of slender
	spired turrets of different heights round the manor (the cluster of cones seen over the city). Gate is -Z."""
	p = [("box", (170, 3, 150), (0, 1.5, 0), GOLD2, g(0.45))]
	# Court wall with crenels and corner turrets, gate on -Z
	for (x1, z1, x2, z2) in ((-85, -75, -14, -75), (14, -75, 85, -75), (85, -75, 85, 75), (85, 75, -85, 75), (-85, 75, -85, -75)):
		L = math.hypot(x2 - x1, z2 - z1)
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		p.append(("box", (L, 20, 5), ((x1 + x2) / 2, 10, (z1 + z2) / 2), GOLD2, g(0.4, rot=(0, yaw, 0))))
		for i in range(int(L // 8)):
			t = (i + 0.5) / int(L // 8)
			p.append(("box", (3.4, 3, 5.4), (x1 + (x2 - x1) * t, 21.5, z1 + (z2 - z1) * t), GOLD3, g(0.4, rot=(0, yaw, 0))))
	for x in (-85, 85):
		for z in (-75, 75):
			p += turret(x, z, 0, 14, 34, 26)
	for x in (-14, 14):
		p += [("box", (10, 32, 10), (x, 16, -75), GOLD, g())] + pyramid(11, 14, (x, 32, -75), GOLDD)
	p += [("box", (18, 10, 6), (0, 25, -75), GOLD, g()), ("box", (14, 16, 6.4), (0, 8, -75), GOLDW, g(0.55)), ("cyl", (14, 6.4, 14), (0, 16, -75), GOLDW, g(0.55, rot=(90, 0, 0), seg=12))]
	# Manor: wings and the central pavilion
	for x in (-40, 40):
		p += [("box", (36, 34, 30), (x, 17, 10), GOLD, g())] + courses(0, 0, ())
		p += [(s, sz, (a + x, b, c + 10), col, o) for s, sz, (a, b, c), col, o in hip(37, 31, 14, 34.6, GOLDD)]
		p += [(s, sz, (a + x, b, c + 10), col, o) for s, sz, (a, b, c), col, o in windows("front", 36, 2, 3, 10, 4, 30)]
		p.append(("box", (37, 1, 31), (x, 34, 10), GOLD3, g()))
	p += [("box", (46, 52, 40), (0, 26, 6), GOLD2, g()), ("box", (47, 1.2, 41), (0, 52.4, 6), GOLD3, g()), ("box", (47, 1, 41), (0, 13, 6), GOLD3, g())]
	p += [(s, sz, (a, b, c + 6), col, o) for s, sz, (a, b, c), col, o in hip(47, 41, 26, 53, GOLDD)]
	p += [(s, sz, (a, b, c + 6), col, o) for s, sz, (a, b, c), col, o in windows("front", 46, 2, 5, 10, 5, 40, arch_top=True)]
	# Pediment gable and a balcony on the pavilion front, dormers and chimneys
	p += [("box", (20, 16, 4), (0, 60, -15), GOLD, g()), ("box", (8, 8, 0.6), (0, 59, -17.2), GOLDW, g(0.55))]
	p += [(s, sz, (a, b, c - 15), col, o) for s, sz, (a, b, c), col, o in gable(22, 4, 10, 68, GOLDD, o=0.6)]
	p += [("box", (22, 1.2, 5), (0, 22, -16.5), GOLD3, g()), ("box", (22, 3, 0.6), (0, 24, -18.8), GOLD3, g())]
	for x in (-14, 14):
		p += [("box", (5, 6, 4), (x, 58, -11), GOLD, g()), ("box", (3, 3.5, 0.6), (x, 58, -13.2), GOLDW, g(0.55))]
	for x, z in ((-16, 20), (16, 20), (-52, 10), (52, 10)):
		p.append(("box", (3.4, 16, 3.4), (x, 62 if abs(x) < 20 else 48, z), GOLD2, g()))
	# The ring of spired turrets round the manor, tallest at the front corners
	for x, z, h, c in ((-25, -15, 74, 40), (25, -15, 74, 40), (-25, 27, 66, 34), (25, 27, 66, 34), (-60, -6, 52, 30), (60, -6, 52, 30), (-60, 26, 46, 26), (60, 26, 46, 26)):
		p += turret(x, z, 0, 12 if h > 60 else 10, h, c)
	# Court: a small domed shrine and planters
	p += [("box", (12, 2, 12), (-50, 3, -45), GOLD3, g()), ("box", (8, 10, 8), (-50, 9, -45), GOLD, g())] + pyramid(11, 7, (-50, 14, -45), GOLDD)
	for x in (-28, 28):
		p += [("box", (10, 3, 4), (x, 4.5, -50), GOLD2, g()), ("ball", (10, 5, 4), (x, 7.5, -50), GOLD3, g(0.4, subdiv=1))]
	return p


def clock_tower():
	"""Hero: the city church and its belfry clock tower. Nave with a steep roof, buttresses and tall arched windows,
	a round window on the west front (plain ring and spokes), a portal; the square tower with a belfry stage of
	paired arches, an abstract clock dial on all four faces (plain disk, rim, twelve tick bars, two hands; no
	numerals), corner pinnacles, an octagonal spire and a ball finial. Tower front is -Z."""
	p = [("box", (40, 36, 90), (0, 18, 30), GOLD, g()), ("box", (41, 1.2, 91), (0, 36.4, 30), GOLD3, g())]
	p += [
		("wedge", (90, 26, 21), (-10.5, 50, 30), GOLDD, g(0.25, rot=(0, 90, 0))),
		("wedge", (90, 26, 21), (10.5, 50, 30), GOLDD, g(0.25, rot=(0, -90, 0))),
	]
	for z in range(-6, 72, 14):  # buttresses and arched windows on both sides
		for s in (-1, 1):
			p.append(("box", (4, 30, 5), (s * 21.5, 15, z), GOLD2, g()))
			if z < 66:
				p += [("box", (0.8, 14, 5), (s * 20.2, 18, z + 7), GOLDW, g(0.55)), ("cyl", (5, 0.8, 5), (s * 20.2, 25, z + 7), GOLDW, g(0.55, rot=(0, 0, 90), seg=8))]
	# Tower
	T = 30
	p += [
		("box", (T, 110, T), (0, 55, -14), GOLD2, g()),
		("box", (T + 2, 2, T + 2), (0, 40, -14), GOLD3, g()),
		("box", (T + 2, 2, T + 2), (0, 80, -14), GOLD3, g()),
		("box", (T + 3, 3, T + 3), (0, 111.5, -14), GOLD3, g()),
		("box", (12, 18, 0.8), (0, 9, -14 - T / 2 - 0.2), GOLDW, g(0.55)),
		("cyl", (12, 0.8, 12), (0, 18, -14 - T / 2 - 0.2), GOLDW, g(0.55, rot=(90, 0, 0), seg=12)),
		("cyl", (14, 0.8, 14), (0, 30, -14 - T / 2 - 0.3), GOLDW, g(0.55, rot=(90, 0, 0), seg=14)),  # round window
		("cyl", (10, 1.0, 10), (0, 30, -14 - T / 2 - 0.5), GOLD3, g(0.25, rot=(90, 0, 0), seg=14)),
	]
	for i in range(6):  # spokes of the round window
		p.append(("box", (0.7, 9, 0.6), (0, 30, -14 - T / 2 - 0.9), GOLD3, g(rot=(0, 0, i * 30))))
	for side in range(4):
		a = side * math.pi / 2
		ca, sa = math.cos(a), math.sin(a)

		def at(lx, ly, lz):
			return (lx * ca + lz * sa, ly, -14 - lx * sa + lz * ca)

		ydeg = math.degrees(a)
		for x in (-6, 6):  # belfry paired arches
			p += [("box", (5, 14, 1), at(x, 98, -T / 2 - 0.1), GOLDW, g(0.55, rot=(0, ydeg, 0))), ("cyl", (5, 1, 5), at(x, 105, -T / 2 - 0.1), GOLDW, g(0.55, rot=(90, ydeg, 0), seg=8))]
		# Abstract dial: disk, rim, tick bars, two hands
		cy = 64
		p += [
			("cyl", (22, 1.2, 22), at(0, cy, -T / 2 - 0.5), GOLD3, g(0.18, rot=(90, ydeg, 0), seg=20, emit=0.25)),
			("cyl", (24, 0.8, 24), at(0, cy, -T / 2 - 0.1), GOLDD, g(0.25, rot=(90, ydeg, 0), seg=20)),
		]
		for t in range(12):
			th = t * 30
			r = 9.2
			p.append(("box", (0.8, 2.4 if t % 3 else 3.4, 0.5), at(-r * math.sin(math.radians(th)), cy + r * math.cos(math.radians(th)), -T / 2 - 1.3), GOLDW, g(0.5, rot=(0, ydeg, th))))
		for th, L, wdt in ((-120, 5.5, 1.3), (60, 8, 0.9)):
			p.append(("box", (wdt, L, 0.5), at(-L / 2 * math.sin(math.radians(th)), cy + L / 2 * math.cos(math.radians(th)), -T / 2 - 1.6), GOLDW, g(0.5, rot=(0, ydeg, th))))
		p.append(("cyl", (1.6, 0.8, 1.6), at(0, cy, -T / 2 - 1.8), GOLDW, g(0.5, rot=(90, ydeg, 0), seg=8)))
	# Corner pinnacles, octagonal spire, finial
	for x in (-T / 2, T / 2):
		for z in (-T / 2, T / 2):
			p += [("box", (4, 10, 4), (x, 118, z - 14), GOLD, g()), ("cone", (5, 14, 5), (x, 130, z - 14), GOLDD, g(0.22, seg=6))]
	p += [
		("cyl", (T * 0.9, 6, T * 0.9), (0, 116, -14), GOLD, g(seg=8)),
		("cone", (T * 0.96, 70, T * 0.96), (0, 154, -14), GOLDD, g(0.22, seg=8)),
		("ball", (4, 4, 4), (0, 191, -14), GOLD3, g(0.12, subdiv=1)),
		("box", (0.8, 8, 0.8), (0, 196, -14), GOLD3, g()),
	]
	return p


def people():
	"""Three townsfolk frozen in gold mid-step (faceless): a hooded traveller striding with a staff, a woman with a
	basket reaching forward, a child running; long cloaks as tapered cones."""
	p = []
	for x, z, stride, arm, extra in ((-4, 0, 26, -35, "staff"), (3, 2, 14, -70, "basket"), (8, -3, 34, 40, "child")):
		s = 0.7 if extra == "child" else 1.0
		y = lambda v: v * s  # noqa: E731
		p += [
			("box", (1.3 * s, 5 * s, 1.4 * s), (x - 0.8 * s, y(3), z), GOLD2, g(rot=(stride, 0, 0))),
			("box", (1.3 * s, 5 * s, 1.4 * s), (x + 0.8 * s, y(3), z), GOLD2, g(rot=(-stride, 0, 0))),
			("cone", (5 * s, 7 * s, 4 * s), (x, y(7.6), z + 0.3), GOLD, g(seg=8, taper=0.45)),  # cloak
			("box", (3 * s, 3.6 * s, 1.8 * s), (x, y(10), z), GOLD, g()),
			("ball", (2.3 * s, 2.6 * s, 2.4 * s), (x, y(13), z), GOLD3, g(0.25, subdiv=2, smooth=True)),
			("cone", (2.9 * s, 3.4 * s, 2.9 * s), (x, y(13.6), z + 0.4), GOLD2, g(seg=8, taper=0.3, rot=(-15, 0, 0))),  # hood
			("box", (1.0 * s, 4 * s, 1.0 * s), (x - 2.1 * s, y(9.6), z - 0.6), GOLD2, g(rot=(arm, 0, 10))),
			("box", (1.0 * s, 4 * s, 1.0 * s), (x + 2.1 * s, y(9.6), z + 0.6), GOLD2, g(rot=(-arm * 0.6, 0, -10))),
		]
		if extra == "staff":
			p.append(("cyl", (0.5, 15, 0.5), (x - 2.6, 7.5, z - 2.2), GOLDD, g(seg=5, rot=(-12, 0, 0))))
		elif extra == "basket":
			p += [("cyl", (3, 2, 3), (x + 2.1, 8.6, z - 3.4), GOLDD, g(seg=8)), ("ball", (2.6, 1.4, 2.6), (x + 2.1, 9.8, z - 3.4), GOLD3, g(subdiv=1))]
	return p


def wagon():
	"""A covered wagon frozen in gold with its draught horse mid-step: plank bed, four spoked-disc wheels, hooped
	canvas top, shafts; crates and barrels beside it."""
	p = [
		("box", (8, 1.4, 16), (0, 4.4, 0), GOLDD, g()),
		("box", (8.4, 2.6, 0.6), (0, 5.8, -8), GOLD2, g()),
		("box", (0.6, 2.6, 16), (-4.1, 5.8, 0), GOLD2, g()),
		("box", (0.6, 2.6, 16), (4.1, 5.8, 0), GOLD2, g()),
		("cyl", (9, 14, 9), (0, 7.5, 1), GOLD3, g(0.4, rot=(90, 0, 0), seg=12)),  # canvas hoop top
		("box", (8.6, 3, 14.4), (0, 5.6, 1), GOLD3, g(0.4)),
	]
	for i in range(4):
		p.append(("cyl", (9.4, 0.6, 9.4), (0, 7.6, -6 + i * 4.4), GOLDD, g(rot=(90, 0, 0), seg=12)))  # hoops
	for x in (-4.6, 4.6):
		for z in (-5, 5):
			p += [("cyl", (6, 0.8, 6), (x, 3, z), GOLD2, g(rot=(0, 0, 90), seg=12)), ("cyl", (1.4, 1.2, 1.4), (x, 3, z), GOLDD, g(rot=(0, 0, 90), seg=6))]
	p += [("box", (0.5, 0.5, 10), (x, 4, -12), GOLDD, g(rot=(-6, 0, 0))) for x in (-2.2, 2.2)]
	# Horse
	p += [
		("box", (3.4, 3.8, 9), (0, 7.4, -19), GOLD, g()),
		("box", (2.2, 5, 2.6), (0, 10.4, -24), GOLD, g(rot=(-35, 0, 0))),
		("box", (1.8, 2, 4.2), (0, 12.6, -26.4), GOLD3, g(rot=(15, 0, 0))),
		("box", (0.8, 2.6, 4), (0, 11.4, -23.2), GOLDD, g(rot=(-35, 0, 0))),  # mane
	]
	for x, z, r in ((-1.1, -15.5, 20), (1.1, -15.5, -10), (-1.1, -22.5, -25), (1.1, -22.5, 15)):
		p.append(("box", (1, 5.6, 1.2), (x, 2.8, z), GOLD2, g(rot=(r, 0, 0))))
	p += [("box", (4, 4, 4), (7, 2, 4), GOLD2, g()), ("box", (3, 3, 3), (7, 5.5, 4.4), GOLD3, g(rot=(0, 20, 0))), ("cyl", (3, 4, 3), (7, 2, -2), GOLDD, g(seg=8))]
	return p


def street():
	"""Street set: an iron-style lantern post with a glowing lamp, a planter box of gold shrubs, a bench."""
	return [
		("box", (2.4, 1.4, 2.4), (0, 0.7, 0), GOLDD, g()),
		("cyl", (0.8, 15, 0.8), (0, 8.5, 0), GOLDD, g(seg=8)),
		("box", (3.6, 0.5, 0.5), (0, 15, 0), GOLDD, g()),
		("box", (2.2, 3, 2.2), (0, 17.4, 0), "FFE6A8", {"emit": 4}),
		("box", (2.8, 0.4, 2.8), (0, 15.8, 0), GOLDD, g()),
		("cone", (3.4, 2, 3.4), (0, 19.9, 0), GOLDD, g(seg=4, rot=(0, 45, 0))),
		("ball", (0.8, 0.8, 0.8), (0, 21.2, 0), GOLD3, g(subdiv=1)),
		("box", (10, 3, 4), (8, 1.5, 0), GOLD2, g()),
		("box", (10.4, 0.6, 4.4), (8, 3.1, 0), GOLD3, g()),
		("ball", (4, 3.6, 3.6), (5.6, 4.6, 0), GOLD3, g(0.4, subdiv=1)),
		("ball", (4.4, 4.2, 3.8), (8.6, 5, 0), GOLD, g(0.4, subdiv=1)),
		("ball", (3.6, 3.4, 3.4), (11, 4.4, 0), GOLD3, g(0.4, subdiv=1)),
		("box", (7, 0.6, 2.2), (-7, 2.2, 0), GOLD2, g()),
		("box", (7, 2.4, 0.5), (-7, 3.6, 1), GOLD2, g()),
		("box", (0.6, 2, 2), (-10, 1, 0), GOLDD, g()),
		("box", (0.6, 2, 2), (-4, 1, 0), GOLDD, g()),
	]


def tree():
	"""A gold-leaf tree: trunk with two limbs and a layered crown of overlapping smooth balls."""
	return [
		("cyl", (2.4, 12, 2.4), (0, 6, 0), GOLDD, g(0.4, seg=8)),
		("cyl", (1.2, 7, 1.2), (2, 12, 0), GOLDD, g(0.4, seg=6, rot=(0, 0, -35))),
		("cyl", (1.2, 7, 1.2), (-2, 12.5, 1), GOLDD, g(0.4, seg=6, rot=(0, 0, 35))),
		("ball", (14, 10, 14), (0, 17, 0), GOLD3, g(0.35, subdiv=2, smooth=True)),
		("ball", (9, 7, 9), (4.5, 20, 2), GOLD, g(0.35, subdiv=2, smooth=True)),
		("ball", (9, 7, 9), (-4, 20.5, -2), GOLD, g(0.35, subdiv=2, smooth=True)),
		("ball", (7, 6, 7), (0, 23.5, 0), GOLD3, g(0.35, subdiv=1)),
	]


def forest():
	"""The golden forest beyond the walls: a mound with a dense clump of gold conifers and round trees."""
	p = [("ball", (90, 14, 70), (0, -2, 0), GOLD2, g(0.45, subdiv=2, smooth=True))]
	for x, z, h in ((0, 0, 40), (18, 8, 32), (-16, 6, 36), (8, -16, 28), (-12, -14, 30), (26, -10, 24), (-28, -4, 22), (30, 14, 20)):
		p.append(("cyl", (2, h * 0.3, 2), (x, 4 + h * 0.15, z), GOLDD, g(0.4, seg=5)))
		for i, (f, w) in enumerate(((0.3, 0.5), (0.52, 0.36), (0.72, 0.22))):
			p.append(("cone", (h * w, h * 0.36, h * w), (x, 4 + h * f + h * 0.18, z), (GOLD, GOLD3, GOLD)[i], g(0.35, seg=7)))
	return p


def build(k):
	k.prop("House", house())
	k.prop("Block", block())
	k.prop("TowerHouse", tower_house())
	k.prop("CityWall", city_wall())
	k.prop("Palace", palace())
	k.prop("ClockTower", clock_tower())
	k.prop("People", people())
	k.prop("Wagon", wagon())
	k.prop("Street", street())
	k.prop("Tree", tree())
	k.prop("Forest", forest())
	# The Great Barrier: a smooth faint dome (unit sphere, scaled per axis below)
	k.prop("Barrier", [("ball", (2, 2, 2), (0, 0, 0), "FFE9B0", {"alpha": 0.12, "rough": 0.1, "emit": 0.18, "subdiv": 5, "smooth": True})])

	c = (k.lo + k.hi) / 2
	hx, hz = (k.hi.x - k.lo.x) / 2, (k.hi.z - k.lo.z) / 2
	WX, WZ = hx * 1.3 + 160, hz * 1.3 + 160  # wall ring (ellipse) round the whole city
	k.ground("C9A048", margin=max(WX, WZ) * 0.8 + 900, rough=0.45)

	# Streets: lanterns and planters at the kerb, frozen people on the pavement, wagons, trees
	ground_along(k, 64, (-27, 27), ["Street"], jitter=1)
	ground_along(k, 58, (-33, 33), ["People"], jitter=5, start=50, spin=True)
	ground_along(k, 270, (-36, 36), ["Wagon"], jitter=6, start=130, spin=True)
	ground_along(k, 110, (-38, 38), ["Tree"], jitter=3, start=85)
	# Street fronts: a continuous row of townhouses facing the road, a second taller row behind
	ground_along(k, 40, (-58, 58), ["House", "House", "Block", "TowerHouse"], jitter=2, start=20, scale=(0.92, 1.0))
	ground_along(k, 52, (-112, 112), ["Block", "TowerHouse", "House", "Tree"], jitter=6, start=40, scale=(1.0, 1.25), clear=80)

	keep_clear = []
	grid = RoadGrid(k)

	def hero(name, f, off, scale):
		"""A landmark ahead of the runner at fraction f, `off` studs to the side (sign picks the side), facing the road."""
		for df in (0.0, 0.02, -0.02, 0.04, 0.06):
			d = k.length * (f + df)
			pos, yaw = k.beside(d, off)
			if k.clear_of_road(pos[0], pos[2], abs(off) * 0.75):
				k.place(name, (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2), scale)
				keep_clear.append((pos[0], pos[2], abs(off) * 0.9))
				return

	hero("Palace", 0.33 + 0.012, -190, 1.25)
	hero("ClockTower", 0.9 + 0.01, 120, 1.25)
	hero("ClockTower", 0.06 + 0.01, -120, 1.1)

	def free(x, z):
		return all((x - a) ** 2 + (z - b) ** 2 > r * r for a, b, r in keep_clear)

	# The rest of the city fills the walled area: blocks of houses with gold trees between
	placed = tries = 0
	while placed < 3200 and tries < 60000:
		tries += 1
		x = k.rng.uniform(c.x - WX, c.x + WX)
		z = k.rng.uniform(c.z - WZ, c.z + WZ)
		if ((x - c.x) / (WX - 60)) ** 2 + ((z - c.z) / (WZ - 60)) ** 2 > 1 or not free(x, z):
			continue
		if grid.clear(x, z, 150):
			yaw = round(k.rng.uniform(0, 4)) * math.pi / 2 + 0.3
			k.place(k.rng.choice(["House", "Block", "TowerHouse", "House", "Tree"]), (x, -1.0, z), yaw, k.rng.uniform(1.1, 1.7))
			placed += 1
	# The towering wall ring with its cone-roofed towers, turned to face inward; skipped where the road passes
	n = int(2 * math.pi * math.sqrt((WX * WX + WZ * WZ) / 2) / 130)
	for j in range(n):
		a = j * math.tau / n
		x, z = c.x + WX * math.cos(a), c.z + WZ * math.sin(a)
		x2, z2 = c.x + WX * math.cos(a + math.tau / n), c.z + WZ * math.sin(a + math.tau / n)
		if grid.clear(x, z, 120):
			seg = math.hypot(x2 - x, z2 - z)
			ob = k.place("CityWall", ((x + x2) / 2, -1.0, (z + z2) / 2), math.atan2(z2 - z, x2 - x) * -1 + 0.0, 1.0)
			ob.scale = (seg / 130, 1.0, 1.0)  # stretch the run along its length to close the ring
	# Beyond the walls: the golden forest of the Golden Land
	for _ in range(240):
		a = k.rng.uniform(0, math.tau)
		r = k.rng.uniform(1.08, 1.22)
		k.place("Forest", (c.x + WX * r * math.cos(a), -1.0, c.z + WZ * r * math.sin(a)), k.rng.uniform(0, math.tau), k.rng.uniform(1.0, 2.2))
	# The Great Barrier over everything: a smooth flattened dome, faint gold
	ob = k.place("Barrier", (c.x, -1.0, c.z), 0.0, 1.0)
	ob.scale = (WX * 1.3, WZ * 1.3, max(WX, WZ) * 0.42)
	k.sky([(0.0, "FFC890"), (0.06, "FF9A5A"), (0.2, "D07068"), (0.5, "7A4A80"), (1.0, "2A2A5A")], strength=1.1, sun=(3.5, SUNSET, 12, 250))
