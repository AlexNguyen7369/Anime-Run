"""World 2 Track 6: Elven Plains (Frieren, Aura the Guillotine arc). Reference notes: docs/world2_refs/ElvenPlains.md.

The northern plains around the count's walled hill town: bright hazy day (cyan sky fading to near-white haze at the
horizon), rolling green hills, dark conifer woods with dirt paths, paler desaturated far woods, one broad snow massif
on the horizon. Landmarks, each from the source and rebuilt from primitives:
- Town (hero): the fortified hill town: a long, low cream curtain wall with unevenly spaced round towers (slate cone
  roofs) and a few square towers along the top of a broad green rise, a packed roofscape, the mansion and church, and
  below the wall the arc's scar: a band of felled dark trunks, stumps and bare earth.
- RuinedCastle (hero): the broken castle where the Guillotine waits (EP9 interior: tall round-arched windows in
  brick-coursed stone, a broken vault): a ruined hall and keep with Romanesque arched window rows and a collapsed gable.
- Rank: her headless army, about thirty bulky suits of near-black plate with an empty gorget ring above the shoulders (no
  heads, no gore), halberd tips up, massed on a raised mound among pines.
- HeroStatue: the village statue of the hero: slim patina figure about 7.5 heads tall, floor-length cape flaring at the
  hem, stacked high collar, bob hair, both hands on the pommel of a long sword planted to the plinth, on a wide
  two-course ashlar plinth, crowned with nine five-petal blue blooms (faceless; no crest).
- Cottage: three-storey half-timbered town house, gable to the street; Mound: rolling swell with a dirt path;
  Flowers: low blue-moon-weed clusters.
Everything in-house, parts only; no crest, text or numerals (design doc 5). Proposed look; the owner approves the
render set (design doc 4.46). Budget (BIOME_ENVIRONMENT_SPEC 4.5): 12 meshes, 2 hero (Town, RuinedCastle)."""

import math

MODEL_SHOTS = ["Town", "RuinedCastle", "Rank", "HeroStatue", "Cottage"]  # hero close-ups (build_track.model_shots); Rank is the headless army

GRASS, GRASS2, GRASS3 = "86BC62", "6FA656", "9CCB72"
PINE, PINE2, BARK = "2E5A3C", "3C6E46", "5A4232"
FARG, FARP, FARP2 = "8CC46C", "8FB0A0", "A0BCAE"  # far, hazed: desaturated and lighter
CREAM, CREAM2, SLATE, SLATE2 = "EAE0C8", "CFC3A6", "68727E", "56606C"
PLASTER, TIMBER, STONEB = "F2ECDE", "5A4030", "A7A296"
ROOF, ROOF2 = "7A5A4A", "5E6870"
RUIN, RUIN2, RUIN3, MOSS = "9A8E80", "7E7468", "B0A494", "5E8046"
DARK = "2A2C30"
EARTH, EARTH2, DEADWOOD = "7A6448", "8E7656", "4A3828"
PATINA, PATINA2, PATINA3, PLINTH, PLINTH2 = "5E9C86", "467C6A", "7AB6A0", "A0A89E", "8A9288"
BLUE, BLUE2, WHITE = "7E8EF2", "A9B6FF", "F4F6FF"
STEEL, STEEL2, STEEL3 = "5E6474", "3E4350", "828A98"
DSTEEL, DSTEEL2, DSTEEL3 = "3A3E48", "2A2D35", "50555F"  # the army's near-black plate (ref 04)
SNOW, ROCK1, ROCK2, ROCKD = "F2F6FA", "A6B6CA", "98A8BE", "6E7C92"
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


def pine(x, z, h, y0=0.0, lean=0.0, cols=(PINE, PINE2), bark=BARK):
	"""A conifer: short trunk and four stacked, narrowing cone tiers."""
	p = [("cyl", (h * 0.07, h * 0.3, h * 0.07), (x, y0 + h * 0.15, z), bark, {"seg": 6})]
	for i, (f, w) in enumerate(((0.22, 0.46), (0.42, 0.38), (0.6, 0.28), (0.76, 0.18))):
		p.append(("cone", (h * w, h * 0.34, h * w), (x, y0 + h * f + h * 0.17, z), cols[i % 2], {"seg": 7, "rot": (lean, i * 23, 0)}))
	return p


def arch_window(x, y, z, w, h, depth, yaw=0.0, col=DARK, seg=10):
	"""Round-arched opening: a dark recess with a half-round head (the head cylinder's lower half hides in the box)."""
	return [
		("box", (w, h, depth), (x, y, z), col, {"rot": (0, yaw, 0)}),
		("cyl", (w, depth, w), (x, y + h / 2, z), col, {"rot": (90, yaw, 0), "seg": seg}),
	]


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
	"""Blue-moon-weed: five low clusters of small five-petal blooms in short grass over a 26 x 18 patch."""
	p = [("cyl", (26, 0.5, 18), (0, 0.25, 0), GRASS3, {"seg": 10})]
	for ci, (cx, cz) in enumerate(((0, 0), (-8, 4), (7, 5), (-5, -5), (8, -4))):
		for j in range(6):
			a, r = j * 2.39996 + ci, 0.9 * math.sqrt(j + 0.5)
			x, z = cx + r * math.cos(a), cz + r * math.sin(a)
			h = 0.35 + (j % 3) * 0.15
			p.append(("cone", (1.0, 0.9, 1.0), (x, 0.7, z), GRASS2, {"seg": 4, "rot": (0, j * 40, 0)}))  # leaf tuft, no stalk
			col = (BLUE, BLUE2, BLUE, WHITE)[(j + ci) % 4]
			p.append(("cyl", (0.8, 0.16, 0.8), (x, 0.7 + h, z), col, {"seg": 5, "emit": 0.12, "rot": (10, j * 31, 0)}))
		p.append(("cone", (1.4, 1.3, 1.4), (cx + 1.6, 1.1, cz - 1.2), GRASS2, {"seg": 4}))
	p.append(("ball", (2.2, 1.0, 1.8), (-11, 0.6, -6), STONEB, {"subdiv": 1}))
	return p


def forest():
	"""A pine wood: seven conifers of mixed height on a low mound, a dirt path winding past it."""
	p = [("ball", (46, 6, 40), (0, -1, 0), GRASS2, {"subdiv": 2, "smooth": True})]
	for x, z, h, lean in ((0, 0, 44, 0), (12, 6, 34, 3), (-11, 5, 38, -3), (5, -12, 30, 2), (-6, -10, 26, -2), (16, -6, 22, 4), (-16, -4, 20, -4)):
		p += pine(x, z, h, 0.5, lean)
	for (x, z, L, yaw) in ((-30, -26, 34, 20), (-4, -32, 26, -10), (20, -28, 30, 25), (40, -14, 30, 55)):
		p.append(("box", (L, 0.3, 5), (x, 0.2, z), EARTH2, {"rot": (0, yaw, 0)}))
	return p


def far_wood():
	"""A far hazed hillside: a broad pale-green swell with pale desaturated pines (aerial perspective)."""
	p = [("ball", (260, 30, 180), (0, -4, 0), FARG, {"subdiv": 2, "smooth": True})]
	for x, z, h in ((-60, -10, 46), (-40, 20, 40), (-20, -30, 50), (10, 10, 44), (40, -20, 38), (60, 15, 42), (80, -5, 34), (-85, 5, 30)):
		y = -4 + 15 * math.sqrt(max(0.0, 1 - (x / 130) ** 2 - (z / 90) ** 2))
		p += pine(x, z, h, y - 1, 0, (FARP, FARP2), FARP)
	return p


