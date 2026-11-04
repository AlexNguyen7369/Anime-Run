# Painted look for sea_cook, post-timeskip: black suit, blue shirt, long fringe over his right eye. Marks: the curled
# eyebrow and chin tuft, drawn in-house (design doc 5). No smoking prop: the audience includes children.
from atlas import INK, paint_hair, shade, swirl_d
from sea_common import cap, circle, fx, hair_back, hairline, hand, head_side, sheet, skirt, strand, strand_zone

SKIN = "#f2d0ac"
SKIN_D = shade(SKIN, 0.68)
HAIR_C = "#eec94b"
HAIR_L = "#f8e07a"
HAIR_D = shade(HAIR_C, 0.6)
SUIT = "#2a2c38"
SUIT_D = "#101018"
SUIT_L = "#646880"
SHIRT = "#3f76b8"
SHIRT_D = shade(SHIRT, 0.66)
SHIRT_L = "#8ab2e0"
DEFAULT = SUIT

HAIR_COLOURS = [HAIR_C, SUIT]
HAIR = {
	"colour": HAIR_C,
	"locks": [
		# the crown swept over from the parting on his left towards his right
		{"b": [0.42, -0.42, 5.28], "c": [0.1, -0.56, 5.46], "t": [-0.5, -0.56, 5.3], "r": 0.26, "flatten": 0.5},
		{"b": [0.46, -0.1, 5.32], "c": [0.1, -0.18, 5.5], "t": [-0.58, -0.3, 5.34], "r": 0.26, "flatten": 0.5},
		{"b": [0.46, 0.24, 5.3], "c": [0.1, 0.2, 5.48], "t": [-0.6, 0.08, 5.3], "r": 0.26, "flatten": 0.5},
		{"b": [0.36, 0.5, 5.26], "c": [0.1, 0.52, 5.42], "t": [-0.58, 0.44, 5.22], "r": 0.24, "flatten": 0.5},
		# the parting's other side: short and tucked behind the left ear
		{"b": [0.5, -0.44, 5.34], "c": [0.74, -0.5, 5.1], "t": [0.76, -0.44, 4.78], "r": 0.17, "flatten": 0.6},
		{"b": [0.54, -0.16, 5.34], "c": [0.82, -0.12, 5.04], "t": [0.8, 0.1, 4.68], "r": 0.2, "flatten": 0.6},
		{"b": [0.54, 0.2, 5.3], "c": [0.82, 0.26, 4.96], "t": [0.78, 0.38, 4.52], "r": 0.2, "flatten": 0.6},
		# his right side, longer, falling by the jaw
		{"b": [-0.56, -0.2, 5.3], "c": [-0.84, -0.24, 4.9], "t": [-0.8, -0.2, 4.44], "r": 0.22, "flatten": 0.6},
		{"b": [-0.56, 0.12, 5.3], "c": [-0.86, 0.14, 4.86], "t": [-0.8, 0.22, 4.4], "r": 0.22, "flatten": 0.6},
		{"b": [-0.54, 0.4, 5.26], "c": [-0.82, 0.48, 4.86], "t": [-0.76, 0.56, 4.44], "r": 0.2, "flatten": 0.6},
		# back: layered clumps tapering to a neat nape
		{"b": [0.42, 0.62, 5.2], "c": [0.52, 0.8, 4.84], "t": [0.46, 0.76, 4.42], "r": 0.2, "flatten": 0.55},
		{"b": [0.14, 0.64, 5.2], "c": [0.18, 0.82, 4.8], "t": [0.14, 0.78, 4.3], "r": 0.2, "flatten": 0.55},
		{"b": [-0.14, 0.64, 5.2], "c": [-0.18, 0.82, 4.8], "t": [-0.14, 0.78, 4.28], "r": 0.2, "flatten": 0.55},
		{"b": [-0.42, 0.62, 5.2], "c": [-0.52, 0.8, 4.84], "t": [-0.46, 0.76, 4.38], "r": 0.2, "flatten": 0.55},
		{"b": [0.28, 0.62, 4.82], "c": [0.32, 0.74, 4.5], "t": [0.26, 0.7, 4.18], "r": 0.16, "flatten": 0.55},
		{"b": [-0.02, 0.62, 4.82], "c": [-0.02, 0.76, 4.5], "t": [-0.02, 0.72, 4.12], "r": 0.16, "flatten": 0.55},
		{"b": [-0.3, 0.62, 4.82], "c": [-0.32, 0.74, 4.5], "t": [-0.28, 0.7, 4.18], "r": 0.16, "flatten": 0.55},
	],
}
PROPS = [
	# polished dress shoes: long, narrow toes
	{"part": "LeftFoot", "box": [0.92, 0.6, 0.2], "at": [0.5, -0.68, 0.1], "colour": "#0f0f14", "bevel": 0.09},
	{"part": "RightFoot", "box": [0.92, 0.6, 0.2], "at": [-0.5, -0.68, 0.1], "colour": "#0f0f14", "bevel": 0.09},
]


