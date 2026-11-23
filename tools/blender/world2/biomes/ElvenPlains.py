"""World 2 Track 6: Elven Plains (Frieren, Aura the Guillotine arc). Reference notes: docs/world2_refs/ElvenPlains.md.

The northern plains around the count's walled hill town: bright hazy day, rolling green hills dotted with dark
conifers, a far range of big snow mountains. Landmarks, each from the source and rebuilt from primitives:
- Town: the fortified hill town (cream curtain walls ringed by round towers with slate cone roofs, a gatehouse, a
  packed roofscape, the count's mansion and a church steeple) on a plateau at the centre of the loop.
- RuinedCastle: the broken castle where the Guillotine waits (jagged keep, roofless towers, arched windows, moss).
- Squad: her headless army, a rank of withered armour with no heads, standing among felled trees (no gore).
- HeroStatue: the village statue of the hero, patina bronze in a long cloak, hands on a planted sword, on a stone
  plinth, crowned with blue flowers (faceless; no crest).
- Cottage: half-timbered village house (stone base, jettied plaster storey, timber frame, steep roof) with a fence
  and a cart; Flowers: the blue-moon-weed patches.
Everything in-house, parts only; no crest, text or numerals (design doc 5). Proposed look; the owner approves the
render set (design doc 4.46). Budget (BIOME_ENVIRONMENT_SPEC 4.5): 12 meshes, 2 hero (Town, RuinedCastle)."""

import math

GRASS, GRASS2, GRASS3 = "86BC62", "6FA656", "9CCB72"
PINE, PINE2, BARK = "2E5A3C", "3C6E46", "5A4232"
CREAM, CREAM2, SLATE, SLATE2 = "EAE0C8", "CFC3A6", "68727E", "56606C"
PLASTER, TIMBER, STONEB = "F2ECDE", "5A4030", "A7A296"
ROOF, ROOF2 = "7A5A4A", "5E6870"
RUIN, RUIN2, MOSS = "8E918A", "70746F", "5E8046"
DARK = "2A2C30"
PATINA, PATINA2, PLINTH = "6FAE9C", "548E7E", "9AA49C"
BLUE, BLUE2, WHITE = "7E8EF2", "A9B6FF", "F4F6FF"
ARMOUR, ARMOUR2, RUST, CLOTH = "4C4F58", "3A3C44", "7A5A40", "4A3A36"
SNOW, ROCK1, ROCK2 = "F4F7FC", "A4B4CC", "98A8C2"
SQ2 = math.sqrt(2)


# --- local part helpers (kit.prop part tuples) ---
def gable(w, d, h, y, color, x=0.0, z=0.0, o=1.0, **opt):
	"""Steep gable roof, ridge along X, eaves at height y, overhang o."""
	return [
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z - d / 4 - o / 2), color, dict(opt)),
		("wedge", (w + 2 * o, h, d / 2 + o), (x, y + h / 2, z + d / 4 + o / 2), color, dict(opt, rot=(0, 180, 0))),
	]


def pyramid(s, h, pos, color, **opt):
	"""Square pyramid roof of side s, base centre at pos."""
	return [("cone", (s * SQ2, h, s * SQ2), (pos[0], pos[1] + h / 2, pos[2]), color, dict(opt, seg=4, rot=(0, 45, 0)))]


def round_tower(x, z, y0, d, h, wall, roof, roof_h, seg=12, band=True):
	"""Round tower with a corbel band and a cone roof (roof None: broken top)."""
	p = [("cyl", (d, h, d), (x, y0 + h / 2, z), wall, {"seg": seg})]
	if band:
		p.append(("cyl", (d * 1.12, 2.2, d * 1.12), (x, y0 + h - 1.1, z), wall, {"seg": seg}))
	if roof:
		p.append(("cone", (d * 1.3, roof_h, d * 1.3), (x, y0 + h + roof_h / 2, z), roof, {"seg": seg}))
	return p


def pine(x, z, h, y0=0.0, lean=0.0):
	"""A dark conifer: short trunk and four stacked, narrowing cone tiers."""
	p = [("cyl", (h * 0.07, h * 0.3, h * 0.07), (x, y0 + h * 0.15, z), BARK, {"seg": 6})]
	for i, (f, w) in enumerate(((0.22, 0.46), (0.42, 0.38), (0.6, 0.28), (0.76, 0.18))):
		p.append(("cone", (h * w, h * 0.34, h * w), (x, y0 + h * f + h * 0.17, z), (PINE, PINE2)[i % 2], {"seg": 7, "rot": (lean, i * 23, 0)}))
	return p


def row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True):
	"""k.along on the ground plane, skipping any spot within `clear` of another part of the looping road."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def facing(k, d, off):
	"""Ground point `off` studs from the centre line at d, and the yaw that turns the prop's -Z toward the road."""
	pos, yaw = k.beside(d, off)
	return (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2)


# --- props ---
def flowers():
	"""Blue-moon-weed patch: low grass mound, grass tufts, five-petal blue and white blooms, two stones."""
	p = [("cyl", (18, 0.8, 13), (0, 0.4, 0), GRASS3, {"seg": 10})]
	for j in range(22):
		a, r = j * 2.39996, 1.2 * math.sqrt(j + 0.5)
		x, z = r * math.cos(a) * 1.25, r * math.sin(a)
		h = 1.6 + (j % 3) * 0.5
		p.append(("cyl", (0.25, h, 0.25), (x, 0.8 + h / 2, z), PINE2, {"seg": 3}))
		col = (BLUE, BLUE2, BLUE, WHITE)[j % 4]
		p.append(("cyl", (1.9, 0.35, 1.9), (x, 0.9 + h, z), col, {"seg": 5, "emit": 0.12, "rot": (12, j * 31, 0)}))
		p.append(("cyl", (0.6, 0.4, 0.6), (x, 1.1 + h, z), "FFF1A8", {"seg": 4}))
	for j in range(7):
		a = j * 0.9 + 0.4
		p.append(("cone", (1.6, 2.6, 1.6), (7.5 * math.cos(a), 2.0, 5.2 * math.sin(a)), GRASS2, {"seg": 4, "rot": (0, 0, (j % 3 - 1) * 14)}))
	p.append(("ball", (3, 1.6, 2.4), (-6, 1.0, 3.5), STONEB, {"subdiv": 1}))
	p.append(("ball", (2, 1.2, 1.8), (5.5, 0.9, -4), STONEB, {"subdiv": 1}))
	return p


