# Painted look for sea_navigator, post-timeskip. Marks: pinwheel and tangerine tattoo on the left shoulder, the wrist
# needle bracelet, the three part staff. Drawn in-house (design doc 5). Top is a plain crop top, no body shaping paint:
# the audience includes children.
import math

from atlas import INK, paint_hair, shade
from sea_common import bead, cap, circle, hair_back, hairline, hand, head_side, sheet, strand, strand_zone, tube

SKIN = "#f5cfa8"
SKIN_D = shade(SKIN, 0.7)
ORANGE = "#ea7a22"
ORANGE_L = "#f6a04a"
GREEN = "#3aa45a"
GREEN_D = shade(GREEN, 0.62)
JEAN = "#38689e"
JEAN_D = shade(JEAN, 0.6)
JEAN_L = "#7ea6d2"
BLUE_INK = "#2a56a8"
DEFAULT = SKIN

HAIR_COLOURS = [ORANGE, ORANGE_L]
HAIR = {"colour": ORANGE, "locks": []}  # her long waves are drawn by model() as multi-point strands
PROPS = [
	# low belt and buckle
	{"part": "LowerTorso", "box": [2.06, 1.06, 0.13], "at": [0, 0, 2.2], "colour": "#6d4a2a", "bevel": 0.025},
	{"part": "LowerTorso", "box": [0.2, 0.05, 0.17], "at": [0.18, -0.54, 2.2], "colour": "#e3b53a", "bevel": 0.012},
	# the heeled sandal: a sole under the toes, a heel post at the back
	{"part": "LeftFoot", "box": [0.92, 0.54, 0.06], "at": [0.5, -0.62, 0.05], "colour": "#c15a22", "bevel": 0.02},
	{"part": "RightFoot", "box": [0.92, 0.54, 0.06], "at": [-0.5, -0.62, 0.05], "colour": "#c15a22", "bevel": 0.02},
	{"part": "LeftFoot", "box": [0.2, 0.2, 0.3], "at": [0.5, 0.52, 0.15], "colour": "#c15a22", "bevel": 0.03},
	{"part": "RightFoot", "box": [0.2, 0.2, 0.3], "at": [-0.5, 0.52, 0.15], "colour": "#c15a22", "bevel": 0.03},
	# bracelet of the needle on the left wrist, gold bangles on the right
	{"part": "LeftHand", "box": [1.04, 1.04, 0.12], "at": [1.5, 0, 2.32], "colour": "#2c4f92", "bevel": 0.02},
	{"part": "RightHand", "box": [1.03, 1.03, 0.05], "at": [-1.5, 0, 2.36], "colour": "#e3b53a", "bevel": 0.012},
	{"part": "RightHand", "box": [1.03, 1.03, 0.05], "at": [-1.5, 0, 2.28], "colour": "#e3b53a", "bevel": 0.012},
]


def _wavy(z0, z1, x0, x1, y0, y1, amp, phase, n=7, freq=1.6):
	pts = []
	for i in range(n):
		t = i / (n - 1)
		wave = amp * math.sin(phase + t * freq * 2 * math.pi) * min(1, t * 2.5)
		pts.append((x0 + (x1 - x0) * t + wave, y0 + (y1 - y0) * t + wave * 0.3, z0 + (z1 - z0) * t))
	return pts


