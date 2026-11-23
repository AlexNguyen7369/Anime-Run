"""World 2 Track 10: Hell Gate (Saw Man). The devils' Hell from the Hell arc, built to read 1-1 with the source (refs and
landmark list: docs/world2_refs/HellGate.md):
- a wide pale plain dotted with dark grass clumps, low hills, under a red-orange sky;
- countless identical doors: straight rows of free-standing panel doors beside the road, and strict rows of doors
  hanging in the sky, every one face-on to the road, denser higher up;
- giant pale hands with long separated fingers rising out of the plain;
- the last stretch runs into the darkness: one vast edgeless black dome (the Abyss) beyond the finish takes over the
  sky above a bright strip of plain, long thin pale arms bent at the elbow float before it at every angle, and two rows
  of kneeling astronauts on dark mounds pray beside the aisle with their palms pressed together before their visors
  (whole figures, no gore, no mission patch);
- the landmark: one giant door standing open over the road, the door the darkness came through, black beyond it.
No symbols or text (design doc 5). The Darkness Devil itself is not modelled (a character): arms and hands only.
Everything in-house, parts only. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

from mathutils import Vector

GROUND, HILL, MOUND = "B8AA8C", "8E8262", "6A5A44"
TUFT, TUFT2 = "262C16", "3A4222"
PALE, PALE2 = "F6F6FA", "E2E4EC"  # near-white skin, cool shade
DOOR, DOOR2, FRAMEC, KNOB = "8A5A3A", "74482C", "5A3A26", "C8A040"
SUIT, SUIT2, GREY, VISOR = "F4F7FC", "E2E6EE", "8E9098", "0A0A0E"  # cool whites; visor glossy black
RIM, WRIST = "E8ECF2", "3A3E48"
GLOVE, BOOT, PACK, LAMP, CUFF, CHEST = "F0F0EC", "E2E2DE", "EEEEEA", "E4E4DE", "9AA6B8", "D0D0CA"
BLACK = "000000"
HAZE = "FF8A4A"  # the horizon colour: the far plain fades into it
WIDE = 1.4  # the dome is this much wider across the road than along it, so it fills the view from the aisle
MOUND_H = 0.2  # the astronaut kneels on a flat dark shadow patch this thick (local studs)
GRASS_EVERY = 150
ARM_COLS = (-400, -270, -140, 140, 270, 400)  # lateral columns of the arm grid over the darkness
DARK_LEN = 1550  # the finale stretch (arms, black ground pools) is the last 1550 studs


# The darkness finale, 700 and 330 studs before the finish (runner lane); build_track renders these too
# Hero models the owner judges at full size (build_track renders m_<Name>_front / _34 close-ups)
MODEL_SHOTS = ["Astronaut", "Hand", "ArmA", "DarkGate", "SkyDoor", "DoorClosed"]

EXTRA_SHOTS = [
	("06_finale_700", (-4137.9, 9.0, 35.5), (-4137.9, 5.0, -48.5)),
	("07_finale_330", (-4137.9, 9.0, -334.5), (-4137.9, 5.0, -418.5)),
]


# --- small vector helpers (Roblox local space, tuples) ---
def add(*v):
	return tuple(sum(c) for c in zip(*v))


def mul(a, s):
	return (a[0] * s, a[1] * s, a[2] * s)


def norm(a):
	ln = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2) or 1.0
	return (a[0] / ln, a[1] / ln, a[2] / ln)


def B(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def seg(p, a, b, r, col, ball=True, **o):
	"""A limb from point a to point b (Roblox local), radius r, with a ball joint at b. rot = tilt from +Y, then yaw."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rx = math.degrees(math.acos(max(-1.0, min(1.0, dy / ln))))
	ry = math.degrees(math.atan2(dx, dz))
	mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
	sub = o.pop("subdiv", 1)
	o.setdefault("seg", 10)
	p.append(("cyl", (2 * r, ln, 2 * r), mid, col, dict(o, rot=(rx, ry, 0), smooth=True)))
	if ball:
		rb = r * o.get("taper", 1.0)  # the joint matches the limb's tapered end: no band (wider balls read as rings)
		p.append(("ball", (2 * rb, 2 * rb, 2 * rb), b, col, {"subdiv": sub, "smooth": True}))


def glow(p, e, cols):
	"""Parts in `cols` given a faint self-light, so white stays white against the black under the red sky."""
	return [(sh, size, pos, col, dict(rest[0] if rest else {}, emit=e) if col in cols else (rest[0] if rest else {})) for sh, size, pos, col, *rest in p]


def shift(p, off):
	return [(s, size, add(pos, off), col, *rest) for s, size, pos, col, *rest in p]


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0, spin=False, clear=0.9):
	"""kit.along, but every prop stands at height y (ground: -1) even beside ramps, and never near another road stretch.
	Without spin the prop is square to the road (-Z faces it), so rows stay straight."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], abs(o) * clear):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw = k.rng.uniform(0, math.tau) if spin else yaw + (math.pi / 2 if off > 0 else -math.pi / 2)
			yy = k.rng.uniform(*y) if isinstance(y, tuple) else y
			k.place(k.rng.choice(names), (pos[0], yy, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def facing(v):
	"""Yaw that turns a prop's -Z toward Roblox direction v (x, z)."""
	return math.atan2(-v[0], -v[1])


