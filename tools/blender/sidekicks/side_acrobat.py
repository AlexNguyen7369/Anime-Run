# Sidekick side_acrobat: a tall eerie dancer in a wide red hat and long red dress, black hair to the ankles and a fixed lipstick grin. Walks. Source and choices: docs/char_evidence/side_acrobat.md.
ID = "side_acrobat"
NAME = "Acro Silka"

RAMPS = {
	"skin": ["#9484a8", "#beb0cc", "#e2d8ea", "#fff8ff"],
	"line": ["#2c2238", "#443656", "#5c4c70", "#7c6c90"],
	"hair": ["#08080e", "#12121c", "#20202e", "#40405c"],
	"red": ["#4a0410", "#80101e", "#b81c2c", "#e84a4c"],
	"hat": ["#380410", "#640c18", "#941626", "#c83a40"],
	"lip": ["#6c0410", "#a80c1c", "#dc2030", "#ff6868"],
	"tooth": ["#b0a890", "#d8d2be", "#f4f0e2", "#ffffff"],
	"hollow": ["#040208", "#0a0610", "#140c1c", "#241a30"],
}


def plate(m, part, ramp, y, pts, t=0.04, a=0.5, b=0.05):
	m.plate(part, ramp, [(x, y, z) for x, z in pts], (0, t, 0), a=a, b=b, g=0.0)


def head(m):
	h = "Head"
	# a long narrow block face, drawn down to a heavy chin
	m.block(h, "skin", 0, 0, 7.24, 5.0, 0.74, 0.7, ch=0.1, flare=-0.02, mids=(6.2,), jit=0.01, a=0.74, b=0.22)
	m.block(h, "skin", 0, -0.12, 5.2, 4.72, 0.44, 0.52, ch=0.1, a=0.74, b=0.22)
	m.block(h, "skin", 0, 0, 5.0, 4.4, 0.36, 0.36, ch=0.04, a=0.44, b=0.36)
	y = -0.72
	for s in (1, -1):
		plate(m, h, "line", y, [(s * 0.1, 6.66), (s * 0.4, 6.86), (s * 0.7, 6.6), (s * 0.62, 6.2), (s * 0.3, 6.1), (s * 0.1, 6.3)])
		plate(m, h, "hollow", y - 0.03, [(s * 0.16, 6.6), (s * 0.4, 6.76), (s * 0.62, 6.56), (s * 0.56, 6.26), (s * 0.3, 6.18), (s * 0.16, 6.34)])
		plate(m, h, "tooth", y - 0.06, [(s * 0.36, 6.5), (s * 0.43, 6.5), (s * 0.43, 6.42), (s * 0.36, 6.42)], a=0.9)
		for i in range(3):
			z = 6.06 - i * 0.12
			plate(m, h, "line", y - 0.01, [(s * 0.2, z), (s * 0.66, z + 0.1), (s * 0.66, z + 0.05), (s * 0.2, z - 0.05)])
		plate(m, h, "line", y - 0.01, [(s * 0.1, 6.98), (s * 0.5, 6.92), (s * 0.5, 6.97), (s * 0.1, 7.04)])
	m.block(h, "skin", 0, -0.78, 6.5, 5.86, 0.1, 0.16, ch=0.04, flare=0.05, a=0.78, b=0.26)  # long nose
	# the painted grin: red lips curled up the cheeks round two rows of big teeth
	plate(m, h, "lip", y - 0.03, [(-0.7, 6.0), (-0.36, 5.68), (0, 5.58), (0.36, 5.68), (0.7, 6.0), (0.68, 5.6), (0.42, 5.18), (0, 5.02), (-0.42, 5.18), (-0.68, 5.6)], t=0.08, a=0.6)
	plate(m, h, "hollow", y - 0.08, [(-0.62, 5.8), (-0.34, 5.6), (0, 5.5), (0.34, 5.6), (0.62, 5.8), (0.58, 5.56), (0.36, 5.26), (0, 5.12), (-0.36, 5.26), (-0.58, 5.56)])
	for i in range(7):
		x = -0.48 + i * 0.16
		u = (abs(x) / 0.48) ** 2
		top, mid, low = 5.47 + 0.2 * u, 5.3 + 0.24 * u, 5.15 + 0.26 * u
		for z1, z0 in ((top, mid + 0.02), (mid - 0.02, low)):
			plate(m, h, "tooth", y - 0.11, [(x - 0.066, z1), (x + 0.066, z1), (x + 0.066, z0), (x - 0.066, z0)], a=0.78, b=0.1)


