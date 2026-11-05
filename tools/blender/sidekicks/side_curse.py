# Sidekick side_curse: the huge pale mouth-headed curse, not the human girl. Flies by hovering: Tail, Crest and each arm are separate parts. Source and choices: docs/char_evidence/side_curse.md.
# Meant for 2.3 studs tall in game, the top of the range in docs/SIDEKICK_SPEC.md "Display". No catalog field sets that yet.
ID = "side_curse"
NAME = "Rikka"

RAMPS = {
	"hide": ["#56616e", "#818d9b", "#a9b4c0", "#d4dbe3"],
	"crease": ["#2c323c", "#465058", "#626c78", "#808a96"],
	"blotch": ["#08090c", "#121418", "#1e2228", "#2e333a"],
	"black": ["#040406", "#0b0c10", "#191b22", "#30323c"],
	"lip": ["#3e0f1a", "#6c1e2e", "#9c3a4e", "#c86c7e"],
	"maw": ["#040203", "#090406", "#10070b", "#180b10"],
	"tongue": ["#2e1a4c", "#47306e", "#654a8c", "#8870a8"],
	"tooth": ["#a8ac9e", "#d6d8cc", "#f2f2e8", "#ffffff"],
	"nail": ["#1a1e2a", "#343a4a", "#586072", "#868e9e"],
}
# the open mouth from the front, half of it: wide across the top, narrowing to a V at the chin. x, z from MOUTH_C
MOUTH = ((0.0, 1.14), (0.72, 1.08), (1.34, 0.86), (1.46, 0.1), (1.08, -0.56), (0.5, -1.14), (0.0, -1.32))
MOUTH_C = (0.0, 5.24)
SKULL = (0, -0.75, 5.3)


def outline(scale, y):
	half = [(x * scale + MOUTH_C[0], y, z * scale + MOUTH_C[1]) for x, z in MOUTH]
	return half + [(-x, y, z) for x, y, z in reversed(half[1:-1])]


def strip(m, part, ramp, ring_a, ring_b, want, **kw):
	"""An open band between two closed rings, each quad wound to face want(its centre): the walls of the mouth, which has no caps."""
	V, n = m.k.Vector, len(ring_a)
	verts, faces = list(ring_a) + list(ring_b), []
	for i in range(n):
		j = (i + 1) % n
		f = [i, j, n + j, n + i]
		p = [V(verts[q]) for q in f]
		if (p[1] - p[0]).cross(p[3] - p[0]).dot(want((p[0] + p[2]) / 2)) < 0:
			f.reverse()
		faces.append(f)
	m.add(part, ramp, verts, faces, keep=True, **kw)


def head(m):
	"""A small dome of a skull, thick finger lobes capping it, and a real open mouth pushed out in front."""
	h, V = "Head", m.k.Vector
	centre = V((MOUTH_C[0], 0, MOUTH_C[1]))
	out = lambda p: V((p.x - centre.x, 0, p.z - centre.z))
	inward = lambda p: -out(p)
	face = lambda p: V((0, -1, 0))
	m.ell(h, "hide", SKULL, (1.5, 1.02, 1.56), rows=5, n=10, a=0.54, b=0.36, g=0.1)
	back, lip_out, lip_in, throat = outline(1.2, -1.42), outline(1.05, -2.3), outline(0.86, -2.24), outline(0.74, -1.84)
	strip(m, h, "hide", back, lip_out, out, a=0.54, b=0.38, g=0.2)
	strip(m, h, "lip", lip_out, lip_in, face, a=0.42, b=0.1, g=0.2, tone=0.0)
	strip(m, h, "maw", lip_in, throat, inward, a=0.5, b=0.05, g=0.0, tone=0.0)
	m.plate(h, "maw", throat, (0, 0.04, 0), a=0.5, b=0.0, g=0.0, tone=0.0)
	# the grooved tongue, lolling up out of the dark
	tongue = [(0, -1.86, 5.5), (0, -2.08, 5.12), (0, -2.24, 4.66), (0, -2.2, 4.32)]
	m.path(h, "tongue", tongue, [0.34, 0.5, 0.42, 0.16], [0.09, 0.13, 0.13, 0.07], n=10, a=0.56, b=0.3, g=0.26, tone=0.0)
	m.path(h, "tongue", [(0, -2.2, 5.12), (0, -2.37, 4.66)], [0.05, 0.05], 0.02, n=4, a=0.1, b=0.05, g=0.0, tone=0.0)
	# long thin teeth from the top edge, the middle ones longest; shorter ones up the V of the jaw
	for x, length in ((0.0, 0.98), (0.36, 0.84), (0.72, 0.92), (1.06, 0.7)):
		for s in (1, -1) if x else (1,):
			z = MOUTH_C[1] + 0.94 - 0.2 * max(0.0, x - 0.72)
			m.spike(h, "tooth", (s * x, -2.17, z), (s * x * 0.94, -2.24, z - length), 0.13, flat=0.7, a=0.74, b=0.2, g=0.0, tone=0.0)
	for x, z, length in ((1.14, 5.1, 0.46), (0.92, 4.66, 0.5), (0.58, 4.28, 0.52), (0.22, 4.1, 0.56)):
		for s in (1, -1):
			m.spike(h, "tooth", (s * x, -2.17, z), (s * x * 0.62, -2.25, z + length), 0.11, flat=0.7, a=0.72, b=0.2, g=0.0, tone=0.0)
	# the shell: five thick lobes over the top, curling down onto the upper lip
	for i in range(-2, 3):
		x, r = i * 0.6, 0.36 - 0.015 * abs(i)
		top = 7.08 - 0.13 * abs(i)
		pts = [(x * 0.9, -0.5, top - 0.5), (x, -1.34, top), (x, -2.14, top - 0.3), (x, -2.5, top - 0.86)]
		m.path(h, "hide", pts, [r, r, r * 0.96, r * 0.7], [r * 0.84, r * 0.9, r * 0.88, r * 0.62], n=8, a=0.58, b=0.36, g=0.12)
		m.ell(h, "hide", pts[-1], (r * 0.74, r * 0.66, r * 0.42), rows=4, n=8, a=0.56, b=0.36, g=0.0)