# --- doors ---
def door(ajar=0, w=8, h=16):
	"""A free-standing panel door: sill step, frame posts and lintel with architrave, the slab (six raised panels on both
	faces, knobs and plates, hinges) hinged on the left and swung `ajar` degrees away from the road; black beyond."""
	a = math.radians(ajar)
	p = [
		("box", (w + 4, 0.8, 4), (0, 0.4, 0), "4A3A2A"),
		("box", (1.4, h + 1.6, 1.8), (-w / 2 - 0.7, h / 2 + 1.2, 0), FRAMEC),
		("box", (1.4, h + 1.6, 1.8), (w / 2 + 0.7, h / 2 + 1.2, 0), FRAMEC),
		("box", (w + 2.8, 1.4, 1.8), (0, h + 1.5, 0), FRAMEC),
		("box", (w + 4, 0.8, 2.2), (0, h + 2.4, 0), FRAMEC),  # architrave cap
	]

	def put(size, x, y, z, col, shape="box", **o):
		cx = -w / 2 + math.cos(a) * x + math.sin(a) * z
		cz = -math.sin(a) * x + math.cos(a) * z
		p.append((shape, size, (cx, y, cz), col, dict(o, rot=(0, ajar, 0))))

	put((w, h, 0.6), w / 2, h / 2 + 0.8, 0, DOOR)
	ph = (h - 4) / 3 - 1
	for side in (-1, 1):
		for col_i in range(2):
			for row in range(3):
				put((w / 2 - 1.6, ph, 0.3), w / 4 + col_i * w / 2, 2.6 + ph / 2 + row * (ph + 1), side * 0.4, DOOR2)
		put((0.9, 1.6, 0.2), w - 1.2, h / 2, side * 0.5, KNOB, metal=1, rough=0.3)
		put((0.9, 0.9, 0.7), w - 1.2, h / 2, side * 0.9, KNOB, shape="ball", subdiv=2, smooth=True, metal=1, rough=0.3)  # round knob
	for y in (3, h - 1.5):
		put((0.5, 1.4, 0.8), 0.2, y, 0, "3A3030", metal=0.8)
	if ajar:
		p.append(("box", (w - 0.2, h - 0.2, 0.2), (0, h / 2 + 0.8, 0.2), BLACK))  # the dark beyond
	return p


def sky_door():
	"""One upright door hanging in Hell's sky: frame, panelled slab on both faces, knobs. Hung in strict rows."""
	p = []
	B(p, (1, 17, 1.4), (-4.5, 8.5, 0), FRAMEC)
	B(p, (1, 17, 1.4), (4.5, 8.5, 0), FRAMEC)
	B(p, (10, 1, 1.4), (0, 17.0, 0), FRAMEC)  # lintel sits on the slab: no gap
	B(p, (8, 16, 0.6), (0, 8.5, 0), DOOR)
	B(p, (10, 0.6, 1.6), (0, 0.2, 0), FRAMEC)  # sill under the slab
	for z in (-0.4, 0.4):
		for x in (-2, 2):
			for y in (4.5, 11.5):
				B(p, (3, 5.5, 0.2), (x, y, z), DOOR2)
		p.append(("ball", (0.75, 0.75, 0.5), (3, 8, z * 1.8), KNOB, {"subdiv": 2, "smooth": True, "metal": 1, "rough": 0.3}))  # round knob
	return p


# --- hands and arms ---
FINGERS = ((-1.35, (1.9, 1.25, 0.9)), (-0.45, (2.15, 1.4, 1.0)), (0.45, (2.0, 1.3, 0.95)), (1.35, (1.55, 1.05, 0.8)))


