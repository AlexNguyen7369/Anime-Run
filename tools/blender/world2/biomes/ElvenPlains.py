"""World 2 Track 1: Elven Plains (Frieren, Aura the Guillotine arc). Reference notes: docs/world2_refs/ElvenPlains.md.

The northern plains around the count's walled hill town: bright hazy day (cyan sky fading to near-white haze at the
horizon), rolling green hills, dark conifer woods with dirt paths, paler desaturated far woods, one broad snow massif
on the horizon. Landmarks, each from the source and rebuilt from primitives:
- Town (hero): the fortified hill town: a long, low cream curtain wall with unevenly spaced round towers (slate cone
  roofs) and a few square towers along the top of a broad green rise, a packed roofscape, the mansion and church, and
  below the wall the arc's scar: a band of felled dark trunks, stumps and bare earth.
- RuinedCastle (hero): the broken castle where the Guillotine waits (EP9 interior: tall round-arched windows in
  brick-coursed stone, a broken vault): a ruined hall and keep with Romanesque arched window rows and a collapsed gable.
- Rank: her headless army, about thirty tall suits of grey plate with an empty gorget ring above the shoulders (no
  heads, no gore), halberd tips up, massed on a raised mound among pines.
- HeroStatue: the village statue of the hero: slim patina figure about 7.5 heads tall, floor-length cape flaring at the
  hem, stacked high collar, bob hair, both hands on the pommel of a long sword planted to the plinth, on a wide
  two-course ashlar plinth, crowned with nine five-petal blue blooms (faceless; no crest).
- Cottage: half-timbered village house; Flowers: low blue-moon-weed clusters.
Everything in-house, parts only; no crest, text or numerals (design doc 5). Proposed look; the owner approves the
render set (design doc 4.46). Budget (BIOME_ENVIRONMENT_SPEC 4.5): 12 meshes, 2 hero (Town, RuinedCastle)."""

import math

import roads
from roads import Roads

# (prop, world x, z, scale) behind the finish: the spots beside the 0.9 axis free of Track 2's ruins, which fill the axis itself
BEHIND_FINISH = [("RuinWall", 306, 425, 1.0), ("Pine", 322, 410, 1.3), ("Pine", 310, 408, 1.2), ("Pine", 325, 420, 1.3), ("Pine", 405, 402, 1.3), ("Pine", 418, 395, 1.3), ("Pine", 412, 410, 1.3), ("Pine", 420, 406, 1.2)]