def model(parts, kit):
	head = parts["Head"]
	line = hairline([(0, 4.78), (45, 4.5), (90, 4.36), (135, 4.46), (180, 4.6), (225, 4.98), (270, 5.1), (315, 5.1)])
	cap(kit, "Head_Cap", HAIR_C, head, line, top=5.44, n=3.6)
	# the long fringe: from the parting on his left, across the forehead and straight down over his right eye to the jaw
	y = -0.68
	rows = [
		[(0.44, y + 0.06, 5.32), (0.2, y, 5.32), (-0.12, y, 5.34), (-0.42, y + 0.02, 5.32), (-0.66, y + 0.1, 5.24)],
		[(0.28, y - 0.01, 5.14), (0.06, y - 0.01, 5.14), (-0.22, y - 0.01, 5.14), (-0.48, y, 5.12), (-0.72, y + 0.06, 5.04)],
		[(0.06, y - 0.01, 4.88), (-0.12, y - 0.02, 4.84), (-0.34, y - 0.02, 4.82), (-0.56, y - 0.01, 4.8), (-0.76, y + 0.04, 4.76)],
		[(-0.1, y, 4.6), (-0.24, y - 0.02, 4.54), (-0.42, y - 0.02, 4.48), (-0.6, y - 0.01, 4.5), (-0.78, y + 0.03, 4.54)],
	]
	sheet(kit, "Head_Fringe", rows, HAIR_C, head, thick=0.08, lock=((0.1, y, 5.34), (-0.4, y, 4.4)))
	# the fringe's tips, separate points so the edge is never a straight cut
	for i, (b, c, t, r) in enumerate(
		(
			((-0.14, y, 4.74), (-0.14, y - 0.05, 4.54), (-0.08, y - 0.03, 4.3), 0.13),
			((-0.32, y, 4.7), (-0.36, y - 0.05, 4.44), (-0.28, y - 0.03, 4.16), 0.15),
			((-0.52, y, 4.7), (-0.56, y - 0.04, 4.42), (-0.52, y - 0.02, 4.1), 0.15),
			((-0.72, y + 0.04, 4.7), (-0.78, y + 0.02, 4.44), (-0.74, y + 0.04, 4.2), 0.12),
		)
	):
		strand(kit, f"Head_FringeTip{i}", [b, c, t], r, HAIR_C, head, flatten=0.45, rings=4, wide=(1, 0, 0))
	# thin raised strands over the broad fringe, so it reads as combed hair
	for i, pts in enumerate(
		(
			[(0.3, y - 0.01, 5.3), (0.08, y - 0.04, 5.14), (-0.16, y - 0.05, 4.9), (-0.22, y - 0.05, 4.6)],
			[(0.16, y - 0.01, 5.32), (-0.1, y - 0.04, 5.14), (-0.36, y - 0.05, 4.86), (-0.42, y - 0.05, 4.5)],
			[(0.0, y - 0.01, 5.34), (-0.28, y - 0.04, 5.14), (-0.54, y - 0.04, 4.86), (-0.62, y - 0.03, 4.52)],
		)
	):
		strand(kit, f"Head_FringeLine{i}", pts, 0.075, HAIR_C, head, flatten=0.4, rings=5, wide=(1, 0, 0))
	torso = parts["LowerTorso"]
	# jacket hem below the waist, two fronts cut away from the last button and a vented back
	skirt(kit, "LowerTorso_HemF", SUIT, torso, [[(0.1, -0.54), (0.58, -0.54), (1.03, -0.52), (1.05, -0.1)], [(-1.05, -0.1), (-1.03, -0.52), (-0.58, -0.54), (-0.1, -0.54)]], 2.18, 1.68, flare=0.03, rows=2)
	skirt(kit, "LowerTorso_HemB", SUIT, torso, [[(1.05, -0.1), (1.05, 0.3), (0.98, 0.54), (0.5, 0.54), (0.04, 0.54)], [(-0.04, 0.54), (-0.5, 0.54), (-0.98, 0.54), (-1.05, 0.3), (-1.05, -0.1)]], 2.18, 1.68, flare=0.03, rows=2)