def hand(p, w, f, s, n, k, curl, seg_n=8, sub=1, palm=False):
	"""A slender open hand from wrist point w: f toward the fingers, s across the palm (thumb on -s), n the palm side
	the fingers curl toward. One skin tone throughout. Palm = a fan of metacarpals ending in knuckle bumps (with a full
	palm pad when `palm`), four separated fingers of three tapering segments, each finger curling a little more than the
	last (index straightest, little finger most curled), and a three-segment thumb. Returns the fingertip points."""
	tips = []
	if palm:  # axis-aligned hands only (f up, n toward -Z): soft palm pad, knuckle ridge and thumb muscle over the metacarpals
		p.append(("ball", (3.0 * k, 4.2 * k, 0.95 * k), add(w, mul(f, 1.9 * k), mul(n, -0.1 * k)), PALE, {"subdiv": sub, "smooth": True}))  # slender flat palm over the knuckles
		p.append(("ball", (2.7 * k, 1.0 * k, 0.8 * k), add(w, mul(f, 3.15 * k), mul(n, -0.15 * k)), PALE, {"subdiv": sub, "smooth": True}))  # webbing across the finger roots: one smooth line
		p.append(("ball", (2.6 * k, 1.1 * k, 0.75 * k), add(w, mul(f, 2.8 * k), mul(n, -0.25 * k)), PALE, {"subdiv": sub, "smooth": True}))
		p.append(("ball", (1.1 * k, 2.0 * k, 0.8 * k), add(w, mul(f, 1.0 * k), mul(s, -0.85 * k), mul(n, 0.05 * k)), PALE, {"subdiv": sub, "smooth": True}))  # low thumb muscle
	else:
		seg(p, w, add(w, mul(f, 2.4 * k)), 0.8 * k, PALE, ball=False, seg=seg_n)  # palm core
	for i, (lat, lengths) in enumerate(FINGERS):
		kn = add(w, mul(f, (3.0 - 0.18 * abs(lat)) * k), mul(s, lat * (0.62 if palm else 0.72) * k), mul(n, (-0.12 if palm else -0.25) * k))
		if not palm:  # the ground hand's flat palm pad stands in for the metacarpals
			seg(p, add(w, mul(s, lat * 0.3 * k)), kn, 0.42 * k, PALE, seg=seg_n, subdiv=sub, taper=0.9)  # metacarpal, knuckle
		if palm:  # a round finger root, so the base blends into the palm instead of showing a cut edge
			rr = 2 * (0.37 - 0.03 * abs(lat)) * k
			p.append(("ball", (rr, rr, rr), kn, PALE, {"subdiv": sub, "smooth": True}))
		sp = math.radians(lat * 6)
		a, c, r = kn, 0.0, (0.37 - 0.03 * abs(lat)) * k
		cf = curl * (0.55, 0.8, 1.0, 1.35)[i]  # index straightest, little finger most curled
		for j, ln in enumerate(lengths):
			c += math.radians(cf * (0.5 if j == 0 else 1.0))
			d = norm(add(mul(f, math.cos(c) * math.cos(sp)), mul(s, math.cos(c) * math.sin(sp)), mul(n, math.sin(c))))
			b = add(a, mul(d, ln * k))
			seg(p, a, b, r, PALE, seg=seg_n, subdiv=sub, taper=0.8)
			a, r = b, r * 0.8
		tips.append(a)
	a = add(w, mul(f, 0.5 * k), mul(s, -0.75 * k))
	r = 0.46 * k
	for d, ln in (
		(add(mul(f, 0.5), mul(s, -0.8), mul(n, 0.35)), 1.5),
		(add(mul(f, 0.8), mul(s, -0.3), mul(n, 0.5)), 1.15),
		(add(mul(f, 0.6), mul(s, 0.1), mul(n, 0.8)), 0.9),
	):
		b = add(a, mul(norm(d), ln * k))
		seg(p, a, b, r, PALE, seg=seg_n, subdiv=sub, taper=0.84)
		a, r = b, r * 0.84
	return tips


def ground_hand(curl):
	"""Hero: a giant pale hand rising out of the plain, palm toward the road (-Z): a forearm swelling out of a heaped,
	rocky mound and narrowing to a soft oval wrist, a padded palm with knuckle bumps, and long separated tapering
	fingers, each curled a little more than the last. One skin tone, no bands."""
	p = [("cone", (30, 5, 26), (0, 1.5, 0), MOUND, {"seg": 14, "taper": 0.4})]
	for i in range(6):
		ang = i * 1.05 + 0.3
		p.append(("ball", (4.5 + i % 3, 2.4, 3.8), (math.cos(ang) * 9, 1.2, math.sin(ang) * 8), "5A4C3A", {"subdiv": 1}))
	w = (0, 20.3, -0.4)
	seg(p, (0, -3, 0), (0, 18.0, -0.35), 3.9, PALE, ball=False, seg=24, taper=0.68)  # one tapering forearm: no joint lines
	p.append(("ball", (7.7, 13, 7.0), (0, 7.5, 0.1), PALE, {"subdiv": 3, "smooth": True}))  # forearm muscle swell, low
	p.append(("ball", (5.4, 6.2, 5.4), (0, 18.0, -0.35), PALE, {"subdiv": 3, "smooth": True}))  # wrist: widest exactly at the forearm's end, so no ledge
	f = norm((0, 1, -0.12))
	hand(p, w, f, (1, 0, 0), norm((0, 0.12, -1)), 3.1, curl, seg_n=12, sub=2, palm=True)
	return p