def cottage():
	"""Half-timbered town house (ref 06): a tall, steep gable turned to the street over three storeys: stone ground
	floor, a jettied plaster storey and a second jetty above it, each with dark posts, rails, K braces and leaded
	windows; open gable with a king post, collar and window; steep shingled roof, chimney, shutters, window box, a
	fence and barrels. Gable front is -Z."""
	W, D = 18, 22
	WIN = "3E5A7A"
	p = [
		("box", (W, 9, D), (0, 4.5, 0), STONEB),
		("box", (W + 0.4, 1, D + 0.4), (0, 0.5, 0), "8C877C"),
	]
	storeys = ((W + 2, D + 2, 9.6, 10.0), (W + 4, D + 4, 20.0, 9.0))  # (width, depth, floor, height): two jetties
	for w, d, y, h in storeys:
		p += [
			("box", (w, h, d), (0, y + h / 2, 0), PLASTER),
			("box", (w + 0.4, 0.9, d + 0.4), (0, y + 0.1, 0), TIMBER),  # jetty beam
			("box", (w + 0.4, 0.6, d + 0.4), (0, y + h / 2, 0), TIMBER),  # mid rail
		]
		for sz in (-1, 1):  # street gable face and back: posts, K braces, windows
			zf = sz * (d / 2 + 0.15)
			for x in (-w / 2 + 0.4, -w / 6, w / 6, w / 2 - 0.4):
				p.append(("box", (0.8, h, 0.4), (x, y + h / 2, zf), TIMBER))
			for x, r in ((-w / 3, 30), (w / 3, -30)):
				p.append(("box", (0.6, h / 2 + 1.2, 0.4), (x, y + h * 0.27, zf), TIMBER, {"rot": (0, 0, r)}))
			p.append(("box", (w / 3 - 1.6, h * 0.36, 0.5), (0, y + h * 0.72, zf), WIN, {"rough": 0.3}))
			for x in (-w / 3, w / 3):
				p.append(("box", (2.6, h * 0.3, 0.5), (x, y + h * 0.76, zf), WIN, {"rough": 0.3}))
		for sx in (-1, 1):  # long sides: posts and a window
			xf = sx * (w / 2 + 0.15)
			for z in (-d / 2 + 0.4, -d / 6, d / 6, d / 2 - 0.4):
				p.append(("box", (0.4, h, 0.8), (xf, y + h / 2, z), TIMBER))
			p.append(("box", (0.5, h * 0.34, 3.0), (xf, y + h * 0.72, 0), WIN, {"rough": 0.3}))
	# steep roof: ridge along Z, gable on the street; two shingled slabs with courses and a ridge cap
	E, RH = 29.0, 19.0
	half = (W + 4) / 2 + 0.6
	pitch = math.degrees(math.atan2(RH, half))
	slope = math.hypot(RH, half) + 1.8
	ca, sa = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
	top = E + RH + 0.5
	L = D + 7
	for sx in (-1, 1):
		p.append(("box", (slope, 0.9, L), (sx * (ca * slope / 2 + sa * 0.45), top - sa * slope / 2 + ca * 0.45, 0), ROOF, {"rot": (0, 0, -sx * pitch)}))
		for t in (0.2, 0.4, 0.6, 0.8):  # shingle courses
			p.append(("box", (0.45, 0.3, L - 0.2), (sx * (ca * slope * t + sa * 1.0), top - sa * slope * t + ca * 1.0, 0), "684A3C", {"rot": (0, 0, -sx * pitch)}))
	p.append(("box", (1.4, 1.0, L + 0.4), (0, top + 0.6, 0), "684A3C"))  # ridge
	for sz in (-1, 1):  # open gable ends: plaster triangle, king post, collar, gable window
		gz = sz * ((D + 4) / 2 + 0.2)
		hw = (W + 4) / 2
		p += [
			("wedge", (0.6, RH, hw), (-hw / 2, E + RH / 2, gz), PLASTER, {"rot": (0, 90, 0)}),
			("wedge", (0.6, RH, hw), (hw / 2, E + RH / 2, gz), PLASTER, {"rot": (0, -90, 0)}),
			("box", (0.8, RH - 1.5, 0.5), (0, E + (RH - 1.5) / 2, gz + sz * 0.3), TIMBER),
			("box", (W - 2, 0.7, 0.5), (0, E + 6.5, gz + sz * 0.3), TIMBER),
			("box", (2.6, 3.4, 0.5), (-3.2, E + 3.0, gz + sz * 0.3), WIN, {"rough": 0.3}),
			("box", (2.6, 3.4, 0.5), (3.2, E + 3.0, gz + sz * 0.3), WIN, {"rough": 0.3}),
			("box", (1.8, 2.4, 0.5), (0, E + 10.5, gz + sz * 0.3), WIN, {"rough": 0.3}),
		]
	# ground floor street front: door, shuttered window with a flower box
	zf = -D / 2 - 0.2
	p += [
		("box", (4.0, 7, 0.6), (-4, 3.5, zf), "6A4A32"),
		("box", (5.0, 0.8, 0.8), (-4, 7.3, zf - 0.1), TIMBER),
		("box", (3.6, 3.4, 0.5), (4, 5, zf), "2E3E52", {"rough": 0.3}),
		("box", (1.4, 3.6, 0.4), (1.5, 5, zf - 0.3), "3F6A4E"),
		("box", (1.4, 3.6, 0.4), (6.5, 5, zf - 0.3), "3F6A4E"),
		("box", (4.2, 1, 1.2), (4, 2.8, zf - 0.5), TIMBER),
	]
	for x in (2.8, 4, 5.2):
		p.append(("ball", (1.1, 1, 1.1), (x, 3.6, zf - 0.6), BLUE, {"subdiv": 1, "emit": 0.1}))
	p += [("box", (3.4, 18, 3.4), (5, E + 9, 6), "8C877C"), ("box", (4, 1, 4), (5, E + 18.4, 6), "6E6A62")]  # chimney
	for x in range(-12, 13, 4):
		p.append(("box", (0.5, 4, 0.5), (x, 2, -D / 2 - 7), TIMBER))
	p += [("box", (25, 0.5, 0.4), (0, 3.2, -D / 2 - 7), TIMBER), ("box", (25, 0.5, 0.4), (0, 1.6, -D / 2 - 7), TIMBER)]
	for x, z in ((W / 2 + 2.2, -6), (W / 2 + 2.2, -3)):
		p.append(("cyl", (2.4, 3.4, 2.4), (x, 1.7, z), "7A5636", {"seg": 8}))
		p.append(("cyl", (2.6, 0.4, 2.6), (x, 2.4, z), DARK, {"seg": 8}))
	return p


def seg(shape, d, p1, p2, color, **opt):
	"""A cyl or cone of diameter d from Roblox point p1 to p2 (a cone's narrow top at p2): kit.prop rot solved for the axis."""
	v = [p2[i] - p1[i] for i in range(3)]
	L = math.sqrt(sum(c * c for c in v)) or 1.0
	X, Y, Z = (c / L for c in v)
	rot = (math.degrees(math.acos(max(-1.0, min(1.0, Y)))), math.degrees(math.atan2(X, Z)), 0)
	mid = tuple((p1[i] + p2[i]) / 2 for i in range(3))
	return (shape, (d, L, d), mid, color, dict(opt, rot=rot))


