# Sidekick side_tiger: a big white tiger with black stripes, teal eyes and a pink nose on four chunky legs. Walks. Source and choices: docs/char_evidence/side_tiger.md.
import math

ID = "side_tiger"
NAME = "Bakku"

RAMPS = {
	"fur": ["#a9acba", "#d2d5de", "#eef0f5", "#ffffff"],
	"cream": ["#b4b0b4", "#dcd8d8", "#f4f2f2", "#ffffff"],
	"stripe": ["#08080c", "#14141a", "#22232c", "#383a46"],
	"eye": ["#0a5c58", "#16948c", "#3cc8bc", "#a8f4ec"],
	"pink": ["#8c4450", "#c06c78", "#e098a0", "#f8c4c8"],
	"mouth": ["#3a1218", "#5c2028", "#7c343c", "#9c5058"],
	"claw": ["#2a2a32", "#4a4a56", "#70707c", "#a0a0ac"],
}
BODY = ((-0.95, 1.72, 0.94, 0.86), (-0.3, 1.74, 0.96, 0.86), (0.5, 1.66, 0.86, 0.78), (1.2, 1.7, 0.92, 0.82), (1.66, 1.72, 0.66, 0.66))  # y, z, half width, half height
SEC = ((1, 0.6), (0.6, 1), (-0.6, 1), (-1, 0.6), (-1, -0.6), (-0.6, -1), (0.6, -1), (1, -0.6))


def box(m, part, ramp, x, y, z1, z0, hw, hd, ch=0.05, flare=0.0, mids=(), **kw):
	"""Model.block with its corner points in ring order: the shared one crosses them, which turns the flat sides inside out."""
	rows = [(z1, hw - ch, hd - ch), (z1 - ch, hw, hd)]
	rows += [(q, hw + flare * (z1 - q) / (z1 - z0), hd + flare * (z1 - q) / (z1 - z0)) for q in mids]
	rows += [(z0 + ch, hw + flare, hd + flare), (z0, hw + flare - ch, hd + flare - ch)]
	rings = []
	for z, w, d in rows:
		c = 0.2 * min(w, d)
		rings.append([(x + px, y + py, z) for px, py in ((w, d - c), (w - c, d), (c - w, d), (-w, d - c), (-w, c - d), (c - w, -d), (w - c, -d), (w, c - d))])
	m.add(part, ramp, *m._loft(rings), **kw)


def around(t):
	"""Point of the boxy section at t, 0 the top centre, +-1 the bottom centre, as (x, z) in unit half sizes."""
	pts = [(0, 1), (0.6, 1), (1, 0.6), (1, -0.6), (0.6, -1), (0, -1)]
	s = 1 if t >= 0 else -1
	u = min(abs(t), 1) * 5
	i = min(int(u), 4)
	f = u - i
	return s * (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f), pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f


def at(y):
	for a, b in zip(BODY, BODY[1:]):
		if y <= b[0]:
			f = (y - a[0]) / (b[0] - a[0])
			return [a[i] + (b[i] - a[i]) * f for i in range(1, 4)]
	return list(BODY[-1][1:])


def body_stripe(m, y, t0, t1, w, lean=0.1):
	"""A tapered band laid on the body's own section from t0 to t1, pointed at t1."""
	n = 7
	rings = []
	for i in range(n):
		f = i / (n - 1)
		t = t0 + (t1 - t0) * f
		yy = y + lean * f + 0.05 * math.sin(i * 2.1)
		ww = w * (1 - 0.92 * f) if f > 0.3 else w * (0.7 + f)
		z, hw, hh = at(yy)
		x, v = around(t)
		rings.append([(x * hw * k, yy + d, z + v * hh * k) for d, k in ((-ww, 0.97), (ww, 0.97), (ww, 1.035), (-ww, 1.035))])
	m.add("Body", "stripe", *m._loft(rings), a=0.5, b=0.2)