def model(parts, kit):
	head = parts["Head"]
	line = hairline([(0, 4.5), (45, 4.3), (90, 4.2), (135, 4.3), (180, 4.5), (225, 4.92), (270, 5.16), (315, 4.92)])
	cap(kit, "Head_Cap", ORANGE, head, line, top=5.52, n=2.8, p=2.3)
	# curtain fringe off a parting just on her left: two sheets arching out past the eyes, then falling by the cheeks
	y = -0.68
	for tag, s, off, col in (("R", -1, 0.0, ORANGE), ("L", 1, 0.0, ORANGE)):
		rows = [
			[(0.1 + s * 0.02, y + 0.2, 5.46), (0.1 + s * 0.2, y + 0.2, 5.44), (0.1 + s * 0.42, y + 0.24, 5.36)],
			[(0.1 + s * 0.12, y, 5.3), (s * 0.34, y - 0.01, 5.32), (s * 0.62, y + 0.04, 5.2)],
			[(s * 0.34, y - 0.01, 5.1), (s * 0.52, y - 0.015, 5.14), (s * 0.74, y + 0.04, 5.0)],
			[(s * 0.5, y, 4.86), (s * 0.62, y - 0.015, 4.88), (s * 0.77, y + 0.05, 4.76)],
			[(s * 0.58, y, 4.56), (s * 0.68, y - 0.015, 4.5), (s * 0.77, y + 0.05, 4.48)],
			[(s * 0.68, y + 0.01, 4.24), (s * 0.7, y, 4.2), (s * 0.73, y + 0.03, 4.22)],
		]
		sheet(kit, f"Head_Curtain{tag}", rows, col, head, thick=0.08, lock=((s * 0.1, y, 5.46), (s * 0.7, y, 4.2)))
		# one lit ribbon on top of each curtain and a short wisp at the cheek, breaking the edge
		strand(kit, f"Head_Lit{tag}", [(0.1 + s * 0.1, y - 0.01, 5.36), (s * 0.34, y - 0.03, 5.28), (s * 0.58, y - 0.03, 5.04), (s * 0.66, y - 0.03, 4.66), (s * 0.68, y - 0.02, 4.32)], 0.08, ORANGE_L, head, flatten=0.4, rings=8, wide=(1, 0, 0))
		strand(kit, f"Head_Wisp{tag}", [(s * 0.46, y - 0.01, 5.0), (s * 0.5, y - 0.03, 4.84), (s * 0.5, y - 0.02, 4.72)], 0.05, ORANGE_L, head, flatten=0.4, rings=4, wide=(1, 0, 0))
	# long falls in front of the shoulders, down the chest
	strand(kit, "Head_FrontL", _wavy(4.92, 3.24, 0.72, 0.64, -0.6, -0.62, 0.07, 0.4), 0.2, ORANGE, head, flatten=0.5, rings=10, wide=(1, 0, 0))
	strand(kit, "Head_FrontR", _wavy(4.9, 3.16, -0.74, -0.64, -0.58, -0.62, 0.07, 2.4), 0.21, ORANGE, head, flatten=0.5, rings=10, wide=(1, 0, 0))
	# the sides sweep behind the shoulders
	for s in (1, -1):
		strand(kit, f"Head_Side{s}A", [(s * 0.7, -0.2, 5.12), (s * 0.86, -0.1, 4.7), (s * 0.84, 0.3, 4.2), (s * 0.86, 0.6, 3.7), (s * 0.82, 0.64, 3.1)], 0.22, ORANGE, head, flatten=0.5, rings=8, wide=(0, 1, 0))
		strand(kit, f"Head_Side{s}B", [(s * 0.68, 0.2, 5.14), (s * 0.84, 0.32, 4.7), (s * 0.86, 0.52, 4.2), (s * 0.78, 0.66, 3.6), (s * 0.84, 0.66, 2.9)], 0.24, ORANGE_L, head, flatten=0.5, rings=8, wide=(0, 1, 0))
	# the great mass down the back to the waist: overlapping wavy ribbons, two layers, uneven tips
	for i, (x, tip, ph, col) in enumerate(((-0.66, 2.62, 0.3, ORANGE), (-0.4, 2.42, 2.0, ORANGE_L), (-0.14, 2.3, 4.0, ORANGE), (0.14, 2.36, 1.0, ORANGE_L), (0.4, 2.3, 3.0, ORANGE), (0.66, 2.56, 5.0, ORANGE_L))):
		strand(kit, f"Head_BackA{i}", _wavy(5.16, tip, x * 0.86, x * 1.08, 0.57, 0.68, 0.075, ph), 0.27, col, head, flatten=0.4, rings=10, wide=(1, 0, 0))
	for i, (x, tip, ph, col) in enumerate(((-0.52, 3.0, 1.2, ORANGE_L), (-0.26, 2.82, 3.2, ORANGE), (0.0, 2.68, 5.0, ORANGE_L), (0.26, 2.9, 0.6, ORANGE), (0.52, 2.96, 2.6, ORANGE_L))):
		strand(kit, f"Head_BackB{i}", _wavy(5.06, tip, x * 0.9, x, 0.62, 0.78, 0.07, ph), 0.22, col, head, flatten=0.4, rings=10, wide=(1, 0, 0))
	# the glass bubble with its needle
	bead(kit, "LeftHand_Glass", (2.04, 0, 2.34), 0.13, "#a8d8f0", parts["LeftHand"])
	# the staff: three blue sections, white joints and tips, held upright in her right hand
	arm = parts["RightHand"]
	x, y = -1.5, -0.62
	tube(kit, "RightHand_Staff", [(x, y, 0.5), (x, y, 1.42)], 0.075, "#3d86c6", arm, sides=8)
	tube(kit, "RightHand_Staff2", [(x, y, 1.42), (x, y, 2.42)], 0.075, "#6fb2e6", arm, sides=8)
	tube(kit, "RightHand_Staff3", [(x, y, 2.42), (x, y, 3.42)], 0.075, "#3d86c6", arm, sides=8)
	for i, z in enumerate((0.5, 1.42, 2.42, 3.42)):
		bead(kit, f"RightHand_Joint{i}", (x, y, z), 0.115, "#f2f2ee", arm)


