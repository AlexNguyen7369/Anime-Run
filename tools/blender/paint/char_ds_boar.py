# Painted look for ds_boar: modelled boar head worn as a mask, bare muscled chest, fur belt, wide trousers, two saw blades.
import math

from atlas import INK, paint_hair, shade
from ds_common import L, coat, ell, hand, panels, shades, tip_tone

SKIN = "#f3d3bb"
SKIN_D = shade(SKIN, 0.66)
FUR = "#5F6E86"
FUR_L = "#8c9ab0"
FUR_D = "#333c50"
PELT = "#7A5F42"
PANTS = "#35465e"
PANTS_L = "#6c84a4"
STEEL = "#A4AEBA"
STEEL_D = "#737E8C"
DEFAULT = SKIN
HAIR_COLOURS = [FUR, PELT]

# mask rings: y, half width, half height, centre z, front to back; the snout is first
RINGS = [(-1.26, 0.3, 0.26, 4.4), (-1.2, 0.42, 0.36, 4.41), (-1.02, 0.47, 0.42, 4.46), (-0.8, 0.62, 0.56, 4.58), (-0.6, 0.86, 0.74, 4.72), (-0.25, 0.94, 0.82, 4.78), (0.25, 0.92, 0.82, 4.8), (0.68, 0.76, 0.72, 4.8), (0.96, 0.46, 0.46, 4.82)]
fx = lambda x: (x + 1) * 65
fy = lambda z: (5.62 - z) * 78.8


def _ear(x, z, y=0.1, r=0.25):
	return L([x, y, z], [x * 1.3, y - 0.02, z + 0.26], [x * 1.45, y + 0.05, z + 0.52], r, flatten=0.4, colour=FUR)


HAIR = {
	"colour": FUR,
	"locks": [
		# mane: bristles along the crown, to the nape
		*[L([s * 0.2, y, z], [s * 0.3, y + 0.14, z + 0.3], [s * 0.34, y + 0.34, z + 0.42], 0.18) for y, z in ((-0.52, 5.34), (-0.2, 5.52), (0.14, 5.56), (0.46, 5.46), (0.74, 5.18)) for s in (-1, 1)],
		*[L([0, y, z], [0, y + 0.16, z + 0.36], [0, y + 0.38, z + 0.46], 0.18) for y, z in ((-0.42, 5.42), (-0.08, 5.56), (0.28, 5.56), (0.62, 5.34), (0.9, 4.96))],
		# cheek and jowl bristles, and the ragged edge of the hide round the neck
		*[L([x, y, z], [x * 1.16, y + 0.06, z - 0.26], [x * 1.3, y + 0.14, z - 0.5], 0.2, mirror=True) for x, y, z in ((0.82, -0.42, 4.5), (0.86, -0.08, 4.42), (0.84, 0.32, 4.44), (0.68, 0.66, 4.5))],
		*[L([x, -0.62, 4.16], [x * 1.1, -0.72, 3.96], [x * 1.14, -0.74, 3.74], 0.2, mirror=True) for x in (0.2, 0.52)],
		*[L([x, 0.62, 4.3], [x * 1.1, 0.74, 3.96], [x * 1.14, 0.7, 3.62], 0.24) for x in (-0.5, -0.17, 0.17, 0.5)],
		# whisker bristles along the upper side of the head
		*[L([0.84, y, 5.08], [1.06, y + 0.06, 5.22], [1.2, y + 0.16, 5.26], 0.16, mirror=True) for y in (-0.3, 0.1, 0.46)],
	],
}


def _saw(sgn):
	"""A chipped saw blade held out and down: a tapered back with convex teeth along its outer edge."""
	side = "Left" if sgn > 0 else "Right"
	x0, z0, dx, dz, length = sgn * 1.72, 1.86, sgn * 0.6, -0.8, 1.95
	nx, nz = -dz * sgn, dx * sgn
	pt = lambda t, w: (x0 + dx * t + nx * w, z0 + dz * t + nz * w)
	part = f"{side}Hand"
	out = [{"part": part, "blade": [pt(0, -0.07), pt(length * 0.9, -0.05), pt(length, 0.06), pt(length * 0.9, 0.14), pt(0, 0.2)], "y": (-0.08, -0.02), "colour": STEEL}]
	for i in range(7):
		t = 0.12 + i * 0.25
		h = 0.1 + (i % 3) * 0.035  # chipped: tooth heights differ
		out.append({"part": part, "blade": [pt(t, 0.16), pt(t + 0.2, 0.15), pt(t + 0.02, 0.17 + h)], "y": (-0.076, -0.024), "colour": STEEL_D})
	out.append({"part": part, "blade": [pt(-0.04, -0.14), pt(-0.04, 0.3), pt(0.04, 0.3), pt(0.04, -0.14)], "y": (-0.1, -0.01), "colour": "#3A4658"})
	out.append({"part": part, "lock": [[sgn * 1.54, -0.05, 2.14], [sgn * 1.62, -0.05, 2.0], [x0, -0.05, z0]], "r": 0.13, "colour": "#465A78", "flatten": 0.9})
	return out


