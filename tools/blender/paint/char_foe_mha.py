# Target look for foe_mha (Shigaraky): long shaggy pale blue-grey hair, a pale severed-hand mask with red eyes staring between its
# fingers, more hands gripping head, neck, chest, back and arms, dry cracked skin, black long-sleeved V-neck, black trousers, red shoes.
# The worn hands have fingers because they are the costume; the figure's own hands stay plain blocks (design doc 5).
from atlas import shade
from mha_style3 import anime_eye, bake, block, core, gem, hand, head_faces, jitter, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#dcd6d2"
SKIN_D = "#a89ea2"
DEFAULT = "#1c1c22"
HAIR_COL = "#A9C1C8"
R = Ramps(
	hair=["#566c78", "#7f99a4", "#a9c1c8", "#c9dade", "#e6f1f2"],
	skin=["#7c747a", "#a49ca0", "#c8c0bf", "#dcd6d2"],
	# the worn hands: greyer and deader than his own skin
	dead=["#6f6a74", "#99939a", "#c4bebe", "#e4dfda"],
	cut=["#3a3238", "#544a50", "#6e6268", "#8a7e82"],
	shirt=["#08080c", "#16161c", "#2a2a34", "#44444f"],
	trousers=["#060608", "#121216", "#22222a", "#383842"],
	red=["#6a0c12", "#9c141c", "#c4202a", "#ea4a4a"],
	sole=["#8a8488", "#c4bec0", "#ebe6e4", "#ffffff"],
)
HAIR = {"colour": HAIR_COL, "locks": []}
PROPS = []


def _add(*vs):
	return tuple(sum(c) for c in zip(*vs))


def _mul(v, k):
	return tuple(c * k for c in v)


def _unit(v):
	n = sum(c * c for c in v) ** 0.5
	return tuple(c / n for c in v)