def body(m):
	b = "Body"
	m.path(b, "fur", [(0, y, z) for y, z, _, _ in BODY], [w for _, _, w, _ in BODY], [h for _, _, _, h in BODY], n=8, a=0.58, b=0.34, jit=0.015)
	box(m, b, "fur", 0, -0.6, 2.72, 2.2, 0.66, 0.5, ch=0.14, jit=0.015, a=0.6, b=0.3)  # shoulder hump
	box(m, b, "cream", 0, -1.08, 1.9, 0.94, 0.62, 0.22, ch=0.1, jit=0.02, a=0.58, b=0.3)
	for i, (y, e, w) in enumerate(((-0.6, 0.5, 0.15), (-0.2, 0.66, 0.16), (0.24, 0.48, 0.15), (0.66, 0.64, 0.16), (1.06, 0.5, 0.14), (1.42, 0.58, 0.11))):
		for s in (1, -1):
			body_stripe(m, y + 0.06 * s, 0.02 * s, s * e, w, lean=0.1 * (1 if i % 2 else -1))
			if i in (1, 3, 4):
				body_stripe(m, y + 0.2, s * 0.78, s * 0.42, w * 0.7)
	for s in (1, -1):
		m.spike(b, "cream", (s * 0.4, -1.1, 1.3), (s * 0.36, -1.28, 0.74), 0.24, flat=0.6, a=0.56, b=0.3)


def leg(m, name, x, y, s, hip, back):
	m.path(name, "fur", [(x, y, hip), (x + s * 0.06, y + (0.1 if back else -0.04), 0.96), (x + s * 0.06, y - 0.02, 0.4)], [0.44, 0.4, 0.36], [0.56 if back else 0.5, 0.42, 0.36], n=8, a=0.56, b=0.34, jit=0.012)
	box(m, name, "fur", x + s * 0.06, y - 0.16, 0.44, 0, 0.44, 0.52, ch=0.1, a=0.6, b=0.32)
	for dx in (-0.28, 0, 0.28):
		box(m, name, "cream", x + s * 0.06 + dx, y - 0.66, 0.26, 0, 0.13, 0.1, ch=0.04, a=0.6, b=0.3)
		m.spike(name, "claw", (x + s * 0.06 + dx, y - 0.72, 0.1), (x + s * 0.06 + dx, y - 0.9, 0.01), 0.06, flat=0.8)
	# tapered bands wrapped round the outer side
	for i, (z, w) in enumerate(((1.34, 0.1), (1.02, 0.1), (0.7, 0.08))):
		f = (hip - z) / (hip - 0.4)
		cx, cyy = x + s * 0.06 * min(1, f * 2), y + (0.1 * (1 - abs(2 * f - 1)) if back else -0.02)
		hw, hd = 0.44 - 0.08 * f, (0.56 if back else 0.5) - (0.2 if back else 0.14) * f
		rings = []
		for j in range(9):
			a = -2.2 + 4.4 * j / 8
			c, n = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.4, c), math.copysign(abs(n) ** 0.4, n)
			ww = w * max(0.08, 1 - abs(a) / 2.2)
			zz = z + 0.06 * math.sin(a)
			rings.append([(cx + s * hw * px * q, cyy + hd * py * q, zz + d) for d, q in ((-ww, 0.97), (ww, 0.97), (ww, 1.06), (-ww, 1.06))])
		m.add(name, "stripe", *m._loft(rings), a=0.5, b=0.2)