def forest():
	"""A clump of seven conifers of mixed height on a low mound (dense pine wood at a glance)."""
	p = [("ball", (46, 6, 40), (0, -1, 0), GRASS2, {"subdiv": 2, "smooth": True})]
	for x, z, h, lean in ((0, 0, 44, 0), (12, 6, 34, 3), (-11, 5, 38, -3), (5, -12, 30, 2), (-6, -10, 26, -2), (16, -6, 22, 4), (-16, -4, 20, -4)):
		p += pine(x, z, h, 0.5, lean)
	return p


def cottage():
	"""Half-timbered village house: stone ground floor, jettied plaster upper storey with a dark timber frame and
	braces, steep shingled gable roof, chimney, shuttered windows, door; a wattle fence and a hand cart at the front."""
	W, D = 22, 16
	p = [
		("box", (W, 9, D), (0, 4.5, 0), STONEB),
		("box", (W + 0.4, 1, D + 0.4), (0, 0.5, 0), "8C877C"),
		("box", (W + 2, 10, D + 2), (0, 14.5, 0), PLASTER),  # jettied storey, 1 stud out each side
		("box", (W + 2.4, 1, D + 2.4), (0, 9.6, 0), TIMBER),  # jetty beam
		("box", (W + 2.4, 0.8, D + 2.4), (0, 19.2, 0), TIMBER),  # wall plate
	]
	p += gable(W + 2, D + 2, 13, 19.6, ROOF, o=1.6)
	p += [("box", (0.6, 12.4, 0.6), (sx * (W / 2 + 1.6), 25.6, sz * (D / 2 + 0.2)), TIMBER, {"rot": (sz * -50, 0, 0)}) for sx in (-1, 1) for sz in (-1, 1)]  # barge boards
	# Gable-end plaster triangles (the wedges cover the roof; the end walls read as plaster with a king post)
	for sx in (-1, 1):
		p.append(("box", (0.5, 11, 0.8), (sx * (W / 2 + 1.25), 25, 0), TIMBER))
	# Timber frame on the road face (-Z) and back face (+Z): posts, a mid rail and K braces
	for sz in (-1, 1):
		zf = sz * (D / 2 + 1.15)
		for x in (-11.5, -6, 0, 6, 11.5):
			p.append(("box", (0.8, 10, 0.4), (x, 14.5, zf), TIMBER))
		p.append(("box", (W + 2, 0.7, 0.4), (0, 14.8, zf), TIMBER))
		for x, r in ((-8.75, 32), (8.75, -32), (-3, -32), (3, 32)):
			p.append(("box", (0.6, 6, 0.4), (x, 12.2, zf), TIMBER, {"rot": (0, 0, r)}))
		for x in (-8.75, 3) if sz < 0 else (-3, 8.75):
			p.append(("box", (3.2, 3.2, 0.5), (x, 17.2, zf), "3E5A7A", {"rough": 0.3}))  # small leaded window
	# Ground floor: door, two shuttered windows, a window box of blue flowers
	p += [
		("box", (4.4, 7, 0.6), (-6, 3.5, -D / 2 - 0.2), "6A4A32"),
		("box", (5.4, 0.8, 0.8), (-6, 7.3, -D / 2 - 0.3), TIMBER),
		("box", (4, 3.6, 0.5), (4, 5, -D / 2 - 0.2), "2E3E52", {"rough": 0.3}),
		("box", (1.6, 3.8, 0.4), (1.2, 5, -D / 2 - 0.5), "3F6A4E"),
		("box", (1.6, 3.8, 0.4), (6.8, 5, -D / 2 - 0.5), "3F6A4E"),
		("box", (4.6, 1, 1.2), (4, 2.8, -D / 2 - 0.7), TIMBER),
	]
	for x in (2.6, 4, 5.4):
		p.append(("ball", (1.2, 1, 1.2), (x, 3.6, -D / 2 - 0.8), BLUE, {"subdiv": 1, "emit": 0.1}))
	# Stone chimney through the roof
	p += [("box", (3.4, 14, 3.4), (7, 27, 3), "8C877C"), ("box", (4, 1, 4), (7, 34.4, 3), "6E6A62")]
	# Wattle fence along the front, a bench, barrels and a two-wheeled hand cart
	for x in range(-14, 15, 4):
		p.append(("box", (0.5, 4, 0.5), (x, 2, -D / 2 - 9), TIMBER))
	p += [("box", (29, 0.5, 0.4), (0, 3.2, -D / 2 - 9), TIMBER), ("box", (29, 0.5, 0.4), (0, 1.6, -D / 2 - 9), TIMBER)]
	p += [("box", (6, 0.5, 1.6), (-6, 2.2, -D / 2 - 2.2), TIMBER), ("box", (0.5, 2, 1.4), (-8.5, 1, -D / 2 - 2.2), TIMBER), ("box", (0.5, 2, 1.4), (-3.5, 1, -D / 2 - 2.2), TIMBER)]
	for x, z in ((W / 2 + 2.5, -4), (W / 2 + 2.5, -1)):
		p.append(("cyl", (2.4, 3.4, 2.4), (x, 1.7, z), "7A5636", {"seg": 8}))
		p.append(("cyl", (2.6, 0.4, 2.6), (x, 2.4, z), DARK, {"seg": 8}))
	p += [
		("box", (6, 0.6, 4), (-W / 2 - 4, 3, -4), "8A6A44"),
		("box", (6, 1.6, 0.4), (-W / 2 - 4, 4, -6), "8A6A44"),
		("box", (6, 1.6, 0.4), (-W / 2 - 4, 4, -2), "8A6A44"),
		("cyl", (3.6, 0.5, 3.6), (-W / 2 - 4, 1.8, -6.4), TIMBER, {"seg": 10, "rot": (90, 0, 0)}),
		("cyl", (3.6, 0.5, 3.6), (-W / 2 - 4, 1.8, -1.6), TIMBER, {"seg": 10, "rot": (90, 0, 0)}),
		("box", (0.5, 0.5, 6), (-W / 2 - 7.5, 2.4, -4), TIMBER, {"rot": (0, 0, 20)}),
	]
	return p


