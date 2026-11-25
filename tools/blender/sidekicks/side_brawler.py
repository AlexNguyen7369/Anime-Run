# Sidekick side_brawler: a hulking crimson fighting kaiju with a split dome head, one long forward horn, a wide grin of square teeth, a pink core in the chest, shoulder spikes, huge fists and a ringed tail. Walks. Source and choices: docs/char_evidence/side_brawler.md.
ID = "side_brawler"
NAME = "Kaijo No. 10"

RAMPS = {
	"red": ["#560c0a", "#8e1a14", "#c02c20", "#e2543e"],
	"plate": ["#300604", "#560c0a", "#80160f", "#a82c20"],
	"deep": ["#160404", "#2a0806", "#420e0a", "#5c1a14"],
	"tooth": ["#7c8478", "#b4b8a4", "#dcdcc8", "#fbfbf0"],
	"eye": ["#b8e8e0", "#e0fff8", "#f4fffc", "#ffffff"],
	"core": ["#a01c6c", "#e03c9c", "#ff78c4", "#ffd0ec"],
	"ink": ["#040304", "#0a0808", "#120e0e", "#1c1616"],
}


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


def head(m):
	h = "Head"
	# a tall dome split down the middle, flaring out behind
	box(m, h, "red", 0, 0.16, 6.2, 4.94, 1.14, 1.0, ch=0.3, mids=(5.6,), jit=0.02, a=0.52, b=0.42)
	box(m, h, "plate", 0, 0.9, 6.0, 5.1, 0.86, 0.46, ch=0.2, jit=0.02, a=0.48, b=0.4)
	for s in (1, -1):
		# each half of the visor is its own plate; the gap between them is the single eye
		m.plate(h, "red", [(s * 0.07, -0.94, 6.1), (s * 0.6, -0.94, 6.06), (s * 1.1, -0.94, 5.6), (s * 1.18, -0.94, 5.14), (s * 0.5, -0.94, 4.98), (s * 0.18, -0.94, 4.98)], (0, 0.24, 0), a=0.56, b=0.4, g=0.2)
		# the dark glossy side window under the visor
		m.plate(h, "ink", [(s * 1.16, -0.6, 5.36), (s * 1.16, 0.5, 5.6), (s * 1.16, 0.6, 5.3), (s * 1.16, -0.6, 5.08)], (0.08, 0, 0), a=0.6, b=0.2)
		m.plate(h, "plate", [(s * 0.6, 1.06, 6.0), (s * 1.12, 0.6, 5.8), (s * 1.3, 1.1, 5.2), (s * 0.7, 1.5, 5.3)], (0.04, 0.1, 0.1), a=0.5, b=0.4)
	m.plate(h, "ink", [(-0.2, -0.84, 5.9), (0.2, -0.84, 5.9), (0.4, -0.84, 4.96), (-0.4, -0.84, 4.96)], (0, 0.08, 0), a=0.4, b=0.1)
	m.plate(h, "eye", [(0, -0.99, 5.56), (0.17, -0.99, 5.02), (0.1, -0.99, 4.92), (-0.1, -0.99, 4.92), (-0.17, -0.99, 5.02)], (0, 0.06, 0), a=0.9, b=0, g=0)
	# the one long horn off the crown, sweeping forward and up
	m.path(h, "red", [(0, 0.1, 6.0), (0, -0.44, 6.5), (0, -1.0, 7.1), (0, -1.3, 7.9), (0, -1.34, 8.5)], [0.46, 0.42, 0.3, 0.17, 0.01], [0.56, 0.46, 0.32, 0.18, 0.01], n=6, a=0.54, b=0.42)
	# the lower face: a dark gap, the wide grin of square teeth, a heavy jaw
	box(m, h, "ink", 0, 0.1, 5.02, 4.4, 1.0, 0.92, ch=0.06, a=0.4, b=0.2)
	box(m, h, "plate", 0, 0.1, 4.98, 4.8, 1.06, 0.98, ch=0.04, a=0.46, b=0.4)
	for i in range(-4, 5):
		x = i * 0.205
		y = -0.88 + 0.016 * abs(i)
		box(m, h, "tooth", x, y, 4.8, 4.56, 0.09, 0.07, ch=0.03, a=0.62, b=0.3)
		box(m, h, "tooth", x, y, 4.53, 4.32, 0.09, 0.07, ch=0.03, a=0.54, b=0.3)
	for s in (1, -1):
		for y in (-0.7, -0.49, -0.28):
			box(m, h, "tooth", s * 0.99, y, 4.78, 4.56, 0.06, 0.09, ch=0.02, a=0.58, b=0.3)
			box(m, h, "tooth", s * 0.99, y, 4.53, 4.32, 0.06, 0.09, ch=0.02, a=0.52, b=0.3)
	box(m, h, "red", 0, 0.04, 4.36, 4.02, 0.9, 0.84, ch=0.1, jit=0.015, a=0.48, b=0.42)
	box(m, h, "plate", 0, -0.7, 4.3, 4.06, 0.5, 0.2, ch=0.07, a=0.54, b=0.4)