def hero_statue():
	"""The hero's statue (ref 05, 08). Wide two-course ashlar plinth; a slim patina figure about 30 studs tall
	(7.5 heads): boots and legs in the cape's front opening, a floor-length cape hanging from the shoulders in vertical
	fold ridges and flaring at the hem, a short shoulder mantle, tunic with strap rungs, a stacked high collar, a full bob
	(crown, side locks to the jaw, pointed bangs), both hands stacked on the pommel at chest height, the long blade planted
	to the plinth, a crown of nine five-petal blue blooms. Faceless; the cape clasp is a plain bar. Front is -Z."""
	p = [
		("box", (22, 3, 22), (0, 1.5, 0), PLINTH2),
		("box", (23, 0.6, 23), (0, 3.2, 0), PLINTH),
		("box", (16, 11, 16), (0, 9, 0), PLINTH),
		("box", (17.4, 1.6, 17.4), (0, 15.3, 0), PLINTH2),
	]
	for y in (6.2, 9.2, 12.2):  # ashlar courses and joints
		p.append(("box", (16.2, 0.25, 16.2), (0, y, 0), "7E8880"))
	for x in (-4, 4):
		p.append(("box", (0.25, 11, 16.2), (x, 9, 0), "7E8880"))
		p.append(("box", (16.2, 11, 0.25), (0, 9, x), "7E8880"))
	for x in (-9, 0, 9):
		p.append(("box", (0.25, 3, 22.2), (x, 1.5, 0), "7E8880"))
	y0 = 16.1
	sm = {"smooth": True}
	# legs and boots in the front opening, slim tunic, belt, strap rungs
	for sx in (-1, 1):
		p += [
			("box", (1.3, 2.4, 2.6), (sx * 0.9, y0 + 1.2, -0.9), PATINA2),
			("cyl", (1.2, 10.4, 1.3), (sx * 0.85, y0 + 7.4, -0.5), PATINA, dict(sm, seg=8)),
		]
	p += [
		("cone", (3.8, 4.6, 2.4), (0, y0 + 14.4, -0.4), PATINA, dict(sm, seg=10, taper=0.85)),  # tunic skirt
		("box", (3.4, 0.6, 2.3), (0, y0 + 16.8, -0.4), PATINA2),  # belt
		("cone", (3.3, 7.0, 2.2), (0, y0 + 20.5, -0.3), PATINA, dict(sm, seg=10, taper=1.15)),  # chest
		("box", (0.45, 7.0, 0.3), (0, y0 + 20.4, -1.55), PATINA2),  # front placket
	]
	for y in (y0 + 17.8, y0 + 21.6, y0 + 22.9):
		p.append(("box", (1.8, 0.35, 0.3), (0, y, -1.62), PATINA3))  # strap rungs
	# the cape: vertical fold ridges hanging from the shoulder line round the back to the hem, open at the front
	SH, HEM = y0 + 23.6, y0 + 0.5
	p.append(("cone", (8.8, SH - HEM - 0.6, 5.2), (0, (SH + HEM) / 2 - 0.3, 1.0), PATINA2, dict(sm, seg=16, taper=0.62)))
	n = 9
	for j in range(n):
		a = math.radians(-148 + j * 296 / (n - 1))  # 0 = straight back, +-148 = the front edges
		top = (3.3 * math.sin(a), SH, 0.6 + 1.6 * math.cos(a))
		bot = (5.3 * math.sin(a), HEM, 1.0 + 3.6 * math.cos(a))
		d = 2.3 if j % 2 else 2.8  # alternating fold ridges
		p.append(seg("cone", d, bot, top, (PATINA2, PATINA)[j % 2], seg=8, taper=0.6, smooth=True))
	p.append(("cone", (11.4, 0.6, 7.8), (0, HEM + 0.3, 1.0), PATINA2, dict(sm, seg=18, taper=0.95)))  # hem lip
	# short shoulder mantle, clasp, stacked high collar
	p += [
		("ball", (8.0, 3.0, 4.6), (0, SH - 0.2, 0.5), PATINA2, dict(sm, subdiv=3)),
		("cone", (8.4, 2.4, 4.8), (0, SH - 1.4, 0.5), PATINA2, dict(sm, seg=16, taper=0.85)),
		("box", (2.0, 0.9, 0.5), (0, SH - 0.6, -2.0), PATINA3),  # clasp (plain bar)
	]
	for i, dd in enumerate((2.8, 2.3, 2.6, 2.2)):
		p.append(("cyl", (dd, 0.5, dd), (0, SH + 0.8 + i * 0.5, 0.2), (PATINA2, PATINA)[i % 2], dict(sm, seg=14)))
	# head (about 4 studs: 7.5 heads) and a full bob: crown, back and sides wider than the face, side locks to the
	# jaw, pointed bangs over the brow
	HY = SH + 4.6
	p += [
		("ball", (2.6, 3.5, 2.8), (0, HY - 0.5, -0.2), PATINA, dict(sm, subdiv=3)),  # face
		("ball", (3.9, 2.9, 3.9), (0, HY + 0.7, 0.15), PATINA3, dict(sm, subdiv=3)),  # crown
		("ball", (3.9, 3.4, 3.0), (0, HY - 0.3, 0.75), PATINA3, dict(sm, subdiv=3)),  # back of the bob
	]
	for sx in (-1, 1):
		p.append(("ball", (1.1, 3.4, 2.6), (sx * 1.45, HY - 0.6, 0.1), PATINA3, dict(sm, subdiv=2)))  # side lock to the jaw
	for x in (-1.2, -0.6, 0.0, 0.6, 1.2):  # bangs: strands pointing down to the brow
		p.append(seg("cone", 0.85, (x * 1.0, HY + 1.5, -1.25), (x * 1.08, HY - 0.15 - abs(x) * 0.3, -1.6), PATINA3, seg=5))
	# forearms out of the cape edges up to the hands stacked on the pommel at chest height
	HAND = (0, y0 + 19.6, -2.4)
	for sx in (-1, 1):
		p.append(seg("cyl", 0.95, (sx * 2.6, y0 + 18.4, -1.2), (sx * 0.5, HAND[1] - 0.1, HAND[2] + 0.2), PATINA2, seg=8, smooth=True))
	p += [
		("box", (2.0, 1.0, 1.4), (0, HAND[1] - 0.3, HAND[2]), PATINA),  # lower hand round the grip
		("box", (2.1, 0.9, 1.3), (0, HAND[1] + 0.55, HAND[2] - 0.15), PATINA3),  # upper hand stacked on it
		("box", (2.0, 0.25, 0.2), (0, HAND[1] + 0.1, HAND[2] - 0.85), PATINA2),  # knuckle line
		# the sword: pommel above the hands, grip below, crossguard, long fullered blade planted on the plinth
		("ball", (0.9, 0.9, 0.9), (0, HAND[1] + 1.4, HAND[2]), PATINA3, dict(sm, subdiv=2)),
		("cyl", (0.5, 1.6, 0.5), (0, HAND[1] - 1.3, HAND[2]), PATINA2, {"seg": 6}),
		("box", (4.4, 0.6, 0.6), (0, HAND[1] - 2.3, HAND[2]), PATINA2),
		("box", (0.9, 0.9, 0.7), (0, HAND[1] - 2.3, HAND[2]), PATINA3, {"rot": (0, 0, 45)}),
		("box", (1.2, HAND[1] - 2.6 - y0 - 1.0, 0.35), (0, (HAND[1] - 2.6 + y0 + 1.0) / 2, HAND[2]), PATINA3, {"metal": 0.3, "rough": 0.4}),
		("box", (0.3, HAND[1] - 3.4 - y0 - 1.0, 0.45), (0, (HAND[1] - 3.4 + y0 + 1.0) / 2, HAND[2]), PATINA2),  # fuller
		("wedge", (1.2, 1.0, 0.35), (0, y0 + 0.5, HAND[2]), PATINA3, {"rot": (0, 0, 180)}),
	]
	for j in range(9):  # crown of nine five-petal blue blooms round the bob
		a = j * math.tau / 9
		bx, bz = 1.9 * math.cos(a), 0.15 + 1.9 * math.sin(a)
		by = HY + 1.3 - 0.25 * math.sin(a)
		tilt = (math.degrees(-math.sin(a)) * 0.5, 0, math.degrees(math.cos(a)) * 0.5)
		for q in range(5):
			pa = q * math.tau / 5 + a
			p.append(("cyl", (0.62, 0.16, 0.5), (bx + 0.36 * math.cos(pa), by, bz + 0.36 * math.sin(pa)), (BLUE, BLUE2)[j % 2], {"seg": 6, "emit": 0.25, "rot": (tilt[0], -math.degrees(pa), tilt[2])}))
		p.append(("cyl", (0.3, 0.24, 0.3), (bx, by + 0.05, bz), "FFF1A8", {"seg": 5}))
	for j in range(7):  # offered flowers at the plinth foot
		p.append(("cyl", (1.2, 0.25, 1.2), (-5 + j * 1.6, 3.6, -9.6 - (j % 2) * 0.8), (BLUE, BLUE2, WHITE)[j % 3], {"seg": 5, "emit": 0.12}))
	return p