PROPS = [
	# fur belt: pelt hanging from the hips, longer at the sides
	*[{"part": "LowerTorso", "lock": [[x, -0.53, 2.42], [x * 1.05, -0.62, 2.1], [x * 1.1, -0.66, tz]], "r": 0.2, "colour": PELT, "flatten": 0.5} for x, tz in ((-0.82, 1.58), (-0.5, 1.72), (-0.16, 1.62), (0.16, 1.7), (0.5, 1.6), (0.82, 1.68))],
	*[{"part": "LowerTorso", "lock": [[x, 0.53, 2.42], [x * 1.05, 0.62, 2.1], [x * 1.1, 0.66, tz]], "r": 0.2, "colour": PELT, "flatten": 0.5} for x, tz in ((-0.82, 1.6), (-0.5, 1.66), (-0.16, 1.56), (0.16, 1.64), (0.5, 1.7), (0.82, 1.58))],
	*[{"part": "LowerTorso", "lock": [[1.02, y, 2.42], [1.1, y, 2.1], [1.14, y, tz]], "r": 0.19, "colour": PELT, "flatten": 0.5, "mirror": True} for y, tz in ((-0.26, 1.6), (0.26, 1.66))],
	*_saw(1),
	*_saw(-1),
]


def bare_torso(f):
	"""Hard block muscle, inked."""
	f.fill(SKIN)
	f.soft("M-5-5H22Q8 70 16 160V205H-5Z", SKIN_D, 0.32, 3)
	f.soft("M205-5H178Q192 70 184 160V205H205Z", SKIN_D, 0.7, 3)
	# pecs
	f.path("M100 26Q58 18 26 44Q22 74 48 84Q84 90 100 70Z", shade(SKIN, 1.04), stroke=INK, sw=1.6)
	f.path("M100 26Q142 18 174 44Q178 74 152 84Q116 90 100 70Z", shade(SKIN, 1.0), stroke=INK, sw=1.6)
	f.path("M36 74Q70 94 98 66Q84 90 48 86Z", SKIN_D, opacity=0.8)
	f.path("M164 74Q130 94 102 66Q116 90 152 86Z", SKIN_D, opacity=0.9)
	f.soft("M40 34Q66 26 88 36Q70 42 44 50Z", "#fff4e6", 0.7, 3)
	f.soft("M112 36Q134 26 160 34Q156 50 130 42Z", "#fff4e6", 0.6, 3)
	f.path(ell(58, 64, 3, 2.6), "#c98a78")
	f.path(ell(142, 64, 3, 2.6), "#c98a78")
	# abs
	f.taper(100, 70, 101, 110, 100, 156, 1.6)
	for y, w in ((98, 30), (118, 28), (138, 26)):
		f.taper(100 - w, y - 4, 100 - w / 2, y + 3, 100, y, 1.2)
		f.taper(100 + w, y - 4, 100 + w / 2, y + 3, 100, y, 1.2)
		f.soft(f"M{100 - w} {y + 2}Q{100 - w / 2} {y + 8} 99 {y + 6}L99 {y + 10}Q{100 - w / 2} {y + 12} {100 - w} {y + 8}Z", SKIN_D, 0.7, 1)
		f.soft(f"M{100 + w} {y + 2}Q{100 + w / 2} {y + 8} 101 {y + 6}L101 {y + 10}Q{100 + w / 2} {y + 12} {100 + w} {y + 8}Z", SKIN_D, 0.8, 1)
	f.taper(68, 88, 62, 124, 76, 160, 1.4)
	f.taper(132, 88, 138, 124, 124, 160, 1.4)
	# serratus
	for y in (92, 104, 116):
		f.taper(28, y, 40, y + 2, 50, y + 8, 0.8)
		f.taper(172, y, 160, y + 2, 150, y + 8, 0.8)
	# collar bones
	f.taper(30, 22, 62, 14, 92, 22, 1.0)
	f.taper(170, 22, 138, 14, 108, 22, 1.0)
	# old scars
	f.ink("M46 44L66 60M50 40L72 56", 1.0, "#b0605a")
	f.ink("M128 98L148 122", 1.2, "#b0605a")


