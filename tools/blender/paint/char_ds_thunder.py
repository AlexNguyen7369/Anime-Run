# Painted look for ds_thunder: yellow shaggy hair, white triangle coat, scared wide eyes and bared teeth.
from atlas import INK, face_base, paint_hair, shade
from ds_common import L, coat, dome, fore, hairline, haori_body, head_sides, katana, scales, sharp_eye, sleeve, tip_tone, tone

SKIN = "#f6dbc2"
HAIRC = "#F2C21A"
TIP = "#e8741a"
DEFAULT = "#1b1b27"
HAIR_COLOURS = [HAIRC]

HAIR = {
	"colour": "#8a5e0c",
	"cap": {"size": [1.34, 1.26, 0.54], "at": [0, 0.02, 5.04], "bevel": 0.24},
	"locks": tone(
		[
			# uneven fringe, flat and falling
			fore(-0.72, 4.38, 0.2, -0.5),
			fore(-0.48, 4.76, 0.27, -0.42),
			fore(-0.24, 4.86, 0.27),
			fore(0.02, 4.72, 0.26),
			fore(0.28, 4.88, 0.26),
			fore(0.5, 4.74, 0.26, 0.44),
			fore(0.72, 4.32, 0.2, 0.5),
			*dome(top=5.8),
			# shaggy crown: low, lies flat, ends flick out
			*[L([x, -0.1, 5.46], [x * 1.3, -0.2, 5.66], [x * 1.65, -0.28, 5.62], 0.3) for x in (-0.34, 0.34)],
			L([0.0, -0.1, 5.5], [-0.06, -0.1, 5.7], [-0.12, -0.22, 5.8], 0.3),
			L([0.0, 0.25, 5.5], [0.2, 0.42, 5.7], [0.3, 0.62, 5.72], 0.3),
			L([-0.3, 0.25, 5.48], [-0.46, 0.45, 5.64], [-0.62, 0.68, 5.6], 0.3),
			# sides, jaw length, tips flicking outward in steps
			L([0.62, -0.1, 5.3], [0.88, -0.15, 4.95], [1.04, -0.2, 4.76], 0.28, mirror=True),
			L([0.66, 0.05, 5.1], [0.84, 0.05, 4.68], [0.98, 0.02, 4.46], 0.27, mirror=True),
			L([0.66, 0.28, 5.0], [0.82, 0.34, 4.52], [0.9, 0.34, 4.12], 0.27, mirror=True),
			# back: layered, stepped, short at the nape
			*[L([x, 0.5, 5.3], [x * 1.15, 0.86, 5.08], [x * 1.3, 1.0, 4.72], 0.31) for x in (-0.56, -0.2, 0.2, 0.56)],
			*[L([x, 0.56, 4.9], [x * 1.1, 0.82, 4.5], [x * 1.25, 0.78, 4.06], 0.3) for x in (-0.54, -0.18, 0.18, 0.54)],
		],
		HAIRC,
	),
}

PROPS = [
	{"part": "UpperTorso", "box": [1.36, 1.14, 0.2], "at": [0, 0, 4.03], "colour": "#1B1B27", "bevel": 0.05},
	*katana("#1c1c26", "#EFC21E", "#8a6a20", guard_size=0.28),
]
YEL = "#f4b91e"
ORG = "#ee8a18"


def pattern(f):
	scales(f, YEL, "#fff8e4", 30, 26, ox=(f.w % 30) / 2, oy=-4)


def fade(f, y0, y1):
	"""Yellow running to orange towards a hem."""
	f.path(f"M-5 {y0}H{f.w + 5}V{y1 + 8}H-5Z", ORG, opacity=0.62, blur=5)
	f.path(f"M-5 {y0 + (y1 - y0) * 0.5}H{f.w + 5}V{y1 + 8}H-5Z", "#e0641a", opacity=0.55, blur=3)


def paint(a):
	paint_hair(a, ["#f4c61f"])
	tip_tone(a, 0, 1, TIP, 30, 0.9)
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=30)
	hairline(f, "#a87410", 18)
	# scared: brows high and pinched up at the middle, eyes wide with tiny irises
	for sgn, ix, ox in ((-1, 50, 17), (1, 80, 113)):
		sharp_eye(f, ix, 66, ox, 61, 9.5, 8.5, "#c9861a", "#6b3f08", "#f4cf6a", 5.4, dx=sgn * -1.5, dy=0.5, pupil=0.45, lid=1.8, shine=1.1, flick=1.5)
		f.ink(f"M{ix - sgn * 2} 79Q{(ix + ox) / 2} 84 {ox + sgn * 2} 74", 0.8, shade(SKIN, 0.55))
		f.path(f"M{ix - sgn * 3} 36Q{(ix + ox) / 2} 37 {ox + sgn * 5} 50Q{(ix + ox) / 2} 45 {ix - sgn * 3} 44Z", "#a86a0c", stroke=INK, sw=1.0)
	# grinding teeth, wide open at the corners
	f.path("M36 101Q65 94 94 101Q97 112 90 118Q65 124 40 118Q33 112 36 101Z", "#fbf8f0", stroke=INK, sw=1.8)
	f.ink("M37 109Q65 106 94 109", 1.3)
	for x in (46, 55, 65, 75, 84):
		f.ink(f"M{x} 99V120", 0.9)
	f.taper(30, 96, 32, 102, 36, 104, 0.7)
	f.taper(100, 96, 98, 102, 94, 104, 0.7)
	f.taper(50, 125, 65, 128, 80, 125, 0.7, shade(SKIN, 0.55))
	# sweat
	f.path("M114 40Q120 50 117 54Q111 54 111 49Q111 45 114 40Z", "#bfe0f2", stroke="#3f6f8c", sw=0.8)
	f.path("M18 32Q24 42 21 46Q15 46 15 41Q15 37 18 32Z", "#bfe0f2", stroke="#3f6f8c", sw=0.8)
	head_sides(a, SKIN, "#e0a815", "#ffe46a")
	haori_body(
		a,
		pattern,
		SKIN,
		coat_hem=lambda f: fade(f, 38, 100),
		sleeve_hem=lambda f: fade(f, 118, 178),
		torso_hem=lambda f: f.path(f"M-5-5H{f.w + 5}V34H-5Z", "#e8981a", opacity=0.28, blur=5),
	)


def model(parts, kit):
	coat(kit, parts, 1.14, 0.12)
	sleeve(kit, parts, 2.28, 0.08)