def torso(m):
	t = "Torso"
	box(m, t, "red", 0, 0.04, 4.2, 2.2, 1.4, 0.78, ch=0.16, flare=-0.14, mids=(3.4, 2.8), jit=0.02, a=0.48, b=0.4)
	box(m, t, "deep", 0, 0, 4.36, 3.9, 0.8, 0.66, ch=0.08, a=0.5, b=0.4)
	y = -0.8
	for s in (1, -1):
		m.plate(t, "red", [(s * 0.1, y, 4.1), (s * 1.3, y, 4.16), (s * 1.4, y, 3.5), (s * 0.9, y, 3.2), (s * 0.34, y, 3.24), (s * 0.1, y, 3.5)], (0, 0.26, 0), a=0.56, b=0.4, g=0.24)
		for i, z in enumerate((3.14, 2.86, 2.58)):
			m.plate(t, "plate", [(s * 0.04, y + 0.04, z), (s * 0.56, y + 0.04, z + 0.04), (s * 0.54, y + 0.04, z - 0.22), (s * 0.04, y + 0.04, z - 0.24)], (0, 0.18, 0), a=0.54, b=0.4)
			m.plate(t, "plate", [(s * 0.62, y + 0.1, z + 0.06), (s * 1.2, y + 0.1, z + 0.16), (s * 1.16, y + 0.1, z - 0.1), (s * 0.62, y + 0.1, z - 0.18)], (0, 0.16, 0), a=0.48, b=0.4)
		m.plate(t, "plate", [(s * 0.06, 0.78, 4.2), (s * 1.3, 0.78, 4.1), (s * 1.2, 0.78, 3.0), (s * 0.5, 0.78, 2.5), (s * 0.06, 0.78, 2.5)], (0, 0.2, 0), a=0.5, b=0.4, g=0.2)
	# the exposed pink core, cracked open at the breastbone
	m.plate(t, "ink", [(0, y - 0.06, 3.86), (0.26, y - 0.06, 3.62), (0.2, y - 0.06, 3.3), (0, y - 0.06, 3.16), (-0.2, y - 0.06, 3.3), (-0.26, y - 0.06, 3.62)], (0, 0.16, 0), a=0.4, b=0.1)
	m.ell(t, "core", (0, y - 0.1, 3.52), (0.18, 0.14, 0.26), rows=4, n=6, a=0.62, b=0.36, g=0)
	for i, z in enumerate((4.0, 3.4, 2.8)):
		m.spike(t, "red", (0, 0.8, z), (0, 1.3, z + 0.2), 0.22, flat=0.6, a=0.54)
	box(m, t, "red", 0, 0, 2.4, 1.86, 1.04, 0.68, ch=0.1, jit=0.015, a=0.46, b=0.4)
	m.plate(t, "plate", [(-0.4, -0.7, 2.36), (0.4, -0.7, 2.36), (0.26, -0.7, 1.8), (-0.26, -0.7, 1.8)], (0, 0.14, 0), a=0.54, b=0.4)