def head(m):
	h, cy, cz = "Head", -1.5, 2.5
	box(m, h, "fur", 0, cy, cz + 0.84, cz - 0.7, 1.0, 0.72, ch=0.2, mids=(cz + 0.3, cz - 0.2), a=0.6, b=0.34)
	y = cy - 0.74
	box(m, h, "cream", 0, y - 0.16, cz + 0.06, cz - 0.6, 0.52, 0.34, ch=0.12, jit=0.01, a=0.62, b=0.3)  # muzzle
	box(m, h, "fur", 0, y - 0.1, cz + 0.34, cz - 0.02, 0.26, 0.3, ch=0.08, a=0.6, b=0.32)  # bridge
	box(m, h, "cream", 0, y - 0.04, cz - 0.52, cz - 0.82, 0.4, 0.3, ch=0.08, a=0.54, b=0.3)  # chin
	ym = y - 0.5
	m.plate(h, "pink", [(-0.22, ym - 0.02, cz + 0.08), (0.22, ym - 0.02, cz + 0.08), (0.12, ym - 0.02, cz - 0.1), (0, ym - 0.02, cz - 0.18), (-0.12, ym - 0.02, cz - 0.1)], (0, 0.14, 0), a=0.56, b=0.3)
	m.plate(h, "stripe", [(-0.025, ym, cz - 0.16), (0.025, ym, cz - 0.16), (0.025, ym, cz - 0.34), (-0.025, ym, cz - 0.34)], (0, 0.06, 0), a=0.5, b=0.1)
	for s in (1, -1):
		m.plate(h, "stripe", [(0, ym, cz - 0.3), (s * 0.4, ym, cz - 0.44), (s * 0.38, ym, cz - 0.5), (0, ym, cz - 0.37)], (0, 0.06, 0), a=0.5, b=0.1)
		for i in range(3):  # whisker dots
			m.plate(h, "stripe", [(s * (0.2 + 0.1 * i), ym, cz - 0.12 - 0.04 * i), (s * (0.26 + 0.1 * i), ym, cz - 0.12 - 0.04 * i), (s * (0.26 + 0.1 * i), ym, cz - 0.18 - 0.04 * i), (s * (0.2 + 0.1 * i), ym, cz - 0.18 - 0.04 * i)], (0, 0.04, 0), a=0.5, b=0.1)
		# narrow teal eye in a black rim, under a heavy brow
		m.plate(h, "stripe", [(s * 0.2, y - 0.02, cz + 0.16), (s * 0.5, y - 0.02, cz + 0.06), (s * 0.84, y - 0.02, cz + 0.36), (s * 0.82, y - 0.02, cz + 0.5), (s * 0.46, y - 0.02, cz + 0.46)], (0, 0.05, 0), a=0.4, b=0.1, g=0)
		m.plate(h, "eye", [(s * 0.3, y - 0.05, cz + 0.2), (s * 0.5, y - 0.05, cz + 0.13), (s * 0.74, y - 0.05, cz + 0.36), (s * 0.48, y - 0.05, cz + 0.4)], (0, 0.03, 0), a=0.7, b=0, g=0.2)
		m.plate(h, "stripe", [(s * 0.47, y - 0.08, cz + 0.16), (s * 0.55, y - 0.08, cz + 0.18), (s * 0.55, y - 0.08, cz + 0.39), (s * 0.47, y - 0.08, cz + 0.39)], (0, 0.02, 0), a=0.4, b=0, g=0)
		m.plate(h, "fur", [(s * 0.14, y - 0.04, cz + 0.32), (s * 0.84, y - 0.04, cz + 0.5), (s * 0.84, y - 0.04, cz + 0.6), (s * 0.14, y - 0.04, cz + 0.46)], (0, 0.12, 0), a=0.62, b=0.32)
		# forehead bars and cheek bars, thin so they read as markings
		for x0, z0, x1, z1, w0, w1 in ((0.04, 0.66, 0.46, 0.78, 0.1, 0.03), (0.04, 0.5, 0.3, 0.58, 0.08, 0.02), (0.5, 0.64, 0.86, 0.76, 0.03, 0.1)):
			m.plate(h, "stripe", [(s * x0, y + 0.0, cz + z0 + w0 / 2), (s * x1, y + 0.0, cz + z1 + w1 / 2), (s * x1, y + 0.0, cz + z1 - w1 / 2), (s * x0, y + 0.0, cz + z0 - w0 / 2)], (0, 0.07, 0), a=0.5, b=0.1)
		for z in (0.02, -0.2, -0.42):
			m.plate(h, "stripe", [(s * 0.6, y, cz + z - 0.02), (s * 0.86, y, cz + z + 0.12), (s * 0.86, y, cz + z - 0.0)], (0, 0.07, 0), a=0.5, b=0.1)
			m.plate(h, "stripe", [(s * 1.0, cy - 0.56, cz + z + 0.15), (s * 1.0, cy + 0.2, cz + z + 0.24), (s * 1.0, cy - 0.56, cz + z)], (0.06, 0, 0), a=0.5, b=0.1)
		# small round ear, black behind, pale and pink inside
		m.disc(h, "stripe", (s * 0.74, cy + 0.12, cz + 0.84), (0, 1, 0), 0.38, th=0.22, n=10, a=0.5, b=0.3)
		m.disc(h, "cream", (s * 0.74, cy + 0.02, cz + 0.83), (0, 1, 0), 0.3, th=0.16, n=10, a=0.64, b=0.26)
		m.disc(h, "pink", (s * 0.74, cy - 0.04, cz + 0.8), (0, 1, 0), 0.16, th=0.14, n=8, a=0.56, b=0.2)
		# ruff of fur round the cheeks
		for i, (x, z, tx, tz) in enumerate(((0.9, 0.1, 1.34, -0.1), (0.9, -0.2, 1.3, -0.5), (0.8, -0.5, 1.02, -0.96), (0.5, -0.6, 0.56, -1.1))):
			m.spike(h, "cream" if i % 2 else "fur", (s * x, cy + 0.06, cz + z), (s * tx, cy + 0.06, cz + tz), 0.28, flat=0.6, a=0.58, b=0.32)