def blotch(m, part, a, c, r, y):
	"""An irregular black patch lying flat on one face of a tendril, long and pointed at both ends."""
	V = m.k.Vector
	off = V((0, y * r * 0.94, 0))
	n = (c - a).cross(V((0, 1, 0))).normalized() * r * 0.74
	pts = [a, a.lerp(c, 0.28) + n * 0.6, a.lerp(c, 0.62) + n, c, a.lerp(c, 0.7) - n * 0.5, a.lerp(c, 0.32) - n * 0.9]
	m.plate(part, "blotch", [q + off for q in pts], (0, 0.05, 0), a=0.5, b=0.1, g=0.0, tone=0.0)


def crest(m):
	"""Long tendrils from the back of the head, fanning out and over, with black patches. The rear ones run black at the root."""
	c, V, math = "Crest", m.k.Vector, m.k.math
	root = V((0, -0.1, 6.0))
	for i, deg in enumerate((-96, -70, -44, -18, 12, 38, 64, 92)):
		a = math.radians(deg)
		d, across = V((math.sin(a), 0, math.cos(a))), V((math.cos(a), 0, -math.sin(a)))
		length = 2.5 + 1.6 * abs(math.sin(a))
		r = 0.42 - 0.02 * (i % 2)
		bend = 1 if deg > 0 else -1
		p = [root + d * 0.3, root + d * (length * 0.42) + V((0, 0.5, 0)), root + d * (length * 0.76) + V((0, 0.9, 0)), root + d * length + across * 0.34 * bend + V((0, 0.76, -0.18))]
		m.path(c, "hide", p, [r * 0.8, r, r * 0.96, r * 0.72], n=8, a=0.56, b=0.36, g=0.1)
		m.ell(c, "hide", tuple(p[-1]), (r * 0.72, r * 0.72, r * 0.72), rows=4, n=8, a=0.56, b=0.36, g=0.0)
		f = 0.18 + 0.1 * (i % 3)
		blotch(m, c, p[1].lerp(p[2], f), p[1].lerp(p[2], f + 0.46), r, -1)
		blotch(m, c, p[2].lerp(p[3], 0.3), p[3], r, -1)
		blotch(m, c, p[0].lerp(p[1], 0.3), p[0].lerp(p[1], 0.9), r, 1)
		blotch(m, c, p[2], p[3], r, 1)
	# the curtain down the back, going black towards the tail
	for x in (-1.1, -0.36, 0.36, 1.1):
		m.path(c, "hide", [(x * 0.7, 0.2, 5.9), (x, 1.2, 5.5), (x * 1.1, 1.5, 4.7)], [0.42, 0.44, 0.4], [0.36, 0.38, 0.36], n=8, a=0.54, b=0.36)
		m.path(c, "black", [(x * 1.1, 1.5, 4.72), (x * 1.08, 1.56, 3.7), (x * 0.7, 1.3, 2.9)], [0.4, 0.38, 0.05], [0.36, 0.34, 0.05], n=8, a=0.46, b=0.42)


