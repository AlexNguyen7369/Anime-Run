# Sidekick side_pig, Hawke: a walking talking pig. Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_pig.md.
# Front faces -Y; +X is the viewer's right in the front view, the pig's own left.
ID = "side_pig"
NAME = "Hawke"

RAMPS = {
	"pink": ["#c0676f", "#e88d92", "#f8a9aa", "#ffc8c2"],
	"snout": ["#cf8d8c", "#efb0ac", "#f8c9c3", "#ffe2da"],
	"blush": ["#e55f70", "#ee6f7d", "#f6838c", "#ff9aa0"],
	"dark": ["#120c0f", "#1f161a", "#32262b", "#4c3e44"],
	"hoof": ["#22140f", "#3a241d", "#553a2e", "#775445"],
	"white": ["#e6e6e6", "#f2f2f2", "#fafafa", "#ffffff"],
	"silver": ["#6e747e", "#a4aab3", "#cfd3d9", "#f4f6f8"],
	"mouth": ["#4a1a22", "#6e2730", "#8e3840", "#a84c52"],
	"tongue": ["#d9606a", "#ec7f84", "#f6989a", "#ffb4b2"],
}
BODY_C, BODY_R = (0, 0.22, 1.5), (1.3, 1.72, 1.26)
HEAD_C, HEAD_R = (0, -1.05, 1.7), (1.02, 0.98, 0.94)


def spot(k, m, part, ramp, c, r, d, rad, squash=1.0, lift=0.03, th=0.03, n=12, a=0.6, b=0.0):
	"""A flat oval lying on the ellipsoid (c, r), in direction d. Its first radius runs level, the second follows the surface upward."""
	d = k.Vector(d).normalized()
	p = k.Vector((c[0] + r[0] * d.x, c[1] + r[1] * d.y, c[2] + r[2] * d.z))
	nrm = k.Vector((d.x / r[0], d.y / r[1], d.z / r[2])).normalized()
	m.disc(part, ramp, p + nrm * lift, nrm, rad, th=th, n=n, squash=squash, a=a, b=b, g=0.0, tone=0.0)


def ear(k, m, s, part):
	"""The long ear: rises from the crown, folds over and hangs past the eye."""
	V = k.Vector
	pts = [V((s * 0.5, -0.85, 2.42)), V((s * 0.92, -0.85, 2.58)), V((s * 1.22, -0.86, 2.3)), V((s * 1.38, -0.88, 1.82)), V((s * 1.4, -0.9, 1.38))]
	m.path(part, "pink", pts, [0.3, 0.46, 0.54, 0.48, 0.24], [0.09, 0.1, 0.1, 0.08, 0.05], n=8, a=0.56, b=0.26, g=0.0)
	m.path(part, "snout", [p + V((s * 0.05, 0, -0.04)) for p in pts[1:3]], [0.3, 0.34], 0.07, n=8, a=0.45, b=0.2, g=0.0)


def leg(k, m, part, x, y):
	m.block(part, "pink", x, y, 0.9, 0.14, 0.26, 0.28, ch=0.05, mids=(0.5,), a=0.54, b=0.3, g=0.1)
	m.block(part, "hoof", x, y, 0.17, 0.0, 0.27, 0.29, ch=0.04, a=0.45, b=0.3, g=0.0)
	m.block(part, "dark", x, y - 0.25, 0.15, 0.0, 0.025, 0.06, ch=0.01, a=0.5, b=0.0, g=0.0)  # the split of the hoof


