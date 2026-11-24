# Sidekick side_shaman, Tuskar: a hulking hooded orc shaman made of violet shadow, two big tusks, a bone mantle, a skull-topped staff. Walks. Evidence: docs/char_evidence/side_shaman.md.
ID = "side_shaman"
NAME = "Tuskar"
RAMPS = {
	"dark": ["#08070e", "#14121e", "#241f34", "#42395a"],
	"robe": ["#160f28", "#281c46", "#412f6c", "#674e9c"],
	"hide": ["#0e0d1a", "#1d1a30", "#322c4e", "#574d80"],
	"bone": ["#6a6480", "#9a94b0", "#ccc6dc", "#f4f0ff"],
	"glow": ["#6a3cf0", "#9064ff", "#b698ff", "#e6dcff"],
	"wood": ["#1a1422", "#30263c", "#4c3e58", "#70607c"],
}
NEON = ("HeadNeon", "StaffNeon")


def build(k):
	import sidekick_solid

	parts = {"Torso": ((0, 0, 3), None), "Head": ((0, 0, 4.1), "Torso"), "HeadNeon": ((0, 0, 4.1), "Head"), "LeftArm": ((1.7, 0, 3.9), "Torso"), "RightArm": ((-1.7, 0, 3.9), "Torso"), "LeftLeg": ((0.6, 0, 2), "Torso"), "RightLeg": ((-0.6, 0, 2), "Torso"), "Staff": ((-1.7, -0.6, 2), "RightArm"), "StaffNeon": ((-1.7, -0.6, 2), "Staff")}
	m = k.Model(ID, RAMPS, parts, neon=NEON)
	sidekick_solid.solid_blocks(m)
	h = "Head"
	m.block(h, "hide", 0, -0.1, 5.2, 4.0, 0.9, 0.84, ch=0.12, jit=0.015, a=0.54)
	# hood with a deep peak
	m.block(h, "robe", 0, 0.16, 5.6, 4.2, 1.06, 0.86, ch=0.2, flare=0.1, jit=0.02)
	m.path(h, "robe", [(0, -0.3, 5.4), (0, 0.4, 5.96), (0, 1.1, 5.9)], [0.9, 0.6, 0.02], [0.4, 0.4, 0.02], n=6)
	m.plate(h, "robe", [(-1.1, -0.8, 4.4), (-1.0, -0.9, 5.2), (-0.5, -0.96, 5.56), (0, -1.0, 5.7), (0.5, -0.96, 5.56), (1.0, -0.9, 5.2), (1.1, -0.8, 4.4), (0.84, -0.96, 4.9), (0, -1.06, 5.24), (-0.84, -0.96, 4.9)], (0, 0.2, 0), a=0.58)
	m.block(h, "hide", 0, -0.5, 4.56, 4.0, 0.74, 0.54, ch=0.1, a=0.6)
	for s in (1, -1):
		m.plate("HeadNeon", "glow", [(s * 0.2, -0.97, 4.76), (s * 0.66, -0.97, 4.94), (s * 0.66, -0.97, 4.8), (s * 0.24, -0.97, 4.66)], (0, 0.03, 0), a=0.9, b=0.0)
		m.path(h, "bone", [(s * 0.46, -0.96, 4.2), (s * 0.66, -1.36, 4.4), (s * 0.7, -1.4, 5.0)], [0.19, 0.16, 0.01], [0.19, 0.16, 0.01], n=6, a=0.6)
	t = "Torso"
	m.block(t, "dark", 0, 0, 4.06, 2.0, 1.24, 0.74, ch=0.1)
	m.block(t, "robe", 0, 0, 3.4, 1.7, 1.2, 0.8, ch=0.06, flare=0.2, jit=0.03, mids=(2.6,))
	m.block(t, "hide", 0, 0.06, 4.24, 3.5, 1.46, 0.92, ch=0.2, jit=0.03)
	for i in range(7):
		x = -0.9 + 0.3 * i
		m.spike(t, "bone", (x, -0.9, 3.66 - 0.12 * (3 - abs(i - 3))), (x * 1.02, -1.0, 3.06 - 0.14 * (3 - abs(i - 3))), 0.12, a=0.6)
	m.block(t, "wood", 0, 0, 2.5, 2.24, 1.32, 0.9, ch=0.05)
	for s, side in ((1, "Left"), (-1, "Right")):
		a, x = f"{side}Arm", s * 1.76
		m.block(a, "hide", x, 0, 4.0, 2.2, 0.6, 0.6, ch=0.1, jit=0.02)
		m.block(a, "robe", x, 0, 4.2, 3.0, 0.7, 0.7, ch=0.16, flare=0.06, jit=0.02)
		m.block(a, "wood", x, 0, 2.8, 2.5, 0.65, 0.65, ch=0.04)
		m.block(a, "hide", x, 0, 2.34, 1.7, 0.62, 0.62, ch=0.1, a=0.6)
		m.spike(a, "bone", (x + s * 0.3, 0, 4.0), (x + s * 0.9, 0.1, 4.8), 0.22)
		l, lx = f"{side}Leg", s * 0.64
		m.block(l, "hide", lx, 0, 2.0, 0.0, 0.52, 0.56, ch=0.06)
		m.block(l, "robe", lx, 0, 1.9, 0.5, 0.6, 0.72, ch=0.05, flare=0.1, jit=0.03)
		m.block(l, "hide", lx, -0.2, 0.36, 0.0, 0.56, 0.74, ch=0.08, a=0.6)
	s, x, y = "Staff", -1.76, -0.8
	m.path(s, "wood", [(x, y, 0.1), (x - 0.06, y, 2.4), (x, y, 5.0)], [0.12, 0.13, 0.14], [0.12, 0.13, 0.14], n=6)
	m.block(s, "bone", x, y, 5.8, 5.1, 0.42, 0.4, ch=0.12, a=0.6)
	m.block(s, "bone", x, y - 0.1, 5.2, 4.9, 0.28, 0.28, ch=0.06)
	for d in (1, -1):
		m.path(s, "bone", [(x + d * 0.34, y, 5.6), (x + d * 0.8, y, 5.9), (x + d * 0.7, y - 0.1, 6.5)], [0.15, 0.13, 0.01], [0.15, 0.13, 0.01], n=6)
		m.plate("StaffNeon", "glow", [(x + d * 0.1, y - 0.43, 5.5), (x + d * 0.3, y - 0.43, 5.54), (x + d * 0.28, y - 0.43, 5.32), (x + d * 0.12, y - 0.43, 5.32)], (0, 0.03, 0), a=0.9, b=0.0)
	m.spike("StaffNeon", "glow", (x, y, 5.84), (x + 0.1, y, 6.9), 0.24, a=0.7)
	return m
