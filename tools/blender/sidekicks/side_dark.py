# Sidekick side_dark, Darkness Devill: a tall cloaked shadow crowned with a cluster of pale blank faces, many long hands reaching from the cloak, a black sword. Flies. No gore. Evidence: docs/char_evidence/side_dark.md.
ID = "side_dark"
NAME = "Darkness Devill"
RAMPS = {
	"cloak": ["#040408", "#0c0c14", "#1a1a26", "#363648"],
	"skin": ["#4e4e5c", "#7c7c8a", "#acacb8", "#dcdce6"],
	"face": ["#7a7a86", "#a8a8b4", "#d4d4dc", "#ffffff"],
	"void": ["#020204", "#050508", "#08080e", "#101018"],
	"blade": ["#101018", "#24242e", "#484856", "#8c8c9c"],
}


def mask(m, part, x, y, z, r):
	m.block(part, "face", x, y, z + r * 1.15, z - r * 1.15, r * 0.86, r * 0.6, ch=r * 0.3, a=0.6, b=0.36)
	for s in (1, -1):
		m.plate(part, "void", [(x + s * r * 0.16, y - r * 0.64, z + r * 0.4), (x + s * r * 0.62, y - r * 0.64, z + r * 0.36), (x + s * r * 0.5, y - r * 0.64, z + r * 0.02), (x + s * r * 0.2, y - r * 0.64, z + r * 0.06)], (0, 0.03, 0), a=0.3, b=0.0)
	m.plate(part, "void", [(x - r * 0.24, y - r * 0.64, z - r * 0.4), (x + r * 0.24, y - r * 0.64, z - r * 0.4), (x + r * 0.14, y - r * 0.64, z - r * 0.78), (x - r * 0.14, y - r * 0.64, z - r * 0.78)], (0, 0.03, 0), a=0.3, b=0.0)


def build(k):
	import sidekick_solid

	parts = {"Torso": ((0, 0, 3.4), None), "Head": ((0, 0, 5.0), "Torso"), "LeftArm": ((1.3, 0, 4.5), "Torso"), "RightArm": ((-1.3, 0, 4.5), "Torso"), "HandsLeft": ((0.9, 0.2, 3.2), "Torso"), "HandsRight": ((-0.9, 0.2, 3.2), "Torso"), "Sword": ((-2.1, -0.8, 2.9), "RightArm")}
	m = k.Model(ID, RAMPS, parts)
	sidekick_solid.solid_blocks(m)
	h = "Head"
	m.block(h, "cloak", 0, 0.1, 6.5, 4.8, 0.8, 0.7, ch=0.2, jit=0.03)
	# the crown of faces, the largest at the front
	mask(m, h, 0, -0.5, 5.7, 0.62)
	for x, y, z, r in ((0.84, -0.2, 6.1, 0.46), (-0.84, -0.2, 6.1, 0.46), (0, -0.2, 6.84, 0.48), (0.66, 0.0, 6.96, 0.36), (-0.66, 0.0, 6.96, 0.36), (0.86, -0.1, 5.2, 0.34), (-0.86, -0.1, 5.2, 0.34), (1.3, 0.1, 6.6, 0.3), (-1.3, 0.1, 6.6, 0.3), (0.2, 0.1, 7.6, 0.34)):
		mask(m, h, x, y, z, r)
	for s in (1, -1):
		m.path(h, "cloak", [(s * 0.6, 0.3, 6.6), (s * 1.3, 0.4, 7.4), (s * 1.5, 0.3, 8.2)], [0.26, 0.2, 0.01], [0.2, 0.16, 0.01], n=6)
	t = "Torso"
	m.block(t, "cloak", 0, 0.06, 4.9, 2.4, 1.16, 0.66, ch=0.16, flare=0.26, mids=(4.0, 3.2), jit=0.05)
	for i, (x, z) in enumerate(((-1.2, 0.5), (-0.6, 0.0), (0, 0.4), (0.6, -0.1), (1.2, 0.5))):
		for y in (-0.5, 0.6):
			m.path(t, "cloak", [(x, y * 0.8, 2.9), (x * 1.16, y, 1.6), (x * 1.2, y * 1.1, z + 0.1 * (i % 2))], [0.5, 0.4, 0.01], [0.3, 0.24, 0.01], n=5, jit=0.02)
	for i in range(4):
		z = 4.4 - i * 0.44
		for s in (1, -1):
			m.plate(t, "skin", [(s * 0.08, -0.74 - 0.04 * i, z), (s * 0.6, -0.74 - 0.04 * i, z - 0.1), (s * 0.54, -0.74 - 0.04 * i, z - 0.24), (s * 0.08, -0.74 - 0.04 * i, z - 0.16)], (0, 0.1, 0), a=0.5)
	for s, side in ((1, "Left"), (-1, "Right")):
		a = f"{side}Arm"
		m.block(a, "cloak", s * 1.44, 0, 4.9, 4.0, 0.5, 0.6, ch=0.16, jit=0.03)
		m.path(a, "skin", [(s * 1.5, 0, 4.4), (s * 2.0, -0.1, 3.7), (s * 2.1, -0.7, 2.9)], [0.28, 0.23, 0.2], [0.28, 0.23, 0.2], n=6)
		m.block(a, "skin", s * 2.1, -0.8, 3.04, 2.6, 0.3, 0.3, ch=0.08, a=0.6)
		g = f"Hands{side}"
		for j, (x1, z1, x2, z2) in enumerate(((2.1, 3.6, 2.9, 4.4), (2.0, 2.6, 2.8, 2.3), (1.7, 4.4, 2.3, 5.6))):
			m.path(g, "skin", [(s * 0.9, 0.4, 3.4), (s * x1, 0.5, z1), (s * x2, 0.2, z2)], [0.2, 0.17, 0.14], [0.2, 0.17, 0.14], n=6, a=0.44)
			m.block(g, "skin", s * x2, 0.14, z2 + 0.2, z2 - 0.2, 0.22, 0.24, ch=0.07, a=0.54)
	s, x, y = "Sword", -2.1, -0.94
	m.path(s, "cloak", [(x, y, 2.3), (x, y, 3.3)], 0.09, 0.09, n=6)
	m.block(s, "blade", x, y, 3.4, 3.26, 0.34, 0.1, ch=0.03)
	m.plate(s, "blade", [(x - 0.14, y, 3.4), (x + 0.14, y, 3.4), (x + 0.12, y, 6.6), (x, y, 7.1), (x - 0.14, y, 6.5)], (0, 0.07, 0), a=0.56)
	return m
