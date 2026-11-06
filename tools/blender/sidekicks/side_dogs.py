# Sidekick side_dogs, Gyokan: a pair of shadow wolves, one white and one black, in one Sidekick slot. Walks. Evidence: docs/char_evidence/side_dogs.md.
# Each dog's parts carry its prefix, White or Black, and neither dog is parented to the other, so each animates on its own.
# Hard facets, soft paint, in-house only. Front faces -Y; +X is the viewer's right in the front view, the wolf's own left.
ID = "side_dogs"
NAME = "Gyokan"

RAMPS = {
	"WhiteFur": ["#a8a4c8", "#cdcae4", "#ebe9f6", "#ffffff"],
	"WhiteShade": ["#8f8bbc", "#aeaad2", "#cbc8e4", "#e2e0f2"],
	"WhiteInner": ["#17151f", "#26232f", "#3a3644", "#54505e"],
	# lifted off pure black: slate planes keep the dark dog readable on a dark background
	"BlackFur": ["#100f17", "#1f1e2a", "#353448", "#5d5d78"],
	"BlackShade": ["#6c6c8c", "#8f90ad", "#b2b3cb", "#d4d5e4"],
	"BlackInner": ["#7a5560", "#9c6f78", "#bb8c92", "#d8acae"],
	"rim": ["#17151f", "#26232f", "#3a3644", "#54505e"],
	"nose": ["#0a0606", "#150c0b", "#221514", "#301e1b"],
	"mouth": ["#3e0f18", "#621c26", "#843038", "#a24a4e"],
	"tooth": ["#c8c6d0", "#e4e3e8", "#f6f6f8", "#ffffff"],
	"eye": ["#b8930c", "#dcb814", "#f4d82c", "#fff27c"],
	"pupil": ["#070608", "#100e12", "#1a171c", "#262228"],
	"claw": ["#2a2730", "#47434f", "#67636f", "#8a8692"],
}
DOG_X = {"White": 1.62, "Black": -1.62}  # white on the viewer's right
JOINTS = {
	"Body": ((0, 0.5, 2.0), None),
	"Head": ((0, -1.5, 3.05), "Body"),
	"HeadJaw": ((0, -2.02, 2.92), "Head"),
	"Tail": ((0, 2.32, 2.6), "Body"),
	"LegFrontLeft": ((0.5, -0.72, 1.6), "Body"),
	"LegFrontRight": ((-0.5, -0.72, 1.6), "Body"),
	"LegBackLeft": ((0.52, 1.72, 1.5), "Body"),
	"LegBackRight": ((-0.52, 1.72, 1.5), "Body"),
}


def tufts(k, m, part, base, count, spread, along, size, seed, ramps, **kw):
	"""A row of hard fur points. base is the row's middle, spread its half-width as a vector, along the direction the fur lies."""
	V = k.Vector
	base, spread, along = V(base), V(spread), V(along)
	for i in range(count):
		t = (i - (count - 1) / 2) / max(0.5, (count - 1) / 2)
		wob = ((seed + i * 7) % 5 - 2) * 0.05
		root = base + spread * t
		ramp = ramps[(seed + i) % len(ramps)]
		m.spike(part, ramp, root, root + along * (1 + wob * 2) + spread.normalized() * t * 0.1, size, flat=0.5, n=6, **kw)


def leg(k, m, part, x, y, hip, back, fur, seed):
	"""A thick thigh, a slimmer lower leg, a plain block paw. A hind leg bends back at the hock."""
	V = k.Vector
	mid = (x, y + (0.34 if back else -0.02), hip * 0.56)
	low = (x, y + (0.1 if back else -0.06), 0.3)
	m.path(part, fur, [(x, y, hip), mid, low], [0.36, 0.24, 0.21], [0.46, 0.27, 0.23], n=8, a=0.54, b=0.3, g=0.1)
	m.block(part, fur, x, low[1] - 0.08, 0.3, 0.0, 0.27, 0.37, ch=0.06, a=0.56, b=0.3, g=0.1)
	for dx in (-0.15, 0.0, 0.15):
		m.spike(part, "claw", (x + dx, low[1] - 0.42, 0.1), (x + dx, low[1] - 0.6, 0.0), 0.06, a=0.5, b=0.34)
	tufts(k, m, part, (x, y - 0.3, hip * 0.72), 2, (0.16, 0, 0), (0, -0.05, -0.3), 0.14, seed + int(abs(x) * 10 + abs(y) * 10), (fur,), a=0.54, b=0.28)


