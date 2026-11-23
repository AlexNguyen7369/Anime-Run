"""World 2 Track 10: Hell Gate (Saw Man). The devils' Hell from the Hell arc, built to read 1-1 with the source (refs and
landmark list: docs/world2_refs/HellGate.md):
- a wide pale plain dotted with dark grass clumps, low hills, under a red-orange sky;
- countless identical doors: straight rows of free-standing panel doors beside the road, and strict rows of doors
  hanging in the sky, every one face-on to the road, denser higher up;
- giant pale hands with long separated fingers rising out of the plain;
- the last stretch runs into the darkness: a pitch-black wall and sky (the Abyss) closes over the road, long thin pale
  arms bent at the elbow float in it at every angle, and two rows of kneeling astronauts pray toward it with their
  palms pressed together before their visors (whole figures, no gore, no mission patch);
- the landmark: one giant door standing open over the road, the door the darkness came through, black beyond it.
No symbols or text (design doc 5). The Darkness Devil itself is not modelled (a character): arms and hands only.
Everything in-house, parts only. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

GROUND, HILL, MOUND = "B8AA8C", "8E8262", "6A5A44"
TUFT, TUFT2 = "262C16", "3A4222"
PALE, PALE2 = "F4ECE4", "E2D6CA"
DOOR, DOOR2, FRAMEC, KNOB = "8A5A3A", "74482C", "5A3A26", "C8A040"
SUIT, SUIT2, GREY, VISOR = "FAFAF8", "DCDCD8", "8E8E8A", "08080C"
BLACK = "000000"
HAZE = "FF8A4A"  # the horizon colour: the far plain fades into it
DARK_LEN = 1550  # the Abyss closes over the last 1550 studs (the straight final stretch)


# The darkness finale, 700 and 330 studs before the finish (runner lane); build_track renders these too
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
		p.append(("ball", (2 * r, 2 * r, 2 * r), b, col, {"subdiv": sub, "smooth": True}))


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

	def put(size, x, y, z, col, **o):
		cx = -w / 2 + math.cos(a) * x + math.sin(a) * z
		cz = -math.sin(a) * x + math.cos(a) * z
		p.append(("box", size, (cx, y, cz), col, dict(o, rot=(0, ajar, 0))))

	put((w, h, 0.6), w / 2, h / 2 + 0.8, 0, DOOR)
	ph = (h - 4) / 3 - 1
	for side in (-1, 1):
		for col_i in range(2):
			for row in range(3):
				put((w / 2 - 1.6, ph, 0.3), w / 4 + col_i * w / 2, 2.6 + ph / 2 + row * (ph + 1), side * 0.4, DOOR2)
		put((0.9, 1.6, 0.2), w - 1.2, h / 2, side * 0.5, KNOB, metal=1, rough=0.3)
		put((0.8, 0.8, 0.8), w - 1.2, h / 2, side * 0.9, KNOB, metal=1, rough=0.3)
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
	B(p, (10, 1, 1.4), (0, 17.5, 0), FRAMEC)
	B(p, (8, 16, 0.6), (0, 8.5, 0), DOOR)
	for z in (-0.4, 0.4):
		for x in (-2, 2):
			for y in (4.5, 11.5):
				B(p, (3, 5.5, 0.2), (x, y, z), DOOR2)
		B(p, (0.7, 0.7, 0.4), (3, 8, z * 1.8), KNOB, metal=1, rough=0.3)
	return p


# --- hands and arms ---
FINGERS = ((-1.35, (1.9, 1.25, 0.9)), (-0.45, (2.15, 1.4, 1.0)), (0.45, (2.0, 1.3, 0.95)), (1.35, (1.55, 1.05, 0.8)))


def hand(p, w, f, s, n, k, curl, seg_n=8, sub=1):
	"""A slender open hand from wrist point w: f toward the fingers, s across the palm (thumb on -s), n the palm side
	the fingers curl toward. Palm = a fan of metacarpals, four separated fingers of three segments each (gaps between
	them, spreading apart), a three-segment thumb. Returns the fingertip points."""
	tips = []
	seg(p, w, add(w, mul(f, 2.4 * k)), 0.8 * k, PALE2, ball=False, seg=seg_n)  # palm core
	for lat, lengths in FINGERS:
		kn = add(w, mul(f, (3.0 - 0.18 * abs(lat)) * k), mul(s, lat * 0.82 * k))
		seg(p, add(w, mul(s, lat * 0.3 * k)), kn, 0.46 * k, PALE2, seg=seg_n, subdiv=sub)  # metacarpal + knuckle
		sp = math.radians(lat * 6)
		a, c = kn, 0.0
		for j, ln in enumerate(lengths):
			c += math.radians(curl * (0.5 if j == 0 else 1.0))
			d = norm(add(mul(f, math.cos(c) * math.cos(sp)), mul(s, math.cos(c) * math.sin(sp)), mul(n, math.sin(c))))
			b = add(a, mul(d, ln * k))
			seg(p, a, b, (0.32 - 0.035 * j) * k, PALE, seg=seg_n, subdiv=sub)
			a = b
		tips.append(a)
	a = add(w, mul(f, 0.5 * k), mul(s, -0.7 * k))
	for d, ln, r in (
		(add(mul(f, 0.5), mul(s, -0.8), mul(n, 0.35)), 1.5, 0.42),
		(add(mul(f, 0.8), mul(s, -0.3), mul(n, 0.5)), 1.15, 0.36),
		(add(mul(f, 0.6), mul(s, 0.1), mul(n, 0.8)), 0.9, 0.3),
	):
		b = add(a, mul(norm(d), ln * k))
		seg(p, a, b, r * k, PALE, seg=seg_n, subdiv=sub)
		a = b
	return tips


def ground_hand(curl):
	"""Hero: a giant pale hand rising out of the plain, palm toward the road (-Z): short tapered forearm out of a heaped
	mound, rounded wrist, slender palm and long separated fingers with a gentle curl."""
	p = [
		("cone", (30, 5, 26), (0, 1.5, 0), MOUND, {"seg": 14, "taper": 0.4}),
		("cyl", (7.4, 22, 6.8), (0, 9, 0), PALE2, {"seg": 16, "taper": 0.78, "smooth": True}),
	]
	w = (0, 20.5, -0.4)
	p.append(("ball", (5.6, 4.4, 4.8), w, PALE2, {"subdiv": 2, "smooth": True}))
	f = norm((0, 1, -0.12))
	hand(p, w, f, (1, 0, 0), norm((0, 0.12, -1)), 3.1, curl, seg_n=12, sub=2)
	return p


def float_arm(bend, wrist, curl):
	"""A long thin pale arm floating free in the darkness: rounded shoulder end, upper arm, elbow bent `bend` degrees,
	forearm, wrist turned `wrist` degrees, slender hand with curled separated fingers. Lies in the horizontal plane;
	the instance is tilted in the build. Centred on its middle so the reach is the same in every direction."""
	p = []
	sh, el = (0, 0, 0), (13, 0, 0)
	b = math.radians(bend)
	wr = add(el, (11 * math.cos(b), 0, -11 * math.sin(b)))
	wb = b + math.radians(wrist)
	f = (math.cos(wb), 0, -math.sin(wb))
	s = (math.sin(wb), 0, math.cos(wb))
	p.append(("ball", (2.7, 2.7, 2.7), sh, PALE2, {"subdiv": 2, "smooth": True}))  # rounded shoulder end, no cut
	seg(p, sh, el, 1.25, PALE2, subdiv=2)
	seg(p, el, wr, 1.0, PALE, subdiv=2)
	tips = hand(p, wr, f, s, (0, -1, 0), 1.0, curl)
	pts = [sh, el, wr] + tips
	c = mul(add(*pts), -1.0 / len(pts))
	return glow(shift(p, c), 0.25, (PALE, PALE2))


# --- astronaut ---
def astronaut():
	"""A kneeling astronaut praying, facing -Z: white suit, round helmet with a centred dark visor and rim, lamp boxes
	on both sides of the helmet, big life-support backpack, gloved palms pressed together upright before the visor.
	No patch or emblem."""
	p = []
	for sx in (-1, 1):
		x = sx * 0.9
		seg(p, (x, 0.6, -0.5), (x, 0.6, 2.3), 0.62, SUIT2)  # shin flat on the ground
		B(p, (1.3, 1.5, 1.2), (x, 0.8, 2.8), GREY)  # boot, toes down behind
		B(p, (1.4, 0.3, 1.4), (x, 0.15, 2.8), "5A5A56")  # sole
		p.append(("ball", (1.5, 1.5, 1.5), (x, 0.7, -0.5), SUIT2, {"subdiv": 1, "smooth": True}))  # knee
		seg(p, (x, 0.7, -0.5), (x, 3.4, 0.0), 0.75, SUIT, ball=False)  # thigh, upright
		seg(p, (sx * 1.75, 6.0, 0.3), (sx * 1.5, 4.7, -1.2), 0.55, SUIT)  # upper arm down to the elbow
		seg(p, (sx * 1.5, 4.7, -1.2), (sx * 0.4, 6.5, -2.0), 0.5, SUIT)  # forearm up to the hands
		p.append(("cyl", (1.2, 0.35, 1.2), (sx * 0.42, 6.55, -2.0), GREY, {"seg": 8, "rot": (30, 0, -sx * 30)}))  # cuff
		B(p, (0.34, 1.3, 0.75), (sx * 0.17, 7.25, -2.05), "ECECE6")  # glove: palms flat together, upright
		B(p, (0.28, 0.5, 0.55), (sx * 0.15, 8.1, -1.95), "ECECE6")  # fingertips, just touching the visor
		B(p, (0.7, 1.6, 1.2), (sx * 1.72, 7.9, -0.15), "D6D6D0")  # helmet side lamp box
		for i in range(3):
			B(p, (0.2, 0.3, 0.3), (sx * 2.1, 7.4 + i * 0.5, -0.3), "FFF4D0", emit=0.5)  # lamp lenses
	B(p, (3.0, 1.4, 2.4), (0, 3.6, 0.2), SUIT2)  # hips
	p.append(("cyl", (3.0, 2.2, 2.4), (0, 4.8, 0.25), SUIT, {"seg": 12, "smooth": True}))  # waist
	B(p, (3.6, 2.0, 2.5), (0, 5.8, 0.25), SUIT)  # chest
	B(p, (1.6, 1.0, 0.35), (0, 5.4, -1.05), "B4B4AE")  # chest control box
	for i, c in enumerate(("C04040", "40A040", "4060C0")):
		B(p, (0.25, 0.25, 0.1), (-0.5 + i * 0.5, 5.45, -1.25), c, emit=0.6)
	B(p, (3.2, 4.0, 1.7), (0, 5.4, 2.3), SUIT2)  # life-support backpack
	B(p, (2.6, 0.5, 1.4), (0, 7.55, 2.3), GREY)  # pack top
	p.append(("cyl", (2.3, 0.6, 2.3), (0, 6.95, 0.2), "B4B4AE", {"seg": 12}))  # neck ring
	p.append(("ball", (3.3, 3.3, 3.3), (0, 8.2, 0.2), SUIT, {"subdiv": 2, "smooth": True}))  # helmet
	p.append(("cyl", (2.75, 0.3, 2.6), (0, 8.15, -1.05), "B4B4AE", {"seg": 16, "rot": (90, 0, 0)}))  # visor rim
	p.append(("ball", (2.45, 2.3, 1.1), (0, 8.15, -1.25), VISOR, {"subdiv": 2, "smooth": True, "rough": 0.08, "metal": 0.6}))
	return glow(p, 0.3, (SUIT, SUIT2, "ECECE6", "D6D6D0"))


# --- the darkness ---
def abyss():
	"""Hero: the darkness the aisle runs into. Matte black, local origin at the finish, -Z beyond it, the road running
	in along +Z. A curved back wall 900 studs high closes the view behind the gate, side walls run back along the last
	stretch, swelling up out of the ground 1750 studs out to full height 1000 studs out (the dark thickens toward the finish), a roof covers the last 1000 studs, and
	the ground beyond the threshold is black. Walls stand 640 studs out, the floor 30+ off the road's end."""
	R, H, T = 640, 900, 12
	p = []
	n = 12
	for i in range(n):  # back wall arc round (0, -100), from the left side to the right side
		th0, th1 = math.pi * (i / n - 0.5), math.pi * ((i + 1) / n - 0.5)
		th = (th0 + th1) / 2
		chord = 2 * R * math.sin((th1 - th0) / 2) + 8
		B(p, (chord, H, T), (R * math.sin(th), H / 2 - 2, -100 - R * math.cos(th)), BLACK, rot=(0, -math.degrees(th), 0))
	z0, z1, n = 1000, 1750, 6  # the dark swells up out of the plain along a quarter-ellipse shoulder
	hs = [H * math.sqrt(max(0.0, 1 - (i / n) ** 2)) for i in range(n + 1)]
	for sx in (-1, 1):
		B(p, (T, H, z0 + 110), (sx * R, H / 2 - 2, (z0 - 100) / 2), BLACK)  # full-height side walls
		for i in range(n):
			za, zb = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
			lo, hi = hs[i + 1], hs[i]
			if lo > 1:
				B(p, (T, lo, zb - za + 2), (sx * R, lo / 2 - 2, (za + zb) / 2), BLACK)
			p.append(("wedge", (T, hi - lo, zb - za + 2), (sx * R, lo + (hi - lo) / 2 - 2, (za + zb) / 2), BLACK, {"rot": (0, 180, 0)}))
	B(p, (2 * R + 20, T, 1760), (0, H, 135), BLACK)  # roof over the last 1000 studs and the back
	B(p, (2 * R, 0.3, 710), (0, 0.15, -385), BLACK)  # floor beyond the finish
	for sx in (-1, 1):
		B(p, (R - 40, 0.3, 560), (sx * (R + 40) / 2, 0.15, 250), BLACK)  # floor either side of the gate
	return p