def float_arm(bend, wrist, curl):
	"""A long pale arm hanging in the darkness (darkness_devil.jpg): rounded shoulder end, long upper arm, a clear elbow
	knob bent `bend` degrees, long forearm, wrist turned `wrist` degrees, a big slender hand (about a third of the
	forearm) with curled separated fingers. Built lying along +X (shoulder at the origin end); the build hangs it near
	vertical, hand down. Centred on its middle so the reach is the same either way."""
	p = []
	sh, el = (0, 0, 0), (17, 0, 0)
	b = math.radians(bend)
	wr = add(el, (15 * math.cos(b), 0, -15 * math.sin(b)))
	wb = b + math.radians(wrist)
	f = (math.cos(wb), 0, -math.sin(wb))
	s = (math.sin(wb), 0, math.cos(wb))
	p.append(("ball", (4.0, 4.0, 4.0), sh, PALE, {"subdiv": 2, "smooth": True}))  # rounded shoulder end, no cut
	seg(p, sh, el, 1.95, PALE, ball=False, subdiv=2, taper=0.85)
	p.append(("ball", (3.9, 3.9, 3.9) if bend > 30 else (3.3, 3.3, 3.3), el, PALE, {"subdiv": 2, "smooth": True}))  # elbow knob
	seg(p, el, wr, 1.6, PALE, subdiv=2, taper=0.75)
	tips = hand(p, wr, f, s, (0, -1, 0), 1.8, curl)
	pts = [sh, el, wr] + tips
	c = mul(add(*pts), -1.0 / len(pts))
	return glow(shift(p, c), 0.2, (PALE,))