def hero_statue():
	"""The hero's statue: stepped ashlar plinth, patina bronze figure in a long cloak, both hands on the pommel of a
	sword planted point-down before him, a blue flower crown on the head. Faceless, no crest. Front is -Z."""
	p = [
		("box", (18, 1.4, 18), (0, 0.7, 0), "8E968E"),
		("box", (15, 1.2, 15), (0, 2.0, 0), PLINTH),
		("box", (12, 9, 12), (0, 7.1, 0), PLINTH),
		("box", (13.4, 1.4, 13.4), (0, 12.3, 0), "AAB2AA"),
	]
	for y in (4.6, 7.6, 10.4):  # ashlar courses
		p.append(("box", (12.2, 0.25, 12.2), (0, y, 0), "7E8880"))
	for x in (-3, 3):
		p.append(("box", (0.25, 9, 12.2), (x, 7.1, 0), "7E8880"))
	y0 = 13.0
	s = 1.4  # figure scale: about 2.8x life size
	f = lambda v: y0 + v * s  # noqa: E731
	p += [
		("box", (1.6 * s, 1.2 * s, 2.4 * s), (-1.0 * s, f(0.6), -0.3), PATINA2),  # boots
		("box", (1.6 * s, 1.2 * s, 2.4 * s), (1.0 * s, f(0.6), -0.3), PATINA2),
		("box", (1.5 * s, 6 * s, 1.6 * s), (-1.0 * s, f(4.0), 0), PATINA),
		("box", (1.5 * s, 6 * s, 1.6 * s), (1.0 * s, f(4.0), 0), PATINA),
		("cone", (8.4 * s, 12.5 * s, 6 * s), (0, f(7.6), 0.9), PATINA2, {"seg": 10, "taper": 0.5}),  # long cloak
		("box", (4.4 * s, 6 * s, 2.6 * s), (0, f(10.0), -0.2), PATINA),  # tunic torso
		("box", (4.6 * s, 0.6 * s, 2.8 * s), (0, f(7.6), -0.2), PATINA2),  # belt
		("box", (0.7 * s, 6 * s, 0.3 * s), (0, f(10), -1.6 * s), PATINA2),  # front placket
		("cyl", (5.6 * s, 1.6 * s, 4 * s), (0, f(13.2), 0.2), PATINA2, {"seg": 10}),  # cloak collar / mantle
		("box", (1.8 * s, 1.0 * s, 0.5 * s), (0, f(12.8), -2.2 * s), PATINA2),  # cloak clasp (plain bar)
		("cyl", (1.4 * s, 1.0 * s, 1.4 * s), (0, f(14.3), 0), PATINA, {"seg": 8}),
		("ball", (2.7 * s, 3.1 * s, 2.8 * s), (0, f(16.2), 0), PATINA, {"subdiv": 2, "smooth": True}),
		("ball", (3.0 * s, 2.2 * s, 3.1 * s), (0, f(17.0), 0.25), "7DBAA8", {"subdiv": 2, "smooth": True}),  # hair
		# Arms bent so both hands rest on the pommel at the chest
		("box", (1.2 * s, 3.6 * s, 1.3 * s), (-2.6 * s, f(10.8), -0.4), PATINA2, {"rot": (25, 0, -12)}),
		("box", (1.2 * s, 3.6 * s, 1.3 * s), (2.6 * s, f(10.8), -0.4), PATINA2, {"rot": (25, 0, 12)}),
		("box", (1.1 * s, 3.2 * s, 1.2 * s), (-1.4 * s, f(8.4), -1.8 * s), PATINA2, {"rot": (60, 0, 40)}),
		("box", (1.1 * s, 3.2 * s, 1.2 * s), (1.4 * s, f(8.4), -1.8 * s), PATINA2, {"rot": (60, 0, -40)}),
		("box", (2.2 * s, 1.3 * s, 1.3 * s), (0, f(7.6), -3.0 * s), PATINA),  # clasped hands
		# The planted sword: pommel, grip, crossguard, long blade to the plinth
		("ball", (0.9 * s, 0.9 * s, 0.9 * s), (0, f(8.7), -3.0 * s), PATINA, {"subdiv": 1}),
		("box", (4.2 * s, 0.6 * s, 0.6 * s), (0, f(6.6), -3.0 * s), PATINA),
		("box", (1.1 * s, 6.6 * s, 0.35 * s), (0, f(3.2), -3.0 * s), "86C2B0", {"metal": 0.3, "rough": 0.4}),
		("box", (0.5 * s, 0.5 * s, 0.4 * s), (0, f(0.0), -3.0 * s), "86C2B0"),
	]
	# Blue moon-weed flower crown: a ring of blooms around the head
	for j in range(9):
		a = j * math.tau / 9
		p.append(("ball", (1.0 * s, 0.7 * s, 1.0 * s), (1.45 * s * math.cos(a), f(17.4), 0.25 + 1.5 * s * math.sin(a)), (BLUE, BLUE2)[j % 2], {"subdiv": 1, "emit": 0.25}))
	# Offered flowers at the plinth foot
	for j in range(7):
		p.append(("cyl", (1.6, 0.3, 1.6), (-5 + j * 1.6, 2.9, -7.8 - (j % 2) * 0.8), (BLUE, BLUE2, WHITE)[j % 3], {"seg": 5, "emit": 0.12}))
	return p