# (world x, z, turn off the town's direction) of the army's ranks, one in each of three run views (0.06, 0.33, 0.62): each passes
# export_props.rules_ok (exact triangles and parts fallback against every road, pads, plaza, own ground)
RANKS = [(-26, -275, 0.0), (85.5, 277.9, 0.0), (-149.4, -412.4, 0.24)]

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
	"""Half-timbered village house: stone ground floor, jettied plaster upper storey with a dark timber frame and
	braces, steep shingled gable roof, chimney, shuttered windows, door, a wattle fence and barrels."""
	W, D = 22, 16
	p = [
		("box", (W, 9, D), (0, 4.5, 0), STONEB),
		("box", (W + 0.4, 1, D + 0.4), (0, 0.5, 0), "8C877C"),
		("box", (W + 2, 10, D + 2), (0, 14.5, 0), PLASTER),  # jettied storey, 1 stud out each side
		("box", (W + 2.4, 1, D + 2.4), (0, 9.6, 0), TIMBER),  # jetty beam
		("box", (W + 2.4, 0.8, D + 2.4), (0, 19.2, 0), TIMBER),  # wall plate
	]
	# roof as two thin shingled slabs over open gable ends (plaster triangles with a timber frame and a window)
	RH, half = 13, (D + 2) / 2
	pitch = math.degrees(math.atan2(RH, half))
	slope = math.hypot(RH, half) + 1.6
	ca, sa = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
	top = 19.6 + RH + 0.5
	for sz in (-1, 1):
		p.append(("box", (W + 5, 0.9, slope), (0, top - sa * slope / 2 + ca * 0.45, sz * (ca * slope / 2 + sa * 0.45)), ROOF, {"rot": (sz * pitch, 0, 0)}))
		for t in (0.22, 0.44, 0.66, 0.88):  # shingle courses
			p.append(("box", (W + 4.8, 0.3, 0.45), (0, top - sa * slope * t + ca * 1.0, sz * (ca * slope * t + sa * 1.0)), "684A3C", {"rot": (sz * pitch, 0, 0)}))
	p.append(("box", (W + 5.4, 1.0, 1.4), (0, top + 0.6, 0), "684A3C"))  # ridge
	for sx in (-1, 1):
		gx = sx * (W / 2 + 1.0)
		p += [
			("wedge", (0.6, RH, half), (gx, 19.6 + RH / 2 - 0.3, -half / 2), PLASTER),
			("wedge", (0.6, RH, half), (gx, 19.6 + RH / 2 - 0.3, half / 2), PLASTER, {"rot": (0, 180, 0)}),
			("box", (0.7, RH - 1, 0.7), (gx + sx * 0.1, 19.6 + (RH - 1) / 2, 0), TIMBER),
			("box", (0.7, 0.6, D + 1), (gx + sx * 0.1, 19.6 + 4.5, 0), TIMBER),
			("box", (0.6, 3, 2.6), (gx + sx * 0.15, 19.6 + 7.4, 0), "3E5A7A", {"rough": 0.3}),
			("box", (0.6, 0.6, 8.5), (gx + sx * 0.1, 19.6 + 2.3, -3.6), TIMBER, {"rot": (-32, 0, 0)}),
			("box", (0.6, 0.6, 8.5), (gx + sx * 0.1, 19.6 + 2.3, 3.6), TIMBER, {"rot": (32, 0, 0)}),
		]
		for z in (-8, -3, 3, 8):  # posts on the jettied storey's end walls
			p.append(("box", (0.4, 10, 0.8), (sx * (W / 2 + 1.15), 14.5, z), TIMBER))
		p.append(("box", (0.4, 3.2, 3.2), (sx * (W / 2 + 1.2), 15.8, 0), "3E5A7A", {"rough": 0.3}))
	for sz in (-1, 1):  # timber frame on both long faces: posts, mid rail, K braces, leaded windows
		zf = sz * (D / 2 + 1.15)
		for x in (-11.5, -6, 0, 6, 11.5):
			p.append(("box", (0.8, 10, 0.4), (x, 14.5, zf), TIMBER))
		p.append(("box", (W + 2, 0.7, 0.4), (0, 14.8, zf), TIMBER))
		for x, r in ((-8.75, 32), (8.75, -32), (-3, -32), (3, 32)):
			p.append(("box", (0.6, 6, 0.4), (x, 12.2, zf), TIMBER, {"rot": (0, 0, r)}))
		for x in (-8.75, 3) if sz < 0 else (-3, 8.75):
			p.append(("box", (3.2, 3.2, 0.5), (x, 17.2, zf), "3E5A7A", {"rough": 0.3}))
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
	p += [("box", (3.4, 14, 3.4), (7, 27, 3), "8C877C"), ("box", (4, 1, 4), (7, 34.4, 3), "6E6A62")]
	for x in range(-14, 15, 4):
		p.append(("box", (0.5, 4, 0.5), (x, 2, -D / 2 - 9), TIMBER))
	p += [("box", (29, 0.5, 0.4), (0, 3.2, -D / 2 - 9), TIMBER), ("box", (29, 0.5, 0.4), (0, 1.6, -D / 2 - 9), TIMBER)]
	for x, z in ((W / 2 + 2.5, -4), (W / 2 + 2.5, -1)):
		p.append(("cyl", (2.4, 3.4, 2.4), (x, 1.7, z), "7A5636", {"seg": 8}))
		p.append(("cyl", (2.6, 0.4, 2.6), (x, 2.4, z), DARK, {"seg": 8}))
	return p