# --- astronaut ---
def astronaut():
	"""A kneeling 1960s astronaut praying, facing -Z, as the Hell arc draws them (astronauts_row.jpg): puffy cool-white
	suit with ribbed knee and elbow bands, a round bubble helmet with a medium white rim round a glossy black visor that
	fills most of the face (highlight top-left), a boxed lamp with three lights on each side of the helmet, chest
	control box with hoses, a big life-support backpack. Kneeling with the weight back: knees down, thighs slanted
	about 40 degrees, hips sat back over the heels. Elbows out, forearms rising to wide mitten gloves (finger grooves,
	flared gauntlet, dark wrist ring) pressed palm to palm before the lower visor. Sits on a flat dark shadow patch.
	No patch emblem or text."""
	lo, up = [], []
	r2 = {"subdiv": 2, "smooth": True}
	r3 = {"subdiv": 3, "smooth": True}
	HY, HZ = 2.65, 1.15  # the hip, sat back over the heels
	UP = (0, HY - 3.2, HZ - 0.1)  # the upper body, built upright over (0, 3.2, 0.1), moved back and down onto the hip
	for sx in (-1, 1):
		x = sx * 0.85
		seg(lo, (x, 0.62, -0.45), (x, 0.55, 1.75), 0.64, SUIT2, ball=False, seg=10, taper=0.86)  # shin on the ground
		lo.append(("ball", (1.2, 1.25, 1.7), (x, 0.72, 2.2), BOOT, {"subdiv": 2}))  # boot, toes down behind
		B(lo, (1.05, 0.3, 1.5), (x, 0.24, 2.25), GREY)  # sole
		lo.append(("ball", (1.55, 1.5, 1.55), (x, 0.72, -0.45), SUIT, r2))  # knee
		lo.append(("cyl", (1.5, 0.2, 1.5), (x, 1.15, -0.25), SUIT2, {"seg": 10, "rot": (40, 0, 0)}))  # ribbed knee band
		seg(lo, (x, 0.9, -0.4), (x * 1.05, HY, HZ), 0.74, SUIT, ball=False, seg=10, taper=1.1)  # thigh, slanted back to the hip
		up.append(("ball", (1.95, 1.8, 1.95), (sx * 1.78, 6.15, 0.25), SUIT, r2))  # shoulder
		el = (sx * 2.05, 4.8, -0.9)
		seg(up, (sx * 1.9, 6.0, 0.15), el, 0.64, SUIT, ball=False, seg=10, taper=0.95)  # upper arm, elbow out
		up.append(("ball", (1.25, 1.25, 1.25), el, SUIT, r2))  # elbow
		wr = (sx * 0.4, 6.35, -2.05)
		d = norm(add(wr, mul(el, -1)))
		c = add(mul(el, 0.67), mul(wr, 0.33))
		seg(up, el, add(wr, mul(d, -0.5)), 0.56, SUIT, ball=False, seg=10, taper=0.9)  # forearm rising to the hands
		seg(up, add(c, mul(d, -0.08)), add(c, mul(d, 0.08)), 0.6, SUIT2, ball=False, seg=10)  # ribbed elbow band
		seg(up, add(wr, mul(d, -0.55)), add(wr, mul(d, -0.38)), 0.55, WRIST, ball=False, seg=10)  # dark wrist ring
		seg(up, add(wr, mul(d, 0.15)), add(wr, mul(d, -0.4)), 0.42, GLOVE, ball=False, seg=10, taper=1.5)  # flared gauntlet cuff
		# The mitten: a wide palm pressed flat to the other at x = 0, the four fingers held together pointing up
		# The joined mittens cover only the lower-middle third of the visor: palm to palm at x = 0, about a third of the
		# visor wide together, fingertips at the visor's mid-height
		up.append(("ball", (0.5, 1.35, 1.15), (sx * 0.25, 6.95, -2.3), GLOVE, r2))  # palm
		up.append(("cyl", (0.46, 0.85, 1.05), (sx * 0.23, 7.75, -2.32), GLOVE, {"seg": 12, "smooth": True}))  # the four fingers held together
		up.append(("ball", (0.46, 0.5, 1.05), (sx * 0.23, 8.2, -2.32), GLOVE, r2))  # their blunt rounded tips
		for z in (-2.62, -2.32, -2.02):  # finger-gap grooves on the back of the mitten
			B(up, (0.08, 0.85, 0.06), (sx * 0.46, 7.75, z), "B4B8C0")
		seg(up, (sx * 0.5, 6.7, -1.95), (sx * 0.32, 7.35, -1.85), 0.16, GLOVE, ball=False, seg=8)  # thumb along the inside
		# Helmet side lamp: an upright box, three lights looking forward
		B(up, (0.45, 1.2, 0.8), (sx * 1.76, 8.35, -0.2), LAMP)
		for i in range(3):
			B(up, (0.24, 0.24, 0.1), (sx * 1.76, 7.98 + i * 0.37, -0.62), "FFF2C8", emit=0.8)
		up.append(("cyl", (0.42, 0.3, 0.42), (sx * 0.9, 4.55, -1.0), ("3A5AA8", "B03A3A")[sx > 0], {"seg": 8, "rot": (90, 0, 0), "metal": 0.5}))  # hose connector
	up.append(("ball", (3.1, 1.9, 2.4), (0, 3.45, 0.2), SUIT2, {"subdiv": 1, "smooth": True}))  # hips
	up.append(("ball", (3.6, 3.7, 2.8), (0, 5.15, 0.25), SUIT, r2))  # puffy torso
	up.append(("cyl", (3.25, 0.25, 2.6), (0, 4.2, 0.25), SUIT2, {"seg": 10}))  # waist band
	B(up, (1.7, 1.0, 0.45), (0, 4.95, -1.08), CHEST)  # chest control box
	for i, c in enumerate(("C04040", "40A040", "D0D0D0")):
		B(up, (0.22, 0.22, 0.1), (-0.5 + i * 0.5, 5.05, -1.33), c, emit=0.5)
	B(up, (3.0, 3.6, 1.5), (0, 5.4, 2.1), PACK)  # life-support backpack
	up.append(("cyl", (1.5, 3.0, 1.5), (0, 7.2, 2.1), PACK, {"seg": 10, "rot": (0, 0, 90), "smooth": True}))  # its rounded top
	up.append(("cyl", (2.5, 0.5, 2.5), (0, 7.05, 0.2), "A8B4C8", {"seg": 12, "metal": 0.6, "rough": 0.35}))  # neck ring
	up.append(("ball", (3.6, 3.5, 3.6), (0, 8.45, 0.1), SUIT, r3))  # round bubble helmet
	up.append(("cyl", (2.85, 0.32, 2.75), (0, 8.4, -1.3), RIM, {"seg": 20, "rot": (90, 0, 0), "smooth": True}))  # medium visor rim
	up.append(("ball", (2.75, 2.6, 1.9), (0, 8.4, -0.85), VISOR, {"subdiv": 3, "smooth": True, "rough": 0.06, "metal": 0.3}))  # glossy black visor
	up.append(("ball", (0.85, 0.42, 0.16), (0.55, 9.05, -1.66), "FFFFFF", {"subdiv": 1, "smooth": True, "emit": 1.0, "rot": (-30, 0, 25)}))  # highlight, top-left
	p = shift(lo + shift(up, UP), (0, MOUND_H, 0))
	p.append(("cyl", (11.0, 0.3, 9.0), (0, 0.05, 0.4), TUFT, {"seg": 14}))  # flat dark shadow patch on the plain
	return glow(p, 0.35, (SUIT, SUIT2, GLOVE, BOOT, PACK, LAMP, CHEST, RIM, "A8B4C8", "C8CCD2"))


# --- the darkness ---
def abyss():
	"""Hero: the darkness the aisle runs into. One vast matte-black dome (unit radius, 1.25 tall; scaled to the room the
	loop leaves) standing on the plain beyond the finish: from every approach it is an edgeless black field that takes
	over the sky above a bright strip of plain, with no corner, roof line or wall edge anywhere on it."""
	return [("ball", (2 * WIDE, 2.5, 2), (0, 0, 0), BLACK, {"subdiv": 4, "smooth": True})]