def build(k):
	math, V = k.math, k.Vector
	parts = {
		"Body": ((0, 0.2, 1.5), None),
		"Head": ((0, -0.6, 1.8), "Body"),
		"HeadEarLeft": ((0.5, -0.85, 2.42), "Head"),
		"HeadEarRight": ((-0.5, -0.85, 2.42), "Head"),
		"Tail": ((0, 1.86, 1.95), "Body"),
		"LegFrontLeft": ((0.68, -0.6, 0.9), "Body"),
		"LegFrontRight": ((-0.68, -0.6, 0.9), "Body"),
		"LegBackLeft": ((0.72, 1.02, 0.9), "Body"),
		"LegBackRight": ((-0.72, 1.02, 0.9), "Body"),
	}
	m = k.Model(ID, RAMPS, parts, a=0.56, b=0.27)
	m.ell("Body", "pink", BODY_C, BODY_R, rows=8, n=14, g=0.1, jit=0.012)
	# the head grows out of the body, one pear from the side
	h = "Head"
	m.ell(h, "pink", HEAD_C, HEAD_R, rows=8, n=14, g=0.08, jit=0.008)
	# the wide flat snout, tipped a little up
	m.path(h, "pink", [(0, -1.72, 1.66), (0, -2.14, 1.7), (0, -2.42, 1.76)], [0.54, 0.63, 0.68], [0.42, 0.5, 0.54], n=12, a=0.56, b=0.26, g=0.0)
	tip = V((0, -2.45, 1.77))
	face = V((0, -1, 0.14)).normalized()
	m.disc(h, "snout", tip, face, 0.66, th=0.05, n=14, squash=0.8, a=0.68, b=0.14, g=0.0, tone=0.0)
	for s in (1, -1):
		x = s * 0.24
		m.plate(h, "dark", [(x - 0.035, -2.49, 2.0), (x + 0.035, -2.49, 2.0), (x + 0.05, -2.47, 1.72), (x, -2.46, 1.54), (x - 0.05, -2.47, 1.72)], (0, 0.03, 0), a=0.5, b=0.0, g=0.0, tone=0.0)
		# the small upright eye, its white glint, the crease of the brow, the blush below
		spot(k, m, h, "dark", HEAD_C, HEAD_R, (s * 0.66, -0.68, 0.34), 0.095, squash=1.9, lift=0.04, a=0.45)
		spot(k, m, h, "white", HEAD_C, HEAD_R, (s * 0.66, -0.68, 0.44), 0.04, squash=1.3, lift=0.07, a=0.8)
		eye = V((s * 0.72, -1.72, 2.42))
		m.path(h, "dark", [eye + V((s * -0.06, -0.05, 0.02)), eye + V((s * 0.04, -0.01, 0.05)), eye + V((s * 0.13, 0.06, 0.0))], 0.022, 0.016, n=4, a=0.5, b=0.0, g=0.0)
		spot(k, m, h, "blush", HEAD_C, HEAD_R, (s * 0.8, -0.56, -0.12), 0.19, squash=0.8, lift=0.03, a=0.5)
	# the open grin under the snout
	spot(k, m, h, "mouth", HEAD_C, HEAD_R, (0, -0.84, -0.62), 0.26, squash=0.6, lift=0.02, a=0.45)
	spot(k, m, h, "tongue", HEAD_C, HEAD_R, (0, -0.8, -0.7), 0.13, squash=0.55, lift=0.045, a=0.55)
	smile = [V(HEAD_C) + V((HEAD_R[0] * x, HEAD_R[1] * y, HEAD_R[2] * z)) * 1.01 for x, y, z in ((-0.62, -0.68, -0.34), (-0.34, -0.84, -0.42), (0, -0.88, -0.44), (0.34, -0.84, -0.42), (0.62, -0.68, -0.34))]
	m.path(h, "dark", smile, 0.028, 0.024, n=4, a=0.5, b=0.0, g=0.0)
	ear(k, m, 1, "HeadEarLeft")
	ear(k, m, -1, "HeadEarRight")
	# the tag earring on the left ear: plain metal, no lettering (shortcut of the source's word on it)
	e = "HeadEarLeft"
	m.ring(e, "silver", (1.42, -0.9, 1.34), (0, 1, 0), 0.07, 0.016, n=8, a=0.6, b=0.3, g=0.0)
	m.block(e, "silver", 1.42, -0.9, 1.28, 0.88, 0.055, 0.1, ch=0.02, a=0.62, b=0.32, g=0.1)
	# the mark on the left flank: four black spots, a clover
	for dy, dz in ((0, 0.25), (0.25, 0.0), (0, -0.25), (-0.25, 0.0)):
		v, w = (0.42 + dy - BODY_C[1]) / BODY_R[1], (2.0 + dz - BODY_C[2]) / BODY_R[2]
		spot(k, m, "Body", "dark", BODY_C, BODY_R, (math.sqrt(1 - v * v - w * w), v, w), 0.165, lift=0.03, th=0.03, n=10, a=0.45)
	# the curled tail
	rings = 15
	curl = [V((0.03 * i, 1.86 + 0.05 * i, 1.95 + 0.04 * i)) for i in range(2)]
	for i in range(rings):
		t = i / (rings - 1)
		a = 2 * math.pi * 1.3 * t - 0.8
		rad = lerp_(0.27, 0.14, t)
		curl.append(V((0.05 + 0.07 * t, 2.15 + 0.08 * t + rad * math.cos(a), 2.2 + rad * math.sin(a))))
	m.path("Tail", "pink", curl, [lerp_(0.1, 0.04, i / (len(curl) - 1)) for i in range(len(curl))], n=6, a=0.56, b=0.3, g=0.0)
	leg(k, m, "LegFrontLeft", 0.68, -0.6)
	leg(k, m, "LegFrontRight", -0.68, -0.6)
	leg(k, m, "LegBackLeft", 0.72, 1.02)
	leg(k, m, "LegBackRight", -0.72, 1.02)
	return m


def lerp_(a, b, t):
	return a + (b - a) * t
