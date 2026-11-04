# Painted look for ds_flame: blazing two-tone hair, huge staring eyes, forked brows, white coat with a flame hem.
from atlas import INK, face_base, paint_hair
from ds_common import L, UNI, coat, dome, flames, fore, hairline, haori_body, head_sides, katana, sharp_eye, sleeve, tip_tone, tone

SKIN = "#f4cfae"
GOLD = "#F7B512"
RED = "#D9341E"
DEFAULT = "#1b1b27"
HAIR_COLOURS = [GOLD, RED]

HAIR = {
	"colour": "#a8660a",
	"cap": {"size": [1.34, 1.26, 0.56], "at": [0, 0.02, 5.04], "bevel": 0.24},
	"locks": tone(
		[
		# fringe parted at the middle, red-tipped strands falling between two gold wings
		fore(-0.15, 4.9, 0.22, -0.08, colour=RED),
		fore(0.15, 4.9, 0.22, 0.08, colour=RED),
		fore(-0.4, 5.0, 0.3, -0.28),
		fore(0.4, 5.0, 0.3, 0.28),
		L([-0.5, -0.1, 5.46], [-0.76, -0.86, 5.36], [-0.92, -0.72, 4.84], 0.3, flatten=0.5),
		L([0.5, -0.1, 5.46], [0.76, -0.86, 5.36], [0.92, -0.72, 4.84], 0.3, flatten=0.5),
		*dome(),
		# flame tongues: tall on top, sweeping out and back; a red tongue among the gold
		L([0.0, -0.3, 5.3], [-0.1, -0.55, 5.85], [0.08, -0.62, 6.32], 0.36),
		L([0.34, -0.25, 5.3], [0.46, -0.48, 5.8], [0.72, -0.5, 6.18], 0.34),
		L([-0.34, -0.25, 5.3], [-0.46, -0.48, 5.8], [-0.72, -0.5, 6.18], 0.34),
		L([0.15, -0.1, 5.3], [0.26, -0.26, 5.74], [0.34, -0.3, 6.04], 0.2, colour=RED),
		L([-0.17, -0.1, 5.3], [-0.26, -0.26, 5.74], [-0.38, -0.3, 6.02], 0.2, colour=RED),
		L([0.6, -0.1, 5.25], [0.9, -0.25, 5.62], [1.26, -0.28, 5.86], 0.32, mirror=True),
		L([0.68, 0.05, 5.0], [1.04, 0.0, 5.18], [1.42, -0.04, 5.3], 0.3, mirror=True),
		L([0.68, 0.15, 4.78], [1.0, 0.18, 4.82], [1.32, 0.18, 4.82], 0.27, mirror=True),
		L([0.66, 0.28, 4.6], [0.92, 0.42, 4.48], [1.14, 0.52, 4.34], 0.24, mirror=True),
		L([0.46, -0.05, 5.36], [0.72, 0.0, 5.8], [1.0, 0.12, 6.0], 0.22, colour=RED, mirror=True),
		L([0.62, 0.12, 5.12], [0.96, 0.18, 5.42], [1.3, 0.24, 5.56], 0.18, colour=RED, mirror=True),
		# crown swept back
		*[L([x, 0.1, 5.38], [x * 1.25, 0.5, 5.8], [x * 1.6, 0.92, 5.96], 0.34) for x in (-0.44, 0.0, 0.44)],
		*[L([x, 0.25, 5.38], [x * 1.3, 0.6, 5.62], [x * 1.6, 1.12, 5.66], 0.18, colour=RED) for x in (-0.24, 0.24)],
		# back: big layered tongues down to the nape
		*[L([x, 0.5, 5.22], [x * 1.2, 0.98, 5.1], [x * 1.5, 1.14, 4.74], 0.32) for x in (-0.58, -0.2, 0.2, 0.58)],
		*[L([x, 0.56, 4.9], [x * 1.15, 0.92, 4.6], [x * 1.3, 0.98, 4.14], 0.31) for x in (-0.56, -0.19, 0.19, 0.56)],
		*[L([x, 0.56, 4.5], [x * 1.1, 0.82, 4.25], [x * 1.2, 0.84, 3.94], 0.26) for x in (-0.38, 0.0, 0.38)],
		],
		GOLD,
	),
}

PROPS = [
	{"part": "UpperTorso", "box": [1.36, 1.14, 0.2], "at": [0, 0, 4.03], "colour": "#1B1B27", "bevel": 0.05},
	*katana("#17171f", "#B3241A", "#E0781C"),
]
WHITE = "#f6f2e8"
R, O, Y = "#d92c1a", "#f47e16", "#fbc92a"


def pattern(f):
	f.fill(WHITE)
	f.soft(f"M{f.w * 0.72}-5H{f.w + 5}V{f.h + 5}H{f.w * 0.8}Z", "#8f8aa0", 0.3, 5)


def paint(a):
	paint_hair(a, ["#f9bb14", "#e23a1e"])
	tip_tone(a, 0, 2, "#e8401c", 34, 0.95)
	tip_tone(a, 1, 2, "#a81a12", 22, 0.7)
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=26)
	hairline(f, "#b8760c", 18)
	# big round staring eyes, gold to red, tiny pupils, looking past you
	for sgn, ix, ox in ((-1, 52, 13), (1, 78, 117)):
		sharp_eye(f, ix, 68, ox, 62, 10.5, 9.5, "#f4b416", "#c7321a", "#ffe874", 13, dx=-sgn * 0.5, dy=1, pupil=0.22, lid=3.2, shine=1.9, flick=3.5)
		cx = (ix + ox) / 2
		# forked brow: heavy lower bar, split into two tails at the outer end
		d = f"M{ix} 49Q{cx} 39 {ox + sgn * 4} 37L{cx + sgn * 4} 41L{ox + sgn * 7} 46Q{cx} 48 {ix + sgn * 1} 55Z"
		f.path(d, "#c8301a", stroke=INK, sw=1.0)
		f.path(f"M{ix} 49Q{cx} 41 {cx + sgn * 2} 41L{cx} 46Q{ix + sgn * 6} 49 {ix + sgn} 54Z", "#f4b416")
	# great open laugh
	f.path("M34 98Q65 92 96 98Q92 123 65 125Q38 123 34 98Z", "#5c1518", stroke=INK, sw=1.8)
	f.path("M36 99Q65 94 94 99L91 107Q65 104 39 107Z", "#fbf8f0")
	f.path("M48 120Q65 110 82 120Q65 127 48 120Z", "#c9434a")
	f.ink("M30 97Q33 95 36 99M100 97Q97 95 94 99", 1.3)
	head_sides(a, SKIN, "#e29a12", "#ffd84a")

	def hem(f):
		flames(f, f.h - 6, f.h * 0.62, 34, (R, O, Y))

	def tall_hem(f):
		flames(f, f.h - 4, 64, 34, (R, O, Y))

	haori_body(a, pattern, SKIN, coat_hem=tall_hem, sleeve_hem=lambda f: flames(f, 178, 58, 32, (R, O, Y)), cuff=UNI, coat_open=30, ink="#6a6478")


def model(parts, kit):
	coat(kit, parts, 0.66, 0.14)
	sleeve(kit, parts, 2.28, 0.1)
