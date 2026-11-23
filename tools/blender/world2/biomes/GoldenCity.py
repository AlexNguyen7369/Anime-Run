"""World 2 Track 9: Golden City (Frieren, Golden Land arc). Reference notes: docs/world2_refs/GoldenCity.md.

The fortress city of Weise after the Sage turned it to gold: dense street fronts of three- to five-storey ashlar
townhouses (window grids, quoins, course lines, hipped and gable roofs, dormers, tower houses with pyramid roofs),
city blocks round courtyards, wide paved squares with planters and a gabled shrine, the towering wall ring with tall
cone-roofed towers, the lord's estate in the centre (a tall hipped-roof manor ringed by spired turrets inside a walled
compound) and the large church; everything solid polished gold, roofs and ground included; townsfolk and a wagon
frozen mid-step; the gold forest beyond the walls; the Great Barrier as a smooth sphere over everything with gold
lattice lines in the sky; a golden-yellow sunset band. Landmarks (heroes): Palace, Church, Barrier.
No symbols, text or numerals (design doc 5). Everything in-house, parts only. Proposed look; the owner approves the
render set (design doc 4.46). Budget (BIOME_ENVIRONMENT_SPEC 4.5): 12 meshes, 3 hero (Palace, Church, Barrier)."""

import math

CLEAR_EXEMPT = {"Barrier"}  # the barrier sphere spans the whole city, hundreds of studs over the road (14+ rule)
MODEL_SHOTS = ["Palace", "Church", "People", "Wagon", "RowA"]  # hero close-ups (build_track.model_shots); RowA holds the townhouse blocks

GOLD, GOLD2, GOLD3, GOLDR, GOLDW = "F2C44C", "DCA83A", "FFE592", "E6AE3E", "6A4812"
SQ2 = math.sqrt(2)


def g(rough=0.3, **o):
	"""Polished gold."""
	return dict({"metal": 1.0, "rough": rough}, **o)


# --- local part helpers ---
def rotate(parts, yaw, dx=0.0, dz=0.0):
	"""Turn a list of parts by `yaw` degrees about Y (kit convention) and move it by (dx, dz)."""
	ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
	out = []
	for shape, size, (x, y, z), col, o in parts:
		o = dict(o)
		r = o.get("rot", (0, 0, 0))
		o["rot"] = (r[0], r[1] + yaw, r[2])
		out.append((shape, size, (x * ca + z * sa + dx, y, -x * sa + z * ca + dz), col, o))
	return out


def move(parts, dx=0.0, dy=0.0, dz=0.0):
	return [(s, sz, (x + dx, y + dy, z + dz), c, o) for s, sz, (x, y, z), c, o in parts]


def gable(w, d, h, y, color=GOLDR, x=0.0, z=0.0, o=0.0):
	"""Gable roof, ridge along X, eaves at height y, overhang o (gold roof)."""
	return [
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z - d / 4 - o / 2), color, g(0.3)),
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z + d / 4 + o / 2), color, g(0.3, rot=(0, 180, 0))),
	]


def pyramid(s, h, pos, color=GOLDR):
	return [("cone", (s * SQ2, h, s * SQ2), (pos[0], pos[1] + h / 2, pos[2]), color, g(0.3, seg=4, rot=(0, 45, 0)))]


def hip(w, d, h, y, color=GOLDR, x=0.0, z=0.0):
	"""Hipped roof over a w x d block (w >= d): a gable of length w - d capped by two square pyramids."""
	p = gable(w - d, d, h, y, color, x, z) if w > d + 0.1 else []
	for dx in ((-(w - d) / 2, (w - d) / 2) if w > d + 0.1 else (0,)):
		p += pyramid(d, h, (x + dx, y, z), color)
	return p


def win_grid(w, y0, floors, fh, cols, arch_top=False):
	"""Window grid on a wall face at z = 0 facing -Z: per window a bright frame and a dark recessed pane in front of it
	(arch_top: the top floor's panes get round heads)."""
	p = []
	step = w / cols
	for f in range(floors):
		y = y0 + f * fh + fh * 0.55
		for c in range(cols):
			u = -w / 2 + step * (c + 0.5)
			p.append(("box", (3.6, 5.8, 0.5), (u, y, -0.25), GOLD3, g()))
			p.append(("box", (2.4, 4.4, 0.6), (u, y - 0.2, -0.5), GOLDW, g(0.5)))
			if arch_top and f == floors - 1:
				p.append(("cyl", (2.4, 0.6, 2.4), (u, y + 2.0, -0.5), GOLDW, g(0.5, rot=(90, 0, 0), seg=8)))
	return p


def face(parts, side, w, d):
	"""Put parts built for a -Z face onto a block w x d: 'front' (-Z), 'back' (+Z), 'left' (-X), 'right' (+X)."""
	if side == "front":
		return move(parts, dz=-d / 2)
	if side == "back":
		return rotate(move(parts, dz=-d / 2), 180)
	return rotate(move(parts, dz=-w / 2), -90 if side == "left" else 90)