def face(a):
	f = a["Head_F"]
	f.fill(SKIN)
	dark = shade(SKIN, 0.72)
	e = shade(SKIN, 0.45)
	f.path("M-5-5H135V30L100 24L82 16L60 16L40 26L-5 34Z", dark, opacity=0.8, blur=2)
	f.soft("M-5 40H8Q6 90 24 135H-5Z", dark, 0.8, 3)
	f.soft("M135 40H122Q124 90 106 135H135Z", dark, 0.95, 3)
	f.soft("M34 130Q65 120 96 130V136H34Z", dark, 0.8, 2)
	# long almond eyes, sharp at the outer corner, three hard lashes
	for cx, s in ((40, -1), (90, 1)):
		f.path(f"M{cx - s * 12} 66Q{cx - s * 4} 52 {cx + s * 8} 52Q{cx + s * 16} 54 {cx + s * 17} 60Q{cx + s * 12} 72 {cx} 74Q{cx - s * 8} 73 {cx - s * 12} 66Z", "#fbf8f2")
		f.path(circle(cx + s * 1.2, 63, 8.2, 10), "#9a5a22")
		f.path(circle(cx + s * 1.2, 58, 7.6, 5), "#4e2a0f")
		f.path(circle(cx + s * 1.2, 69.5, 5, 2.6), "#d69448")
		f.path(circle(cx + s * 1.2, 63, 3.8, 4.6), "#120a08")
		f.path(circle(cx + s * 3.8 - 1, 58.5, 2.1), "#ffffff")
		f.path(f"M{cx - s * 14} 68Q{cx - s * 6} 48 {cx + s * 9} 49Q{cx + s * 18} 50 {cx + s * 22} 56L{cx + s * 18} 59Q{cx + s * 12} 54 {cx + s * 8} 54Q{cx - s * 4} 54 {cx - s * 14} 68Z", INK)
		f.path(f"M{cx + s * 18} 56L{cx + s * 25} 50L{cx + s * 19} 59Z", INK)
		f.path(f"M{cx + s * 15} 52L{cx + s * 21} 45L{cx + s * 18} 53Z", INK)
		f.ink(f"M{cx - s * 8} 73Q{cx} 76 {cx + s * 12} 68", 0.9, "#6a3a22")
		# thin arched brow
		f.path(f"M{cx - s * 11} 42Q{cx + s * 4} 33 {cx + s * 20} 42Q{cx + s * 4} 37 {cx - s * 11} 45Z", "#9c4b16")
	# small straight nose, a touch of shadow
	f.path("M66 78L62 86L68 87Z", dark, opacity=0.6)
	f.ink("M62 87Q65 88.5 69 87", 0.9, e)
	# knowing smile, lips closed at one end, a line of teeth
	f.path("M50 104Q65 108 82 102Q78 112 65 113Q54 113 50 104Z", "#fbf8f2", stroke="#7c2f26", sw=1.4)
	f.path("M53 108Q65 113 78 106Q72 113 65 113Q57 113 53 108Z", "#c5534a")
	f.ink("M47 102Q49 103 51 105", 1.0, "#7c2f26")
	f.ink("M85 100Q83 101 81 103", 1.0, "#7c2f26")
	f.taper(58, 118, 65, 120, 74, 118, 0.7, e)