def hat(m):
	h = "Hat"
	n = 14
	rings = []
	# one wide drooping brim and a soft low crown
	for r, z in ((0.5, 7.0), (2.0, 6.82), (2.06, 6.9), (1.9, 7.02), (0.96, 7.2), (0.98, 7.6), (0.82, 7.9), (0.4, 7.98)):
		rings.append([(r * m_cos(i, n), r * 0.94 * m_sin(i, n) + 0.04, z + 0.26 - 0.1 * r * m_sin(i, n)) for i in range(n)])
	m.add(h, "hat", *m._loft(rings), a=0.5, b=0.44)
	rings = [[(r * m_cos(i, n), r * 0.94 * m_sin(i, n) + 0.04, z - 0.1 * r * m_sin(i, n)) for i in range(n)] for r, z in ((1.0, 7.44), (1.04, 7.48), (1.03, 7.66), (0.98, 7.68))]
	m.add(h, "hollow", *m._loft(rings), a=0.6, b=0.3)


def m_cos(i, n):
	import math

	return math.cos(2 * math.pi * i / n)


def m_sin(i, n):
	import math

	return math.sin(2 * math.pi * i / n)


def hair(m):
	h = "Hair"
	m.block(h, "hair", 0, 0.14, 7.34, 5.8, 0.86, 0.74, ch=0.08, a=0.5, b=0.4)
	for s in (1, -1):
		# two straight front curtains either side of the face
		m.path(h, "hair", [(s * 0.78, -0.5, 7.0), (s * 0.92, -0.7, 5.6), (s * 0.94, -0.84, 4.2), (s * 0.92, -0.9, 2.5)], [0.2, 0.24, 0.24, 0.02], [0.16, 0.18, 0.16, 0.02], n=6, a=0.54, b=0.5)
		m.path(h, "hair", [(s * 0.86, 0.0, 7.0), (s * 1.06, -0.1, 5.4), (s * 1.2, -0.2, 3.8), (s * 1.26, -0.1, 1.9)], [0.36, 0.4, 0.4, 0.02], [0.2, 0.22, 0.2, 0.02], n=6, a=0.5, b=0.5)
	# the long fall down the back to the ankles, its ends lifting
	for i, (x, tx, tz, ty) in enumerate(((-0.7, -1.3, 0.5, 1.5), (-0.35, -0.7, 0.2, 1.3), (0.0, 0.1, 0.36, 1.7), (0.35, 0.8, 0.2, 1.36), (0.7, 1.4, 0.56, 1.6))):
		m.path(h, "hair", [(x, 0.6, 6.9), (x * 1.2, 0.86, 5.0), (x * 1.3, 0.9, 2.8), (tx * 0.9, ty * 0.8, 1.2), (tx, ty, tz)], [0.34, 0.42, 0.44, 0.34, 0.02], [0.24, 0.24, 0.22, 0.18, 0.02], n=6, a=0.48, b=0.5, jit=0.012)
	# two free whips of hair, her weapon, curling out low at the sides
	for n, s in (("HairWhipLeft", 1), ("HairWhipRight", -1)):
		m.path(n, "hair", [(s * 0.8, 0.9, 3.4), (s * 1.4, 1.1, 2.4), (s * 2.1, 1.0, 1.7), (s * 2.7, 0.8, 1.9), (s * 2.9, 0.6, 2.5), (s * 2.6, 0.5, 2.8)], [0.4, 0.38, 0.32, 0.24, 0.14, 0.02], [0.24, 0.24, 0.22, 0.18, 0.12, 0.02], n=6, a=0.5, b=0.5, jit=0.012)