def face(a):
	f = a["Head_F"]
	f.fill(SKIN)
	dark = shade(SKIN, 0.7)
	e = shade(SKIN, 0.42)
	# the fringe's cast shadow is heavy on his right; long lean cheek
	f.path("M-5-5H135V30L116 34L100 26L84 34L70 40L64 70L60 104L42 118L-5 124Z", shade(SKIN, 0.6), opacity=0.95, blur=2)
	f.soft("M135 30H120Q118 86 98 135H135Z", dark, 1.0, 3)
	f.soft("M64 90Q72 112 88 122L82 130Q66 118 60 96Z", dark, 0.5, 2)
	f.soft("M30 130Q65 120 104 130V136H30Z", dark, 0.9, 2)
	# hair painted over his right eye, in case an angle looks behind the fringe
	f.path("M-5-5H62L58 40L52 90L34 112L-5 120Z", HAIR_D)
	# his left eye: long, cool, half lidded, the blue iris pushed under the lid
	f.path("M80 64Q94 54 114 58Q112 68 100 70Q88 71 80 64Z", "#fbf8f2")
	f.path(circle(97, 62, 6.4, 7.6), "#2f7ed8")
	f.path(circle(97, 58.6, 6.2, 4), "#123a78")
	f.path(circle(97, 62, 3.2, 4), "#07080e")
	f.path(circle(95, 59.5, 1.3), "#ffffff")
	f.path("M78 65Q92 50 116 56L120 60L113 60Q94 55 80 66Z", INK)
	f.ink("M84 69Q96 73 110 65", 0.9)
	f.taper(86, 74, 98, 77, 108, 72, 0.5, e)
	# the curled brow: the tail runs in from the temple and winds into a tight spiral at its inner end
	f.path("M90 42Q106 49 126 39L126 43Q106 54 88 47Z", "#94701a")
	f.path(swirl_d(84, 39, 8.4, turns=2.2, a0=0.9), stroke="#94701a", sw=2.5)
	# narrow nose, long shadow
	f.taper(68, 56, 67, 74, 66, 86, 0.8, dark)
	f.path("M68 74L63 90L72 91Z", dark, opacity=0.6)
	f.ink("M62 91Q67 94 73 91", 1.1, e)
	# thin sardonic mouth, the left corner up
	f.path("M60 108Q74 110 92 101", stroke=INK, sw=1.7)
	f.ink("M92 101Q95 100 96 97", 1.1)
	f.taper(66, 113, 76, 115, 84, 111, 0.7, e)
	# goatee: a narrow pointed tuft on the chin and a thin patch under the lip, stubble along the jaw on his left
	f.path("M63 120Q70 117 78 120L74 129L70 135L67 129Z", "#c49d2b")
	for x in (66, 70, 74):
		f.taper(x, 120, x, 125, x - (x - 70) * 0.4, 131, 0.5, "#8a6c14")
	f.path("M68 112H74L71 117Z", "#c49d2b")
	for x, y in ((98, 114), (103, 108), (108, 102), (92, 120), (86, 124)):
		f.ink(f"M{x} {y}l1.4 2.4", 0.8, "#b89a48")