def dog(k, m, p, seed):
	"""One whole wolf at x 0, on the parts prefixed p. build moves it to its place."""
	V = k.Vector
	fur, shade, inner = p + "Fur", p + "Shade", p + "Inner"
	b = p + "Body"
	# a big-shouldered wolf body sloping to the hips
	spine = [(0, 2.35, 2.42), (0, 1.5, 2.38), (0, 0.5, 2.62), (0, -0.55, 2.86), (0, -1.15, 3.02)]
	m.path(b, fur, spine, [0.42, 0.68, 0.76, 0.88, 0.72], [0.56, 0.8, 0.92, 1.02, 0.82], n=8, g=0.14, jit=0.018)
	# the great shaggy ruff, the mane down the neck and chest, in hard fur points with shade between
	tufts(k, m, b, (0, -1.0, 3.72), 5, (0.62, 0.05, 0), (0, 0.5, 0.2), 0.24, seed + 1, (fur, fur, shade))
	tufts(k, m, b, (0, -1.35, 2.92), 5, (0.8, 0, 0), (0, -0.28, -0.72), 0.27, seed + 2, (fur,))
	tufts(k, m, b, (0, -1.22, 2.3), 5, (0.68, 0, 0), (0, -0.2, -0.72), 0.26, seed + 3, (fur, shade))
	tufts(k, m, b, (0, -0.95, 1.8), 3, (0.42, 0, 0), (0, -0.04, -0.62), 0.22, seed + 4, (fur,))
	for s in (1, -1):
		# side mane and flank tufts, breaking the silhouette
		tufts(k, m, b, (s * 0.92, -0.75, 3.0), 4, (0, 0.42, 0.28), (s * 0.34, 0.34, -0.5), 0.24, seed + 5, (fur, shade))
		tufts(k, m, b, (s * 0.92, -0.1, 2.32), 4, (0, 0.58, 0.05), (s * 0.2, 0.34, -0.52), 0.22, seed + 6, (shade, fur, fur))
		tufts(k, m, b, (s * 0.76, 0.9, 2.0), 4, (0, 0.6, 0.05), (s * 0.14, 0.34, -0.5), 0.2, seed + 7, (fur, shade))
		tufts(k, m, b, (s * 0.58, 1.75, 2.05), 3, (0, 0.34, 0.02), (s * 0.12, 0.3, -0.5), 0.18, seed + 8, (fur,))
	# a pale-shade saddle of points along the back
	for i, (y, z) in enumerate(((-0.5, 3.8), (0.1, 3.5), (0.72, 3.38), (1.32, 3.12), (1.9, 2.92))):
		tufts(k, m, b, (0, y, z), 3, (0.36, 0.04, 0), (0, 0.46, 0.1), 0.2, seed + 9 + i, (shade, fur))
	h = p + "Head"
	# a broad skull and the long wedge of the muzzle
	m.path(h, fur, [(0, -1.1, 3.72), (0, -1.5, 3.82), (0, -1.95, 3.68), (0, -2.15, 3.42)], [0.5, 0.64, 0.6, 0.4], [0.5, 0.6, 0.48, 0.32], n=8, a=0.56, b=0.32, g=0.06, jit=0.008)
	m.path(h, fur, [(0, -2.05, 3.38), (0, -2.55, 3.22), (0, -3.05, 3.08)], [0.42, 0.34, 0.26], [0.26, 0.22, 0.18], n=8, a=0.56, b=0.32, g=0.0)
	# nose
	m.ell(h, "nose", (0, -3.12, 3.17), (0.24, 0.16, 0.16), rows=4, n=8, a=0.5, b=0.3, g=0.0, tone=0.0)
	# the upper gum and fangs, the mouth snarling open
	m.path(h, "mouth", [(0, -2.02, 3.02), (0, -2.55, 2.98), (0, -3.0, 2.92)], [0.38, 0.32, 0.22], 0.07, n=6, a=0.5, b=0.22, g=0.0)
	for s in (1, -1):
		m.spike(h, "tooth", (s * 0.19, -2.9, 2.96), (s * 0.2, -2.92, 2.56), 0.075, a=0.66, b=0.2)
		m.spike(h, "tooth", (s * 0.28, -2.4, 3.0), (s * 0.3, -2.42, 2.76), 0.06, a=0.66, b=0.2)
		m.spike(h, "tooth", (s * 0.3, -2.15, 3.0), (s * 0.32, -2.15, 2.82), 0.055, a=0.66, b=0.2)
		# the slanted yellow eye under a dark brow, a line of shade beneath, on the flat of the skull
		c = V((s * 0.5, -2.02, 3.58))
		face = V((s * 0.62, -0.74, 0.12))
		e1 = V((s * 0.74, 0.62, 0.0)).normalized()
		off = face.normalized() * 0.03
		m.plate(h, "rim", [c + e1 * -0.28 + V((0, 0, -0.13)), c + e1 * 0.32 + V((0, 0, 0.15)), c + e1 * 0.26 + V((0, 0, -0.13)), c + e1 * -0.13 + V((0, 0, -0.24))], off * 1.2, a=0.5, b=0.0, g=0.0, tone=0.0)
		c2 = c + face.normalized() * 0.03
		m.plate(h, "eye", [c2 + e1 * -0.2 + V((0, 0, -0.08)), c2 + e1 * 0.23 + V((0, 0, 0.1)), c2 + e1 * 0.18 + V((0, 0, -0.08)), c2 + e1 * -0.08 + V((0, 0, -0.16))], off, a=0.62, b=0.0, g=0.0, tone=0.0)
		c3 = c2 + face.normalized() * 0.03
		m.disc(h, "pupil", c3 + e1 * 0.05 + V((0, 0, -0.025)), face, 0.065, th=0.02, n=8, squash=1.4, a=0.5, b=0.0, g=0.0, tone=0.0)
		m.path(h, shade, [c + e1 * -0.32 + V((0, -0.06, 0.2)), c + e1 * 0.02 + V((0, -0.02, 0.22)), c + e1 * 0.26 + V((0, 0.0, 0.25))], [0.08, 0.11, 0.05], 0.06, n=6, a=0.36, b=0.2, g=0.0)
		# the pale shade streak on the muzzle, the pointed upright ear
		m.path(h, shade, [(s * 0.34, -2.28, 3.34), (s * 0.28, -2.8, 3.2)], [0.05, 0.03], 0.025, n=4, a=0.5, b=0.1, g=0.0)
		m.spike(h, fur, (s * 0.42, -1.45, 4.12), (s * 0.68, -1.2, 5.02), 0.3, flat=0.5, n=6, a=0.58, b=0.34)
		m.spike(h, inner, (s * 0.42, -1.6, 4.16), (s * 0.66, -1.29, 4.82), 0.16, flat=0.3, n=6, a=0.5, b=0.2)
		# cheek ruff
		tufts(k, m, h, (s * 0.62, -1.75, 3.25), 3, (0, 0.28, 0.14), (s * 0.34, 0.26, -0.36), 0.2, seed + 11, (fur, shade))
	# a forehead point of shade and the shaggy crown
	tufts(k, m, h, (0, -1.45, 4.25), 3, (0.2, 0, 0), (0, 0.32, 0.26), 0.18, seed + 12, (fur,))
	m.spike(h, shade, (0, -2.1, 3.75), (0, -1.68, 4.12), 0.1, flat=0.3, n=6, a=0.42, b=0.2)
	# the lower jaw, dropped open
	j = p + "HeadJaw"
	m.path(j, fur, [(0, -2.0, 2.92), (0, -2.45, 2.62), (0, -2.84, 2.42)], [0.36, 0.28, 0.2], [0.16, 0.13, 0.1], n=8, a=0.5, b=0.3, g=0.0)
	m.path(j, "mouth", [(0, -2.05, 3.0), (0, -2.48, 2.72), (0, -2.78, 2.56)], [0.28, 0.22, 0.13], 0.04, n=6, a=0.5, b=0.2, g=0.0)
	for s in (1, -1):
		m.spike(j, "tooth", (s * 0.15, -2.72, 2.58), (s * 0.16, -2.72, 2.82), 0.055, a=0.66, b=0.2)
		m.spike(j, "tooth", (s * 0.22, -2.4, 2.75), (s * 0.23, -2.4, 2.92), 0.045, a=0.66, b=0.2)
	# the bushy tail, carried low, in hard plumes
	t = p + "Tail"
	m.path(t, fur, [(0, 2.32, 2.6), (0, 2.95, 2.2), (0, 3.42, 1.56), (0, 3.58, 0.98)], [0.24, 0.42, 0.4, 0.05], [0.24, 0.42, 0.4, 0.05], n=8, a=0.54, b=0.32, g=0.08, jit=0.02)
	for i, (y, z) in enumerate(((2.86, 2.52), (3.28, 1.98), (3.54, 1.4))):
		tufts(k, m, t, (0, y, z), 3, (0.28, 0, 0), (0, 0.32, -0.42), 0.17, seed + 13 + i, (fur, shade))
	leg(k, m, p + "LegFrontLeft", 0.5, -0.72, 1.6, False, fur, seed)
	leg(k, m, p + "LegFrontRight", -0.5, -0.72, 1.6, False, fur, seed)
	leg(k, m, p + "LegBackLeft", 0.52, 1.72, 1.5, True, fur, seed)
	leg(k, m, p + "LegBackRight", -0.52, 1.72, 1.5, True, fur, seed)
	if p == "Black":
		# its own markings: a pale blaze down the chest, an ash stripe along each flank
		for x, top, low in ((0, 2.95, 1.55), (0.26, 2.75, 1.85), (-0.26, 2.75, 1.85)):
			m.spike(p + "Body", shade, (x, -1.5, top), (x, -1.62, low), 0.2, flat=0.4, n=6, a=0.62, b=0.24)
		for s in (1, -1):
			m.spike(p + "Body", shade, (s * 0.95, -0.35, 2.92), (s * 0.86, 1.2, 2.36), 0.11, flat=0.4, n=6, a=0.56, b=0.24)


def build(k):
	parts = {}
	for p, x in DOG_X.items():
		for name, (joint, parent) in JOINTS.items():
			parts[p + name] = ((joint[0] + x, joint[1], joint[2]), p + parent if parent else None)
	m = k.Model(ID, RAMPS, parts, a=0.54, b=0.3)
	for seed, (p, x) in enumerate(DOG_X.items()):
		dog(k, m, p, seed * 3)
		for name in JOINTS:
			for v in m.bm[p + name].verts:
				v.co.x += x
	return m