def tattoo(f, cx, cy, r, ink):
	"""A pinwheel on the left of a round tangerine with a leaf, all in one blue ink."""
	px = cx - r * 0.72
	for i in range(4):
		ang = i * math.pi / 2
		c, q = math.cos(ang), math.sin(ang)
		pt = lambda u, v: f"{px + (u * c - v * q) * r:.1f} {cy + (u * q + v * c) * r:.1f}"
		f.path(f"M{pt(0, 0)}L{pt(0.82, 0)}L{pt(0.55, 0.52)}Z", ink)
	f.path(circle(px, cy, r * 0.09), ink)
	tx = cx + r * 0.72
	f.path(circle(tx, cy + r * 0.15, r * 0.52, r * 0.46), "none", stroke=ink, sw=r * 0.16)
	for dx in (-0.2, 0.0, 0.2):
		f.ink(f"M{tx + dx * r} {cy - r * 0.2}Q{tx + dx * 2 * r} {cy + r * 0.15} {tx + dx * r} {cy + r * 0.5}", r * 0.06, ink)
	f.path(f"M{tx} {cy - r * 0.34}Q{tx + r * 0.42} {cy - r * 0.86} {tx + r * 0.72} {cy - r * 0.48}Q{tx + r * 0.3} {cy - r * 0.2} {tx} {cy - r * 0.34}Z", ink)
	f.path(f"M{tx} {cy - r * 0.34}Q{tx - r * 0.42} {cy - r * 0.8} {tx - r * 0.66} {cy - r * 0.44}Q{tx - r * 0.3} {cy - r * 0.2} {tx} {cy - r * 0.34}Z", ink)


def jean_leg(f, key):
	f.fill(JEAN)
	f.folds(4, JEAN_D, JEAN_L, y0=0.06, y1=0.3, pinch=(50, 6), width=1.3)
	f.folds(4, JEAN_D, JEAN_L, y0=0.68, y1=0.82, pinch=(50, 172), width=1.1)
	f.taper(50, 2, 49, 90, 50, 170, 1.0, JEAN_L)
	f.taper(14, 112, 50, 120, 86, 108, 1.2, JEAN_D)
	if key == "F":
		f.path("M8 14Q40 34 76 14", stroke=JEAN_D, sw=1.6)
		f.path("M8 18Q40 38 76 18", stroke="#d8a93a", sw=0.8)
	if key == "B":
		f.path("M22 16H78V50L50 58L22 50Z", shade(JEAN, 0.86), stroke=JEAN_D, sw=1.4)
		f.path("M26 20H74V48L50 54L26 48Z", "none", stroke="#d8a93a", sw=0.7)
	# hem break over the sandal
	f.path("M-5 174H105V184H-5Z", shade(JEAN, 0.82))
	f.ink("M-5 174H105", 0.9, "#d8a93a")
	f.ink("M-5 184H105", 1.5)