def rank():
	"""Aura's headless army (refs 03, 04, 09): a rank block of thirty suits of dark plate in four staggered ranks on a
	raised mound among pines. Each suit: sabatons, greaves, knee cops, flared cuisses, a faulds skirt, a pigeon-chest
	breastplate widening to the shoulders, round pauldrons, arms with gauntlets, and an empty gorget ring standing
	above the shoulders, dark inside, where the head should be (no head, no gore); halberds and spears tips up."""
	MX, MZ = 50, 32
	p = [("ball", (MX * 2, 14, MZ * 2), (0, -2, 0), "6A8E50", {"subdiv": 3, "smooth": True})]
	for x, z, h in ((-44, 16, 46), (44, 12, 50), (-30, 26, 38)):
		y = -2 + 7 * math.sqrt(max(0.0, 1 - (x / MX) ** 2 - (z / MZ) ** 2))
		p += pine(x, z, h, y - 0.5)
	S = 1.25  # suits stand about 25 studs tall to the gorget rim
	m = {"metal": 0.35, "rough": 0.6}
	ms = dict(m, smooth=True)
	i = 0
	for r, (z, n) in enumerate(((-17, 8), (-7, 8), (3, 7), (13, 7))):
		for c in range(n):
			x = (c - (n - 1) / 2) * 10.4 + (r % 2) * 2.2 + ((c * 7 + r * 3) % 5 - 2) * 0.4
			zz = z + ((c * 5 + r) % 3 - 1) * 0.8
			y = -2 + 7 * math.sqrt(max(0.0, 1 - (x / MX) ** 2 - (zz / MZ) ** 2)) - 0.4
			def at(px, py, pz):
				return (x + px * S, y + py * S, zz + pz * S)
			for sx in (-1, 1):
				p += [
					("box", (1.5 * S, 1.0 * S, 2.8 * S), at(sx * 0.95, 0.5, -0.5), DSTEEL2, m),  # sabaton
					("cyl", (1.5 * S, 5 * S, 1.6 * S), at(sx * 0.95, 3.3, 0), DSTEEL2, dict(ms, seg=8)),  # greave
					("cyl", (2.0 * S, 1.4 * S, 2.0 * S), at(sx * 0.95, 5.9, -0.15), DSTEEL3, dict(ms, seg=8)),  # knee cop
					("cone", (1.9 * S, 4.2 * S, 2.0 * S), at(sx * 1.0, 8.4, 0), DSTEEL, dict(ms, seg=8, taper=1.3)),  # cuisse
					("ball", (3.9 * S, 3.3 * S, 3.9 * S), at(sx * 3.4, 17.5, 0), DSTEEL3, dict(ms, subdiv=1)),  # big round pauldron
					("cyl", (3.6 * S, 0.7 * S, 3.5 * S), at(sx * 3.5, 16.0, 0), DSTEEL2, dict(ms, seg=8)),  # its lower lame
					("cyl", (1.6 * S, 4.4 * S, 1.7 * S), at(sx * 3.6, 13.6, 0.1), DSTEEL2, dict(ms, seg=8)),  # arm
					("box", (1.8 * S, 2.0 * S, 1.9 * S), at(sx * 3.6, 10.8, -0.2), DSTEEL, m),  # gauntlet
				]
			p += [
				("cone", (6.0 * S, 3.2 * S, 4.0 * S), at(0, 10.9, 0), DSTEEL2, dict(ms, seg=10, taper=0.72)),  # faulds skirt
				("cyl", (4.4 * S, 1.0 * S, 3.0 * S), at(0, 12.8, 0), DARK, dict(m, seg=10)),  # waist belt
				("cone", (4.6 * S, 5.4 * S, 3.4 * S), at(0, 15.9, -0.05), DSTEEL, dict(ms, seg=12, taper=1.45)),  # broad breastplate
				("box", (0.35 * S, 4.8 * S, 0.35 * S), at(0, 15.8, -2.25), DSTEEL3, m),  # ridge
				("cyl", (2.8 * S, 1.4 * S, 2.8 * S), at(0, 19.2, 0), DSTEEL3, dict(ms, seg=12)),  # empty gorget ring
				("cyl", (2.0 * S, 1.0 * S, 2.0 * S), at(0, 19.5, 0), "121316", {"seg": 12}),  # its dark hollow
			]
			wx = 4.8 if (i // 2) % 2 == 0 else -4.8
			if i % 2 == 0:  # halberd: shaft, broad axe blade, blade horn, back spike, top spike
				p += [
					("cyl", (0.55, 26 * S, 0.55), at(wx, 13, -0.8), "2E261E", {"seg": 5}),
					("box", (2.4, 4.2 * S, 0.35), at(wx * 1.27, 24.0, -0.8), STEEL3, m),  # broad axe blade, outboard
					("box", (1.0, 1.6 * S, 0.35), at(wx * 1.46, 26.4, -0.8), STEEL3, m),  # blade horn
					("box", (1.4, 0.6, 0.35), at(wx * 0.79, 24.6, -0.8), STEEL3, m),  # back spike
					("cone", (0.9, 3.0 * S, 0.9), at(wx, 27.9, -0.8), STEEL3, {"seg": 4}),
				]
			else:  # spear
				p += [("cyl", (0.5, 24 * S, 0.5), at(wx, 12, -0.8), "2E261E", {"seg": 5}), ("cone", (1.0, 3.2 * S, 1.0), at(wx, 25.6, -0.8), STEEL3, {"seg": 4})]
			i += 1
	return p


def ruin_wall():
	"""A ruined stretch of the same castle along the road: brick-coursed wall with two tall round-arched windows, a
	broken top, a roofless half tower, fallen blocks and moss."""
	p = [
		("box", (32, 20, 5), (0, 10, 0), RUIN),
		("box", (12, 9, 5), (-10, 24.5, 0), RUIN),
		("box", (6, 4, 5), (-1, 22, 0), RUIN2),
		("box", (32.4, 2.2, 5.4), (0, 1.1, 0), MOSS),
		("box", (8, 1.4, 5.4), (-10, 29.6, 0), MOSS),
	]
	for y in (5, 9, 13, 17):
		p.append(("box", (32.2, 0.3, 5.2), (0, y, 0), RUIN2))
	for x in (-8, 4):
		p += arch_window(x, 10, 0, 4.4, 9, 5.4)
		p.append(("box", (5.6, 0.8, 6), (x, 5.2, 0), RUIN3))
	p += round_tower(17, 2, 0, 12, 26, RUIN2, None, 0, seg=10)
	p += [
		("box", (5, 3, 4), (17, 27, 2), RUIN2, {"rot": (0, 20, 8)}),
		("box", (6, 3.6, 4.6), (-6, 1.8, -7), RUIN2, {"rot": (0, 25, 10)}),
		("box", (4, 3, 3.6), (4, 1.5, -8), RUIN, {"rot": (14, 60, 0)}),
		("box", (3, 2.4, 3), (10, 1.2, -6), RUIN2, {"rot": (0, 10, 22)}),
		("ball", (5, 2.2, 4), (12, 0.6, -7), MOSS, {"subdiv": 1}),
	]
	return p


def ruined_castle():
	"""Hero: the ruined castle where the Guillotine waits (refs 12, 13: tall round-arched windows in brick-coursed
	warm stone, a broken vault). A rocky rise; a long ruined hall whose side walls carry rows of tall paired arched
	windows; a collapsed gable end with a huge broken arch; a square keep with arched window rows and a broken crown;
	roofless round towers; broken curtain walls with gaps; rubble, moss and ivy. Front (gate) is -Z."""
	p = [
		("cyl", (240, 26, 200), (0, 6, 0), GRASS2, {"seg": 36, "taper": 0.78, "smooth": True}),
		("ball", (120, 30, 70), (-70, 4, 60), "7A9A5E", {"subdiv": 2, "smooth": True}),
		("ball", (60, 18, 40), (90, 4, -40), STONEB, {"subdiv": 1}),
	]
	Y = 19.0
	walls = (((-75, -60), (-18, -60)), ((18, -60), (75, -60)), ((75, -60), (75, 10)), ((75, 34), (75, 60)), ((-75, 60), (-75, 0)), ((-75, -22), (-75, -60)))
	for i, ((x1, z1), (x2, z2)) in enumerate(walls):
		L = math.hypot(x2 - x1, z2 - z1)
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		h = (22, 14, 22, 12, 20, 16)[i]
		cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		p.append(("box", (L, h, 6), (cx, Y + h / 2, cz), RUIN, {"rot": (0, yaw, 0)}))
		p.append(("box", (L + 0.4, 3, 6.4), (cx, Y + 1.5, cz), MOSS, {"rot": (0, yaw, 0)}))
		p.append(("box", (L + 0.2, 0.4, 6.2), (cx, Y + h * 0.55, cz), RUIN2, {"rot": (0, yaw, 0)}))
		n = int(L // 7)
		for j in range(n):
			if (j * 7 + i) % 5 in (1, 2) or (i < 2 and 0.3 < (j + 0.5) / n < 0.55):
				continue  # knocked-out crenels, and a long breach in each front wall
			t = (j + 0.5) / n
			p.append(("box", (3.4, 3.4, 6.2), (x1 + (x2 - x1) * t, Y + h + 1.7, z1 + (z2 - z1) * t), RUIN2, {"rot": (0, yaw, 0)}))
	# Gatehouse with a round arch, its top broken: one tower stump, the other cut on a slant, the lintel half gone
	p += [
		("box", (14, 26, 14), (-18, Y + 13, -60), RUIN2),
		("box", (8, 6, 14), (-21, Y + 29, -60), RUIN2),  # surviving corner of the left tower top
		("box", (14, 20, 14), (18, Y + 10, -60), RUIN2),
		("wedge", (14, 7, 14), (18, Y + 23.5, -60), RUIN2, {"rot": (0, 90, 0)}),  # slanted break
		("box", (11, 6, 7), (-5.5, Y + 21, -60), RUIN2),  # what is left of the lintel
		("box", (6, 4, 5), (8, Y + 2, -70), RUIN2, {"rot": (10, 30, 14)}),  # fallen blocks
		("box", (5, 3.4, 5), (14, Y + 1.7, -72), RUIN, {"rot": (0, 50, -10)}),
		("box", (4, 3, 4), (-2, Y + 1.5, -71), RUIN2, {"rot": (18, 12, 0)}),
	]
	p += arch_window(0, Y + 7.5, -60, 12, 15, 7.4, seg=12)
	# The great hall runs back from the gate: its front gable faces the road with the huge broken arched window
	# (refs 12, 13): the arch head shattered open on the right, one mullion and a transom left in it; side walls with
	# rows of tall paired round-arched windows at uneven broken heights; the back end collapsed
	HX, HZ, HL, HH = -12, 12, 84, 40
	gz = HZ - HL / 2  # front gable line
	for s_ in (-1, 1):
		x = HX + s_ * 17
		top = [HH, HH - 6, HH, HH - 14, HH - 4, HH - 20] if s_ < 0 else [HH - 10, HH, HH - 2, HH - 16, HH, HH - 8]
		for j, h in enumerate(top):  # wall bays of uneven broken height
			z = gz + HL / 12 + j * HL / 6
			p.append(("box", (5, h, HL / 6 + 0.2), (x, Y + h / 2, z), RUIN))
			p.append(("box", (5.4, 0.4, HL / 6 + 0.4), (x, Y + 8, z), RUIN2))
			if h > 24:
				p += arch_window(x, Y + 18, z - 3, 3.6, 12, 5.6, yaw=90)
				p += arch_window(x, Y + 18, z + 3, 3.6, 12, 5.6, yaw=90)
				p.append(("box", (6, 0.8, 12), (x, Y + 11.6, z), RUIN3))
			p.append(("box", (4, h * 0.9, 4), (x + s_ * 3.5, Y + h * 0.45, z - HL / 12), RUIN2))  # buttress
	# front gable: a tall wall with the huge round-arched window open to the sky, its head shattered on the right
	# (voussoirs survive on the left only), one mullion and a transom left standing, the right half broken low
	AW, SILL, AH = 22, 16, 44  # opening width, sill height, opening height to the crown
	R = AW / 2
	cy = Y + SILL + AH - R  # centre of the arch head
	p += [
		("box", (12, 70, 5), (HX - R - 6, Y + 35, gz), RUIN),  # left pier to the gable top
		("wedge", (12, 16, 5), (HX - R - 6, Y + 78, gz), RUIN, {"rot": (0, 90, 0)}),
		("box", (12, 46, 5), (HX + R + 6, Y + 23, gz), RUIN),  # right pier, broken lower
		("box", (7, 7, 5), (HX + R + 4, Y + 48, gz), RUIN2, {"rot": (0, 0, 24)}),  # jagged break
		("box", (AW + 0.2, SILL, 5), (HX, Y + SILL / 2, gz), RUIN),  # sill wall
		("box", (AW + 24.4, 0.6, 5.6), (HX, Y + SILL, gz), RUIN2),
		("box", (12.6, 0.6, 5.6), (HX - R - 6, Y + 40, gz), RUIN2),
		("box", (1.1, AH - R + 2, 1.2), (HX + 1.5, Y + SILL + (AH - R + 2) / 2, gz), RUIN3),  # mullion
		("box", (AW, 1.0, 1.2), (HX, Y + SILL + AH * 0.42, gz), RUIN3),  # transom
		("box", (1.0, 7, 1.0), (HX + 6.5, Y + SILL + 3.5, gz), RUIN3),  # stub of a second mullion
		("box", (4, 3, 4), (HX + 8, Y + 1.5, gz - 8), RUIN2, {"rot": (14, 30, 0)}),  # fallen tracery
	]
	for q in range(8):  # voussoirs from the left springing round past the crown, then broken off
		t = math.radians(180 - q * 15)
		p.append(("box", (2.6, 3.6, 5.4), (HX + (R + 1.6) * math.cos(t), cy + (R + 1.6) * math.sin(t), gz), RUIN3, {"rot": (0, 0, q * 15 - 90)}))
	for q in range(6):  # wall over the arch on the left, stepped down to the break
		x = HX - R + q * 3.6
		top = Y + (74, 74, 74, 72, 70, 66)[q]
		yb = cy + math.sqrt(max(0.0, (R + 3.4) ** 2 - (x - HX) ** 2))
		if top > yb:
			p.append(("box", (3.8, top - yb, 5), (x, (top + yb) / 2, gz), RUIN))
	# the back end collapsed: rubble heap and a fallen vault rib
	p += [
		("ball", (34, 12, 30), (HX, Y + 2, HZ + HL / 2), RUIN2, {"subdiv": 1}),
		("box", (6, 4, 6), (HX + 14, Y + 2, HZ + HL / 2 + 8), RUIN, {"rot": (12, 30, 8)}),
		("box", (5, 20, 5), (HX - 6, Y + 6, HZ + HL / 2 - 10), RUIN2, {"rot": (0, 20, 64)}),
	]
	# Square keep with arched window rows and a broken crown
	kx, kz = 45, 30
	p += [
		("box", (30, 66, 30), (kx, Y + 33, kz), RUIN),
		("box", (32, 3, 32), (kx, Y + 1.5, kz), MOSS),
		("box", (32, 2, 32), (kx, Y + 44, kz), RUIN2),
		("box", (12, 14, 12), (kx - 9, Y + 73, kz - 9), RUIN),
		("box", (9, 9, 9), (kx + 10, Y + 70.5, kz + 10), RUIN),
	]
	for side in range(4):
		a = side * math.pi / 2
		dx, dz = math.sin(a), -math.cos(a)
		for y in (Y + 24, Y + 52):
			for t in (-7, 7):
				p += arch_window(kx + dx * 15.3 + dz * -t, y, kz + dz * 15.3 + dx * t, 4, 10, 1.4, yaw=-side * 90, seg=8)
	# Corner towers: roofless with jagged tops
	for x, z, h in ((-75, -60, 42), (75, -60, 34), (75, 60, 48), (-75, 60, 16)):
		p += round_tower(x, z, Y, 20, h, RUIN2, None, 0, seg=12)
		p.append(("box", (8, 8, 6), (x + 4, Y + h + 4, z - 3), RUIN2, {"rot": (0, 25, 0)}))
		p += arch_window(x, Y + h * 0.6, z - 10.2, 3, 7, 1.2, seg=8)
	# Court rubble, ivy
	for x, z, s in ((-10, 40, 9), (40, -30, 7), (-55, 40, 8), (0, -35, 6)):
		p.append(("ball", (s * 1.6, s * 0.7, s * 1.3), (x, Y + s * 0.2, z), RUIN2, {"subdiv": 1}))
	for x, z, h, w in ((HX - 15, gz - 2.8, 30, (8, 30, 1)), (kx - 15.4, kz + 4, 34, (1, 34, 7)), (75.2, 30, 14, (1, 14, 6))):
		p.append(("box", w, (x, Y + h / 2 + 2, z), MOSS))
	return p


def town():
	"""Hero: the count's fortified town on its broad hill (ref 01): a long, low cream curtain wall on a flattened oval,
	towers spaced unevenly (mostly round with slate cones and finials, three square with pyramid caps), crenels, a
	gatehouse, a packed roofscape, the mansion and the church spire; on the front slope below the wall the scar of the
	war: felled dark trunks lying every way, stumps and bare earth. Gate is -Z."""
	p = [
		("ball", (900, 150, 620), (0, -12, 0), GRASS2, {"subdiv": 3, "smooth": True}),
		("ball", (720, 60, 330), (0, 62 - 26, 0), GRASS2, {"subdiv": 3, "smooth": True}),  # the hilltop, no lip
	]
	Y = 62.0
	RX, RZ = 300, 130
	angs = [0.0, 0.33, 0.61, 1.02, 1.3, 1.7, 2.05, 2.5, 2.85, 3.14, 3.5, 3.86, 4.15, 4.42, 4.9, 5.2, 5.62, 5.95]
	pts = [(RX * math.cos(a), RZ * math.sin(a)) for a in angs]
	for j in range(len(pts)):
		(x1, z1), (x2, z2) = pts[j], pts[(j + 1) % len(pts)]
		L = math.hypot(x2 - x1, z2 - z1) - 12
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		h = 15 + (j * 5) % 5
		p.append(("box", (L, h + 14, 5), (cx, Y + h / 2 - 7, cz), CREAM, {"rot": (0, yaw, 0)}))  # footing sunk into the slope
		p.append(("box", (L, 1.0, 5.8), (cx, Y + h - 1.5, cz), CREAM2, {"rot": (0, yaw, 0)}))
		n = int(L // 6)
		for i in range(n):
			t = 0.5 + ((i + 0.5) / n - 0.5) * L / (L + 12)
			p.append(("box", (3, 3, 5.4), (x1 + (x2 - x1) * t, Y + h + 1.5, z1 + (z2 - z1) * t), CREAM, {"rot": (0, yaw, 0)}))
	for j, (x, z) in enumerate(pts):
		if j in (4, 9, 15):  # square towers with pyramid caps
			p += [("box", (16, 48, 16), (x, Y + 10, z), CREAM), ("box", (17.4, 1.4, 17.4), (x, Y + 34.4, z), CREAM2)]
			p += pyramid(17, 16, (x, Y + 35, z), SLATE)
			continue
		d, h, rh = ((22, 40, 24), (16, 30, 18), (19, 34, 20), (14, 26, 16))[j % 4]
		p += round_tower(x, z, Y - 14, d, h + 14, CREAM, SLATE, rh, seg=12)
		p.append(("cyl", (2, 4, 2), (x, Y + h + rh + 1, z), SLATE2, {"seg": 6}))
		p.append(("box", (1.6, 5, 1), (x, Y + h - 10, z - d / 2 - 0.2), DARK))
	gz = -RZ  # gatehouse
	for x in (-14, 14):
		p += [("box", (14, 52, 14), (x, Y + 12, gz), CREAM), ("box", (15.4, 1.6, 15.4), (x, Y + 38.8, gz), CREAM2)]
		p += pyramid(15, 18, (x, Y + 39.6, gz), SLATE)
	p += [("box", (16, 16, 7), (0, Y + 22, gz), CREAM2)]
	p += arch_window(0, Y + 7, gz, 10, 14, 7.4, col="4A3E34", seg=12)
	# Roofscape: three rings of steep-gabled houses
	ri = 0
	for ring, (rx, rz, n) in enumerate(((240, 96, 26), (170, 62, 20), (95, 32, 12))):
		for i in range(n):
			a = (i + 0.5 * ring) * math.tau / n
			if ring == 0 and abs(math.sin(a) + 1) < 0.1:
				continue
			x, z = rx * math.cos(a), rz * math.sin(a)
			w, dd = 16 + (ri * 7) % 9, 12 + (ri * 5) % 5
			h = 9 + (ri * 3) % 7
			yaw = -math.degrees(a) + 90
			col = (PLASTER, CREAM, "E4D6BC")[ri % 3]
			p.append(("box", (w, h + 8, dd), (x, Y + h / 2 - 4, z), col, {"rot": (0, yaw, 0)}))
			ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
			for shape, size, (px, py, pz), c, o in gable(w, dd, 9 + ri % 4, Y + h, (ROOF2, ROOF, SLATE)[ri % 3], o=0.8):
				o = dict(o)
				r = o.get("rot", (0, 0, 0))
				o["rot"] = (r[0], r[1] + yaw, r[2])
				p.append((shape, size, (x + px * ca + pz * sa, py, z - px * sa + pz * ca), c, o))
			ri += 1
	mx, mz = -30, 20  # mansion
	p += [("box", (50, 34, 34), (mx, Y + 17, mz), PLASTER), ("box", (52, 1.6, 36), (mx, Y + 34.8, mz), CREAM2)]
	p += gable(16, 34, 18, Y + 35.6, SLATE, x=mx, z=mz, o=0.0)
	for dx in (-8, 8):
		p += pyramid(34, 18, (mx + dx, Y + 35.6, mz), SLATE)
	for x in (-27, 27):
		for z in (-19, 19):
			p += round_tower(mx + x, mz + z, Y, 10, 42, CREAM, SLATE, 18, seg=10)
	cx, cz = 80, -10  # church
	p += [("box", (22, 22, 56), (cx, Y + 11, cz), PLASTER)]
	p += [("wedge", (58, 14, 12), (cx - 6, Y + 29, cz), ROOF2, {"rot": (0, 90, 0)}), ("wedge", (58, 14, 12), (cx + 6, Y + 29, cz), ROOF2, {"rot": (0, -90, 0)})]
	p += [("box", (16, 56, 16), (cx, Y + 28, cz - 34), CREAM), ("box", (17.4, 2, 17.4), (cx, Y + 56, cz - 34), CREAM2)]
	p += [("cone", (16 * SQ2, 48, 16 * SQ2), (cx, Y + 81, cz - 34), SLATE, {"seg": 4, "rot": (0, 45, 0)})]
	# The scar below the wall on the front slope: bare earth patches, felled trunks lying every way, stumps
	def slope_y(x, z):
		return -12 + 75 * math.sqrt(max(0.0, 1 - (x / 450) ** 2 - (z / 310) ** 2))

	for j in range(9):
		x, z = -260 + j * 65, -RZ - 70 - (j % 3) * 22
		p.append(("ball", (90, 6, 46), (x, slope_y(x, z) - 1.0, z), (EARTH, EARTH2)[j % 2], {"subdiv": 1, "rot": (-14, (j * 37) % 40 - 20, 0)}))
	for j in range(44):
		x = -290 + (j * 137) % 580
		z = -RZ - 40 - (j * 53) % 120
		y = slope_y(x, z)
		L = 26 + (j * 7) % 18
		p.append(("cyl", (2.6, L, 2.6), (x, y + 1.2, z), (DEADWOOD, BARK, "3A2C20")[j % 3], {"seg": 5, "rot": (0, (j * 71) % 180, 90 - 12)}))
		if j % 3 == 0:
			p.append(("cyl", (3.4, 3, 3.4), (x + 8, y + 1.2, z - 5), DEADWOOD, {"seg": 6}))
		if j % 5 == 0:  # a dead standing trunk
			p.append(("cyl", (2, 18, 2), (x - 6, y + 8, z + 4), DEADWOOD, {"seg": 5, "rot": (6, 0, -5)}))
	return p


def swell():
	"""A low rolling swell of the plain (ref 01): two overlapping grass domes, a pale dirt path winding over them and on
	across the flat, bare-earth patches, two pines. Fits inside a 180-stud radius."""
	RX, RY, RZ = 160, 11, 110

	def ground(x, z):
		return -1 + RY * math.sqrt(max(0.0, 1 - (x / RX) ** 2 - (z / RZ) ** 2))

	p = [
		("ball", (RX * 2, RY * 2, RZ * 2), (0, -1, 0), GRASS3, {"subdiv": 3, "smooth": True}),
		("ball", (180, 16, 130), (70, -2, 40), GRASS2, {"subdiv": 3, "smooth": True}),
	]
	pts = [(-178, -40), (-130, -30), (-85, -8), (-40, 4), (0, 0), (40, -14), (80, -30), (118, -24), (150, 0), (178, 22)]
	for (x1, z1), (x2, z2) in zip(pts, pts[1:]):  # the path, patch by patch, sitting on the swell
		mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
		L = math.hypot(x2 - x1, z2 - z1) + 6
		yaw = -math.degrees(math.atan2(z2 - z1, x2 - x1))
		p.append(("ball", (L, 1.6, 7), (mx, ground(mx, mz) + 0.1, mz), EARTH2, {"subdiv": 2, "rot": (0, yaw, 0)}))
	for x, z, w, d in ((-60, 50, 46, 22), (90, 60, 34, 18), (30, -60, 40, 20)):  # bare-earth patches
		p.append(("ball", (w, 1.8, d), (x, ground(x, z) + 0.1, z), EARTH, {"subdiv": 2, "rot": (0, x * 0.4, 0)}))
	p += pine(-90, 60, 30, ground(-90, 60) - 0.5) + pine(110, -60, 26, ground(110, -60) - 0.5)
	return p


def mountain():
	"""A broad snow range (ref 01): hazed green-grey foothill swells under three broad massifs of uneven height, each a
	broad rock body with a dark rock band and a snow mantle down its upper slopes, and a lower snowy shoulder to one
	side; desaturated blue-grey for distance, smooth-shaded so the summits and shoulders read rounded, without seams."""
	sm = {"smooth": True}
	p = []
	for x, z, r, h in ((-1100, -160, 1300, 200), (-100, -200, 1500, 240), (950, -180, 1300, 210)):  # foothills
		p.append(("ball", (r, h * 2, r * 0.45), (x, 0, z), "A2B8B4", dict(sm, subdiv=2)))
	for x, z, w, h, sh in ((-950, 60, 1250, 560, 1), (180, 0, 1550, 780, -1), (1150, 80, 1000, 440, 1)):
		d = w * 0.55
		p += [
			("cone", (w, h, d), (x, h / 2, z), ROCK2, dict(sm, seg=18, taper=0.1)),  # broad rock body
			("cone", (w * 0.7, h * 0.27, d * 0.7), (x, h * 0.42, z - 3), ROCKD, dict(sm, seg=18, taper=0.62)),  # dark rock band
			# snow mantle on the same slope as the body, a hair proud of it, its summit rounded by smooth shading
			("cone", (w * 0.62, h * 0.56, d * 0.62), (x, h * 0.72, z - 4), SNOW, dict(sm, seg=18, taper=0.17)),
			("ball", (w * 0.13, h * 0.07, d * 0.13), (x, h * 0.99, z - 4), SNOW, dict(sm, subdiv=2)),  # rounded summit
		]
		sx = x + sh * w * 0.38  # a lower snowy shoulder to one side
		p += [
			("cone", (w * 0.6, h * 0.6, d * 0.6), (sx, h * 0.3, z + 30), ROCK1, dict(sm, seg=14, taper=0.08)),
			("cone", (w * 0.32, h * 0.3, d * 0.32), (sx, h * 0.46, z + 26), SNOW, dict(sm, seg=14, taper=0.1)),
		]
	return p


def build(k):
	k.prop("Flowers", flowers())
	k.prop("Pine", pine(0, 0, 30))
	k.prop("Forest", forest())
	k.prop("FarWood", far_wood())
	k.prop("Cottage", cottage())
	k.prop("HeroStatue", hero_statue())
	k.prop("Rank", rank())
	k.prop("RuinWall", ruin_wall())
	k.prop("RuinedCastle", ruined_castle())
	k.prop("Town", town())
	k.prop("Mountain", mountain())
	k.prop("Mound", swell())  # low rolling swells with dirt paths and bare earth

	k.ground(GRASS, margin=4200)  # grass to the horizon
	cx, cz = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2

	def outside(d):
		"""+1 if the right of the road at d faces away from the loop centre, else -1."""
		p, right, _ = k.at(d)
		return 1 if (p.x + right.x - cx) ** 2 + (p.z + right.z - cz) ** 2 > (p.x - cx) ** 2 + (p.z - cz) ** 2 else -1

	# Landmark 1: the hill town on the horizon dead ahead of the start straight, gate and scar toward the runner
	sp, _, st = k.at(k.length * 0.06)
	tx, tz = cx, cz
	for D in range(900, 3000, 50):
		x, z = sp.x + st.x * D, sp.z + st.z * D
		if k.clear_of_road(x, z, 800):
			tx, tz = x, z
			break
	TS = 1.6
	k.place("Town", (tx, -1.0, tz), math.atan2(-(sp.x - tx), -(sp.z - tz)), TS)
	keep_clear = [(tx, tz, 450 * TS)]
	front = math.atan2(sp.z - tz, sp.x - tx)
	for j in range(16):  # pine woods round the hill, the runner's side left open
		a = j * math.tau / 16 + k.rng.uniform(-0.08, 0.08)
		if abs((a - front + math.pi) % math.tau - math.pi) < 0.8:
			continue
		r = 450 * TS + k.rng.uniform(20, 120)
		x, z = tx + r * math.cos(a), tz + r * math.sin(a)
		if k.clear_of_road(x, z, 90):
			k.place("Forest", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.4, 2.0))

	# Landmark 2: the ruined castle on its rise outside the loop, ahead of the runner at a third of the lap
	castle_d = k.length * 0.4
	for f in (0.4, 0.45, 0.36, 0.5):
		d = k.length * f
		s = outside(d)
		pos, yaw = facing(k, d, s * 260)
		if k.clear_of_road(pos[0], pos[2], 150):
			k.place("RuinedCastle", pos, yaw, 1.5)
			keep_clear.append((pos[0], pos[2], 210))
			castle_d = d
			break

	def free(x, z, r=0.0):
		return all((x - a) ** 2 + (z - b) ** 2 > (rr + r) ** 2 for a, b, rr in keep_clear)

	# Landmark 3: two villages, laid out differently; the hero's statue on the green of each
	villages = (
		(0.06, -1, ((-30, 62, 0.0), (10, 70, 0.1), (52, 60, -0.1), (90, 66, 0.2), (-10, 112, 0.3), (40, 118, -0.2))),
		(0.62, 1, ((-60, 58, 0.4), (-20, 96, -0.3), (64, 74, 0.6), (96, 110, -0.5), (20, 140, 0.2))),
	)
	for f, side, houses in villages:
		d0 = k.length * f + 30
		s = side * outside(d0)
		pos, yaw = facing(k, d0 + 40, s * 36)
		k.place("HeroStatue", pos, yaw)
		keep_clear.append((pos[0], pos[2], 16))
		for dd, off, turn in houses:
			pos, yaw = facing(k, d0 + dd, s * off)
			if k.clear_of_road(pos[0], pos[2], 40):
				ob = k.place("Cottage", pos, yaw + turn, k.rng.uniform(0.9, 1.15))
				if turn > 0.15:
					ob.scale[0] *= -1  # mirrored plan for variety
				keep_clear.append((pos[0], pos[2], 26))
	# A third hamlet near the end with no statue: a loose cluster set back from the road
	d0 = k.length * 0.88
	s = -outside(d0)
	for dd, off, turn in ((0, 90, 0.5), (40, 130, -0.7), (90, 100, 1.2), (-40, 150, 2.0)):
		pos, yaw = facing(k, d0 + dd, s * off)
		if k.clear_of_road(pos[0], pos[2], 60):
			k.place("Cottage", pos, yaw + turn, k.rng.uniform(0.9, 1.1))
			keep_clear.append((pos[0], pos[2], 26))

	# Landmark 4: the headless army massed on mounds among pines before the castle, facing the town
	d = castle_d - k.length * 0.12
	while d < castle_d + k.length * 0.06:
		side = k.rng.choice((-1, 1))
		off = side * k.rng.uniform(82, 140)
		centre, _ = k.beside(d, off)
		if k.clear_of_road(centre[0], centre[2], 78) and free(centre[0], centre[2], 50):  # mound half-width 48 + 24 + margin
			yaw = math.atan2(-(tx - centre[0]), -(tz - centre[2])) + k.rng.uniform(-0.25, 0.25)
			k.place("Rank", (centre[0], -1.0, centre[2]), yaw, k.rng.uniform(1.0, 1.08))
			keep_clear.append((centre[0], centre[2], 50))
		d += k.rng.uniform(55, 85)

	# Meadow dressing by the road: blue-moon-weed clusters, single pines, ruin fragments, pine woods with paths
	row(k, 70, (-44, 44), ["Flowers"], 40, jitter=4, face_road=False)  # patch half-size 13: edge stays 24+ from the centre line
	row(k, 80, (-54, 54), ["Pine"], 44, jitter=12, start=60, scale=(0.9, 1.5), face_road=False)
	row(k, 420, (-60, 60), ["RuinWall"], 50, jitter=10, start=260)
	row(k, 130, (-110, 110), ["Forest", "Pine"], 90, jitter=24, scale=(0.9, 1.4), face_road=False)

	def scatter(count, names, clearance, lo, hi, scale, inside=None):
		placed = tries = 0
		while placed < count and tries < count * 40:
			tries += 1
			x = k.rng.uniform(lo[0], hi[0])
			z = k.rng.uniform(lo[1], hi[1])
			if inside is not None and ((x - cx) ** 2 + (z - cz) ** 2 > inside ** 2):
				continue
			if free(x, z, 40) and k.clear_of_road(x, z, clearance):
				k.place(k.rng.choice(names), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))
				placed += 1

	lo, hi = (k.lo.x - 500, k.lo.z - 500), (k.hi.x + 500, k.hi.z + 500)
	scatter(110, ["Forest", "Forest", "Pine"], 130, lo, hi, (1.0, 1.8))  # infield and near woods with paths
	scatter(26, ["Mound"], 270, lo, hi, (0.9, 1.25))  # rolling swells with dirt paths over the plain
	scatter(60, ["Mound"], 130, lo, hi, (0.45, 0.52))  # smaller swells nearer the road
	scatter(40, ["Flowers"], 60, (k.lo.x - 200, k.lo.z - 200), (k.hi.x + 200, k.hi.z + 200), (1.2, 2.0))
	scatter(6, ["RuinWall"], 120, lo, hi, (1.0, 1.3))
	# Hazed far woods in a ring beyond the track, then the snow massif on the horizon
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z) / 2
	for j in range(34):
		a = j * math.tau / 34 + k.rng.uniform(-0.06, 0.06)
		r = span + k.rng.uniform(650, 1300)
		x, z = cx + r * math.cos(a), cz + r * math.sin(a)
		if free(x, z, 120):
			k.place("FarWood", (x, -1.0, z), a + math.pi / 2 + k.rng.uniform(-0.4, 0.4), k.rng.uniform(1.0, 1.8))
	ta = math.atan2(tz - cz, tx - cx)  # the massif stands behind the hill town, as in ref 01
	for j, (da, rr, sc) in enumerate(((0.0, 3800, 1.3), (-1.3, 3900, 0.85), (1.5, 4000, 0.7), (math.pi, 3900, 0.9))):
		a = ta + da
		r = span + rr
		k.place("Mountain", (cx + r * math.cos(a), -1.0, cz + r * math.sin(a)), -a + math.pi / 2, sc)
	# Bright hazy day: cyan overhead fading to near-white haze at the horizon (no fog: it blacked out the render)
	k.sky([(0.0, "F6FAF8"), (0.04, "E6F2F4"), (0.12, "C4E4EE"), (0.35, "8ACCE6"), (1.0, "4AA8D6")], strength=0.85, sun=(3.4, "FFF6E6", 48, 150))