def pelt_band(f):
	"""Fur belt round the hips."""
	f.path(f"M-5 156H{f.w + 5}V{f.h + 5}H-5Z", PELT)
	r = f.rng
	for i in range(int(f.w / 5)):
		x = i * 5 + r.uniform(-2, 2)
		f.taper(x, 150 + r.uniform(0, 6), x + r.uniform(-2, 2), 176, x + r.uniform(-3, 3), 205, 1.3, shade(PELT, r.choice((0.5, 1.4, 0.7))))
	f.path(f"M-5 158L{f.w * 0.2} 150L{f.w * 0.5} 156L{f.w * 0.8} 150L{f.w + 5} 158", stroke=INK, sw=1.4)


def arm(f, key):
	f.fill(SKIN)
	f.soft("M76-5H105V210H82Q92 100 76-5Z", SKIN_D, 0.28, 3)
	f.soft("M-5-5H8Q4 100 10 210H-5Z", SKIN_D, 0.3, 2)
	# shoulder cap, biceps, elbow, forearm
	f.taper(4, 42, 50, 60, 96, 38, 2.0)
	f.soft("M16 58Q50 50 84 56Q86 90 52 100Q18 94 16 58Z", "#fff0dc", 0.6, 4)
	f.taper(16, 56, 10, 80, 22, 102, 1.7)
	f.taper(84, 56, 90, 80, 78, 102, 1.7)
	f.taper(34, 108, 50, 114, 66, 108, 1.5)
	f.taper(16, 118, 10, 146, 22, 170, 1.4)
	f.taper(84, 118, 90, 146, 78, 170, 1.4)
	f.taper(50, 124, 46, 146, 52, 170, 0.9)
	hand(f, key, SKIN, 180)


def fur_face(f, base, n=90, light=FUR_L, dark=FUR_D, w=1.2):
	f.fill(base)
	r = f.rng
	for i in range(n):
		x, y = r.uniform(0, f.w), r.uniform(0, f.h)
		f.taper(x, y, x + r.uniform(-3, 3), y + 6, x + r.uniform(-5, 5), y + r.uniform(10, 16), w, r.choice((light, dark, dark)))