def paint(a):
	paint_hair(a, [ORANGE, ORANGE_L])
	strand_zone(a, 0, 2, ORANGE, lines=40)
	strand_zone(a, 1, 2, ORANGE_L, lines=40)
	face(a)
	# ---- torso: a green crop top with white trim to the ribs, bare midriff, low jeans
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M-5-5H205V6H-5Z", SKIN_D, 0.7, 2)
	# fitted sleeveless top: wide straps, scooped neck, a curved hem, white trim on both edges and a white wave across it
	top = "M34-5H70Q72 22 100 26Q128 22 130-5H166L188 30L192 92Q100 104 8 92L12 30Z"
	f.path(top, GREEN, stroke=INK, sw=1.8)
	f.ink("M70-5Q72 22 100 26Q128 22 130-5", 3.4, "#f0f0ec")
	f.ink("M9 86Q100 98 191 86", 4.2, "#f0f0ec")
	f.path("M14 62Q60 40 100 58T186 50", stroke="#f0f0ec", sw=2.6)
	f.taper(36, 30, 60, 50, 90, 80, 1.1, GREEN_D)
	f.taper(164, 30, 140, 50, 110, 80, 1.1, GREEN_D)
	f.soft("M12 30H28Q20 60 26 90H8Z", GREEN_D, 0.6, 2)
	f.soft("M188 30H172Q180 60 174 90H192Z", GREEN_D, 0.75, 2)
	f.soft("M-5 96H205V106H-5Z", SKIN_D, 0.75, 2)
	# midriff: plain, the navel and a soft shadow only
	f.soft("M-5 100Q6 130 -5 165H16Q10 130 16 100Z", SKIN_D, 0.6, 3)
	f.soft("M205 100Q194 130 205 165H184Q190 130 184 100Z", SKIN_D, 0.75, 3)
	f.taper(100, 118, 100, 130, 100, 142, 0.9, shade(SKIN, 0.6))
	f.ink("M98 146Q100 149 102 146", 1.0, shade(SKIN, 0.5))
	# low jeans
	f.path("M-5 164H205V205H-5Z", JEAN)
	f.ink("M-5 164H205", 1.6)
	f.ink("M100 176V205", 1.3, JEAN_D)
	f.ink("M100 176V205", 0.6, "#d8a93a")
	f.edges(0.22)
	f = a["Torso_B"]
	f.fill(SKIN)
	f.path("M8 30L34-5H70Q100 34 130-5H166L192 30V88Q100 98 8 88Z", GREEN, stroke=INK, sw=1.8)
	f.ink("M9 82Q100 92 191 82", 4, "#f0f0ec")
	f.soft("M100 96Q90 130 100 164Q110 130 100 96Z", SKIN_D, 0.8, 2)
	f.path("M-5 164H205V205H-5Z", JEAN)
	f.ink("M-5 164H205", 1.6)
	f.edges(0.22)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SKIN)
		f.path("M-5 30H105V92H-5Z", GREEN)
		f.path("M-5 84H105V92H-5Z", "#f0f0ec")
		f.ink("M-5 30H105M-5 92H105", 1.6)
		f.soft("M-5 96H105V112H-5Z", SKIN_D, 0.8, 3)
		f.path("M-5 164H105V205H-5Z", JEAN)
		f.ink("M-5 164H105", 1.6)
		f.edges(0.3)
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SKIN)
			# slim, not muscled: a soft shoulder, the elbow, the shadow side
			f.soft("M72 0Q90 80 78 172H105V0Z", SKIN_D, 0.7, 2)
			f.soft("M-5 0Q10 80 8 172H-5Z", SKIN_D, 0.45, 2)
			f.taper(30, 106, 50, 111, 70, 106, 1.0, shade(SKIN, 0.55))
			hand(f, side, key, SKIN)
			if side == "Left" and key in "OF":
				tattoo(f, 50, 28, 26 if key == "O" else 22, BLUE_INK)
			f.edges(0.2)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			jean_leg(f, key)
			# sandal straps and toes under the hem
			f.path("M-5 184H105V205H-5Z", SKIN if key == "F" else "#c15a22")
			if key == "F":
				f.path("M6 186H94V192H6Z", "#c15a22", stroke=INK, sw=0.9)
				for x in (20, 36, 50, 64, 80):
					f.ink(f"M{x} 196V205", 0.9, shade(SKIN, 0.5))
				f.path("M-5 201H105V205H-5Z", "#c15a22")
			f.edges(0.24)
		a[f"{side}Leg_T"].fill(JEAN)
		a[f"{side}Leg_Bo"].fill("#7a3a14")
	hair_back(a["Head_B"], ORANGE)
	a["Head_T"].fill(ORANGE)
	a["Head_Bo"].fill(SKIN_D)
	head_side(a["Head_L"], SKIN, ORANGE, True, hair_front=0.08, low=0.9, back_low=1.1, ear=False)
	head_side(a["Head_R"], SKIN, ORANGE, False, hair_front=0.08, low=0.9, back_low=1.1, ear=False)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(JEAN)