def dark_gate():
	"""The landmark: one giant panel door standing open at the end of the road (placed at x2 scale, front -Z toward the
	runner). Posts on plinths, a moulded lintel, the slab swung open away from the runner with raised panels, round knobs
	on backplates and hinges; a black void fills the opening inside the frame depth (the build stands the gate past the
	road's end so the void is 24+ off the line), the black dome beyond it."""
	W, H = 54, 110
	p = [
		("box", (8, H + 4, 10), (-W / 2 - 4, (H - 4) / 2, 0), FRAMEC),
		("box", (8, H + 4, 10), (W / 2 + 4, (H - 4) / 2, 0), FRAMEC),
		("box", (W + 16, 10, 10), (0, H + 5, 0), FRAMEC),
		("box", (W + 24, 4, 13), (0, H + 12, 0), "4A3020"),
		("box", (W + 30, 3, 15), (0, H + 15.5, 0), FRAMEC),
	]
	for sx in (-1, 1):
		x = sx * (W / 2 + 4)
		B(p, (12, 6, 14), (x, 2, 0), "3A2A1A")  # plinth
		B(p, (11, 5, 13), (x, H - 4, 0), "4A3020")  # capital
		B(p, (2, H - 12, 11), (x - sx * 2.5, H / 2, 0), "4A3020")  # fluting strip
	B(p, (W + 1, H + 1, 3.5), (0, (H + 1) / 2 - 0.5, 2.75), BLACK)  # the void, fitted inside the frame depth behind the opening
	ang = 115  # swung open toward the runner (-Z), off to the side: the slab reads from the aisle and from the side
	a = math.radians(ang)
	hx = -W / 2

	def put(size, x, y, z, col, shape="box", **o):
		p.append((shape, size, (hx + math.cos(a) * x + math.sin(a) * z, y, -math.sin(a) * x + math.cos(a) * z), col, dict(o, rot=(0, ang, 0))))

	put((W, H, 3), W / 2, H / 2, 0, DOOR)
	ph = (H - 20) / 3 - 4
	for side in (-1, 1):
		for ci in range(2):
			for row in range(3):
				y = 10 + ph / 2 + row * (ph + 4)
				put((W / 2 - 8, ph, 1.2), W / 4 + ci * W / 2, y, side * 1.8, DOOR2)
				put((W / 2 - 14, ph - 6, 0.8), W / 4 + ci * W / 2, y, side * 2.6, DOOR)
		put((4.5, 9, 0.8), W - 6, H / 2, side * 1.9, KNOB, metal=1, rough=0.3)  # backplate
		put((4.4, 4.4, 3.4), W - 6, H / 2, side * 3.6, KNOB, shape="ball", subdiv=2, smooth=True, metal=1, rough=0.3)  # round knob
	for y in (12, H / 2, H - 12):
		put((3, 10, 4), 1.5, y, 0, "3A3030", metal=0.8)  # hinges
	return p


def tufts():
	"""A wide patch of dark grass clumps on the pale plain (32 clumps of blades filling a disc 12 studs across), two pale
	flowers."""
	p = []
	for t in range(32):
		r, th = 6.0 * math.sqrt((t + 0.5) / 32), t * 2.39996  # sunflower spread: fills the disc evenly, no ring
		tx, tz, h = math.cos(th) * r, math.sin(th) * r, 0.65 + 0.35 * ((t * 0.37) % 1.0)
		for i in range(4):
			ang = i * 1.57 + t
			ht = 2.2 * h + (i % 2) * 0.5
			p.append(("cone", (0.6, ht, 0.6), (tx + math.cos(ang) * 0.35, ht / 2, tz + math.sin(ang) * 0.35), TUFT if i % 2 else TUFT2, {"seg": 4, "rot": (math.cos(ang) * 24, 0, math.sin(ang) * 24)}))
	for i, c in enumerate(("F2E8D8", "E8C8D0")):
		p.append(("ball", (0.5, 0.4, 0.5), (0.8 - i * 2.4, 2.0, 0.6 + i * 0.4), c, {"subdiv": 1}))
	return p


def hexcol(h):
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], 1.0)