def squad():
	"""Six headless suits of withered armour in two ranks (no heads, no gore: an empty gorget ring above the
	shoulders), swords and a halberd held upright, tattered cloaks; two felled trunks and a stump of the cut forest."""
	p = []
	for i, (x, z, yaw) in enumerate(((-9, -4, 0), (0, -5, 4), (9, -4, -3), (-4.5, 5, 2), (4.5, 5, -5), (13, 5, 6))):
		lean = (i % 3 - 1) * 4
		m = {"metal": 0.6, "rough": 0.55}
		p += [
			("box", (1.4, 1.0, 2.2), (x - 0.9, 0.5, z - 0.3), ARMOUR2, m),
			("box", (1.4, 1.0, 2.2), (x + 0.9, 0.5, z - 0.3), ARMOUR2, m),
			("box", (1.3, 4.6, 1.4), (x - 0.9, 3.3, z), ARMOUR, m),
			("box", (1.3, 4.6, 1.4), (x + 0.9, 3.3, z), ARMOUR, m),
			("box", (1.5, 1.2, 1.6), (x - 0.9, 3.6, z - 0.1), ARMOUR2, m),  # knee cops
			("box", (1.5, 1.2, 1.6), (x + 0.9, 3.6, z - 0.1), ARMOUR2, m),
			("cone", (4.4, 2.6, 3.0), (x, 6.6, z), CLOTH, {"seg": 6, "taper": 0.7}),  # tasset skirt
			("box", (3.8, 4.4, 2.4), (x, 9.6, z), ARMOUR, dict(m, rot=(lean, yaw, 0))),  # breastplate
			("wedge", (3.9, 1.6, 1.0), (x, 10.4, z - 1.5), ARMOUR2, dict(m, rot=(0, 180 + yaw, 0))),  # chest ridge
			("box", (2.0, 1.4, 2.6), (x - 2.5, 11.5, z), ARMOUR2, dict(m, rot=(0, 0, 18))),  # pauldrons
			("box", (2.0, 1.4, 2.6), (x + 2.5, 11.5, z), ARMOUR2, dict(m, rot=(0, 0, -18))),
			("box", (1.1, 4.2, 1.2), (x - 2.6, 8.9, z - 0.3), ARMOUR, m),
			("box", (1.1, 4.2, 1.2), (x + 2.6, 8.9, z - 0.6), ARMOUR, dict(m, rot=(30, 0, 0))),
			("cyl", (2.2, 0.9, 2.2), (x, 12.2, z), ARMOUR2, dict(m, seg=8)),  # empty gorget ring: headless
			("cyl", (1.3, 0.5, 1.3), (x, 12.5, z), DARK, {"seg": 8}),
			("wedge", (4.0, 8.6, 1.0), (x, 7.6, z + 1.8), CLOTH, {"rot": (6, 180, 0)}),  # tattered cloak
		]
		if i % 3 == 1:  # halberd
			p += [("cyl", (0.4, 18, 0.4), (x + 2.8, 9, z - 1.6), "4A3A2C", {"seg": 5}), ("wedge", (0.3, 3, 2.4), (x + 2.8, 17, z - 2.4), RUST, {"rot": (0, 90, 0)})]
		else:  # sword raised before the chest
			p += [("box", (0.5, 7, 0.25), (x + 2.6, 9.4, z - 2.6), "8C9096", {"metal": 0.8, "rough": 0.3}), ("box", (2.2, 0.4, 0.4), (x + 2.6, 6.2, z - 2.6), RUST)]
	# Felled trunks and a stump from the cut forest (ref: the scar of broken logs in front of the town)
	p += [
		("cyl", (2.4, 22, 2.4), (-4, 1.2, 13), BARK, {"seg": 7, "rot": (0, 70, 90)}),
		("cyl", (2.0, 16, 2.0), (8, 1.0, 15), "6A5038", {"seg": 7, "rot": (0, -20, 90)}),
		("cyl", (3.2, 2.4, 3.2), (-14, 1.2, 10), "6A5038", {"seg": 8}),
		("cone", (3.2, 2.6, 3.2), (-14, 3.6, 10), "8A7050", {"seg": 8, "taper": 0.6, "rot": (20, 0, 0)}),
	]
	return p


def ruin_wall():
	"""Mid ruin: a broken stretch of castle wall with two arched windows, a roofless half tower, fallen blocks, moss."""
	p = [
		("box", (32, 18, 5), (0, 9, 0), RUIN),
		("box", (12, 8, 5), (-10, 22, 0), RUIN),
		("box", (6, 4, 5), (-1, 20, 0), RUIN),
		("box", (32.4, 2.2, 5.4), (0, 1.1, 0), MOSS),
		("box", (8, 1.6, 5.4), (-10, 26.2, 0), MOSS),
	]
	for x in (-9, 3):  # arched windows (dark recess + rounded head)
		p += [("box", (4.4, 7, 5.4), (x, 9, 0), DARK), ("cyl", (4.4, 5.4, 4.4), (x, 12.5, 0), DARK, {"rot": (90, 0, 0), "seg": 10})]
		p.append(("box", (5.6, 0.8, 6), (x, 5.2, 0), "A0A49C"))
	p += round_tower(17, 2, 0, 12, 24, RUIN2, None, 0, seg=10)
	p += [
		("box", (5, 3, 4), (17, 25, 2), RUIN2, {"rot": (0, 20, 8)}),
		("box", (6, 3.6, 4.6), (-6, 1.8, -7), RUIN2, {"rot": (0, 25, 10)}),
		("box", (4, 3, 3.6), (4, 1.5, -8), RUIN, {"rot": (14, 60, 0)}),
		("box", (3, 2.4, 3), (10, 1.2, -6), RUIN2, {"rot": (0, 10, 22)}),
		("cyl", (4, 6, 4), (-20, 2.8, -4), RUIN, {"seg": 10, "rot": (0, 30, 90)}),  # fallen column drum
		("ball", (5, 2.2, 4), (12, 0.6, -7), MOSS, {"subdiv": 1}),
	]
	return p