def hero_statue():
	"""The hero's statue (ref 05, 08). Wide two-course ashlar plinth; a slim patina figure about 30 studs tall
	(7.5 heads): boots, floor-length cape flaring at the hem, tunic, stacked high collar, bob hair, both hands on the
	pommel at chest height, a long blade planted to the plinth, a crown of nine five-petal blue blooms. Faceless;
	the cape clasp is a plain bar. Front is -Z."""
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
	p += [
		# boots and legs, seen in the cape's front opening
		("box", (1.5, 2.2, 2.8), (-1.0, y0 + 1.1, -1.2), PATINA2),
		("box", (1.5, 2.2, 2.8), (1.0, y0 + 1.1, -1.2), PATINA2),
		("box", (1.3, 9, 1.5), (-1.0, y0 + 6.6, -0.8), PATINA),
		("box", (1.3, 9, 1.5), (1.0, y0 + 6.6, -0.8), PATINA),
		("cone", (4.6, 5.2, 2.8), (0, y0 + 12.4, -0.7), PATINA, {"seg": 10, "taper": 0.86, "smooth": True}),  # tunic skirt
		("box", (4.4, 0.6, 2.7), (0, y0 + 15.2, -0.7), PATINA2),  # belt
		("cone", (4.2, 8.2, 2.6), (0, y0 + 19.3, -0.5), PATINA, {"seg": 10, "taper": 1.12, "smooth": True}),  # chest
		("box", (0.5, 7.4, 0.3), (0, y0 + 19.6, -1.9), PATINA2),  # front placket
		# the cape: a smooth bell from the shoulders to the plinth, flaring at the hem, open at the front
		("cone", (10.6, 23.2, 6.0), (0, y0 + 11.9, 1.1), PATINA2, {"seg": 20, "taper": 0.5, "smooth": True}),
		("cone", (11.0, 0.6, 6.4), (0, y0 + 0.6, 1.1), PATINA2, {"seg": 20, "smooth": True, "taper": 0.98}),  # hem lip
		("ball", (7.6, 2.8, 4.4), (0, y0 + 23.0, 0.4), PATINA2, {"subdiv": 3, "smooth": True}),  # mantle over the shoulders
		("box", (1.8, 1.0, 0.5), (0, y0 + 22.6, -1.9), PATINA3),  # clasp (plain bar)
		# stacked high collar
		("cyl", (3.0, 0.8, 3.0), (0, y0 + 24.4, 0.1), PATINA2, {"seg": 14, "smooth": True}),
		("cyl", (2.7, 0.8, 2.7), (0, y0 + 25.2, 0.1), PATINA, {"seg": 14, "smooth": True}),
		("cyl", (2.4, 0.8, 2.4), (0, y0 + 26.0, 0.1), PATINA2, {"seg": 14, "smooth": True}),
		# head and bob hair
		("ball", (2.5, 3.3, 2.8), (0, y0 + 27.6, -0.1), PATINA, {"subdiv": 3, "smooth": True}),
		("ball", (3.3, 3.0, 3.4), (0, y0 + 28.7, 0.35), PATINA3, {"subdiv": 3, "smooth": True}),  # bob: crown and back
		("ball", (3.4, 3.0, 3.2), (0, y0 + 27.7, 0.55), PATINA3, {"subdiv": 3, "smooth": True}),  # bob: sides to the jaw
		("ball", (2.9, 1.1, 1.0), (0, y0 + 28.8, -1.2), PATINA3, {"subdiv": 2, "smooth": True}),  # bangs
		# forearms out of the cape, hands stacked on the pommel at the waist
		("cyl", (0.9, 3.4, 0.9), (-1.5, y0 + 18.9, -2.0), PATINA2, {"seg": 8, "smooth": True, "rot": (90, -40, 0)}),
		("cyl", (0.9, 3.4, 0.9), (1.5, y0 + 18.9, -2.0), PATINA2, {"seg": 8, "smooth": True, "rot": (90, 40, 0)}),
		("ball", (2.2, 1.4, 1.5), (0, y0 + 19.0, -3.2), PATINA, {"subdiv": 1, "smooth": True}),  # hands
		# the sword: pommel above the hands, crossguard below, long blade planted on the plinth
		("ball", (1.0, 1.0, 1.0), (0, y0 + 20.1, -3.2), PATINA3, {"subdiv": 1, "smooth": True}),
		("box", (5.0, 0.6, 0.7), (0, y0 + 17.6, -3.2), PATINA2),
		("box", (0.8, 0.8, 0.8), (-2.6, y0 + 17.6, -3.2), PATINA2, {"rot": (0, 0, 45)}),
		("box", (0.8, 0.8, 0.8), (2.6, y0 + 17.6, -3.2), PATINA2, {"rot": (0, 0, 45)}),
		("box", (1.3, 16.2, 0.35), (0, y0 + 9.2, -3.2), PATINA3, {"metal": 0.3, "rough": 0.4}),
		("box", (0.3, 15.6, 0.45), (0, y0 + 9.4, -3.2), PATINA2),  # fuller
		("wedge", (1.3, 1.1, 0.35), (0, y0 + 0.6, -3.2), PATINA3, {"rot": (0, 0, 180)}),
	]
	for j in range(9):  # crown of nine five-petal blue blooms round the bob
		a = j * math.tau / 9
		bx, bz = 1.72 * math.cos(a), 0.35 + 1.72 * math.sin(a)
		by = y0 + 29.5 - 0.25 * math.sin(a)
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
			x = (c - (n - 1) / 2) * 9.2 + (r % 2) * 2.2 + ((c * 7 + r * 3) % 5 - 2) * 0.4
			zz = z + ((c * 5 + r) % 3 - 1) * 0.8
			y = -2 + 7 * math.sqrt(max(0.0, 1 - (x / MX) ** 2 - (zz / MZ) ** 2)) - 0.4
			def at(px, py, pz):
				return (x + px * S, y + py * S, zz + pz * S)
			for sx in (-1, 1):
				p += [
					("box", (1.3 * S, 0.9 * S, 2.6 * S), at(sx * 0.8, 0.45, -0.5), STEEL2, m),  # sabaton
					("cyl", (1.25 * S, 5 * S, 1.4 * S), at(sx * 0.8, 3.3, 0), STEEL2, dict(ms, seg=8)),  # greave
					("cyl", (1.7 * S, 1.3 * S, 1.7 * S), at(sx * 0.8, 5.9, -0.15), STEEL3, dict(ms, seg=8)),  # knee cop
					("cone", (1.5 * S, 4.2 * S, 1.6 * S), at(sx * 0.85, 8.4, 0), STEEL, dict(ms, seg=8, taper=1.3)),  # cuisse
					("cyl", (2.7 * S, 2.3 * S, 2.7 * S), at(sx * 2.55, 17.4, 0), STEEL3, dict(ms, seg=10, rot=(0, 0, 90))),  # pauldron
					("cyl", (1.15 * S, 4.2 * S, 1.2 * S), at(sx * 2.6, 14.4, 0.1), STEEL2, dict(ms, seg=8)),  # arm
					("box", (1.4 * S, 1.7 * S, 1.5 * S), at(sx * 2.6, 11.6, -0.2), STEEL, m),  # gauntlet
				]
			p += [
				("cone", (4.8 * S, 3.0 * S, 3.4 * S), at(0, 11.0, 0), STEEL2, dict(ms, seg=10, taper=0.72)),  # faulds skirt
				("cyl", (3.2 * S, 1.0 * S, 2.3 * S), at(0, 12.8, 0), DARK, dict(m, seg=10)),  # waist belt
				("cone", (3.4 * S, 5.0 * S, 2.6 * S), at(0, 15.7, -0.05), STEEL, dict(ms, seg=12, taper=1.42)),  # breastplate
				("box", (0.3 * S, 4.4 * S, 0.3 * S), at(0, 15.6, -1.7), STEEL3, m),  # ridge
				("cyl", (2.5 * S, 1.6 * S, 2.5 * S), at(0, 18.9, 0), STEEL3, dict(ms, seg=12)),  # empty gorget ring
				("cyl", (1.8 * S, 1.0 * S, 1.8 * S), at(0, 19.3, 0), DARK, {"seg": 12}),  # its dark hollow
			]
			wx = 3.6 if i % 2 == 0 else -3.6
			if i % 3 != 2:  # halberd: shaft, axe blade, back spike, top spike
				p += [
					("cyl", (0.5, 26 * S, 0.5), at(wx, 13, -0.6), "3E3228", {"seg": 5}),
					("wedge", (0.35, 2.2 * S, 1.6 * S), at(wx, 23.8, -1.4), STEEL3, dict(m, rot=(0, 90, 0))),
					("cone", (0.9, 3.0 * S, 0.9), at(wx, 27.5, -0.6), STEEL3, {"seg": 4}),
				]
			else:  # spear
				p += [("cyl", (0.45, 24 * S, 0.45), at(wx, 12, -0.6), "3E3228", {"seg": 5}), ("cone", (1.0, 3.2 * S, 1.0), at(wx, 25.6, -0.6), STEEL3, {"seg": 4})]
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
		h = (26, 18, 22, 12, 20, 16)[i]
		cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		p.append(("box", (L, h, 6), (cx, Y + h / 2, cz), RUIN, {"rot": (0, yaw, 0)}))
		p.append(("box", (L + 0.4, 3, 6.4), (cx, Y + 1.5, cz), MOSS, {"rot": (0, yaw, 0)}))
		p.append(("box", (L + 0.2, 0.4, 6.2), (cx, Y + h * 0.55, cz), RUIN2, {"rot": (0, yaw, 0)}))
		n = int(L // 7)
		for j in range(n):
			if (j + i) % 3 == 2:
				continue
			t = (j + 0.5) / n
			p.append(("box", (3.4, 3.4, 6.2), (x1 + (x2 - x1) * t, Y + h + 1.7, z1 + (z2 - z1) * t), RUIN2, {"rot": (0, yaw, 0)}))
	# Gatehouse with a round arch
	for x in (-18, 18):
		p += [("box", (14, 36, 14), (x, Y + 18, -60), RUIN2), ("box", (15, 2, 15), (x, Y + 36, -60), RUIN)]
	p += [("box", (22, 10, 7), (0, Y + 27, -60), RUIN2)]
	p += arch_window(0, Y + 9, -60, 14, 18, 7.4, seg=12)
	# The great hall: long side walls with rows of tall paired round-arched windows, broken gable ends
	HX, HZ, HL, HH = -20, 5, 90, 40
	for s in (-1, 1):
		z = HZ + s * 16
		top = [HH, HH - 6, HH, HH - 14, HH - 4, HH - 20] if s < 0 else [HH - 10, HH, HH - 2, HH - 16, HH, HH - 8]
		for j, h in enumerate(top):  # wall bays of uneven broken height
			x = HX - HL / 2 + HL / 12 + j * HL / 6
			p.append(("box", (HL / 6 + 0.2, h, 5), (x, Y + h / 2, z), RUIN))
			p.append(("box", (HL / 6 + 0.4, 0.4, 5.4), (x, Y + 8, z), RUIN2))
			if h > 24:
				p += arch_window(x - 3, Y + 18, z, 3.6, 12, 5.6)
				p += arch_window(x + 3, Y + 18, z, 3.6, 12, 5.6)
				p.append(("box", (12, 0.8, 6), (x, Y + 11.6, z), RUIN3))
			p.append(("box", (4, h * 0.9, 4), (x - HL / 12, Y + h * 0.45, z + s * 3.5), RUIN2))  # buttress
	# West gable end: a tall wall with one huge broken arched window (ref 12)
	gx = HX - HL / 2
	p += [("box", (5, 54, 36), (gx, Y + 27, HZ), RUIN), ("wedge", (5, 16, 18), (gx, Y + 62, HZ - 9), RUIN, {"rot": (0, 180, 0)})]
	p += arch_window(gx, Y + 26, HZ, 14, 30, 5.6, yaw=90, seg=14)
	p += [("box", (5.4, 0.5, 36.4), (gx, Y + y, HZ), RUIN2) for y in (10, 20, 46)]
	# East end collapsed: rubble heap and a fallen vault rib
	p += [
		("ball", (36, 12, 34), (HX + HL / 2, Y + 2, HZ), RUIN2, {"subdiv": 1}),
		("box", (6, 4, 6), (HX + HL / 2 + 10, Y + 2, HZ - 14), RUIN, {"rot": (12, 30, 8)}),
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
	for x, z, h, w in ((gx - 2.8, HZ + 10, 30, (1, 30, 8)), (kx - 15.4, kz + 4, 34, (1, 34, 7)), (75.2, 30, 14, (1, 14, 6))):
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


def mountain():
	"""One broad snow massif (ref 01): hazed green-grey foothill swells, then broad peaks of varied height along an
	uneven ridgeline with a dark rock band under each snowfield and smooth snow caps; desaturated blue-grey for
	distance, smooth-shaded so no facet seams read against the sky."""
	sm = {"smooth": True}
	p = []
	for x, z, r, h in ((-1000, -60, 1100, 220), (-200, -20, 1300, 260), (700, -40, 1200, 240), (1300, -80, 800, 180)):  # foothills
		p.append(("ball", (r, h * 2, r * 0.5), (x, 0, z), "A2B8B4", {"subdiv": 3, "smooth": True}))
	peaks = ((-1150, 80, 300, 420), (-820, 20, 470, 600), (-470, 60, 400, 520), (-120, 40, 560, 760), (240, 80, 480, 640), (560, 30, 420, 560), (880, 70, 340, 480), (1180, 40, 260, 380))
	for i, (x, z, h, r) in enumerate(peaks):
		lean = (i % 3 - 1) * 4
		yaw = i * 37
		base = 30 + (i * 53) % 90  # peaks rise from different heights: an uneven ridgeline
		hh = h + 200 - base
		o = dict(sm, seg=12, rot=(lean, yaw, -lean))
		p.append(("cone", (r * 1.6, hh, r * 1.0), (x, base + hh / 2, z), ROCK1 if i % 2 else ROCK2, o))
		p.append(("cone", (r * 1.14, hh * 0.72, r * 0.71), (x, base + hh * 0.64, z - 4), ROCKD, o))  # bare rock band
		p.append(("cone", (r * 0.78, hh * 0.5, r * 0.49), (x, base + hh * 0.75 + 3, z - 7), SNOW, dict(o, seg=7, smooth=False)))  # snowfield, ragged edge
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
	k.prop("Mound", [("ball", (140, 34, 100), (0, -4, 0), "7DB25E", {"subdiv": 3, "smooth": True}), ("ball", (80, 30, 70), (40, -2, 18), "78AC5A", {"subdiv": 3, "smooth": True})] + pine(-30, 10, 34, 8) + pine(20, -16, 28, 9) + pine(46, 20, 30, 11))

	k.ground(GRASS, margin=7000)  # grass to the horizon
	r = Roads(k.track["Number"])
	cx, cz = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2
	BOX = {"Forest": (90, 62), "Pine": (12, 12), "Flowers": (26, 19), "RuinWall": (41, 21), "Mound": (150, 104)}
	taken = []  # (x, z, radius) of the landmarks

	def free(x, z, rad=0.0):
		return all(math.hypot(x - a, z - b) > rr + rad for a, b, rr in taken)

	# The road winds twice round the spawn plaza, its laps and Track 2's road 150 studs apart: everything that the game
	# builds stands in those gaps, on this track's own half of them. The horizon pieces stand past the outer tracks.
	# Landmark 1: the hill town on the horizon ahead of the start straight, gate and scar toward the runner, in the
	# 1,800-stud gap between Track 9's road and Track 10's
	sp, _, _ = k.at(k.length * 0.06)
	TS = 1.6
	tx, tz = 620.0, -3220.0
	k.place("Town", (tx, -1.0, tz), math.atan2(-(sp.x - tx), -(sp.z - tz)), TS)
	# Landmark 2: the ruined castle, at its approved 1.5 beside the town on the horizon (no gap on this track's ground holds
	# it). game_shots.py --castle-052 builds the owner's option instead: 0.52, dead ahead at the end of the start straight
	option = "castle_052" in roads.OPTIONS
	# game_shots.py --turned: the other option for the owner, not exported: the statues and ranks turned to the runner, with one more
	# of each than the approved rules allow where they stand (default: statue square to the road, rank toward the town)
	turned = "turned" in roads.OPTIONS
	best = None
	for x in range(-190, -90, 4) if option else ():
		for z in range(-310, -220, 4):
			yaw = math.atan2(-(sp.x - x), -(sp.z - z))
			if r.fits(x, z, yaw, 226 * 0.52, 190 * 0.52, clear=24.2):
				off = abs(x - sp.x) + 0.3 * abs(z + 260)
				if best is None or off < best[0]:
					best = (off, x, z, yaw)
	if best:
		_, x, z, yaw = best
		k.place("RuinedCastle", (x, -1.0, z), yaw, 0.52)
		taken.append((x, z, 74))
	else:
		x, z = -1500.0, -3150.0
		yaw = math.atan2(-(sp.x - x), -(sp.z - z))
		assert r.fits(x, z, yaw, 372, 302, own=False)
		k.place("RuinedCastle", (x, -1.0, z), yaw, 1.5)

	# Open lines from the run cameras to the landmarks: no tree on them
	sight = []

	def see(f, x, z):
		p, right, _ = k.at(k.length * f)
		sight.append((p.x + right.x * 10, p.z + right.z * 10, x, z))

	def hidden(x, z, w):
		for x0, z0, x1, z1 in sight:
			dx, dz = x1 - x0, z1 - z0
			t = max(0.0, min(0.92, ((x - x0) * dx + (z - z0) * dz) / (dx * dx + dz * dz)))
			if math.hypot(x - x0 - t * dx, z - z0 - t * dz) < w / 2 + 12 * t + 2:
				return True
		return False

	for f, d, off in ((0.9, 2800, 42), (0.9, 2838, 58), (0.33, 1075, -70), (0.33, 1110, -70), (0.06, 228, -46)):
		pos, _ = facing(k, d, off)
		see(f, pos[0], pos[2])
	see(0.06, -150, -274)
	see(0.06, -110, -280)

	def stand_rank(x, z, yaw=None, shifts=(0.0, 0.12, -0.12, 0.25, -0.25)):
		"""A rank facing the town (the approved turn, within 0.25 rad); True where it fits."""
		for sh in shifts if yaw is None else (0.0,):
			y = (math.atan2(-(tx - x), -(tz - z)) + sh) if yaw is None else yaw
			if free(x, z, 50) and r.fits(x, z, y, 104, 66, clear=24.5):
				k.place("Rank", (x, -1.0, z), y)
				taken.append((x, z, 50))
				return True
		return False

	def put(name, d, off, turn=0.0, scale=1.0, size=None, rad=None, faces=True):
		"""The prop at `off` studs beside the road at d, its front to the road; False where it does not fit."""
		pos, yaw = facing(k, d, off)
		yaw = yaw + turn if faces else k.rng.uniform(0, math.tau)
		w, dep = size or BOX[name]
		rad = max(w, dep) * scale / 2 if rad is None else rad
		if name in ("Pine", "Forest") and r.nearest([(pos[0], pos[2])])[0][0] < 50:
			return False
		if name in ("Pine", "Forest") and hidden(pos[0], pos[2], w * scale):
			return False
		if name == "Pine" and pos[0] > sp.x and pos[2] < sp.z and math.hypot(pos[0] - sp.x, pos[2] - sp.z) < 170:
			return False  # no pine before the infield ruin in the 0.06 view
		if not free(pos[0], pos[2], rad) or not r.fits(pos[0], pos[2], yaw, w * scale, dep * scale):
			return False
		k.place(name, pos, yaw, scale)
		taken.append((pos[0], pos[2], rad))
		return True

	if not turned:
		for x, z, sh in RANKS:
			if option and x == -26:  # the castle stands there: the next free spot east of it
				any(stand_rank(x2, -276) for x2 in range(0, 120, 4))
				continue
			k.place("Rank", (x, -1.0, z), math.atan2(-(tx - x), -(tz - z)) + sh)
			taken.append((x, z, 50))
			see({-26: 0.06, 85.5: 0.33, -149.4: 0.62}[x], x, z)
	# Landmark 3: villages along the first lap and the last straight; the hero's statue on the green of two of them
	# The hero's statue where the 0.06 run camera sees it, left of the castle, and one by the finish for the 0.9 camera
	for d, off in ((228, -46), (222, -50), (216, -44), (235, -44), (205, -50), (200, -58)):
		pos, yaw = facing(k, d, off)
		if turned:
			yaw = math.atan2(-(sp.x - pos[0]), -(sp.z - pos[2]))
		if r.fits(pos[0], pos[2], yaw, 24, 24, clear=24.5) and all(math.hypot(pos[0] - a, pos[2] - b) > 12 + 62 for a, b, _ in (taken[:1] if option else ())):
			k.place("HeroStatue", pos, yaw)
			taken.append((pos[0], pos[2], 16))
			print("Statue 06 at", d, off)
			break
	# the end of the start straight: a rank on its mound under the broken walls of a ruin (the castle's place)
	if not option:
		for x, z, turn, sc in ((-150, -274, 0.0, 1.3), (-104, -280, -0.35, 1.2), (-200, -240, 0.6, 1.0)):
			yaw = math.atan2(-(sp.x - x), -(sp.z - z)) + turn
			if free(x, z, 18) and r.fits(x, z, yaw, 41 * sc, 21 * sc):
				k.place("RuinWall", (x, -1.0, z), yaw, sc)
				taken.append((x, z, 24))
		if turned:
			any(stand_rank(x, -276) for x in range(-56, 40, 6))
	# Finish: the statue and a ruin group beside the last straight, a rank of the army across it
	for d, off in ((2800, 42), (2790, 42), (2770, 42)):
		if put("HeroStatue", d, off, 0.9 if turned else 0.0, size=(24, 24), rad=18):
			print("Statue 90 at", d)
			break
	for d, off in ((2790, -68), (2780, -70), (2770, -68), (2760, -66)) if turned else ():
		if put("Rank", d, off, 0.0, size=(104, 66), rad=52):
			break
	for d, off, turn, sc in ((2838, 58, 0.5, 1.1), (2745, 62, -0.4, 1.0), (2700, 66, 0.2, 1.2), (2846, -50, 0.3, 1.0)):
		put("RuinWall", d, off, turn, sc)
	for f, statue, houses in (
		(0.045, False, ((-60, -58, 0.0), (-26, -62, 0.1), (46, -58, -0.1), (80, -64, 0.2), (-44, -98, 0.3), (-4, -100, -0.2), (36, -98, 0.1))),
		(0.30, False, ((-50, -58, 0.4), (40, -62, -0.3), (74, -58, 0.5), (-20, -100, 0.2), (24, -98, -0.4))),
		(0.30, False, ((-30, 58, 0.2), (10, 60, -0.3), (48, 58, 0.3))),
		(0.80, False, ((-60, -60, 0.5), (-24, -96, -0.3), (14, -58, 0.2), (30, -98, -0.6))),
	):
		d0 = k.length * f + 30
		if statue:
			put("HeroStatue", d0, -42, size=(24, 24), rad=16)
		for dd, off, turn in houses:
			put("Cottage", d0 + dd, off, turn, k.rng.uniform(0.9, 1.05), size=(30, 29), rad=17)

	def outer(d):
		p, right, _ = k.at(d)
		return 1 if (p.x + right.x - cx) ** 2 + (p.z + right.z - cz) ** 2 > (p.x - cx) ** 2 + (p.z - cz) ** 2 else -1

	# the 0.62 view: a conifer band and a mound outside the bend ahead of it
	for d, name, sc in ((2005, "Forest", 1.0), (2070, "Forest", 1.05), (2150, "Mound", 0.8), (2235, "Forest", 1.0), (2300, "Forest", 1.05)):
		for shift in (0, 8, -8, 16, -16):
			if any(put(name, d + shift, outer(d) * o, 0.0, sc, rad=46 if name == "Mound" else 34) for o in (70, 66, 74)):
				break
	# Landmark 4: the headless army massed on mounds among pines along the second lap, facing the road
	# ahead of the 0.33 run camera outside the road, then outside the bend the 0.62 camera looks into, then anywhere on the
	# second lap: 4 in all, as the approved draft kept
	n = sum(1 for ob in k.col.objects if ob.data and ob.data.name.endswith("_Rank"))
	for dd in ((1060, 1160), (2080, 2240), (2240, 2500), (1180, 1400), (700, 1000), (500, 700)):
		done = False
		for d in range(*dd, 10):
			for o in (-66, -70, -74, -62, 66, 70, 74):
				if turned and not done and n < 6:
					pos, yaw = facing(k, d, o)
					if stand_rank(pos[0], pos[2], yaw if turned else None):
						n, done = n + 1, True
						print("Rank at", d, o)
	print("Ranks", n)

	# Meadow dressing by the road: blue-moon-weed clusters, single pines, ruin fragments, small pine woods with paths
	def line(every, offs, name, jitter, start, scale, faces=False):
		d = start
		while d < k.length - 70:
			for off in offs:
				o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
				put(name, d + k.rng.uniform(-jitter, jitter), o, 0.0, k.rng.uniform(*scale), faces=faces)
			d += every

	# low mounds and dark conifer bands outside the road (the horizon from the runner's eye), ruins in uneven groups
	d, j = 250, 0
	while d < k.length - 60:  # sizes, turns and spacing vary
		sc = (0.8, 0.92, 0.84)[j % 3]
		put("Mound", d, outer(d) * (52 * sc + 27), (0.0, math.pi, 0.1, math.pi - 0.1)[j % 4], sc, rad=52 * sc + 10)
		d, j = d + (110, 175, 140, 205)[j % 4], j + 1
	for d, off, turn, sc in ((300, 58, 0.2, 1.1), (345, 60, -0.5, 1.0), (690, 58, 0.0, 1.2), (1010, 56, 0.7, 1.0), (1050, 66, -0.2, 1.2), (1600, 60, 0.4, 1.1), (1640, 62, -0.3, 1.0), (1675, 58, 0.1, 1.2), (2250, 58, 0.3, 1.0)):
		put("RuinWall", d, off, turn, sc)
	for o in (70, 104, 136):  # up to three deep where the gap to the next road is wide
		for d in range(90 + o % 30, int(k.length) - 50, 46):
			put("Forest", d, outer(d) * o, 0.0, k.rng.uniform(0.9, 1.05), rad=30)
	for o in (70, 96, 120, 140):
		for d in range(60 + o % 9, int(k.length) - 40, 13):
			if (d // 78) % 3 == 2:
				continue  # clumps, not an even row
			put("Pine", d, outer(d) * (o + k.rng.uniform(-5, 5)), 0.0, k.rng.uniform(1.0, 1.5), rad=7, faces=False)
	line(170, (-72, 72), "Forest", 8, 70, (0.9, 1.05), faces=True)
	line(44, (-44, 44), "Flowers", 4, 40, (1.0, 1.0))
	for o in (56, 65, 74):  # the dense band outside the bend the 0.62 view looks into
		for d in range(1960 + o % 7, 2420, 15):
			put("Pine", d, outer(d) * (o + k.rng.uniform(-3, 3)), 0.0, k.rng.uniform(1.0, 1.5), rad=7, faces=False)
	for d in range(60, int(k.length) - 70, 150):  # clumps of pines, well off the barrier
		for off in (-66, 66):
			for dd, do in ((0, 0), (13, 8), (-12, 7), (5, -9), (20, -6)):
				put("Pine", d + dd + (40 if off > 0 else 0), off + do, 0.0, k.rng.uniform(0.9, 1.4), rad=7, faces=False)

	def scatter(count, names, rad, scale, pad, own=True):
		placed = tries = 0
		while placed < count and tries < count * 60:
			tries += 1
			x, z = k.rng.uniform(k.lo.x - pad, k.hi.x + pad), k.rng.uniform(k.lo.z - pad, k.hi.z + pad)
			name, sc, yaw = k.rng.choice(names), k.rng.uniform(*scale), k.rng.uniform(0, math.tau)
			w, dep = BOX[name]
			if not (name in ("Pine", "Forest") and hidden(x, z, w * sc)) and free(x, z, rad) and r.fits(x, z, yaw, w * sc, dep * sc, own=own):
				k.place(name, (x, -1.0, z), yaw, sc)
				taken.append((x, z, rad))
				placed += 1

	scatter(14, ["Mound"], 52, (0.8, 0.95), 220)
	scatter(50, ["Forest"], 30, (0.9, 1.1), 220)
	scatter(110, ["Flowers"], 8, (1.2, 1.5), 180)
	scatter(40, ["Pine"], 7, (0.9, 1.5), 220)
	# The snow massif behind the hill town (ref 01) past Track 10's road: the draft's only horizon pieces with the town, off
	# this track's own ground, so not built (docs/WORLD2_SPEC.md). Scale over 1.26 keeps the exported mesh in its 3 pieces.
	k.place("Mountain", (700, -1.0, -5150), 0.0, 1.35)
	# More woods that fit this track's own land, none over another track's props
	near = r.neighbours()
	(lox, loz), (hix, hiz) = r.ground(4)
	n = 0
	for _ in range(5000):
		x, z = k.rng.uniform(lox, hix), k.rng.uniform(loz, hiz)
		name, sc = k.rng.choice((("Mound", 0.8), ("Forest", 1.0), ("Pine", 1.5), ("Pine", 1.2)))
		w, dep = {"FarWood": (248, 180)}.get(name, BOX.get(name))
		yaw = k.rng.choice((0.0, math.pi / 2))
		if free(x, z, w * sc / 2) and r.fits(x, z, yaw, w * sc, dep * sc, own=False) and not r.overlaps(near, x, z, yaw, w * sc, dep * sc):
			k.place(name, (x, -1.0, z), yaw, sc)
			taken.append((x, z, w * sc / 2))
			n += 1
	print("BACKDROP", n)
	# Behind the finish, on the 0.9 view's axis
	for name, x, z, sc in BEHIND_FINISH:
		w, dep = BOX[name]
		if free(x, z, 6) and r.fits(x, z, 0.0, w * sc, dep * sc, own=False):
			k.place(name, (x, -1.0, z), 0.0, sc)
			taken.append((x, z, 8))
	if option:  # pines at the mound's foot, under its overhanging corner towers (a fault of the mesh)
		_, x, z, yaw = best
		for j in range(40):
			a = j * math.tau / 40
			for rr in (0.5, 0.56):
				lx, lz = 252 * 0.52 * rr * math.cos(a), 212 * 0.52 * rr * math.sin(a)
				px, pz = x + lx * math.cos(yaw) + lz * math.sin(yaw), z - lx * math.sin(yaw) + lz * math.cos(yaw)
				if abs(lz + 60) > 22 and r.fits(px, pz, 0.0, 14, 14) and j % 3:
					k.place("Pine", (px, -1.0, pz), k.rng.uniform(0, math.tau), k.rng.uniform(0.9, 1.0))
					break
	# Bright hazy day: cyan overhead fading to near-white haze at the horizon (no fog: it blacked out the render)
	k.sky([(0.0, "F6FAF8"), (0.04, "E6F2F4"), (0.12, "C4E4EE"), (0.35, "8ACCE6"), (1.0, "4AA8D6")], strength=0.85, sun=(3.4, "FFF6E6", 48, 150))
	roads.apply_cross_track(k)