def paint(a):
	paint_hair(a, ["#8391a8", "#8a6c4a"])
	tip_tone(a, 0, 2, "#c2ccd8", 18, 0.55)
	tip_tone(a, 1, 2, "#c29a6a", 18, 0.6)
	# ---- the mask, front projection
	f = a["Head_F"]
	fur_face(f, FUR)
	f.soft("M-5-5H135V30Q65 44 -5 30Z", FUR_D, 0.55, 3)
	f.soft(f"M0 70Q30 86 40 112H0Z", FUR_D, 0.6, 3)
	f.soft(f"M130 70Q100 86 90 112H130Z", FUR_D, 0.7, 3)
	f.soft("M46 56Q65 50 84 56V74H46Z", FUR_L, 0.5, 4)
	# eyes: sunk, slanted, dark, a cold glint
	for sgn, cx in ((-1, fx(-0.5)), (1, fx(0.5))):
		ey = fy(4.86)
		f.path(f"M{cx - sgn * 16} {ey + 5}Q{cx} {ey - 11} {cx + sgn * 17} {ey - 12}Q{cx + sgn * 16} {ey + 6} {cx} {ey + 10}Q{cx - sgn * 10} {ey + 10} {cx - sgn * 16} {ey + 5}Z", "#0d0e14", stroke=INK, sw=1.2)
		f.path(ell(cx + sgn * 1, ey - 1, 6.5, 6), "#27324a")
		f.path(ell(cx + sgn * 1, ey - 1, 3, 3), "#040408")
		f.path(ell(cx - sgn * 1.5, ey - 3.5, 1.5, 1.5), "#ffffff")
		# brow ridge pressing down on the eye
		f.path(f"M{cx - sgn * 20} {ey + 2}L{cx + sgn * 21} {ey - 18}L{cx + sgn * 20} {ey - 12}L{cx - sgn * 15} {ey + 6}Z", FUR_D, stroke=INK, sw=1.0)
	# snout: pale muzzle, pink pad, nostrils, lip line
	cz = fy(4.42)
	f.path(ell(65, cz + 2, 36, 32), shade(FUR, 1.25))
	r = f.rng
	for i in range(40):
		t = r.uniform(0, 6.28)
		x, y = 65 + 34 * math.cos(t), cz + 2 + 30 * math.sin(t)
		f.taper(x, y, x + 2, y + 3, x + r.uniform(-3, 3), y + 7, 0.8, FUR_D)
	f.path(ell(65, cz, 24, 20), "#e0a0a0", stroke=INK, sw=2)
	f.path(ell(63, cz - 4, 18, 11), "#eebcb8")
	f.path(ell(56, cz + 1, 5, 7.5), "#2c1218", stroke=INK, sw=0.8)
	f.path(ell(74, cz + 1, 5, 7.5), "#2c1218", stroke=INK, sw=0.8)
	f.ink(f"M65 {cz + 4}V{cz + 20}", 1.2)
	f.ink(f"M33 {cz + 22}Q65 {cz + 40} 97 {cz + 22}", 2.2)
	# ---- mask sides, back, top
	for n in ("Head_L", "Head_R", "Head_B", "Head_T"):
		fur_face(a[n], FUR, 70, FUR_L, FUR_D, 1.5)
	a["Head_T"].soft("M-5 40H135V120H-5Z", FUR_D, 0.5, 4)
	for n, cx in (("Head_L", 40), ("Head_R", 80)):
		a[n].path(ell(cx, 46, 9, 5), "#101018", stroke=INK, sw=1)
	a["Head_Bo"].fill(FUR_D)
	# ---- bare body
	f = a["Torso_F"]
	bare_torso(f)
	pelt_band(f)
	f.edges(0.2)
	f = a["Torso_B"]
	f.fill(SKIN)
	f.soft("M-5-5H18V205H-5ZM205-5H178V205H205Z", SKIN_D, 0.34, 3)
	f.taper(100, 4, 102, 80, 100, 156, 1.6)
	f.path("M100 18Q54 22 30 70Q60 88 96 76Z", shade(SKIN, 1.03), stroke=INK, sw=1.4)
	f.path("M100 18Q146 22 170 70Q140 88 104 76Z", shade(SKIN, 0.98), stroke=INK, sw=1.4)
	f.taper(40, 92, 66, 130, 94, 150, 1.2)
	f.taper(160, 92, 134, 130, 106, 150, 1.2)
	f.soft("M92 80H108V150H92Z", SKIN_D, 0.7, 3)
	f.ink("M56 50L80 74M126 40L146 62M60 110L82 118", 1.1, "#b0605a")
	pelt_band(f)
	f.edges(0.2)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SKIN)
		f.soft("M74-5H105V205H78Z", SKIN_D, 0.5, 3)
		f.soft("M-5-5H16V205H-5Z", SKIN_D, 0.4, 2)
		for y in (40, 60, 80, 100, 120):
			f.taper(16, y, 40, y + 4, 62, y + 8, 1.0)
		pelt_band(f)
		f.edges(0.2)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(PANTS)
	for side in ("Left", "Right"):
		for key in "FBOI":
			arm(a[f"{side}Arm_{key}"], key)
			a[f"{side}Arm_{key}"].edges(0.18)
			# leg: wide trousers, shin wraps in a diamond pattern, bare foot
			f = a[f"{side}Leg_{key}"]
			f.fill(PANTS)
			shades(f, 4, 0.05, 0.6, (50, 120), op=0.5, light=PANTS_L, lop=0.6)
			f.path("M-5 120H105V178H-5Z", "#efebe0")
			for i, x in enumerate(range(-20, 120, 25)):
				for y in (130, 154):
					xx = x + (12 if y == 154 else 0)
					f.path(f"M{xx} {y}L{xx + 12} {y - 10}L{xx + 24} {y}L{xx + 12} {y + 10}Z", "#1d1e26")
			f.ink("M-5 120H105M-5 178H105", 1.6)
			f.path("M-5 178H105V205H-5Z", SKIN)
			f.path("M-5 170H105V182H-5Z", PELT, stroke=INK, sw=1.2)
			if key == "F":
				for x in (20, 34, 48, 62, 76):
					f.ink(f"M{x} 192V203", 1.0, "#a06a50")
			f.ink("M-5 202H105", 1.4)
			f.edges(0.26)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(PANTS)
		a[f"{side}Leg_Bo"].fill(shade(SKIN, 0.5))
	f = a["Coat"]
	f.fill(PANTS)
	f.soft("M240-5H305V105H240Z", "#000000", 0.25, 5)
	shades(f, 14, 0.05, 0.86, (150, 130), op=0.5, light=PANTS_L, lop=0.7, width=1.2)
	f.path("M-5 88H305V105H-5Z", shade(PANTS, 0.8))
	f.ink("M-5 88H305", 2)
	for x in range(0, 300, 12):
		f.ink(f"M{x} 88L{x + 4} 100", 0.7, "#10141c")
	a["CoatIn"].fill(shade(PANTS, 0.45))