def building(w, d, floors, roof, cols, sides=("front", "left", "right"), fh=9.0, arch=False, dormers=0):
	"""An ashlar townhouse: plinth, body, course lines every floor, cornice, corner quoins, window grids on the given
	faces (the gable ends included), roof 'hip' | 'gable' | 'pyramid', optional dormers and a chimney."""
	H = floors * fh + 2
	p = [("box", (w, H, d), (0, H / 2, 0), GOLD, g()), ("box", (w + 1.2, 2, d + 1.2), (0, 1, 0), GOLD2, g())]
	for f in range(1, floors):
		p.append(("box", (w + 0.6, 0.6, d + 0.6), (0, 2 + f * fh, 0), GOLD3, g()))
	p.append(("box", (w + 1.4, 1.2, d + 1.4), (0, H + 0.2, 0), GOLD3, g()))
	for x in (-w / 2, w / 2):
		for z in (-d / 2, d / 2):
			p.append(("box", (1.4, H - 2, 1.4), (x, H / 2 + 1, z), GOLD3, g()))
	if "back" not in sides:  # the back face (seen across the blocks) gets a window band per floor
		for f in range(floors):
			p.append(("box", (w - 3, 3.8, 0.6), (0, 2 + f * fh + fh * 0.55, d / 2 + 0.2), GOLDW, g(0.5)))
	for s in sides:
		fw = w if s in ("front", "back") else d
		n = cols if s in ("front", "back") else max(1, int(fw // 8))
		p += face(win_grid(fw - 2, 2, floors, fh, n, arch), s, w, d)
	if roof == "hip":
		p += hip(w + 1, d + 1, d * 0.45, H + 0.8) if w >= d else rotate(hip(d + 1, w + 1, w * 0.45, H + 0.8), 90)
	elif roof == "gable":
		p += gable(w, d + 1, d * 0.5, H + 0.8, o=0.6)
		for i in range(dormers):
			x = -w / 2 + w / (dormers + 1) * (i + 1)
			p += [("box", (4.6, 5, 4), (x, H + 3.5, -d / 2 + 3), GOLD, g()), ("box", (2.8, 3, 0.6), (x, H + 3.4, -d / 2 + 0.8), GOLDW, g(0.5))]
			p += move(gable(4.6, 4, 2.6, H + 6, o=0.4), x, 0, -d / 2 + 3)
	elif roof == "pyramid":
		p += pyramid(max(w, d) + 2, max(w, d) * 0.9, (0, H + 0.8, 0))
		p += [("ball", (2, 2, 2), (0, H + max(w, d) * 0.9 + 1.6, 0), GOLD3, g(0.15, subdiv=1))]
	p.append(("box", (2.6, 7, 2.6), (w * 0.3, H + 4, d * 0.2), GOLD2, g()))
	return p, H


def kerb_set():
	"""Kerb dressing in front of a street front: a gold lantern post (warm gold glass) and a planter of gold shrubs."""
	return [
		("box", (2.4, 1.4, 2.4), (0, 0.7, 0), GOLD2, g()),
		("cyl", (0.8, 15, 0.8), (0, 8.5, 0), GOLD2, g(seg=8)),
		("box", (2.2, 3, 2.2), (0, 17.4, 0), "F0B848", g(0.2, emit=0.25)),  # lantern glass, gold and unlit (frozen)
		("box", (2.8, 0.4, 2.8), (0, 15.8, 0), GOLD2, g()),
		("cone", (3.4, 2, 3.4), (0, 19.9, 0), GOLDR, g(0.3, seg=4, rot=(0, 45, 0))),
		("box", (10, 3, 4), (8, 1.5, 0), GOLD2, g()),
		("box", (10.4, 0.6, 4.4), (8, 3.1, 0), GOLD3, g()),
		("ball", (4, 3.6, 3.6), (5.6, 4.6, 0), GOLD3, g(0.3, subdiv=1, smooth=True)),
		("ball", (4.4, 4.2, 3.8), (8.6, 5, 0), GOLD, g(0.3, subdiv=1, smooth=True)),
		("ball", (3.6, 3.4, 3.4), (11, 4.4, 0), GOLD3, g(0.3, subdiv=1, smooth=True)),
	]


def row_a():
	"""Street front A (about 84 studs): a three-storey hipped-roof house, a four-storey merchant block with a shop
	arcade, round-headed top windows and dormers, and a five-storey tower house with a pyramid roof; kerb set."""
	a, _ = building(28, 20, 3, "hip", 4, ("front", "left"))
	b, _ = building(38, 22, 4, "gable", 5, ("front",), arch=True, dormers=3)
	c, _ = building(18, 18, 5, "pyramid", 2, ("front", "right"), arch=True)
	p = move(a, -28, 0, 0) + move(b, 5, 0, 0) + move(c, 33, 0, 0)
	for i in range(4):  # shop arches on the merchant block
		p += [("box", (6, 6, 0.8), (5 - 13.5 + i * 9, 4, -11.4), GOLDW, g(0.5)), ("cyl", (6, 0.8, 6), (5 - 13.5 + i * 9, 7, -11.4), GOLDW, g(0.5, rot=(90, 0, 0), seg=10))]
	p += move(kerb_set(), -20, 0, -16) + move(kerb_set(), 22, 0, -16)  # kerb set 46 studs from the centre line
	return p


def row_b():
	"""Street front B (about 84 studs): a wide four-storey gable block with a centre pediment, a narrow tower house and
	a three-storey house with its gable end to the street; kerb set."""
	a, H = building(44, 22, 4, "gable", 6, ("front", "left"), dormers=2)
	b, _ = building(16, 16, 5, "pyramid", 2, ("front",), arch=True)
	c, _ = building(24, 20, 3, "gable", 3, ("left", "right", "front"))
	p = move(a, -19, 0, 0) + move(b, 11, 0, 2) + move(rotate(c, 90), 31, 0, 0)
	p += move(gable(14, 4, 7, H + 0.8, o=0.4), -19, 0, -10)  # centre pediment
	p += [("box", (14, 6, 4), (-19, H - 2, -10), GOLD, g()), ("cyl", (4, 0.6, 4), (-19, H + 3.5, -12.2), GOLDW, g(0.5, rot=(90, 0, 0), seg=10))]
	p += [("box", (5, 7, 0.8), (-19, 4.5, -11.4), GOLDW, g(0.5)), ("cyl", (5, 0.8, 5), (-19, 8, -11.4), GOLDW, g(0.5, rot=(90, 0, 0), seg=10))]
	p += move(kerb_set(), -24, 0, -16) + move(kerb_set(), 18, 0, -16)
	return p


def city_block():
	"""A city block of about 120 x 120 round a courtyard: eight attached buildings of three to five storeys (window
	bands, course lines, cornices, hipped roofs) and a corner tower house; seen from above it reads as a dense block."""
	p = []
	specs = ((-36, -48, 44, 22, 4, 0), (12, -48, 46, 22, 3, 0), (48, -14, 22, 50, 4, 0), (48, 34, 22, 44, 3, 0), (10, 48, 50, 22, 5, 0), (-36, 48, 40, 22, 3, 0), (-48, 10, 22, 50, 4, 0), (-48, -26, 22, 22, 5, 1))
	for x, z, w, d, fl, tower in specs:
		H = fl * 9 + 2
		p += [("box", (w, H, d), (x, H / 2, z), GOLD if fl % 2 else GOLD2, g())]
		p.append(("box", (w + 1.2, 1.2, d + 1.2), (x, H + 0.2, z), GOLD3, g()))
		for f in range(fl):  # window bands on all four faces
			y = 2 + f * 9 + 5
			p.append(("box", (w + 0.4, 3.6, d * 0.4), (x, y, z), GOLDW, g(0.5)))
			p.append(("box", (w * 0.4, 3.6, d + 0.4), (x, y, z), GOLDW, g(0.5)))
		for f in range(1, fl):
			p.append(("box", (w + 0.6, 0.6, d + 0.6), (x, 2 + f * 9, z), GOLD3, g()))
		# piers through the window bands (each box crosses both opposite faces): the bands read as window grids
		for i in range(1, int(w // 6.5)):
			p.append(("box", (1.6, fl * 9 - 2, d + 0.8), (x - w / 2 + i * w / int(w // 6.5), 2 + fl * 4.5, z), GOLD if fl % 2 else GOLD2, g()))
		for i in range(1, int(d // 6.5)):
			p.append(("box", (w + 0.8, fl * 9 - 2, 1.6), (x, 2 + fl * 4.5, z - d / 2 + i * d / int(d // 6.5)), GOLD if fl % 2 else GOLD2, g()))
		for sx in (-1, 1):  # quoins
			for sz in (-1, 1):
				p.append(("box", (1.4, fl * 9, 1.4), (x + sx * w / 2, 2 + fl * 4.5 - 1, z + sz * d / 2), GOLD3, g()))
		if tower:
			p += pyramid(w + 2, 20, (x, H + 0.8, z))
		else:
			p += move(hip(w + 1, d + 1, d * 0.42, H + 0.8) if w >= d else rotate(hip(d + 1, w + 1, w * 0.42, H + 0.8), 90), x, 0, z)
	p.append(("box", (70, 0.4, 70), (0, 0.2, 0), GOLD2, g(0.35)))  # courtyard paving
	return p


def square():
	"""A wide paved square (100 x 80): paving with joint lines, a small gabled shrine on a stepped plinth in the
	centre (the market square's kiosk), four planters of shrubs with lanterns, benches."""
	p = [("box", (100, 0.6, 80), (0, 0.3, 0), GOLD2, g(0.3))]
	for x in range(-40, 41, 10):
		p.append(("box", (0.4, 0.2, 80), (x, 0.65, 0), GOLD3, g()))
	for z in range(-30, 31, 10):
		p.append(("box", (100, 0.2, 0.4), (0, 0.65, z), GOLD3, g()))
	p += [
		("box", (14, 1.2, 14), (0, 1.2, 0), GOLD3, g()),
		("box", (11, 1.2, 11), (0, 2.4, 0), GOLD2, g()),
		("box", (8, 9, 6), (0, 7.5, 0), GOLD, g()),
		("box", (4, 6, 0.6), (0, 6.5, -3.2), GOLDW, g(0.5)),
		("cyl", (4, 0.6, 4), (0, 9.5, -3.2), GOLDW, g(0.5, rot=(90, 0, 0), seg=10)),
	]
	p += gable(8, 6, 5, 12, o=0.8)
	p += [("box", (1, 3, 1), (0, 18.5, 0), GOLD3, g()), ("ball", (1.6, 1.6, 1.6), (0, 20.6, 0), GOLD3, g(0.15, subdiv=1))]
	for x, z in ((-30, -24), (30, -24), (-30, 24), (30, 24)):
		p += move(kerb_set(), x - 8, 0, z)
	for x in (-14, 14):
		p += [("box", (7, 0.6, 2.2), (x, 2.4, -30), GOLD2, g()), ("box", (7, 2.4, 0.5), (x, 3.8, -29), GOLD2, g())]
	return p


def city_wall():
	"""A 130-stud run of the towering city wall: plinth, courses, crenellated walk, slits, and a round tower with a
	corbel band and a very tall slender cone roof (the walls' signature on the skyline)."""
	L, H, T = 130, 50, 12
	p = [
		("box", (L, H, T), (0, H / 2, 0), GOLD2, g(0.3)),
		("box", (L, 8, T + 4), (0, 4, 0), GOLDR, g(0.3)),
		("box", (L + 0.4, 1.6, T + 1.6), (0, H - 0.8, 0), GOLD3, g()),
	]
	for y in (16, 32):
		p.append(("box", (L, 0.6, T + 0.4), (0, y, 0), GOLD3, g()))
	for i in range(int(L // 6)):
		p.append(("box", (3.4, 4, T), (-L / 2 + 3 + i * 6, H + 2, 0), GOLD3, g()))
	for x in range(-50, 51, 20):
		p.append(("box", (1.6, 6, 0.8), (x, 36, -T / 2 - 0.2), GOLDW, g(0.5)))
	x = L / 2
	p += [
		("cyl", (34, 96, 34), (x, 48, 0), GOLD, g(seg=14)),
		("cyl", (39, 3, 39), (x, 94.5, 0), GOLD3, g(seg=14)),
		("cone", (44, 96, 44), (x, 144, 0), GOLDR, g(0.3, seg=14)),
		("ball", (5, 5, 5), (x, 193, 0), GOLD3, g(0.15, subdiv=1)),
	]
	for y in (40, 64):
		for a in (-0.6, 0.6):
			p.append(("box", (2, 7, 0.8), (x + 17 * math.sin(a), y, -17 * math.cos(a)), GOLDW, g(0.5, rot=(0, -math.degrees(a), 0))))
	return p


def turret(x, z, y0, dia, h, cone_h, seg=10):
	"""Slender round turret: shaft, window, corbel band, tall cone spire and a ball finial."""
	return [
		("cyl", (dia, h, dia), (x, y0 + h / 2, z), GOLD, g(seg=seg)),
		("cyl", (dia * 1.18, 2.2, dia * 1.18), (x, y0 + h - 1.1, z), GOLD3, g(seg=seg)),
		("cone", (dia * 1.3, cone_h, dia * 1.3), (x, y0 + h + cone_h / 2, z), GOLDR, g(0.3, seg=seg)),
		("ball", (dia * 0.22, dia * 0.22, dia * 0.22), (x, y0 + h + cone_h + dia * 0.08, z), GOLD3, g(0.15, subdiv=1)),
		("box", (1.6, 4.4, 0.8), (x, y0 + h * 0.7, z - dia / 2), GOLDW, g(0.5)),
	]


def palace():
	"""Hero: the lord's estate (refs 01, 02): a walled court with crenels, corner turrets and a gatehouse; the tall
	manor (central pavilion with a steep hipped roof and a pediment gable, two wings), window grids, dormers,
	chimneys; a ring of eight tall spired turrets round the manor (the cluster of cones over the city). Gate is -Z."""
	p = [("box", (170, 3, 150), (0, 1.5, 0), GOLD2, g(0.3))]
	for (x1, z1, x2, z2) in ((-85, -75, -14, -75), (14, -75, 85, -75), (85, -75, 85, 75), (85, 75, -85, 75), (-85, 75, -85, -75)):
		L = math.hypot(x2 - x1, z2 - z1)
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		p.append(("box", (L, 20, 5), ((x1 + x2) / 2, 10, (z1 + z2) / 2), GOLD2, g(0.3, rot=(0, yaw, 0))))
		for i in range(int(L // 8)):
			t = (i + 0.5) / int(L // 8)
			p.append(("box", (3.4, 3, 5.4), (x1 + (x2 - x1) * t, 21.5, z1 + (z2 - z1) * t), GOLD3, g(rot=(0, yaw, 0))))
	for x in (-85, 85):
		for z in (-75, 75):
			p += turret(x, z, 0, 14, 36, 30)
	for x in (-14, 14):
		p += [("box", (10, 32, 10), (x, 16, -75), GOLD, g())] + pyramid(11, 14, (x, 32, -75))
	p += [("box", (18, 10, 6), (0, 25, -75), GOLD, g()), ("box", (14, 16, 6.4), (0, 8, -75), GOLDW, g(0.5)), ("cyl", (14, 6.4, 14), (0, 16, -75), GOLDW, g(0.5, rot=(90, 0, 0), seg=12))]
	for x in (-40, 40):  # wings
		wing, _ = building(36, 30, 3, "hip", 4, ("front", "left" if x < 0 else "right"), fh=10)
		p += move(wing, x, 0, 10)
	core, H = building(46, 40, 5, "none", 5, ("front", "left", "right"), fh=10, arch=True)
	p += move(core, 0, 0, 6)
	p += move(hip(47, 41, 30, H + 0.8), 0, 0, 6)
	p += [("box", (22, 16, 4), (0, H + 8, -15), GOLD, g()), ("box", (8, 8, 0.6), (0, H + 7, -17.2), GOLDW, g(0.5))]
	p += move(gable(24, 4, 11, H + 16, o=0.6), 0, 0, -15)
	p += [("box", (24, 1.2, 5), (0, 22, -16.5), GOLD3, g()), ("box", (24, 3, 0.6), (0, 24, -18.8), GOLD3, g())]
	for x in (-14, 14):
		p += [("box", (5, 6, 4), (x, H + 6, -11), GOLD, g()), ("box", (3, 3.5, 0.6), (x, H + 6, -13.2), GOLDW, g(0.5))]
	for x, z, h, c in ((-26, -16, 92, 52), (26, -16, 92, 52), (-26, 28, 84, 46), (26, 28, 84, 46), (-62, -6, 64, 40), (62, -6, 64, 40), (-62, 26, 58, 34), (62, 26, 58, 34)):
		p += turret(x, z, 0, 13 if h > 80 else 11, h, c)
	return p


def church():
	"""Hero: the city's large church: a long nave with a steep roof and a clerestory of tall arched windows over lower
	side aisles with lean-to roofs and buttresses; a transept with its own gables and an octagonal crossing lantern;
	a round apse; the west tower rising in stages to a belfry of paired arches with corner pinnacles and a tall
	octagonal spire; a deep arched portal and a pair of tall lancet windows (no round window or dial). West front is -Z."""
	NW, NH, NL, NZ = 40, 46, 120, 50  # nave width, wall height, length, centre z
	p = [("box", (NW, NH, NL), (0, NH / 2, NZ), GOLD, g()), ("box", (NW + 1.4, 1.4, NL + 1.4), (0, NH + 0.2, NZ), GOLD3, g())]
	p += rotate(gable(NL, NW + 1, 30, NH + 0.8, o=0.6), 90, 0, NZ)
	for s in (-1, 1):  # aisles, lean-to roofs, buttresses, windows
		ax = s * (NW / 2 + 9)
		p += [("box", (18, 24, NL - 10), (ax, 12, NZ + 5), GOLD2, g()), ("box", (18.8, 1, NL - 9), (ax, 24.4, NZ + 5), GOLD3, g())]
		p.append(("wedge", (NL - 10, 10, 19), (ax, 29.4, NZ + 5), GOLDR, g(0.3, rot=(0, 90 * -s, 0))))
		for i in range(7):
			z = NZ - NL / 2 + 16 + i * 15
			p.append(("box", (4, 22, 5), (s * (NW / 2 + 19), 11, z + 7.5), GOLD3, g()))
			p.append(("box", (0.8, 12, 4.4), (s * (NW / 2 + 18.2), 12, z), GOLDW, g(0.5)))
			p.append(("cyl", (4.4, 0.8, 4.4), (s * (NW / 2 + 18.2), 18, z), GOLDW, g(0.5, rot=(0, 0, 90), seg=8)))
			p.append(("box", (0.8, 12, 4), (s * (NW / 2 + 0.2), 36, z), GOLDW, g(0.5)))  # clerestory
			p.append(("cyl", (4, 0.8, 4), (s * (NW / 2 + 0.2), 42, z), GOLDW, g(0.5, rot=(0, 0, 90), seg=8)))
	tz = NZ + 30  # transept
	p += [("box", (110, 42, 32), (0, 21, tz), GOLD, g())]
	p += move(gable(110, 33, 24, 42.8, o=0.6), 0, 0, tz)
	for s in (-1, 1):
		p.append(("box", (0.8, 22, 8), (s * 55.2, 22, tz), GOLDW, g(0.5)))
		p.append(("cyl", (8, 0.8, 8), (s * 55.2, 33, tz), GOLDW, g(0.5, rot=(0, 0, 90), seg=10)))
	p += [("cyl", (30, 20, 30), (0, 80, tz), GOLD2, g(seg=8)), ("cone", (34, 40, 34), (0, 110, tz), GOLDR, g(0.3, seg=8)), ("ball", (4, 4, 4), (0, 132, tz), GOLD3, g(0.15, subdiv=1))]
	p += [("cyl", (NW, NH - 6, NW), (0, (NH - 6) / 2, NZ + NL / 2), GOLD2, g(seg=14)), ("cone", (NW + 4, 22, NW + 4), (0, NH - 6 + 11, NZ + NL / 2), GOLDR, g(0.3, seg=14))]
	T, TH = 36, 120  # west tower in stages
	tzc = NZ - NL / 2 - T / 2 + 2
	p += [("box", (T, TH, T), (0, TH / 2, tzc), GOLD2, g())]
	for y in (46, 84, TH):
		p.append(("box", (T + 2.4, 2.4, T + 2.4), (0, y, tzc), GOLD3, g()))
	for x in (-T / 2, T / 2):
		for z in (-T / 2, T / 2):
			p.append(("box", (5, TH * 0.9, 5), (x, TH * 0.45, tzc + z), GOLD3, g()))  # corner buttresses
			p += [("box", (5, 12, 5), (x, TH + 7, tzc + z), GOLD, g()), ("cone", (6, 20, 6), (x, TH + 23, tzc + z), GOLDR, g(0.3, seg=6))]
	for side in range(4):  # belfry: paired arched openings on every face
		for x in (-7, 7):
			p += rotate([("box", (6, 20, 1.2), (x, 100, -T / 2 - 0.1), GOLDW, g(0.5)), ("cyl", (6, 1.2, 6), (x, 110, -T / 2 - 0.1), GOLDW, g(0.5, rot=(90, 0, 0), seg=8))], side * 90, 0, tzc)
	p += [("cyl", (T * 0.92, 8, T * 0.92), (0, TH + 4, tzc), GOLD, g(seg=8)), ("cone", (T, 96, T), (0, TH + 56, tzc), GOLDR, g(0.3, seg=8)), ("ball", (5, 5, 5), (0, TH + 106, tzc), GOLD3, g(0.12, subdiv=1))]
	fz = tzc - T / 2  # portal and lancet windows on the west face
	p += [
		("box", (20, 30, 2), (0, 15, fz - 1), GOLD3, g()),
		("box", (12, 22, 2.4), (0, 11, fz - 1.4), GOLDW, g(0.5)),
		("cyl", (12, 2.4, 12), (0, 22, fz - 1.4), GOLDW, g(0.5, rot=(90, 0, 0), seg=12)),
	]
	for x in (-6, 6):  # a pair of tall lancet windows over the portal (no round window: it read as a clock face)
		p += [("box", (6.4, 30, 1.4), (x, 58, fz - 0.6), GOLD3, g()), ("box", (4.2, 27, 1.8), (x, 57, fz - 1.0), GOLDW, g(0.5))]
		p += rotate(gable(1.4, 6.4, 6, 73, GOLD3), 90, x, fz - 0.6)  # pointed head
	p += [("box", (1.0, 27, 0.6), (x, 57, fz - 2.0), GOLD3, g()) for x in (-6, 6)]  # mullions
	p += move(gable(26, 2, 10, 80, o=0.0), 0, 0, fz - 1.0)  # gablet over the lancets
	return p


def barrier():
	"""Hero: the Great Barrier: a smooth unit sphere (scaled uniformly when placed), faint gold, and two thin glowing
	gold rim rings (low and mid latitude) that draw the dome's edge as a line in the sky."""
	p = [("ball", (2, 2, 2), (0, 0, 0), "FFE9B0", {"alpha": 0.1, "rough": 0.1, "emit": 0.15, "subdiv": 5, "smooth": True})]
	t = 0.0016
	line = {"emit": 1.6, "metal": 0.4, "rough": 0.2}
	for e, n in ((5, 96), (34, 72)):
		er = math.radians(e)
		for i in range(n):
			ph = (i + 0.5) * math.tau / n
			L = math.tau * math.cos(er) / n * 1.04
			yaw = math.degrees(math.atan2(-math.cos(ph), -math.sin(ph)))
			p.append(("box", (L, t, t), (math.cos(er) * math.cos(ph), math.sin(er), math.cos(er) * math.sin(ph)), "FFE07A", dict(line, rot=(0, yaw, 0))))
	return p


def people():
	"""Three townsfolk frozen in gold mid-stride, faceless and hooded: a cloaked traveller with a staff, a woman with
	a basket, a running child. Smooth cloaks (tapered cones), legs in stride below the hem, clear silhouettes."""
	p = []
	for x, z, s, stride, extra in ((-5, 0, 1.0, 28, "staff"), (3, 3, 0.95, 18, "basket"), (9, -3, 0.68, 36, "child")):
		f = lambda v: v * s  # noqa: E731
		sn = math.sin(math.radians(stride))
		p += [
			("box", (1.3 * s, 6 * s, 1.5 * s), (x - 0.8 * s, f(3), z), GOLD2, g(rot=(stride, 0, 0))),
			("box", (1.3 * s, 6 * s, 1.5 * s), (x + 0.8 * s, f(3), z), GOLD2, g(rot=(-stride, 0, 0))),
			("box", (1.6 * s, 1.2 * s, 2.6 * s), (x - 0.8 * s, f(0.6), z - f(2.6) * sn), GOLD2, g()),
			("box", (1.6 * s, 1.2 * s, 2.6 * s), (x + 0.8 * s, f(0.6), z + f(2.6) * sn), GOLD2, g()),
			("cone", (6.6 * s, 11.5 * s, 5.6 * s), (x, f(8.4), z + 0.5 * s), GOLD, g(0.22, seg=16, taper=0.48, smooth=True, rot=(5, 0, 0))),  # long cloak, shoulders to calf
			("cone", (4.6 * s, 2.6 * s, 4.0 * s), (x, f(14.3), z + 0.3 * s), GOLD, g(0.22, seg=16, taper=0.55, smooth=True)),  # capelet over the shoulders
			("ball", (2.2 * s, 2.6 * s, 2.4 * s), (x, f(16.3), z - 0.55 * s), GOLD3, g(0.2, subdiv=2, smooth=True)),  # head (faceless)
			("ball", (3.4 * s, 3.7 * s, 3.3 * s), (x, f(16.7), z + 0.6 * s), GOLD, g(0.22, subdiv=2, smooth=True)),  # hood framing the face
			("cone", (1.6 * s, 2.8 * s, 1.6 * s), (x, f(16.4), z + 2.2 * s), GOLD, g(0.22, seg=10, smooth=True, rot=(110, 0, 0))),  # hood tip falling back
			("cone", (1.6 * s, 5 * s, 1.6 * s), (x + 2.1 * s, f(11.2), z - 1.0 * s), GOLD2, g(rot=(150, 0, 6), seg=10, taper=0.65, smooth=True)),  # arm bent forward in a wide sleeve, cuff at the hand
		]
		if extra == "staff":
			p.append(("cyl", (0.6, 19, 0.6), (x + 3.2, 9.5, z - 3.2), GOLDR, g(seg=6, rot=(-10, 0, 0))))
			p.append(("ball", (1.4, 1.4, 1.4), (x + 3.2, 19, z - 4.8), GOLD3, g(0.15, subdiv=1)))
		elif extra == "basket":
			p += [("cyl", (3.4, 2.2, 3.4), (x + 2.6, 9.6, z - 4.2), GOLDR, g(seg=10)), ("ball", (3, 1.4, 3), (x + 2.6, 10.9, z - 4.2), GOLD3, g(subdiv=1, smooth=True))]
	return p


def wagon():
	"""A covered wagon frozen in gold with its draught horse mid-step: plank bed with sides, four spoked wheels, a big
	hooped canvas canopy, shafts; the horse (body, neck, head, mane, tail, legs mid-stride); crates and a barrel."""
	p = [
		("box", (9, 1.4, 18), (0, 4.6, 0), GOLD2, g()),
		("box", (9.4, 3, 0.6), (0, 6.6, 9), GOLD, g()),
		("box", (0.6, 3, 18), (-4.6, 6.6, 0), GOLD, g()),
		("box", (0.6, 3, 18), (4.6, 6.6, 0), GOLD, g()),
		("cyl", (10, 17, 11), (0, 8.4, 0.4), GOLD3, g(0.3, rot=(90, 0, 0), seg=16, smooth=True)),  # canopy
	]
	for i in range(5):
		p.append(("cyl", (10.6, 0.7, 11.6), (0, 8.4, -7.6 + i * 4), GOLD, g(rot=(90, 0, 0), seg=16)))
	for x in (-5.2, 5.2):
		for z in (-6, 6):
			p += [("cyl", (6.4, 0.8, 6.4), (x, 3.2, z), GOLD, g(rot=(0, 0, 90), seg=14)), ("cyl", (1.6, 1.4, 1.6), (x, 3.2, z), GOLD3, g(rot=(0, 0, 90), seg=8))]
			for a in (0, 60, 120):
				p.append(("box", (0.6, 5.6, 0.5), (x, 3.2, z), GOLD3, g(rot=(a, 0, 0))))
	p += [("box", (0.6, 0.6, 12), (x, 4.6, -14), GOLD2, g(rot=(-4, 0, 0))) for x in (-2.4, 2.4)]
	p += [
		# the draught horse, smooth-shaded: barrel body, chest and haunch, arched neck, tapered head, mane, tail
		("cyl", (4.4, 9, 4.8), (0, 9.2, -21), GOLD, g(rot=(90, 0, 0), seg=14, smooth=True)),
		("ball", (4.8, 5.2, 5.2), (0, 9.4, -16.6), GOLD, g(subdiv=3, smooth=True)),  # haunch
		("ball", (4.6, 5.4, 5.0), (0, 9.6, -25.4), GOLD, g(subdiv=3, smooth=True)),  # chest
		("cone", (3.6, 7.4, 3.0), (0, 13.6, -27.8), GOLD, g(rot=(-34, 0, 0), seg=12, taper=0.62, smooth=True)),  # neck
		("cone", (2.6, 5.2, 2.2), (0, 15.4, -31.2), GOLD3, g(rot=(-112, 0, 0), seg=12, taper=0.55, smooth=True)),  # head, muzzle forward-down
		("ball", (1.0, 1.6, 0.8), (-0.8, 17.6, -29.8), GOLD3, g(subdiv=2, smooth=True)),  # ears
		("ball", (1.0, 1.6, 0.8), (0.8, 17.6, -29.8), GOLD3, g(subdiv=2, smooth=True)),
		("box", (0.6, 7.0, 1.0), (0, 14.4, -27.2), GOLDR, g(rot=(-34, 0, 0))),  # mane
		("cone", (1.6, 6.5, 1.2), (0, 7.4, -13.4), GOLDR, g(rot=(155, 0, 0), seg=8, taper=0.4, smooth=True)),  # tail
		("box", (4.8, 0.6, 3.6), (0, 11.4, -22), GOLD3, g()),  # harness pad
	]
	for x, z, r in ((-1.4, -16.8, 12), (1.4, -16.8, -6), (-1.4, -25.2, -12), (1.4, -25.2, 8)):  # legs mid-stride, hooves
		p.append(("cone", (1.6, 7.6, 1.6), (x, 3.8, z), GOLD2, g(rot=(r, 0, 0), seg=8, taper=0.62, smooth=True)))
		p.append(("cyl", (1.4, 0.9, 1.6), (x, 0.45, z - 3.4 * math.sin(math.radians(r))), GOLDR, g(seg=8)))
	p += [("box", (4, 4, 4), (8, 2, 4), GOLD2, g()), ("box", (3, 3, 3), (8, 5.5, 4.4), GOLD3, g(rot=(0, 20, 0))), ("cyl", (3, 4, 3), (8, 2, -2), GOLDR, g(seg=10))]
	return p


def tree():
	"""A gold-leaf tree: a tall visible trunk with two limbs and a canopy of three layered tiers of leaf clusters."""
	p = [
		("cyl", (2.6, 18, 2.6), (0, 9, 0), GOLDR, g(0.3, seg=8)),
		("cyl", (1.2, 8, 1.2), (2.2, 15, 0), GOLDR, g(0.3, seg=6, rot=(0, 0, -38))),
		("cyl", (1.2, 8, 1.2), (-2.2, 15.5, 1), GOLDR, g(0.3, seg=6, rot=(0, 0, 38))),
	]
	for y, r, n, size in ((17, 6.5, 5, 7.5), (22, 4.5, 4, 6.5), (26.5, 1.5, 2, 5.5)):
		for i in range(n):
			a = i * math.tau / n + y
			p.append(("ball", (size, size * 0.62, size), (r * math.cos(a), y, r * math.sin(a)), (GOLD3, GOLD)[i % 2], g(0.28, subdiv=1, smooth=True)))
	return p


def forest():
	"""The golden forest beyond the walls: a mound with a dense clump of gold conifers."""
	p = [("ball", (90, 14, 70), (0, -2, 0), GOLD2, g(0.35, subdiv=2, smooth=True))]
	for x, z, h in ((0, 0, 40), (18, 8, 32), (-16, 6, 36), (8, -16, 28), (-12, -14, 30), (26, -10, 24), (-28, -4, 22), (30, 14, 20)):
		p.append(("cyl", (2, h * 0.3, 2), (x, 4 + h * 0.15, z), GOLDR, g(0.3, seg=5)))
		for i, (f, w) in enumerate(((0.3, 0.5), (0.52, 0.36), (0.72, 0.22))):
			p.append(("cone", (h * w, h * 0.36, h * w), (x, 4 + h * f + h * 0.18, z), (GOLD, GOLD3, GOLD)[i], g(0.28, seg=7)))
	return p


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


def build(k):
	k.prop("RowA", row_a())
	k.prop("RowB", row_b())
	k.prop("CityBlock", city_block())
	k.prop("Square", square())
	k.prop("CityWall", city_wall())
	k.prop("Palace", palace())
	k.prop("Church", church())
	k.prop("Barrier", barrier())
	k.prop("People", people())
	k.prop("Wagon", wagon())
	k.prop("Tree", tree())
	k.prop("Forest", forest())

	grid = RoadGrid(k)
	c = (k.lo + k.hi) / 2
	hx, hz = (k.hi.x - k.lo.x) / 2, (k.hi.z - k.lo.z) / 2
	WX, WZ = hx * 1.3 + 160, hz * 1.3 + 160  # wall ring (ellipse) round the whole city
	RB = max(WX, WZ) * 1.12  # barrier sphere radius
	gr = k.ground("E2B24E", margin=RB - max(hx, hz) + 5000, rough=0.3)
	bsdf = next(n for n in gr.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Metallic"].default_value = 0.85  # the ground is gold too

	keep_clear = []

	def free(x, z, r=0.0):
		return all((x - a) ** 2 + (z - bz) ** 2 > (rr + r) ** 2 for a, bz, rr in keep_clear)

	def on_sightline(f, clear, scale, name):
		"""A landmark dead ahead of the runner's camera at fraction f, beyond where the straight ends, facing it."""
		p, _, t = k.at(k.length * f)
		for D in range(260, 3000, 20):
			x, z = p.x + t.x * D, p.z + t.z * D
			if grid.clear(x, z, clear) and free(x, z, clear):
				k.place(name, (x, -1.0, z), math.atan2(-(p.x - x), -(p.z - z)), scale)
				keep_clear.append((x, z, clear))
				return

	on_sightline(0.33, 220, 1.7, "Palace")  # court corner at 1.7x is 192 from its centre
	on_sightline(0.62, 200, 1.5, "Church")  # apse end reaches 165 from its origin at 1.5x

	# Wide squares at intervals beside the road, alternating sides
	squares = []
	d, side = 400.0, 1
	while d < k.length - 300:
		pos, yaw = k.beside(d, side * 78)
		if grid.clear(pos[0], pos[2], 70) and free(pos[0], pos[2], 60):
			k.place("Square", (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if side > 0 else -math.pi / 2), 1.0)
			squares.append((d, side))
			keep_clear.append((pos[0], pos[2], 60))
		d += 1100
		side = -side

	def near_square(d, side):
		return any(abs(d - sd) < 75 and ss == side for sd, ss in squares)

	# Street fronts: continuous rows of townhouses facing the road on both sides, with kerb lanterns and planters
	d, i = 30.0, 0
	while d < k.length - 70:
		for side in (-1, 1):
			if near_square(d, side):
				continue
			pos, yaw = k.beside(d, side * 62)
			if grid.clear(pos[0], pos[2], 56) and free(pos[0], pos[2], 30):
				k.place(("RowA", "RowB")[(i + (side > 0)) % 2], (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if side > 0 else -math.pi / 2), 1.0)
		d += 86
		i += 1
	# Frozen people, trees and wagons on the pavements
	for every, off, names, start, spin in ((120, 38, ["People"], 60, True), (170, 36, ["Tree"], 100, False), (430, 45, ["Wagon"], 220, False)):  # group radius about 11: 24+ from the centre line
		d = start
		while d < k.length - 70:
			for side in (-1, 1):
				pos, yaw = k.beside(d + k.rng.uniform(-8, 8), side * off)
				if grid.clear(pos[0], pos[2], off * 0.9) and free(pos[0], pos[2], 4):
					k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), k.rng.uniform(0, math.tau) if spin else yaw, 1.0)  # wagons and trees keep to the road's heading
			d += every

	# The rest of the city on a street grid: blocks round courtyards, every so often an open square
	cell, n = 168, 0
	x0 = c.x - WX
	while x0 < c.x + WX:
		z0 = c.z - WZ
		while z0 < c.z + WZ:
			x, z = x0 + k.rng.uniform(-6, 6), z0 + k.rng.uniform(-6, 6)
			if ((x - c.x) / (WX - 90)) ** 2 + ((z - c.z) / (WZ - 90)) ** 2 < 1 and grid.clear(x, z, 150) and free(x, z, 90):
				n += 1
				if n % 13 == 0:
					k.place("Square", (x, -1.0, z), 0.0, 1.0)
				else:
					k.place("CityBlock", (x, -1.0, z), round(k.rng.uniform(0, 3)) * math.pi / 2, k.rng.uniform(1.0, 1.2))
			z0 += cell
		x0 += cell
	# The towering wall ring with its tall cone-roofed towers; skipped where the road passes
	nw = int(2 * math.pi * math.sqrt((WX * WX + WZ * WZ) / 2) / 130)
	for j in range(nw):
		a = j * math.tau / nw
		x, z = c.x + WX * math.cos(a), c.z + WZ * math.sin(a)
		x2, z2 = c.x + WX * math.cos(a + math.tau / nw), c.z + WZ * math.sin(a + math.tau / nw)
		if grid.clear(x, z, 120):
			ob = k.place("CityWall", ((x + x2) / 2, -1.0, (z + z2) / 2), -math.atan2(z2 - z, x2 - x), 1.0)
			ob.scale = (math.hypot(x2 - x, z2 - z) / 130, 1.0, 1.0)
	# Beyond the walls: the golden forest of the Golden Land
	for _ in range(150):
		a = k.rng.uniform(0, math.tau)
		r = k.rng.uniform(1.06, 1.24)
		k.place("Forest", (c.x + WX * r * math.cos(a), -1.0, c.z + WZ * r * math.sin(a)), k.rng.uniform(0, math.tau), k.rng.uniform(1.4, 2.6))
	# The Great Barrier: a true sphere over everything, its gold lattice lines visible in the sky from the road
	k.place("Barrier", (c.x, -1.0, c.z), 0.0, RB)
	# Sunset: a golden-yellow sun band at the horizon, warm peach above, dusky rose overhead
	k.sky([(0.0, "FFE27A"), (0.05, "FFD060"), (0.14, "FFB458"), (0.3, "F0A070"), (0.6, "C88A80"), (1.0, "8A6A88")], strength=1.3, sun=(2.8, "FFD890", 16, 250))