def ruined_castle():
	"""Hero: the ruined castle where the Guillotine waits. A rocky rise, a broken curtain wall with gaps, an arched
	gate, two roofless round towers with jagged tops, a tall square keep broken open on one side with rows of arched
	windows, a collapsed hall, rubble and moss, a dark stair to a dais in the courtyard. Front (gate) is -Z."""
	p = [
		("cyl", (240, 26, 200), (0, 6, 0), GRASS2, {"seg": 18, "taper": 0.78}),
		("ball", (120, 30, 70), (-70, 4, 60), "7A9A5E", {"subdiv": 2, "smooth": True}),
		("ball", (60, 18, 40), (90, 4, -40), STONEB, {"subdiv": 1}),
	]
	Y = 19.0
	# Curtain wall around a 150 x 120 court with gaps where it fell
	walls = (
		((-75, -60), (-18, -60)), ((18, -60), (75, -60)),
		((75, -60), (75, 10)), ((75, 34), (75, 60)),
		((75, 60), (10, 60)), ((-30, 60), (-75, 60)),
		((-75, 60), (-75, 0)), ((-75, -22), (-75, -60)),
	)
	for i, ((x1, z1), (x2, z2)) in enumerate(walls):
		L = math.hypot(x2 - x1, z2 - z1)
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		h = (30, 22, 26, 14, 28, 18, 24, 20)[i]
		cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		p.append(("box", (L, h, 6), (cx, Y + h / 2, cz), RUIN, {"rot": (0, yaw, 0)}))
		p.append(("box", (L + 0.4, 3, 6.4), (cx, Y + 1.5, cz), MOSS, {"rot": (0, yaw, 0)}))
		n = int(L // 7)
		for j in range(n):  # broken crenellation: some merlons missing
			if (j + i) % 3 == 2:
				continue
			t = (j + 0.5) / n
			p.append(("box", (3.4, 3.4, 6.2), (x1 + (x2 - x1) * t, Y + h + 1.7, z1 + (z2 - z1) * t), RUIN2, {"rot": (0, yaw, 0)}))
	# Gatehouse: two square towers and an arch
	for x in (-18, 18):
		p += [("box", (14, 40, 14), (x, Y + 20, -60), RUIN2), ("box", (15, 2, 15), (x, Y + 40, -60), RUIN)]
		p.append(("box", (2.4, 6, 0.8), (x, Y + 28, -67.3), DARK))
	p += [
		("box", (22, 12, 7), (0, Y + 30, -60), RUIN2),
		("box", (14, 22, 7.4), (0, Y + 11, -60), DARK),
		("cyl", (14, 7.4, 14), (0, Y + 22, -60), DARK, {"rot": (90, 0, 0), "seg": 12}),
		("box", (8, 8, 7), (-5, Y + 4, -42), RUIN, {"rot": (12, 30, 8)}),  # fallen gate block
	]
	# Corner towers: two standing with jagged broken tops, one collapsed to a stub
	for x, z, h in ((-75, -60, 46), (75, -60, 38), (75, 60, 52), (-75, 60, 16)):
		p += round_tower(x, z, Y, 20, h, RUIN2, None, 0, seg=12)
		p.append(("box", (8, 8, 6), (x + 4, Y + h + 4, z - 3), RUIN2, {"rot": (0, 25, 0)}))
		p.append(("box", (5, 5, 5), (x - 5, Y + h + 2.5, z + 4), RUIN2, {"rot": (0, -15, 0)}))
		for k2 in range(3):
			p.append(("box", (2, 5, 1), (x + 10.2 * math.cos(k2 * 2.1), Y + 12 + k2 * 10, z + 10.2 * math.sin(k2 * 2.1)), DARK, {"rot": (0, -math.degrees(k2 * 2.1) + 90, 0)}))
	# The keep: tall square tower broken open on one side, arched window rows, jagged crown
	kx, kz = 20, 20
	p += [
		("box", (34, 70, 34), (kx, Y + 35, kz), RUIN),
		("box", (36, 3, 36), (kx, Y + 1.5, kz), MOSS),
		("box", (36, 2.4, 36), (kx, Y + 48, kz), RUIN2),
		("box", (14, 16, 14), (kx - 10, Y + 78, kz - 10), RUIN),
		("box", (10, 10, 10), (kx + 12, Y + 75, kz + 12), RUIN),
		("box", (8, 6, 8), (kx + 12, Y + 73, kz - 12), RUIN2),
		("box", (16, 40, 2), (kx + 6, Y + 40, kz - 17.3), DARK),  # the broken-open face
		("box", (10, 6, 10), (kx + 18, Y + 3, kz - 26), RUIN2, {"rot": (20, 30, 12)}),
		("box", (7, 5, 7), (kx + 6, Y + 2.5, kz - 32), RUIN, {"rot": (-10, 50, 0)}),
	]
	for side in range(4):
		a = side * math.pi / 2
		dx, dz = math.sin(a), -math.cos(a)
		for lvl, y in enumerate((Y + 22, Y + 40, Y + 58)):
			for t in (-8, 8):
				if side == 0 and t > 0 and lvl < 2:
					continue  # inside the broken-open face
				x = kx + dx * 17.3 + dz * -t
				z = kz + dz * 17.3 + dx * t
				p.append(("box", (4, 7, 1.2), (x, y, z), DARK, {"rot": (0, -side * 90, 0)}))
				p.append(("cyl", (4, 1.2, 4), (x, y + 3.5, z), DARK, {"rot": (90, -side * 90, 0), "seg": 8}))
	# Collapsed hall: two broken side walls with arched openings and a fallen roof beam
	for z in (-28, -6):
		p.append(("box", (50, 18, 4), (-35, Y + 9, z), RUIN2))
		for x in (-50, -35, -20):
			p += [("box", (6, 9, 4.4), (x, Y + 8, z), DARK), ("cyl", (6, 4.4, 6), (x, Y + 12.5, z), DARK, {"rot": (90, 0, 0), "seg": 8})]
	p += [
		("box", (3, 3, 30), (-40, Y + 10, -17), "4A3A2C", {"rot": (0, 15, 22)}),
		("box", (30, 2, 26), (-35, Y + 1, -17), "75786F"),
	]
	# The court: rubble heaps and a stair to a dais
	for x, z, s in ((-10, 30, 9), (40, -30, 7), (-50, 30, 8), (55, 35, 6), (0, -10, 5)):
		p.append(("ball", (s * 1.6, s * 0.7, s * 1.3), (x, Y + s * 0.2, z), RUIN2, {"subdiv": 1}))
	for i in range(4):
		p.append(("box", (20 - i * 3, 1.4, 6 - i * 0.4), (-10, Y + 0.7 + i * 1.4, 12 - i * 4), "9A9D96"))
	p.append(("box", (12, 6, 4), (-10, Y + 6, -2), RUIN2))
	# Ivy and moss streaks on the keep and walls
	for x, z, h in ((kx - 17.4, kz + 4, 30), (kx + 17.4, kz - 6, 22), (-75.2, 30, 14), (60, 60.2, 12)):
		p.append(("box", (1, h, 6) if abs(x) > 50 or abs(x - kx) > 10 else (6, h, 1), (x, Y + h / 2 + 2, z), MOSS))
	return p


def town():
	"""Hero: the count's fortified town on its hill plateau (Aura arc): long cream curtain walls on an oval ring,
	14 round towers with slate cone roofs and corbel bands, crenellations, a gatehouse with square towers, a packed
	roofscape of steep gables, the count's mansion with corner turrets and a church with a spire. Gate is -Z."""
	p = [
		("cyl", (700, 70, 460), (0, 22, 0), GRASS2, {"seg": 22, "taper": 0.84}),
		("cyl", (586, 4, 384), (0, 58, 0), "7CAE5E", {"seg": 22}),
	]
	Y = 59.0
	RX, RZ, N = 230, 140, 14
	pts = [(RX * math.cos(j * math.tau / N), RZ * math.sin(j * math.tau / N)) for j in range(N)]
	for j in range(N):
		(x1, z1), (x2, z2) = pts[j], pts[(j + 1) % N]
		L = math.hypot(x2 - x1, z2 - z1) - 16
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		p.append(("box", (L, 24, 6), (cx, Y + 12, cz), CREAM, {"rot": (0, yaw, 0)}))
		p.append(("box", (L, 1.4, 7), (cx, Y + 19, cz), CREAM2, {"rot": (0, yaw, 0)}))
		n = int(L // 7)
		for i in range(n):
			t = (i + 0.5) / n
			x, z = x1 + (x2 - x1) * (0.5 + (t - 0.5) * L / (L + 16)), z1 + (z2 - z1) * (0.5 + (t - 0.5) * L / (L + 16))
			p.append(("box", (3.4, 3.6, 6.4), (x, Y + 25.8, z), CREAM, {"rot": (0, yaw, 0)}))
	for j, (x, z) in enumerate(pts):
		big = j in (0, 4, 7, 10)
		d, h = (24, 50) if big else (18, 40)
		p += round_tower(x, z, Y, d, h, CREAM, SLATE, 26 if big else 20, seg=12)
		p.append(("cyl", (2.2, 4, 2.2), (x, Y + h + (26 if big else 20) + 1, z), SLATE2, {"seg": 6}))  # finial
		p.append(("box", (1.6, 5, 1), (x, Y + h - 12, z - d / 2 - 0.2), DARK))  # arrow slit
	# Gatehouse on the south (-Z) side: square towers with pyramid roofs, arched gate, a road ramp down the hill
	gz = -RZ
	for x in (-16, 16):
		p += [("box", (16, 46, 16), (x, Y + 23, gz), CREAM), ("box", (17.4, 1.6, 17.4), (x, Y + 46.8, gz), CREAM2)]
		p += pyramid(17, 22, (x, Y + 47.6, gz), SLATE)
		p.append(("box", (3, 6, 1), (x, Y + 32, gz - 8.4), DARK))
	p += [
		("box", (18, 20, 8), (0, Y + 26, gz), CREAM2),
		("box", (12, 16, 8.4), (0, Y + 8, gz), "4A3E34"),
		("cyl", (12, 8.4, 12), (0, Y + 16, gz), "4A3E34", {"rot": (90, 0, 0), "seg": 12}),
		("box", (30, 2, 90), (0, Y - 18, gz - 50), "B8AA88", {"rot": (-22, 0, 0)}),
	]
	# Roofscape: three rings of steep-gabled houses (cream walls, grey and red-brown roofs, chimneys)
	ri = 0
	for ring, (rx, rz, n) in enumerate(((180, 104, 22), (126, 70, 16), (70, 38, 10))):
		for i in range(n):
			a = (i + 0.5 * ring) * math.tau / n
			if ring == 0 and abs(math.sin(a) + 1) < 0.12:
				continue  # keep the gate street open
			x, z = rx * math.cos(a), rz * math.sin(a)
			w, dd = 16 + (ri * 7) % 9, 12 + (ri * 5) % 5
			h = 10 + (ri * 3) % 8
			yaw = -math.degrees(a) + 90
			col = (PLASTER, CREAM, "E4D6BC")[ri % 3]
			p.append(("box", (w, h, dd), (x, Y + h / 2, z), col, {"rot": (0, yaw, 0)}))
			for part in gable(w, dd, 9 + ri % 4, Y + h, (ROOF2, ROOF, SLATE)[ri % 3], o=0.8):
				shape, size, (px, py, pz), c, o = part
				ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
				o = dict(o)
				r = o.get("rot", (0, 0, 0))
				o["rot"] = (r[0], r[1] + yaw, r[2])
				p.append((shape, size, (x + px * ca + pz * sa, py, z - px * sa + pz * ca), c, o))
			if ri % 2 == 0:
				p.append(("box", (2.4, 8, 2.4), (x + 2, Y + h + 6, z), "9A8E7A"))
			ri += 1
	# The count's mansion: a tall block with a hipped roof, four corner turrets, a walled yard
	mx, mz = -20, 30
	p += [
		("box", (64, 4, 50), (mx, Y + 2, mz), CREAM2),
		("box", (50, 36, 34), (mx, Y + 22, mz), PLASTER),
		("box", (52, 1.6, 36), (mx, Y + 40.8, mz), CREAM2),
	]
	p += gable(16, 34, 18, Y + 41.6, SLATE, x=mx, z=mz, o=0.0)
	for dx in (-8, 8):
		p += pyramid(34, 18, (mx + dx, Y + 41.6, mz), SLATE)
	for x in (-27, 27):
		for z in (-19, 19):
			p += round_tower(mx + x, mz + z, Y + 4, 10, 44, CREAM, SLATE, 18, seg=10)
	for lvl in range(3):
		for i in range(6):
			p.append(("box", (3, 5, 0.6), (mx - 18 + i * 7.2, Y + 12 + lvl * 10, mz - 17.2), "3E5068"))
	# Church: nave with a steep roof and a west tower with a tall spire
	cx, cz = 70, -10
	p += [("box", (22, 22, 56), (cx, Y + 11, cz), PLASTER)]
	p += [
		("wedge", (58, 14, 12), (cx - 6, Y + 29, cz), ROOF2, {"rot": (0, 90, 0)}),
		("wedge", (58, 14, 12), (cx + 6, Y + 29, cz), ROOF2, {"rot": (0, -90, 0)}),
	]
	p += [("box", (16, 56, 16), (cx, Y + 28, cz - 34), CREAM), ("box", (17.4, 2, 17.4), (cx, Y + 56, cz - 34), CREAM2)]
	p += [("cone", (16 * SQ2, 48, 16 * SQ2), (cx, Y + 81, cz - 34), SLATE, {"seg": 4, "rot": (0, 45, 0)})]
	for i in range(4):
		a = i * math.pi / 2
		p.append(("box", (3, 8, 0.6), (cx + 8.3 * math.sin(a), Y + 46, cz - 34 - 8.3 * math.cos(a)), DARK, {"rot": (0, -i * 90, 0)}))
	for i in range(5):
		p.append(("box", (3, 9, 0.6), (cx + 11.2, Y + 11, cz - 20 + i * 10), "3E5068", {"rot": (0, 90, 0)}))
	return p


def mountain():
	"""A far snow range chunk: three overlapping peaks with ridges and big snow caps."""
	p = []
	for x, z, r, h, c in ((0, 0, 900, 340, ROCK1), (-480, 80, 700, 250, ROCK2), (520, 60, 760, 280, "9CAEC8"), (200, 220, 560, 200, ROCK2)):
		p.append(("cone", (r, h, r * 0.7), (x, h / 2, z), c, {"seg": 11}))
		p.append(("cone", (r * 0.62, h * 0.62, r * 0.44), (x, h * 0.69 + 1, z), SNOW, {"seg": 11}))
		p.append(("cone", (r * 0.4, h * 0.36, r * 0.3), (x + r * 0.14, h * 0.5, z - r * 0.08), SNOW, {"seg": 8, "rot": (0, 30, 0)}))
	return p


def build(k):
	k.prop("Flowers", flowers())
	k.prop("Pine", pine(0, 0, 30))
	k.prop("Forest", forest())
	k.prop("Cottage", cottage())
	k.prop("HeroStatue", hero_statue())
	k.prop("Squad", squad())
	k.prop("RuinWall", ruin_wall())
	k.prop("RuinedCastle", ruined_castle())
	k.prop("Town", town())
	k.prop("Mountain", mountain())
	k.prop("Mound", [("ball", (140, 34, 100), (0, -4, 0), GRASS2, {"subdiv": 3, "smooth": True}), ("ball", (80, 30, 70), (40, -2, 18), "7DB060", {"subdiv": 3, "smooth": True})])
	k.prop("Cloud", [
		("ball", (60, 16, 34), (0, 0, 0), "FFFFFF", {"emit": 0.35, "subdiv": 2, "smooth": True}),
		("ball", (36, 20, 26), (-16, 6, 2), "FFFFFF", {"emit": 0.35, "subdiv": 2, "smooth": True}),
		("ball", (40, 22, 28), (14, 7, -2), "FFFFFF", {"emit": 0.35, "subdiv": 2, "smooth": True}),
	])

	k.ground(GRASS, margin=1100)
	cx, cz = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2

	def outside(d):
		"""+1 if the right of the road at d faces away from the loop centre, else -1."""
		p, right, _ = k.at(d)
		return 1 if (p.x + right.x - cx) ** 2 + (p.z + right.z - cz) ** 2 > (p.x - cx) ** 2 + (p.z - cz) ** 2 else -1

	# Landmark 1: the walled hill town on the horizon dead ahead of the start straight (as the source's first view of
	# it: a long pale wall line on a green rise, snow range behind), gate turned toward the runner
	sp, _, st = k.at(k.length * 0.06)
	tx, tz = cx, cz
	for D in range(900, 2600, 50):
		x, z = sp.x + st.x * D, sp.z + st.z * D
		if k.clear_of_road(x, z, 720):
			tx, tz = x, z
			break
	k.place("Town", (tx, -1.0, tz), math.atan2(-(sp.x - tx), -(sp.z - tz)), 1.9)
	keep_clear = [(tx, tz, 700)]
	front = math.atan2(sp.z - tz, sp.x - tx)
	for j in range(22):  # pine woods on the slopes round the town, the runner's side left open
		a = j * math.tau / 22 + k.rng.uniform(-0.08, 0.08)
		if abs((a - front + math.pi) % math.tau - math.pi) < 0.7:
			continue
		r = k.rng.uniform(690, 820)
		x, z = tx + r * math.cos(a), tz + r * math.sin(a)
		if k.clear_of_road(x, z, 90):
			k.place("Forest", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.4, 2.0))

	# Landmark 2: the ruined castle on its rise outside the loop, ahead of the runner at a third of the lap
	for f in (0.4, 0.45, 0.36, 0.5):
		d = k.length * f
		s = outside(d)
		pos, yaw = facing(k, d, s * 260)
		if k.clear_of_road(pos[0], pos[2], 150):
			k.place("RuinedCastle", pos, yaw, 1.5)
			keep_clear.append((pos[0], pos[2], 210))
			castle_d = d
			break
	else:
		castle_d = k.length * 0.4

	def free(x, z):
		return all((x - a) ** 2 + (z - b) ** 2 > r * r for a, b, r in keep_clear)

	# Landmark 3: villages of half-timbered cottages, each with the hero's statue on the green facing the road
	for f, side in ((0.06, -1), (0.62, 1), (0.9, -1)):
		d0 = k.length * f + 30
		s = side * outside(d0)
		pos, yaw = facing(k, d0 + 40, s * 34)
		k.place("HeroStatue", pos, yaw)
		keep_clear.append((pos[0], pos[2], 16))
		for j, (dd, off) in enumerate(((-30, 62), (10, 70), (52, 60), (90, 66), (-10, 110), (40, 118), (130, 64))):
			pos, yaw = facing(k, d0 + dd, s * off)
			if k.clear_of_road(pos[0], pos[2], 40):
				k.place("Cottage", pos, yaw + (k.rng.uniform(-0.25, 0.25) if j > 3 else 0.0), k.rng.uniform(0.95, 1.1))
				keep_clear.append((pos[0], pos[2], 26))
		for dd in (-20, 20, 70):
			pos, yaw = facing(k, d0 + dd, -s * 30)
			k.place("Flowers", pos, yaw)

	# Landmark 4: the headless army in loose ranks on the field before the castle, facing the town
	d = castle_d - k.length * 0.12
	while d < castle_d + k.length * 0.06:
		for side in (-1, 1):
			off = side * k.rng.uniform(40, 150)
			centre, _ = k.beside(d, off)
			if not (k.clear_of_road(centre[0], centre[2], 34) and free(centre[0], centre[2])):
				continue
			yaw = math.atan2(-(cx - centre[0]), -(cz - centre[2])) + k.rng.uniform(-0.3, 0.3)
			k.place("Squad", (centre[0], -1.0, centre[2]), yaw, k.rng.uniform(0.95, 1.1))
		d += k.rng.uniform(24, 40)

	# Meadow dressing by the road: blue-moon-weed patches, single pines, ruin fragments
	row(k, 34, (-30, 30), ["Flowers"], 26, jitter=4, face_road=False)
	row(k, 60, (-52, 52), ["Pine", "Pine", "Flowers"], 44, jitter=10, start=60, scale=(0.9, 1.5), face_road=False)
	row(k, 300, (-60, 60), ["RuinWall"], 50, jitter=10, start=220)
	row(k, 90, (-96, 96), ["Forest", "Pine", "Pine"], 80, jitter=20, scale=(0.9, 1.4), face_road=False)

	def scatter(count, names, clearance, margin, scale):
		placed = tries = 0
		while placed < count and tries < count * 30:
			tries += 1
			x = k.rng.uniform(k.lo.x - margin, k.hi.x + margin)
			z = k.rng.uniform(k.lo.z - margin, k.hi.z + margin)
			if free(x, z) and k.clear_of_road(x, z, clearance):
				k.place(k.rng.choice(names), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))
				placed += 1

	scatter(90, ["Forest", "Forest", "Pine"], 130, 600, (1.0, 1.8))
	scatter(60, ["Mound"], 150, 700, (0.8, 2.0))
	scatter(80, ["Flowers"], 60, 300, (1.2, 2.2))
	scatter(10, ["RuinWall"], 120, 400, (1.0, 1.3))
	# The snow range rings the plains outside the track's whole area, so it always sits on the horizon
	rad = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z) / 2 + 1700
	for j in range(22):
		a = j * math.tau / 26 + k.rng.uniform(-0.05, 0.05)
		r = rad + k.rng.uniform(-60, 220)
		k.place("Mountain", (cx + r * math.cos(a), -1.0, cz + r * math.sin(a)), a + math.pi / 2 + k.rng.uniform(-0.3, 0.3), k.rng.uniform(1.0, 1.5))
	for _ in range(22):
		x = k.rng.uniform(k.lo.x - 600, k.hi.x + 600)
		z = k.rng.uniform(k.lo.z - 600, k.hi.z + 600)
		k.place("Cloud", (x, k.rng.uniform(420, 560), z), k.rng.uniform(0, math.tau), k.rng.uniform(1.6, 3.0))
	# Bright hazy day: high warm sun, pale haze at the horizon fading to clear blue
	k.sky([(0.0, "EEF5F8"), (0.06, "CFE4F2"), (0.2, "9CC8EE"), (1.0, "5A98DC")], strength=0.8, sun=(3.4, "FFF4E0", 48, 150))