def body(m):
	"""Enormous shoulders over a deep ribcage, coming down to the black tail."""
	t, V = "Body", m.k.Vector
	rows = ((5.9, 1.3, 0.8, 0.3), (5.3, 2.14, 1.2, 0.24), (4.5, 2.1, 1.28, 0.16), (3.6, 1.66, 1.14, 0.2), (2.86, 1.2, 0.9, 0.36))
	rings = []
	for z, w, d, y in rows:
		rings.append([(w * c, y + d * q, z) for c, q in ((1, 0.5), (0.62, 1), (-0.62, 1), (-1, 0.5), (-1, -0.5), (-0.62, -1), (0.62, -1), (1, -0.5))])
	m.add(t, "hide", *m._loft(rings), a=0.52, b=0.4, g=0.1, jit=0.02)
	for s in (1, -1):
		m.ell(t, "hide", (s * 1.02, -0.72, 4.84), (1.02, 0.5, 0.66), rows=4, n=8, a=0.6, b=0.36, g=0.1)  # chest
		m.ell(t, "hide", (s * 1.34, -0.56, 3.68), (0.56, 0.5, 0.84), rows=4, n=8, a=0.52, b=0.4, g=0.1)  # flank
		# black patches where the hide gives way to the tail
		m.path(t, "blotch", [(s * 1.08, -0.42, 3.36), (s * 1.18, -0.34, 3.06), (s * 0.96, -0.32, 2.84)], [0.05, 0.12, 0.05], [0.14, 0.3, 0.1], n=6, a=0.5, b=0.1, g=0.0, tone=0.0)
		m.path(t, "blotch", [(s * 1.5, 0.4, 3.6), (s * 1.5, 0.6, 3.26), (s * 1.3, 0.76, 2.96)], [0.05, 0.1, 0.05], [0.14, 0.26, 0.1], n=6, a=0.5, b=0.1, g=0.0, tone=0.0)
	# the belly in shadow, and the ladder of heavy ribs laid over it
	m.block(t, "crease", 0, -0.6, 4.32, 2.86, 1.08, 0.5, ch=0.1, flare=-0.14, a=0.4, b=0.2, g=0.1)
	for i, z in enumerate((4.2, 3.86, 3.52, 3.18, 2.92)):
		w = 1.2 - 0.1 * i
		y = -1.12 + 0.06 * i
		m.path(t, "hide", [(w, y + 0.56, z + 0.1), (w * 0.62, y + 0.1, z), (0, y, z - 0.08), (-w * 0.62, y + 0.1, z), (-w, y + 0.56, z + 0.1)], [0.1, 0.13, 0.13, 0.13, 0.1], [0.11, 0.13, 0.13, 0.13, 0.11], n=6, a=0.6, b=0.36, g=0.0)
	# grey hatching etched in the pale hide
	for x, y, z, dz in ((1.5, -0.96, 5.06, -0.42), (1.2, -1.12, 5.2, -0.36), (-1.42, -1.0, 5.1, -0.4), (-1.08, -1.14, 5.22, -0.3), (1.86, -0.46, 4.2, -0.5), (-1.86, -0.46, 4.2, -0.5)):
		m.path(t, "crease", [V((x, y, z)), V((x + 0.08, y, z + dz))], [0.035, 0.012], 0.03, n=4, a=0.34, b=0.1, g=0.0, tone=0.0)


def tail(m):
	"""No legs: the body runs out into a black trailing wisp, hanging clear below. The lowest point of the model."""
	t = "Tail"
	spine = [(0, 0.36, 3.3), (0.1, 0.72, 2.5), (0.6, 1.06, 1.64), (0.78, 1.14, 0.9), (0.08, 0.92, 0.38), (-1.0, 0.62, 0.16), (-2.1, 0.36, 0.0)]
	m.path(t, "black", spine, [1.12, 0.98, 0.8, 0.66, 0.46, 0.22, 0.01], [0.86, 0.76, 0.64, 0.52, 0.34, 0.16, 0.01], n=8, a=0.46, b=0.44, g=0.1, jit=0.015)
	m.path(t, "black", [(0.8, 1.1, 1.3), (1.5, 1.16, 1.0), (2.2, 1.0, 1.26), (2.5, 0.9, 1.74)], [0.3, 0.2, 0.1, 0.01], n=6, a=0.46, b=0.44)
	m.path(t, "black", [(-0.1, 0.9, 1.4), (-0.86, 1.1, 1.24), (-1.42, 1.1, 1.6)], [0.22, 0.14, 0.01], n=6, a=0.46, b=0.44)


