# Painted look for ds_hero: green and black check coat over the corps uniform, hanging card earrings, forehead scar.
from atlas import INK, face_base, paint_hair, shade
from ds_common import L, checks, coat, dome, ell, fore, hairline, haori_body, head_sides, katana, panels, sharp_eye, sleeve, tip_tone, tone

SKIN = "#f2c9a4"
HAIR = "#4A1418"
TIP = "#b5362a"
GREEN = "#1f9463"
BLACK = "#15151b"
EYE = "#8f1f22"
DEFAULT = "#1b1b27"
HAIR_COLOURS = [HAIR]


HAIR = {
	"colour": "#260a0e",
	"cap": {"size": [1.34, 1.26, 0.56], "at": [0, 0.02, 5.04], "bevel": 0.24},
	"locks": tone(
		[
			# fringe: chunky spikes around a bare patch of forehead on the character's left, where the scar sits
			fore(-0.72, 4.42, 0.2, -0.5),
			fore(-0.5, 4.72, 0.27, -0.44),
			fore(-0.22, 4.82, 0.28),
			fore(0.05, 4.86, 0.26),
			fore(0.3, 5.24, 0.2),
			fore(0.54, 4.8, 0.24, 0.5),
			fore(0.74, 4.46, 0.2, 0.5),
			*dome(),
			# top: short spikes standing up and out
			L([0.05, -0.2, 5.45], [0.1, -0.35, 5.72], [0.14, -0.5, 5.92], 0.3),
			L([-0.26, -0.25, 5.45], [-0.38, -0.38, 5.68], [-0.46, -0.46, 5.86], 0.3),
			L([0.36, -0.25, 5.42], [0.5, -0.35, 5.62], [0.68, -0.42, 5.74], 0.3),
			L([-0.54, -0.15, 5.32], [-0.8, -0.2, 5.44], [-1.04, -0.26, 5.5], 0.28),
			L([0.6, -0.08, 5.3], [0.84, -0.12, 5.4], [1.08, -0.14, 5.38], 0.27),
			L([0.62, 0.05, 5.1], [0.88, 0.05, 5.1], [1.08, 0.02, 4.9], 0.27, mirror=True),
			L([0.64, 0.25, 5.0], [0.86, 0.3, 4.92], [1.02, 0.36, 4.66], 0.25, mirror=True),
			# crown, swept back
			*[L([x, 0.15, 5.46], [x * 1.2, 0.42, 5.72], [x * 1.45, 0.76, 5.78], 0.3) for x in (-0.42, 0.0, 0.42)],
			# back of the head, layered to the nape
			*[L([x, 0.5, 5.28], [x * 1.15, 0.85, 5.15], [x * 1.3, 1.08, 4.88], 0.31) for x in (-0.56, -0.2, 0.2, 0.56)],
			*[L([x, 0.58, 4.88], [x * 1.1, 0.84, 4.56], [x * 1.2, 0.8, 4.1], 0.31) for x in (-0.54, -0.18, 0.18, 0.54)],
			# behind the ear
			L([0.66, 0.3, 4.9], [0.8, 0.4, 4.66], [0.82, 0.44, 4.36], 0.2, mirror=True),
		],
		HAIR_COLOURS[0],
	),
}

PROPS = [
	{"part": "UpperTorso", "box": [1.36, 1.14, 0.2], "at": [0, 0, 4.03], "colour": "#1B1B27", "bevel": 0.05},
	*katana("#17171f", "#23232e", "#0f0f15"),
]


def pattern(f):
	checks(f, GREEN, BLACK, 30, ox=(f.w % 60) / 2)
	f.soft(f"M-5-5H{f.w + 5}V{f.h * 0.14}H-5Z", "#ffffff", 0.05, 3)


def paint_card(f):
	"""Card earring: white strip, red sun and rays."""
	f.path("M-2-2H26V62H-2Z", "#f6f2e8")
	f.path("M-2-2H26V3H-2ZM-2 57H26V62H-2Z", "#d23026")
	for x, y in ((3, 34), (12, 30), (21, 34), (1, 44), (23, 44), (12, 50)):
		f.ink(f"M12 22L{x} {y + 12}", 1.6, "#d23026")
	f.path(ell(12, 19, 8.5, 8.5), "#d23026", stroke=INK, sw=0.7)
	f.path("M-2 64H26V122H-2Z", "#f6f2e8")


def paint(a):
	paint_hair(a, ["#4c1418"])
	tip_tone(a, 0, 1, "#a02c26", 24, 0.8)
	# ---- face: big steady eyes, level brows, firm mouth
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=34)
	hairline(f, "#2c0c10", 20)
	sc = "#c9272b"
	# forehead scar on the character's left, flame shaped
	f.path("M78 44Q74 34 84 30Q84 36 90 30Q90 24 98 22Q98 30 106 28Q104 34 112 36Q104 44 98 50Q90 56 84 50Q78 50 78 44Z", shade(sc, 0.82), stroke=shade(sc, 0.5), sw=0.9)
	f.path("M84 44Q86 36 92 38Q96 32 102 34Q100 40 96 46Q90 50 84 44Z", sc)
	f.taper(14, 46, 32, 37, 53, 51, 3.4, "#3a1014")
	f.taper(116, 46, 98, 39, 77, 51, 3.0, "#3a1014")
	sharp_eye(f, 50, 69, 19, 63, 6.6, 6.0, "#9e2a28", "#4e0d12", "#e4603a", 9.2, dx=1, dy=1, pupil=0.42)
	sharp_eye(f, 80, 69, 111, 63, 6.6, 6.0, "#9e2a28", "#4e0d12", "#e4603a", 9.2, dx=-1, dy=1, pupil=0.42)
	# firm mouth, the jaw set: a line, no lips
	f.taper(47, 106, 65, 102, 83, 105, 1.5)
	f.taper(47, 106, 65, 104, 83, 105, 0.5, "#7a3a30")
	f.taper(44, 104, 45, 106, 49, 108, 0.7)
	f.taper(86, 103, 85, 105, 81, 107, 0.7)
	f.taper(54, 117, 65, 120, 76, 117, 0.8, shade(SKIN, 0.55))
	f.taper(26, 94, 30, 106, 40, 116, 0.7, shade(SKIN, 0.62))
	f.taper(104, 94, 100, 106, 90, 116, 0.7, shade(SKIN, 0.62))
	head_sides(a, SKIN, HAIR_COLOURS[0], "#8c2c2c")
	haori_body(a, pattern, SKIN)
	paint_card(a["Extra"])


def model(parts, kit):
	head = parts["Head"]
	for sgn in (1, -1):
		x0, y0, x1, y1, zt, zb = 0.68, -0.14, 0.83, 0.0, 4.48, 4.02
		tag = lambda u, v: ("Extra", u, v)
		q = [((x0, y0, zt), tag(1, 0)), ((x0, y0, zb), tag(1, 60)), ((x1, y1, zb), tag(23, 60)), ((x1, y1, zt), tag(23, 0))]
		if sgn < 0:
			q = [((-p[0], p[1], p[2]), t) for p, t in reversed(q)]
		panels(kit, f"Head_Card{sgn}", head, [q], lining=tag(12, 90))
		kit.rbox(f"Head_CardPin{sgn}", (0.03, 0.03, 0.1), (sgn * 0.74, -0.08, 4.5), "#e8c55a", head, bevel=0)
	coat(kit, parts, 1.12, 0.12)
	sleeve(kit, parts, 2.28, 0.08)