def model(parts, kit):
	coat(kit, parts, 0.82, 0.24, zt=2.02, front_flare=0.18)
	head = parts["Head"]
	n = 16

	def ring(i):
		y, w, h, zc = RINGS[i]
		out = []
		for k in range(n):
			t = 2 * math.pi * k / n
			c, s = math.cos(t), math.sin(t)
			# superellipse: a boxy skull
			px = w * math.copysign(abs(c) ** 0.72, c)
			pz = h * math.copysign(abs(s) ** 0.72, s)
			out.append((px, y, zc + pz))
		return out

	def tag(n3, p):
		x, y, z = p
		ny, nx, nz = n3[1], n3[0], n3[2]
		if ny < -0.42:
			return ("Head_F", max(0, min(130, fx(x))), max(0, min(130, fy(z))))
		if abs(nz) > max(abs(nx), abs(ny)):
			if nz > 0:
				return ("Head_T", max(0, min(130, fx(x))), max(0, min(120, (y + 1.3) / 2.3 * 120)))
			return ("Head_Bo", 60, 60)
		if ny > abs(nx):
			return ("Head_B", max(0, min(130, (1 - x) * 65)), max(0, min(130, fy(z))))
		if nx > 0:
			return ("Head_L", max(0, min(120, (y + 1.3) / 2.3 * 120)), max(0, min(130, fy(z))))
		return ("Head_R", max(0, min(120, (1.0 - y) / 2.3 * 120)), max(0, min(130, fy(z))))

	quads = []
	rs = [ring(i) for i in range(len(RINGS))]

	def add(ps):
		v = kit.Vector
		nrm = (v(ps[1]) - v(ps[0])).cross(v(ps[2]) - v(ps[1])).normalized()
		quads.append([(p, tag(nrm, p)) for p in ps])

	for i in range(len(rs) - 1):
		for k in range(n):
			j = (k + 1) % n
			# ring runs anticlockwise seen from the front (-Y looking +Y has +X on the viewer's right)
			add([rs[i][k], rs[i + 1][k], rs[i + 1][j], rs[i][j]])
	front = (0, RINGS[0][0] - 0.02, RINGS[0][3])
	back = (0, RINGS[-1][0] + 0.06, RINGS[-1][3])
	for k in range(n):
		j = (k + 1) % n
		add([rs[0][j], front, rs[0][k]])
		add([rs[-1][k], back, rs[-1][j]])
	panels(kit, "Head_Mask", head, quads)
	# ears, with a dark inner
	for sgn in (1, -1):
		kit.lock(f"Head_Ear{sgn}", [sgn * 0.68, 0.08, 5.3], [sgn * 1.0, 0.06, 5.52], [sgn * 1.12, 0.14, 5.8], 0.38, FUR, head, flatten=0.5)
		kit.lock(f"Head_EarIn{sgn}", [sgn * 0.78, -0.04, 5.34], [sgn * 0.98, -0.08, 5.5], [sgn * 1.08, -0.04, 5.7], 0.2, "#C88A8A", head, flatten=0.3)
		# tusks: short, curving up beside the muzzle
		kit.lock(f"Head_Tusk{sgn}", [sgn * 0.36, -1.08, 4.14], [sgn * 0.5, -1.24, 4.2], [sgn * 0.54, -1.28, 4.56], 0.09, "#F1E8D0", head, flatten=0.9)