def hand(m, a, wrist, tip, up):
	"""A huge flat palm, four long splayed fingers and a thumb, each ending in a dark pointed nail."""
	V = m.k.Vector
	wrist, tip, up = V(wrist), V(tip), V(up).normalized()
	d = (tip - wrist).normalized()
	across = d.cross(up).normalized()
	# lofted by hand: path() would pick its own width axis, and the palm must spread across the fingers
	rings = [[c + across * w * x + up * th * q for x, q in ((1, 1), (-1, 1), (-1, -1), (1, -1))] for c, w, th in ((wrist, 0.58, 0.38), (wrist.lerp(tip, 0.5), 0.9, 0.36), (tip + d * 0.06, 0.86, 0.3))]
	m.add(a, "hide", *m._loft([[tuple(q) for q in r] for r in rings]), a=0.58, b=0.36, g=0.1)
	for off, splay, length, r in ((-0.64, -0.4, 0.94, 0.25), (-0.22, -0.12, 1.14, 0.26), (0.22, 0.12, 1.14, 0.26), (0.64, 0.4, 0.94, 0.25), (0.82, 1.3, 0.82, 0.28)):
		base = tip + across * off * 1.02 - d * (0.1 if off < 0.8 else 0.5)
		f = (d + across * splay).normalized()
		joint = base + f * length * 0.55 - up * 0.1
		end = base + f * length - up * 0.28
		m.path(a, "hide", [base, joint, end], [r, r * 0.92, r * 0.72], [r * 0.9, r * 0.84, r * 0.66], n=6, a=0.58, b=0.36, g=0.0)
		m.spike(a, "nail", end - f * 0.06, end + f * 0.42 - up * 0.1, r * 0.72, flat=0.72, a=0.5, b=0.36, g=0.0, tone=0.0)


def arm(m, side, shoulder, elbow, wrist, tip, up):
	"""A long heavy arm: a bulging shoulder, ropey upper arm and thick forearm, hatched in grey."""
	a, V = f"{side}Arm", m.k.Vector
	s0, e, w = V(shoulder), V(elbow), V(wrist)
	m.ell(a, "hide", tuple(s0), (1.04, 0.98, 0.94), rows=4, n=10, a=0.56, b=0.38, g=0.1)
	m.path(a, "hide", [s0, s0.lerp(e, 0.55), e], [0.76, 0.76, 0.6], n=8, a=0.54, b=0.38, jit=0.015)
	m.ell(a, "hide", tuple(e), (0.62, 0.62, 0.62), rows=4, n=8, a=0.56, b=0.36, g=0.0)
	m.path(a, "hide", [e, e.lerp(w, 0.45), w], [0.6, 0.72, 0.54], n=8, a=0.56, b=0.38, jit=0.015)
	hand(m, a, wrist, tip, up)
	# grey hatching, offset to the camera side of the limb
	for p, q, r in ((s0, e, 0.76), (e, w, 0.7)):
		for t, off in ((0.34, 0.26), (0.5, -0.22), (0.68, 0.14)):
			c = p.lerp(q, t) + V((0, -r * 0.94, 0)) + V((off, 0, 0))
			along = (q - p).normalized() * 0.34
			m.path(a, "crease", [c - along, c + along], [0.012, 0.035], 0.03, n=4, a=0.34, b=0.1, g=0.0, tone=0.0)


def build(k):
	parts = {
		"Body": ((0, 0.2, 4.0), None),
		"Head": ((0, -0.4, 5.3), "Body"),
		"Crest": ((0, -0.1, 6.0), "Head"),
		"Tail": ((0, 0.36, 3.3), "Body"),
		"LeftArm": ((2.2, 0.05, 5.2), "Body"),
		"RightArm": ((-2.2, -0.05, 5.1), "Body"),
	}
	m = k.Model(ID, RAMPS, parts)
	m.k = k
	head(m)
	crest(m)
	body(m)
	tail(m)
	# the lunge: one arm flung up and out with fingers spread, the other driving low and forward
	arm(m, "Left", (2.2, 0.05, 5.2), (3.34, 0.1, 4.5), (3.82, -0.56, 5.46), (4.06, -0.84, 6.1), (-0.2, -1, 0.1))
	arm(m, "Right", (-2.2, -0.05, 5.1), (-3.08, -0.56, 3.56), (-2.96, -1.5, 2.6), (-2.96, -2.04, 2.0), (0.1, -0.3, 0.8))
	return m