def tail(m):
	t = "Tail"
	pts = [(0, 1.7, 1.9), (0.1, 2.3, 1.7), (0.3, 2.8, 2.1), (0.4, 2.9, 2.9), (0.2, 2.7, 3.5)]
	rad = [0.26, 0.25, 0.24, 0.23, 0.2]
	m.path(t, "fur", pts, rad, n=8, a=0.56, b=0.34)
	m.path(t, "stripe", [(0.2, 2.7, 3.46), (0.08, 2.56, 3.82)], [0.22, 0.06], n=8, a=0.5, b=0.3)
	V = type(m.light)
	for i, f in enumerate((0.2, 0.5, 0.8)):
		for a, c in ((1, 2), (2, 3)):
			p, q = V(pts[a]).lerp(V(pts[c]), f), V(pts[a]).lerp(V(pts[c]), f + 0.14)
			m.path(t, "stripe", [tuple(p), tuple(q)], [0.265, 0.265], n=8, a=0.5, b=0.3)


def build(k):
	parts = {
		"Body": ((0, 0.3, 1.7), None),
		"Head": ((0, -1.1, 2.2), "Body"),
		"Tail": ((0, 1.6, 1.9), "Body"),
		"LegFrontLeft": ((0.6, -0.6, 1.5), "Body"),
		"LegFrontRight": ((-0.6, -0.6, 1.5), "Body"),
		"LegBackLeft": ((0.62, 1.2, 1.5), "Body"),
		"LegBackRight": ((-0.62, 1.2, 1.5), "Body"),
	}
	m = k.Model(ID, RAMPS, parts)
	body(m)
	head(m)
	tail(m)
	for name, x, y, s, back in (("LegFrontLeft", 0.6, -0.6, 1, False), ("LegFrontRight", -0.6, -0.6, -1, False), ("LegBackLeft", 0.62, 1.24, 1, True), ("LegBackRight", -0.62, 1.24, -1, True)):
		leg(m, name, x, y, s, 1.6, back)
	return m