def torso(m):
	t = "Torso"
	m.block(t, "red", 0, 0, 4.5, 2.7, 1.06, 0.6, ch=0.08, jit=0.015, mids=(3.6,), a=0.52, b=0.44)
	m.block(t, "red", 0, 0, 4.72, 4.36, 0.6, 0.52, ch=0.06, a=0.56, b=0.42)  # high neck
	m.block(t, "hat", 0, 0, 3.06, 2.84, 1.09, 0.64, ch=0.03, a=0.5, b=0.4)
	for i, z in enumerate((4.2, 3.86, 3.52)):
		m.block(t, "hat", 0, -0.62, z + 0.07, z - 0.07, 0.07, 0.04, ch=0.02, a=0.6, b=0.3)
	# the skirt: a long bell with deep folds, cut at the shin
	n = 24
	rings = []
	for z, hw, hd, amp in ((2.94, 1.04, 0.6, 0.0), (2.3, 1.16, 0.78, 0.04), (1.4, 1.34, 1.0, 0.08), (0.72, 1.5, 1.16, 0.1), (0.66, 1.42, 1.08, 0.1)):
		ring = []
		for j in range(n):
			c, s = m_cos(j, n), m_sin(j, n)
			p = 1 + (amp if j % 2 else -amp)
			ring.append((hw * p * (abs(c) ** 0.6) * (1 if c >= 0 else -1), hd * p * (abs(s) ** 0.6) * (1 if s >= 0 else -1), z))
		rings.append(ring)
	m.add("Skirt", "red", *m._loft(rings), a=0.5, b=0.5, g=0.14)


def build(k):
	parts = {
		"Torso": ((0, 0, 3), None),
		"Head": ((0, 0, 4.6), "Torso"),
		"Hat": ((0, 0, 7.0), "Head"),
		"Hair": ((0, 0, 6.6), "Head"),
		"HairWhipLeft": ((0.8, 0.9, 3.4), "Head"),
		"HairWhipRight": ((-0.8, 0.9, 3.4), "Head"),
		"Skirt": ((0, 0, 2.9), "Torso"),
		"LeftArm": ((1.5, 0, 4.2), "Torso"),
		"RightArm": ((-1.5, 0, 4.2), "Torso"),
		"LeftLeg": ((0.5, 0, 2.0), "Torso"),
		"RightLeg": ((-0.5, 0, 2.0), "Torso"),
	}
	# a dancer's open arms
	m = k.Model(ID, RAMPS, parts, {"LeftArm": (-14, -30, 0), "RightArm": (-14, 30, 0)})
	head(m)
	hat(m)
	hair(m)
	torso(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		a, x = f"{side}Arm", s * 1.5
		m.block(a, "red", x, 0, 4.48, 2.5, 0.5, 0.5, ch=0.08, flare=0.06, jit=0.015, mids=(3.5,), a=0.52, b=0.44)
		m.block(a, "hat", x, 0, 2.6, 2.4, 0.6, 0.6, ch=0.03, a=0.5, b=0.4)
		m.block(a, "skin", x, 0, 2.5, 1.86, 0.46, 0.46, ch=0.06, a=0.56, b=0.36)
		l, lx = f"{side}Leg", s * 0.52
		m.block(l, "skin", lx, 0, 1.6, 0.16, 0.44, 0.44, ch=0.05, a=0.5, b=0.38)
		m.block(l, "skin", lx, -0.2, 0.3, 0.0, 0.46, 0.66, ch=0.07, a=0.56, b=0.38)
	return m