def paint(a):
	paint_hair(a, [HAIR_C, SUIT])
	strand_zone(a, 0, 2, HAIR_C, lines=42)
	strand_zone(a, 1, 2, SUIT)
	face(a)
	# ---- torso front: suit jacket, shirt, narrow tie
	f = a["Torso_F"]
	f.fill(SUIT)
	f.path("M60-5H140L108 130H92Z", SHIRT)
	# shirt stripes and folds
	for x in (70, 80, 90, 110, 120, 130):
		f.ink(f"M{x} -5L{100 + (x - 100) * 0.25} 130", 0.7, SHIRT_L)
	f.soft("M60-5H140V20Q100 40 60 20Z", SHIRT_D, 0.5, 2)
	f.path("M64 -5L100 22L88 44L52 6Z", shade(SHIRT, 1.3), stroke=INK, sw=1.4)
	f.path("M136 -5L100 22L112 44L148 6Z", shade(SHIRT, 1.3), stroke=INK, sw=1.4)
	f.path("M92 20H108L111 36L104 114L100 124L96 114L89 36Z", "#111118", stroke=INK, sw=1.2)
	f.path("M92 20H108L106 36H94Z", "#22222c")
	f.taper(96, 38, 97, 80, 98, 112, 0.7, SUIT_L)
	# lapels: long and sharp
	f.path("M52-5L92 134L80 134L44 62L66 50L40-5Z", "#2c2e3a", stroke=INK, sw=1.8)
	f.path("M148-5L108 134L120 134L156 62L134 50L160-5Z", "#2c2e3a", stroke=INK, sw=1.8)
	f.taper(58, 52, 74, 90, 86, 128, 0.8, SUIT_L)
	f.taper(142, 52, 126, 90, 114, 128, 0.8, SUIT_L)
	# the single button stance, front edge opening towards the hem
	f.ink("M92 134Q96 170 74 205", 2.2)
	f.ink("M108 134Q104 170 126 205", 2.2)
	f.path("M92 134Q96 170 74 205H126Q104 170 108 134Z", "#17171f")
	f.path(circle(114, 150, 3.4), "#0a0a10", stroke=SUIT_L, sw=0.9)
	# pockets, breast pocket with a pale fold
	f.ink("M26 158L62 152", 1.5, SUIT_L)
	f.ink("M138 152L174 158", 1.5, SUIT_L)
	f.ink("M146 66L176 62", 1.4, SUIT_L)
	f.path("M150 66L160 56L172 62L174 63Z", "#d8dce4", stroke=INK, sw=0.7)
	f.folds(5, SUIT_D, SUIT_L, y0=0.3, y1=0.8, pinch=(100, 150), width=1.3)
	f.edges(0.3)
	# ---- torso back
	f = a["Torso_B"]
	f.fill(SUIT)
	f.path("M60-5Q100 14 140-5V10Q100 30 60 10Z", "#2c2e3a", stroke=INK, sw=1.6)
	f.ink("M100 28V205", 1.6, SUIT_D)
	f.taper(20, 40, 60, 60, 90, 90, 1.1, SUIT_L)
	f.taper(180, 40, 140, 60, 110, 90, 1.1, SUIT_L)
	f.folds(6, SUIT_D, SUIT_L, y0=0.3, y1=0.84, pinch=(100, 170), width=1.3)
	f.edges(0.3)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SUIT)
		f.ink("M50-5V205", 1.4, SUIT_D)
		f.folds(4, SUIT_D, SUIT_L, y0=0.1, y1=0.8, pinch=(50, 150), width=1.3)
		f.edges(0.3)
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SUIT)
			f.folds(5, SUIT_D, SUIT_L, y0=0.04, y1=0.72, pinch=(50, 104), width=1.3)
			f.taper(14, 96, 50, 110, 88, 98, 1.2, SUIT_D)
			f.ink("M50-5V40", 0.9, SUIT_D)
			# blue cuff shows past the jacket sleeve
			f.path("M-5 154H105V174H-5Z", SHIRT)
			f.path("M-5 154H105V160H-5Z", SUIT_D, opacity=0.6)
			f.ink("M-5 154H105", 2)
			f.ink("M-5 174H105", 1.2)
			if key == "O":
				for y in (136, 144):
					f.path(circle(fx(side, key, 0.72), y, 2.2), "#0a0a10", stroke=SUIT_L, sw=0.6)
			hand(f, side, key, SKIN, y=174)
			f.edges(0.3)
		a[f"{side}Arm_T"].fill(SUIT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		# ---- legs: long trousers, pressed crease, a clean break on black shoes. The kick is the whole character.
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(SUIT)
			f.path("M50-5L47 186H53Z", SUIT_L, opacity=0.35)
			f.taper(50, 2, 50, 90, 50, 180, 1.1, SUIT_L)
			f.folds(4, SUIT_D, SUIT_L, y0=0.05, y1=0.4, pinch=(50, 6), width=1.2)
			f.taper(16, 96, 50, 110, 84, 94, 1.1, SUIT_D)
			f.taper(14, 160, 50, 168, 86, 158, 1.0, SUIT_L)
			f.path("M-5 172Q50 180 105 172V205H-5Z", "#0f0f14")
			f.ink("M-5 172Q50 180 105 172", 2)
			f.path("M-5 193H105V205H-5Z", "#050508")
			if key == "F":
				f.path("M22 190Q50 176 78 190Q50 196 22 190Z", "#3a3c4a", opacity=0.9)
				f.ink("M36 182L64 188M64 182L36 188", 1.0, "#3a3c4a")
			f.edges(0.3)
		a[f"{side}Leg_T"].fill(SUIT)
		a[f"{side}Leg_Bo"].fill("#050508")
	hair_back(a["Head_B"], HAIR_C, SKIN, nape=106, jag=8)
	a["Head_T"].fill(HAIR_C)
	a["Head_Bo"].fill(SKIN_D)
	head_side(a["Head_L"], SKIN, HAIR_C, True, hair_front=0.38, low=0.42)
	head_side(a["Head_R"], SKIN, HAIR_C, False, hair_front=0.1, low=0.84, back_low=0.9, ear=False)
	a["Torso_T"].fill(SUIT)
	a["Torso_Bo"].fill(SUIT)