def ground_shader(k, mat, ox, oz, near, far):
	"""The plain reaches the horizon: the ground fades from the plain into the sky's horizon colour (unlit), measured
	from the track centre, so the edge never shows and the far plain melts into the haze."""
	nt = mat.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	dist = nt.nodes.new("ShaderNodeVectorMath")
	dist.operation = "DISTANCE"
	dist.inputs[1].default_value = (ox, oz, 0.0)
	nt.links.new(geo.outputs["Position"], dist.inputs[0])
	rng = nt.nodes.new("ShaderNodeMapRange")
	rng.inputs["From Min"].default_value = near
	rng.inputs["From Max"].default_value = far
	nt.links.new(dist.outputs["Value"], rng.inputs["Value"])
	emit = nt.nodes.new("ShaderNodeEmission")
	emit.inputs["Color"].default_value = hexcol(HAZE)
	emit.inputs["Strength"].default_value = 1.0
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(rng.outputs["Result"], mix.inputs["Fac"])
	nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
	nt.links.new(emit.outputs["Emission"], mix.inputs[2])
	nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def dark_under(mat, cx, cy, r0, r1):
	"""The plain turns black toward the dome: pure black inside r0 of (cx, cy) (Blender XY), the normal ground beyond r1,
	so the darkness rises out of the plain with no hard base edge."""
	nt = mat.node_tree
	out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
	prev = out.inputs["Surface"].links[0].from_socket
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	dist = nt.nodes.new("ShaderNodeVectorMath")
	dist.operation = "DISTANCE"
	dist.inputs[1].default_value = (cx, cy, 0.0)
	nt.links.new(geo.outputs["Position"], dist.inputs[0])
	rng = nt.nodes.new("ShaderNodeMapRange")
	rng.interpolation_type = "SMOOTHSTEP"
	rng.inputs["From Min"].default_value = r0
	rng.inputs["From Max"].default_value = r1
	rng.inputs["To Min"].default_value = 1.0  # black at r0, fading out to the plain at r1
	rng.inputs["To Max"].default_value = 0.0
	nt.links.new(dist.outputs["Value"], rng.inputs["Value"])
	black = nt.nodes.new("ShaderNodeEmission")
	black.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(rng.outputs["Result"], mix.inputs["Fac"])
	nt.links.new(prev, mix.inputs[1])
	nt.links.new(black.outputs["Emission"], mix.inputs[2])
	nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def flat_caps(ob):
	"""Cylinder end caps shaded flat, so smooth limbs show no dark band where a cap meets the side (or a joint)."""
	for poly in ob.data.polygons:
		if len(poly.vertices) > 4:
			poly.use_smooth = False


def fill_light(k):
	"""A soft shadowless white fill from the other side of the sun: whites stay white under the red sky, and every
	model reads from the front as well as from the runner's side (Roblox: ambient / OutdoorAmbient)."""
	import bpy

	sun = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
	sun.data.energy = 2.0
	sun.data.color = (0.92, 0.95, 1.0)  # cool white: suits, hands and arms stay stark white, not peach
	sun.data.use_shadow = False
	sun.rotation_euler = (math.radians(55), 0, math.radians(195))
	k.col.objects.link(sun)


def matte(mat):
	b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Specular IOR Level"].default_value = 0.0  # pure black: no sky sheen


def scatter_ring(k, count, names, rmin, rmax, scale, y=-1.0):
	"""Props spread over the far plain between radius rmin and rmax from the track centre (rolling hills to the edge)."""
	c = (k.lo + k.hi) / 2
	for _ in range(count):
		ang = k.rng.uniform(0, math.tau)
		r = math.sqrt(k.rng.uniform(rmin * rmin, rmax * rmax))
		k.place(k.rng.choice(names), (c.x + math.cos(ang) * r, y, c.z + math.sin(ang) * r), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))


# Sky doors: strict rows parallel to the road, (height, scale, offsets); more rows higher up
SKY_TIERS = (
	(300, 5.0, (-640, -440, 440, 640)),
	(470, 6.0, (-820, -620, -420, -220, 220, 420, 620, 820)),
	(680, 7.0, (-900, -700, -500, -300, -100, 100, 300, 500, 700, 900)),
)