def arm(m, side, s):
	a, x = f"{side}Arm", s * 1.92
	box(m, a, "red", x, 0, 4.4, 3.4, 0.76, 0.76, ch=0.22, mids=(3.9,), jit=0.02, a=0.52, b=0.42)
	m.spike(a, "red", (x + s * 0.24, 0.1, 4.2), (x + s * 0.62, 0.2, 5.1), 0.32, flat=0.8, a=0.56)
	m.spike(a, "plate", (x - s * 0.2, 0.3, 4.2), (x - s * 0.1, 0.5, 4.8), 0.24, flat=0.8, a=0.52)
	box(m, a, "deep", x, 0, 3.5, 2.9, 0.54, 0.54, ch=0.05, a=0.5, b=0.4)
	box(m, a, "plate", x, -0.1, 3.46, 2.96, 0.6, 0.56, ch=0.1, jit=0.015, a=0.5, b=0.4)
	box(m, a, "red", x, 0, 2.94, 2.0, 0.68, 0.68, ch=0.1, flare=0.1, jit=0.02, a=0.52, b=0.42)
	for z in (2.76, 2.42):
		m.plate(a, "deep", [(x - 0.6, -0.78, z), (x, -0.8, z - 0.16), (x + 0.6, -0.78, z), (x + 0.6, -0.78, z - 0.06), (x, -0.8, z - 0.22), (x - 0.6, -0.78, z - 0.06)], (0, 0.14, 0), a=0.5, b=0.1)
	m.spike(a, "red", (x + s * 0.5, 0.3, 2.8), (x + s * 1.0, 0.6, 3.2), 0.24, flat=0.7, a=0.54)
	# the huge plain block fist
	box(m, a, "red", x, -0.06, 2.0, 1.06, 0.84, 0.84, ch=0.12, jit=0.015, a=0.54, b=0.42)
	box(m, a, "plate", x, -0.86, 1.86, 1.5, 0.72, 0.1, ch=0.06, a=0.58, b=0.4)


def leg(m, side, s):
	l, x = f"{side}Leg", s * 0.74
	box(m, l, "red", x, 0, 2.0, 1.06, 0.66, 0.72, ch=0.1, jit=0.02, a=0.5, b=0.42)
	m.plate(l, "plate", [(x - 0.46, -0.72, 1.9), (x + 0.46, -0.72, 1.9), (x + 0.36, -0.72, 1.2), (x - 0.36, -0.72, 1.2)], (0, 0.16, 0), a=0.54, b=0.4)
	box(m, l, "plate", x, -0.5, 1.2, 0.86, 0.4, 0.3, ch=0.08, a=0.58, b=0.4)
	box(m, l, "deep", x, 0.04, 1.1, 0.8, 0.54, 0.56, ch=0.04, a=0.5, b=0.4)
	box(m, l, "red", x, 0.04, 0.96, 0.3, 0.58, 0.62, ch=0.08, flare=0.06, jit=0.015, a=0.5, b=0.42)
	box(m, l, "red", x, -0.2, 0.46, 0, 0.66, 0.84, ch=0.12, a=0.54, b=0.42)
	for dx in (-0.4, 0, 0.4):
		m.spike(l, "plate", (x + dx, -0.9, 0.2), (x + dx, -1.4, 0.02), 0.2, flat=0.8, a=0.56)


def tail(m):
	"""Ringed and tapering, out behind and to the viewer's right, small spikes along its top."""
	t = "Tail"
	V = type(m.light)
	pts = [V(p) for p in ((0, 0.5, 2.0), (0.5, 1.4, 1.5), (1.2, 2.1, 1.0), (2.1, 2.5, 0.8), (2.9, 2.5, 1.1), (3.4, 2.3, 1.7))]
	rad = [0.56, 0.5, 0.42, 0.33, 0.24, 0.06]
	for i in range(5):
		for j in range(2):
			p, q = pts[i].lerp(pts[i + 1], j / 2), pts[i].lerp(pts[i + 1], (j + 1) / 2 - 0.06)
			r0, r1 = rad[i] + (rad[i + 1] - rad[i]) * j / 2, rad[i] + (rad[i + 1] - rad[i]) * (j + 1) / 2
			m.path(t, "red" if j else "plate", [p, q], [r0 * 1.02, r1 * 1.1], n=8, a=0.52, b=0.42)
			if i < 4:
				m.spike(t, "red", p + V((0, 0, r0 * 0.8)), p + V((0.1, 0.1, r0 + 0.36)), 0.16, flat=0.6, a=0.56)
	m.path(t, "deep", pts, [r * 0.8 for r in rad], n=8, a=0.5, b=0.3)


def build(k):
	parts = {
		"Torso": ((0, 0, 3), None),
		"Head": ((0, 0, 4.1), "Torso"),
		"LeftArm": ((1.92, 0, 4.0), "Torso"),
		"RightArm": ((-1.92, 0, 4.0), "Torso"),
		"LeftLeg": ((0.74, 0, 2.0), "Torso"),
		"RightLeg": ((-0.74, 0, 2.0), "Torso"),
		"Tail": ((0, 0.6, 2.0), "Torso"),
	}
	m = k.Model(ID, RAMPS, parts)
	head(m)
	torso(m)
	tail(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm(m, side, s)
		leg(m, side, s)
	return m