def dark_gate():
	"""The landmark: one giant panel door standing open over the road. Posts sit 27+ studs from the centre line and run
	deep into the ground, the lintel is 110 studs up, the slab is swung open away from the runner with raised panels,
	knobs and hinges on both faces; the black Abyss fills the view through it."""
	W, H = 54, 110
	p = [
		("box", (8, H + 60, 10), (-W / 2 - 4, (H - 60) / 2, 0), FRAMEC),
		("box", (8, H + 60, 10), (W / 2 + 4, (H - 60) / 2, 0), FRAMEC),
		("box", (W + 16, 10, 10), (0, H + 5, 0), FRAMEC),
		("box", (W + 24, 4, 13), (0, H + 12, 0), "4A3020"),
		("box", (W + 30, 3, 15), (0, H + 15.5, 0), FRAMEC),
	]
	for sx in (-1, 1):
		x = sx * (W / 2 + 4)
		B(p, (12, 6, 14), (x, 2, 0), "3A2A1A")  # plinth
		B(p, (11, 5, 13), (x, H - 4, 0), "4A3020")  # capital
		B(p, (2, H - 12, 11), (x - sx * 2.5, H / 2, 0), "4A3020")  # fluting strip
	ang = 140
	a = math.radians(ang)
	hx = -W / 2

	def put(size, x, y, z, col, **o):
		p.append(("box", size, (hx + math.cos(a) * x + math.sin(a) * z, y, -math.sin(a) * x + math.cos(a) * z), col, dict(o, rot=(0, ang, 0))))

	put((W, H, 3), W / 2, H / 2, 0, DOOR)
	ph = (H - 20) / 3 - 4
	for side in (-1, 1):
		for ci in range(2):
			for row in range(3):
				y = 10 + ph / 2 + row * (ph + 4)
				put((W / 2 - 8, ph, 1.2), W / 4 + ci * W / 2, y, side * 1.8, DOOR2)
				put((W / 2 - 14, ph - 6, 0.8), W / 4 + ci * W / 2, y, side * 2.6, DOOR)
		put((5, 8, 1), W - 6, H / 2, side * 2.0, KNOB, metal=1, rough=0.3)
		put((4, 4, 4), W - 6, H / 2, side * 3.8, KNOB, metal=1, rough=0.3)
	for y in (12, H / 2, H - 12):
		put((3, 10, 4), 1.5, y, 0, "3A3030", metal=0.8)  # hinges
	return p