def build(k):
	k.prop("DoorClosed", door())
	k.prop("DoorOpen", door(ajar=50))
	k.prop("SkyDoor", sky_door())
	k.prop("Hand", glow(ground_hand(28), 0.15, (PALE,)))
	k.prop("ArmA", float_arm(6, 8, 22))  # straight, hanging
	k.prop("ArmB", float_arm(85, -15, 34))  # bent at a clear elbow
	k.prop("Astronaut", astronaut())
	k.prop("DarkGate", dark_gate())
	k.prop("Abyss", abyss())
	k.prop("Grass", tufts())
	k.prop("Hill", [("ball", (2, 0.35, 2), (0, 0, 0), HILL, {"subdiv": 3, "smooth": True})])

	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	g = k.ground(GROUND, margin=24000, rough=1.0)
	ground_shader(k, g.data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)  # Blender XY: (x, -z)
	ground_shader(k, k.props["Hill"].data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)
	matte(k.props["Abyss"].data.materials[0])
	for name in ("Hand", "ArmA", "ArmB", "Astronaut"):
		flat_caps(k.props[name])
	fill_light(k)
	L = k.length
	dark = L - DARK_LEN
	doors = ["DoorClosed", "DoorClosed", "DoorOpen"]
	# Straight rows of identical doors standing on the plain, square to the road, two each side
	ground_along(k, 90, (-42, 42), doors, start=40, end=dark - 60, clear=0.8)
	ground_along(k, 90, (-88, 88), doors, start=85, end=dark - 60, scale=(1.25, 1.25), clear=0.8)
	# Dark grass clumps across the pale plain; rolling hills out to the horizon
	ground_along(k, GRASS_EVERY, (-56, 56, -96, 96, -140, 140), ["Grass"], jitter=6, start=20, end=L - 60, spin=True, scale=(2.4, 3.2), clear=0.75)  # patch edge 24+ off the road
	k.field(50, ["Hill"], clearance=260, margin=800, scale=(80, 160))
	scatter_ring(k, 90, ["Hill"], span * 0.75, span * 2.4, (250, 650))
	# Giant pale hands rising out of the plain: whole hands in view beside the road, colossal ones far out
	ground_along(k, 650, (-180, 180), ["Hand"], jitter=40, start=400, end=dark - 300, scale=(1.6, 2.0))
	k.field(16, ["Hand"], clearance=900, margin=700, scale=(5.0, 6.5))
	# The darkness: one vast black dome beyond the finish, as big as the loop allows (it clears every road stretch by 50)
	p, right, t = k.at(L)
	R = 2600.0

	def clear(ctr, R):
		for w in k.wps:
			v = Vector((w.x - ctr.x, 0, w.z - ctr.z))
			if (v.dot(right) / (R * WIDE + 50)) ** 2 + (v.dot(t) / (R + 50)) ** 2 <= 1.0:
				return False
		return True

	while True:
		ctr = p + t * (R + 60)
		if R <= 800 or clear(ctr, R):
			break
		R -= 50
	print("ABYSS radius", R)
	ob = k.place("Abyss", (ctr.x, -1.0, ctr.z), facing((t.x, t.z)), R)
	ob.visible_shadow = False
	for mat in (g.data.materials[0], k.props["Hill"].data.materials[0]):
		dark_under(mat, ctr.x, -ctr.z, R + 40, R + 380)  # black only past the last astronaut (Blender XY: (x, -z))
	# Doors fill the sky in strict rows following the road, each face-on to the road's heading; none hang before the dark
	d = 60.0
	while d < dark - 200:
		p, right, t2 = k.at(d)
		yaw = facing((t2.x, t2.z))
		for y, sc, offs in SKY_TIERS:
			for o in offs:
				q = p + right * o
				if (Vector((q.x, 0, q.z)) - Vector((ctr.x, 0, ctr.z))).length < R * WIDE + 700:
					continue  # would hang in front of the black dome
				k.place("SkyDoor", (q.x, y, q.z), yaw, sc).visible_shadow = False  # no door shadows on the plain
		d += 250
	# Long pale arms hanging in the dark, half straight and half bent: an even jittered grid over the last stretch, each
	# cell an arm-length apart; a few more over the open plain. None within 15 studs of a giant hand.
	hands = [(o.location.x, o.location.y, o.scale.x) for o in k.col.objects if o.data is k.props["Hand"].data]

	def arm(d, off, y, sc):
		pos, yaw = k.beside(d, off)
		if any(math.hypot(pos[0] - hx, -pos[2] - hy) < 22 * hs + 30 * sc + 15 for hx, hy, hs in hands):
			return False  # Blender XY is (x, -z); hand bound ~22 x scale, arm half-length ~30 x scale
		ob = k.place(k.rng.choice(("ArmA", "ArmB")), (pos[0], y, pos[2]), yaw + k.rng.uniform(0, math.tau), sc)
		ob.rotation_euler = (math.radians(k.rng.uniform(-8, 8)), math.radians(90 + k.rng.uniform(-10, 10)), ob.rotation_euler[2])  # hanging, hand down
		return True

	d, row = dark + 80, 0
	while d < L + 200:
		for o in ARM_COLS:
			off = o + (55 if row % 2 else 0) * (1 if o > 0 else -1)
			arm(d + k.rng.uniform(-20, 20), off + k.rng.uniform(-20, 20), k.rng.uniform(95, 230), k.rng.uniform(1.9, 2.3))
		d, row = d + 120, row + 1
	dd, n = 300.0, 0
	while dd < dark - 200 and n < 100:
		off = (1 if n % 2 else -1) * k.rng.uniform(100, 210)
		pos, _ = k.beside(dd, off)
		if k.clear_of_road(pos[0], pos[2], 80) and arm(dd, off, k.rng.uniform(62, 90), k.rng.uniform(1.3, 1.5)):
			n += 1
		dd += 110
	# Two rows of kneeling astronauts praying on dark shadow patches, side-on down the aisle: each turned 45 degrees from
	# the road toward the gate, so the visor and the big backpack both read from the runner camera
	ang = math.radians(45)
	d = L - 650
	while d < L - 250:
		for sx in (-1, 1):
			pos, _ = k.beside(d, sx * 34)
			_, right, t = k.at(d)
			v = (-sx * right.x * math.cos(ang) + t.x * math.sin(ang), -sx * right.z * math.cos(ang) + t.z * math.sin(ang))
			k.place("Astronaut", (pos[0], -1.0, pos[2]), facing(v), 1.5)
		d += 14
	p, right, t = k.at(L)
	q = p + t * 26  # past the road's end: frame face 16 studs out, the void 28+
	k.place("DarkGate", (q.x, p.y - 1.0, q.z), facing((-t.x, -t.z)), 2.0)  # x2, front toward the runner
	k.sky([(0.0, HAZE), (0.06, "F0602E"), (0.22, "C02018"), (0.55, "820A12"), (1.0, "3A0208")], strength=1.0, sun=(2.6, "FFEEDD", 40, 15))