def _bar(k, part, name, pts, across, out, w, t, ramp="dead", end=0.75):
	"""A square-section bar along pts, blunt-tipped: a finger or wrist. across and out set its width and thickness axes;
	out may be a list, one per point, so a finger stays solid as it turns a corner."""
	across = _unit(across)
	outs = out if isinstance(out, list) else [out] * len(pts)
	rings = []
	for i, (p, o) in enumerate(zip(pts, outs)):
		q = end if i == len(pts) - 1 else 1.0
		rings.append([_add(p, _mul(across, a * w * q), _mul(_unit(o), b * t * q)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
	verts, faces, flat = k._loft(rings)
	return bake(k, k._mesh(name, part, verts, faces, flat, outline=0), ramp, a=0.56, b=0.4, g=0.04)


def _hand(k, part, tag, c, u, v, n, wrap=None, reach=(0.2, 0.16), spread=0.1, thumb=1, wrist=0.2):
	"""A worn hand lying on a surface. c palm centre, u across the knuckles, v towards the fingertips, n outward.
	wrap: direction the last finger joint turns to go round a corner; default curls down into the surface."""
	u, v, n = _unit(u), _unit(v), _unit(n)
	pu, pv, pn = 0.25, 0.2, 0.065
	# the palm: thicker at the heel, thin at the knuckles
	rings = [[_add(c, _mul(v, a * pv), _mul(u, b * pu * (0.92 if a < 0 else 1.0)), _mul(n, d * pn)) for b, d in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for a in (-1, 1)]
	verts, faces, flat = k._loft(rings)
	bake(k, k._mesh(f"H{tag}Palm", part, verts, faces, flat, outline=0), "dead", a=0.56, b=0.4, g=0.04)
	for i, off in enumerate((-0.75, -0.25, 0.25, 0.75)):
		base = _add(c, _mul(v, pv * 0.8), _mul(u, off * pu), _mul(n, 0.005))
		fan = _add(v, _mul(u, off * spread))
		mid = _add(base, _mul(fan, reach[0]), _mul(n, 0.02))
		tip = _add(mid, _mul(_unit(wrap), reach[1])) if wrap else _add(mid, _mul(fan, reach[1]), _mul(n, -0.03))
		_bar(k, part, f"H{tag}F{i}", (base, mid, tip), u, [n, _add(n, v), v] if wrap else n, 0.05, 0.055)
	if thumb:
		base = _add(c, _mul(v, -pv * 0.3), _mul(u, thumb * pu * 0.9))
		tip = _add(base, _mul(u, thumb * 0.2), _mul(v, 0.12))
		_bar(k, part, f"H{tag}Thumb", (base, tip), v, n, 0.055, 0.055)
	# the wrist, ending in a grey cut
	if wrist:
		w0 = _add(c, _mul(v, -pv * 0.9))
		w1 = _add(w0, _mul(v, -wrist))
		_bar(k, part, f"H{tag}Wrist", (w0, w1), u, n, 0.17, 0.07, end=1.0)
		_bar(k, part, f"H{tag}Cut", (w1, _add(w1, _mul(v, -0.012))), u, n, 0.15, 0.055, ramp="cut", end=1.0)


def _mask(k):
	"""The hand on the face: palm over nose and mouth, fingers up the forehead, wrist under the chin; eyes show in the two gaps."""
	h = "Head"
	y = -0.86
	# narrow at the heel, broad at the knuckles, so it reads as a hand and not a cloth mask
	block(k, h, "MaskPalm", 0, y, 4.54, 4.04, 0.58, 0.06, "dead", ch=0.03, flare=-0.2, corner=0.2, a=0.56, b=0.34, g=0.06)
	for i, x in enumerate((-0.47, -0.15, 0.15, 0.47)):
		block(k, h, f"MaskKnuckle{i}", x, y - 0.05, 4.56, 4.42, 0.115, 0.045, "dead", ch=0.02, a=0.64, b=0.34)
	for i, (x0, x1, z1) in enumerate(((-0.15, -0.16, 5.54), (0.15, 0.17, 5.6))):
		_bar(k, h, f"MaskIn{i}", ((x0, y - 0.02, 4.5), (x0 * 1.02, y - 0.04, 5.02), (x1, y - 0.03, z1)), (1, 0, 0), (0, -1, 0), 0.1, 0.045)
	for s, name, z1 in ((1, "A", 5.3), (-1, "B", 5.36)):
		_bar(k, h, f"MaskOut{name}", ((s * 0.49, y - 0.02, 4.5), (s * 0.86, y + 0.0, 4.92), (s * 0.98, y + 0.12, z1)), (1, -0.1, 0), (0, -1, 0), 0.095, 0.045)
	# the thumb runs under the viewer's left eye to the cheek
	_bar(k, h, "MaskThumb", ((-0.44, y - 0.02, 4.22), (-0.78, y + 0.02, 4.42), (-0.96, y + 0.2, 4.56)), (0, 0, 1), (0, -1, 0), 0.085, 0.045)
	block(k, h, "MaskWrist", 0, y, 4.06, 3.86, 0.3, 0.055, "dead", ch=0.02, a=0.5, b=0.34)
	block(k, h, "MaskCut", 0, y, 3.86, 3.84, 0.28, 0.045, "cut", ch=0.005, a=0.5, b=0.3)


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.94, 5.2, 0.5), (1.03, 5.5, 0.5), (0.96, 5.84, 0.5), (0.6, 6.08, 0.5), (0.2, 6.16, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.98, outline=0)
	jitter(dome, 0.03)
	bake(k, dome, "hair", a=0.48, b=0.34)
	# the mess on top: tufts lying over and outward, none standing up
	for i, (b, t, r) in enumerate((((-0.3, 0.0, 6.04), (-1.12, 0.1, 5.82), 0.3), ((0.42, 0.3, 6.02), (1.14, 0.42, 5.8), 0.3), ((0.0, 0.42, 6.06), (0.1, 1.04, 5.86), 0.34), ((-0.3, -0.34, 6.06), (-0.96, -0.62, 5.78), 0.28), ((0.46, -0.3, 6.04), (1.06, -0.5, 5.76), 0.26))):
		gem(k, "Head", f"Tuft{i}", b, t, r, flat=0.55, twist=0.2 + 0.11 * i, bend=0.14)
	# the long shaggy fringe, stopping just above the eyes; between the mask's fingers it shows
	for i, (x, xt, zt, r) in enumerate(((-0.72, -0.86, 4.96, 0.28), (-0.44, -0.52, 4.92, 0.28), (-0.08, -0.06, 5.06, 0.26), (0.28, 0.4, 4.9, 0.3), (0.66, 0.74, 4.94, 0.28))):
		gem(k, "Head", f"Fringe{i}", (x * 0.9, -0.5, 5.84), (xt, -0.9, zt), r, flat=0.5, twist=0.15 + 0.17 * i, bend=0.18)
	for s in (1, -1):
		# long side locks to the shoulder, in front of and behind the ear
		for i, (y, zt, r, out) in enumerate(((-0.5, 4.3, 0.26, 1.04), (-0.14, 3.98, 0.3, 1.12), (0.22, 3.92, 0.32, 1.14), (0.56, 3.94, 0.32, 1.1))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.88, y * 0.9, 5.56), (s * out, y * 1.05, zt + 0.05 * (i % 2)), r, flat=0.5, twist=0.2 + 0.23 * i, across=(0, 1, 0))
	block(k, "Head", "Back", 0, 0.42, 5.46, 4.24, 0.98, 0.5, "hair", ch=0.12, corner=0.3, jit=0.03, mids=(5.0,), a=0.44, b=0.46, g=0.1)
	for i, x in enumerate((-0.82, -0.42, 0.02, 0.44, 0.84)):
		gem(k, "Head", f"BackLong{i}", (x * 0.9, 0.8, 5.5), (x * 1.06, 1.06, 3.72 + 0.12 * (i % 2)), 0.36, flat=0.42, twist=0.2 + 0.1 * i, across=(1, 0, 0))


def _head_hands(k):
	h = "Head"
	_hand(k, h, "Crown", (0.22, 0.02, 6.2), (1, 0.2, 0), (-0.25, -0.9, -0.22), (0, -0.22, 0.97), reach=(0.22, 0.2), wrist=0.08)
	for s, tag in ((1, "L"), (-1, "R")):
		_hand(k, h, f"Side{tag}", (s * 1.06, 0.1, 5.3), (0, 0, s), (0, -1, 0.1), (s, 0, 0), reach=(0.2, 0.18), thumb=-s, wrist=0.2)


def _shirt(k):
	t = "UpperTorso"
	block(k, t, "Body", 0, 0, 3.98, 2.06, 1.06, 0.58, "shirt", ch=0.08, flare=0.02, jit=0.022, mids=(3.4, 2.7), a=0.46, b=0.58, tone=0.05)
	block(k, t, "Hem", 0, 0, 2.2, 2.02, 1.1, 0.62, "shirt", ch=0.03, a=0.42, b=0.52)
	block(k, t, "Hips", 0, 0, 2.04, 1.88, 1.05, 0.58, "trousers", ch=0.02, a=0.42, b=0.55)
	block(k, t, "Neck", 0, 0.02, 4.1, 3.9, 0.46, 0.42, "skin", ch=0.03, a=0.48, b=0.3)
	# the V-neck: bare chest, a black band on each edge
	verts = [(-0.46, -0.6, 3.98), (0.46, -0.6, 3.98), (0, -0.6, 3.44), (-0.46, -0.62, 3.98), (0.46, -0.62, 3.98), (0, -0.62, 3.44)]
	bake(k, k._mesh("VNeck", t, verts, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], outline=0), "skin", a=0.5, b=0.3)
	for s in (1, -1):
		strip(k, t, f"VBand{s}", (s * 0.5, 3.98), (0, 3.4), 0.05, -0.65, 0.05, "shirt", a=0.56, b=0.5)
	# the neck hands, one each side, fingers over the collarbone towards the throat
	_hand(k, t, "NeckL", (0.72, -0.66, 3.66), (0, 0, 1), (-0.9, 0, 0.3), (0, -1, 0), reach=(0.17, 0.15), thumb=-1, wrist=0.14)
	_hand(k, t, "NeckR", (-0.72, -0.66, 3.66), (0, 0, -1), (0.9, 0, 0.3), (0, -1, 0), reach=(0.17, 0.15), thumb=1, wrist=0.14)
	# one on the chest, one on the ribs, one across the upper back
	_hand(k, t, "Chest", (-0.42, -0.66, 2.92), (1, 0, 0.2), (0.25, 0, 0.9), (0, -1, 0), reach=(0.2, 0.17))
	_hand(k, t, "Rib", (0.62, -0.66, 2.48), (1, 0, -0.3), (-0.3, 0, 0.9), (0, -1, 0), reach=(0.2, 0.17), thumb=-1)
	_hand(k, t, "Back", (0.1, 0.65, 2.96), (1, 0, 0.3), (-0.3, 0, 0.9), (0, 1, 0), reach=(0.2, 0.17))


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.0, 2.56, 0.52, 0.53, "shirt", ch=0.1, corner=0.2, jit=0.02, sub=1, mids=(3.3,), a=0.46, b=0.58, tone=0.05)
	block(k, arm, "Cuff", ax, 0, 2.66, 2.46, 0.55, 0.56, "shirt", ch=0.04, corner=0.18, a=0.4, b=0.5)
	hand(k, arm, ax, "skin", z1=2.5)
	# a hand round the upper arm and one round the forearm: palm outside, fingers over the front, thumb behind
	ox = ax + s * 0.59
	for tag, z in (("U", 3.46), ("F", 2.86)):
		_hand(k, arm, f"{side}{tag}", (ox, -0.02, z), (0, 0, s), (0, -1, 0), (s, 0, 0), wrap=(-s, 0, 0), reach=(0.4, 0.42), thumb=0, spread=0.0, wrist=0.12)
		b = (ox, 0.1, z - 0.14)
		_bar(k, arm, f"{side}{tag}Thumb", (b, (ox, 0.42, z - 0.3), (ax + s * 0.2, 0.58, z - 0.34)), (0, 0, 1), [(s, 0, 0), (s, 1, 0), (0, 1, 0)], 0.055, 0.055)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 0.6, 0.52, 0.57, "trousers", ch=0.04, flare=0.03, corner=0.16, jit=0.025, mids=(1.4, 0.9), a=0.44, b=0.55, tone=0.05)
	block(k, leg, "Cuff", x, 0, 0.74, 0.56, 0.58, 0.62, "trousers", ch=0.03, a=0.38, b=0.5)
	# the plain red sneaker
	block(k, leg, "Shoe", x, -0.12, 0.62, 0.1, 0.55, 0.72, "red", ch=0.05, corner=0.25, a=0.54, b=0.5)
	block(k, leg, "Toe", x, -0.5, 0.36, 0.1, 0.5, 0.36, "red", ch=0.1, corner=0.3, a=0.56, b=0.5)
	block(k, leg, "Sole", x, -0.14, 0.12, 0.0, 0.56, 0.76, "sole", ch=0.02, a=0.5, b=0.36)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_mask(k)
	_head_hands(k)
	_shirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def paint(a):
	R.paint(a)
	f = head_faces(a, SKIN, SKIN_D, HAIR_COL)
	for s, x in ((-1, 35), (1, 95)):
		# sunken, sleepless sockets
		f.soft(f"M{x - 24} 40H{x + 24}V74Q{x} 86 {x - 24} 74Z", "#6a5660", 0.75, 3)
		anime_eye(f, x, 58, s, "#c8141e", w=30, up=12, dn=11, lift=1, lt=2.6, wing=1.5, ir=7.5, pupil=0.32, lash="#3a2a34", white="#f6f0ea")
		# dry skin: cracks running out from the eye
		for dx0, y0, dx1, y1 in ((20, 44, 29, 37), (22, 72, 30, 80), (10, 76, 15, 88), (-12, 76, -16, 86)):
			f.taper(x + s * dx0, y0, x + s * (dx0 + dx1) / 2, (y0 + y1) / 2 + 1, x + s * dx1, y1, 1.3, shade(SKIN_D, 0.5))
	# the scar through the brow over the viewer's left eye
	f.path("M27 34L31 50L28 51Z", shade(SKIN_D, 0.5))
	f.path("M31 66L35 78L32 79Z", shade(SKIN_D, 0.5))