def tufts():
	"""A patch of dark grass clumps on the pale plain, with two small pale flowers."""
	p = []
	for t, (tx, tz, h) in enumerate(((0, 0, 1.0), (2.6, 1.2, 0.8), (-2.2, 1.6, 0.9), (1.0, -2.4, 0.75), (-1.8, -1.8, 0.85), (3.4, -1.0, 0.7), (-3.4, -0.2, 0.65))):
		for i in range(5):
			ang = i * 1.26 + t
			ht = 2.2 * h + (i % 2) * 0.5
			p.append(("cone", (0.55, ht, 0.55), (tx + math.cos(ang) * 0.35, ht / 2, tz + math.sin(ang) * 0.35), TUFT if i % 2 else TUFT2, {"seg": 4, "rot": (math.cos(ang) * 24, 0, math.sin(ang) * 24)}))
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
	k.prop("Hand", ground_hand(14))
	k.prop("ArmA", float_arm(70, 15, 22))
	k.prop("ArmB", float_arm(115, -20, 38))
	k.prop("Astronaut", astronaut())
	k.prop("DarkGate", dark_gate())
	k.prop("Abyss", abyss())
	k.prop("Grass", tufts())
	k.prop("Hill", [("ball", (2, 0.35, 2), (0, 0, 0), HILL, {"subdiv": 3, "smooth": True})])
	k.prop("Void", [("cyl", (120, 0.3, 120), (0, 0, 0), BLACK, {"seg": 24})])

	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	g = k.ground(GROUND, margin=24000, rough=1.0)
	ground_shader(k, g.data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)  # Blender XY: (x, -z)
	ground_shader(k, k.props["Hill"].data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)
	for name in ("Abyss", "Void"):
		matte(k.props[name].data.materials[0])
	L = k.length
	dark = L - DARK_LEN
	doors = ["DoorClosed", "DoorClosed", "DoorOpen"]
	# Straight rows of identical doors standing on the plain, square to the road, two each side
	ground_along(k, 90, (-42, 42), doors, start=40, end=dark - 60, clear=0.8)
	ground_along(k, 90, (-88, 88), doors, start=85, end=dark - 60, scale=(1.25, 1.25), clear=0.8)
	# Dark grass clumps across the pale plain; rolling hills out to the horizon
	ground_along(k, 150, (-40, 40, -70, 70, -135, 135), ["Grass"], jitter=6, start=20, end=L - 300, spin=True, scale=(2.0, 2.6), clear=0.7)  # patch edge 24+ off the road
	k.field(50, ["Hill"], clearance=260, margin=800, scale=(80, 160))
	scatter_ring(k, 90, ["Hill"], span * 0.75, span * 2.4, (250, 650))
	# Giant pale hands rising out of the plain: whole hands in view beside the road, colossal ones far out
	ground_along(k, 650, (-180, 180), ["Hand"], jitter=40, start=400, end=dark - 300, scale=(1.6, 2.0))
	k.field(16, ["Hand"], clearance=900, margin=700, scale=(5.0, 6.5))
	# Doors fill the sky in strict rows following the road, each face-on to the road's heading
	d = 60.0
	while d < dark - 200:
		p, right, t = k.at(d)
		yaw = facing((t.x, t.z))
		for y, sc, offs in SKY_TIERS:
			for o in offs:
				q = p + right * o
				k.place("SkyDoor", (q.x, y, q.z), yaw, sc).visible_shadow = False  # no door shadows on the plain
		d += 250
	# The darkness: the Abyss closes over the last stretch, its own shadow kept off the plain inside
	p, right, t = k.at(L)
	ob = k.place("Abyss", (p.x, -1.0, p.z), facing((t.x, t.z)))
	ob.visible_shadow = False
	# Black ground pooling along the last stretch, sparse at first, closing in toward the gate
	d = L - 1000
	while d < L - 40:
		f = (d - (L - 1000)) / 960
		for sx in (-1, 1):
			if k.rng.random() < 0.35 + 0.65 * f:
				sc = 0.5 + f * 1.1
				pos, _ = k.beside(d + k.rng.uniform(-20, 20), sx * (26 + 60 * sc + k.rng.uniform(0, 30)))
				k.place("Void", (pos[0], -0.85, pos[2]), k.rng.uniform(0, math.tau), sc)
		d += 90 - f * 40

	# Long pale arms floating in the dark at every angle: near ones 35-65 up beside the aisle, more deeper in
	def arm(d, off, y, sc):
		pos, yaw = k.beside(d, off)
		ob = k.place(k.rng.choice(("ArmA", "ArmB")), (pos[0], y, pos[2]), yaw + k.rng.uniform(0, math.tau), sc)
		ob.rotation_euler = (math.radians(k.rng.uniform(-55, 55)), math.radians(k.rng.uniform(-55, 55)), ob.rotation_euler[2])

	d = dark + 60
	while d < L + 250:
		for sx in (-1, 1):
			arm(d + k.rng.uniform(-10, 10), sx * k.rng.uniform(85, 160), k.rng.uniform(35, 65), k.rng.uniform(1.2, 1.6))
		d += 26
	for _ in range(110):
		arm(k.rng.uniform(dark + 100, L + 380), k.rng.choice((-1, 1)) * k.rng.uniform(170, 470), k.rng.uniform(40, 520), k.rng.uniform(1.8, 3.2))
	# Two rows of kneeling astronauts praying toward the darkness: each turned 40 degrees from the road toward the gate
	ang = math.radians(40)
	d = dark + 250
	while d < L - 250:
		for sx in (-1, 1):
			pos, _ = k.beside(d, sx * 30)
			_, right, t = k.at(d)
			v = (-sx * right.x * math.cos(ang) + t.x * math.sin(ang), -sx * right.z * math.cos(ang) + t.z * math.sin(ang))
			k.place("Astronaut", (pos[0], -1.0, pos[2]), facing(v), 1.5)
		d += 14
	pos, yaw = k.beside(L - 200, 0, 0.0)
	k.place("DarkGate", pos, yaw)
	k.sky([(0.0, HAZE), (0.06, "F0602E"), (0.22, "C02018"), (0.55, "820A12"), (1.0, "3A0208")], strength=1.0, sun=(2.6, "FFEEDD", 40, 15))
