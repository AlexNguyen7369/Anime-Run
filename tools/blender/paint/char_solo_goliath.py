# Target look for solo_goliath "Tomas Andre" (design doc section 5): a huge man with long golden hair swept back past the shoulders, a sprawling goatee and dark
# sunglasses; his beach look: an oversized open Hawaiian-style shirt over a bare chest with black in-house tribal lines, baggy shorts and big sandals. Big by garment only:
# the same block body, a wider shirt, wider sleeves and shorts, a bigger hair mass. +X is the viewer's right. Drawn in-house.
from atlas import shade
from ds_style3 import art_uv, rect_d, studs
from jk_common import brow2, form, nose
from jk_style3 import crown
from solo_style3 import Kit, Ramps, big_head, block, ears, finish, gem, head_rest, prism, slab

SKIN = "#e7b288"
SKIN_D = "#b07c58"
GOLD = "#e8b83e"
BEARD = "#c2822a"
SHIRT = "#14707a"
SHIRT_D = "#0a4a54"
DEFAULT = SHIRT
R = Ramps(
	hair=["#8a5a14", "#c08a22", "#e8b83e", "#fbd66a", "#fff0a8"],
	beard=["#6e3e10", "#94601c", "#c2822a", "#dfa84a", "#f4cc7a"],
	skin=["#a87a56", "#cc9a72", "#e7b288", "#f8cea8"],
	shirt=["#07333a", "#0a4a54", "#14707a", "#2096a2", "#44bcc6"],
	cargo=["#3e3a24", "#5a5434", "#787046", "#968e5e", "#b4ac7c"],
	pocket=["#2e2a1a", "#46412a", "#5e5838", "#787048"],
	boot=["#1e120a", "#2e1c10", "#44291a", "#5e3c28", "#7c5438"],
	sole=["#0a0a0c", "#16161a", "#24242a", "#34343c"],
	lens=["#04040a", "#0a0a14", "#12121f", "#2a2a44"],
	frame=["#5a4a1a", "#9a7e24", "#d2ac3c", "#fbe08a"],
)
HAIR = {"colour": "#E8B83E", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.3), (1.1, 5.56), (1.06, 5.84), (0.74, 6.08), (0.22, 6.2)])
	block(k, "Head", "Back", 0, 0.34, 5.5, 3.9, 1.04, 0.66, "hair", ch=0.06, corner=0.3, jit=0.02, sub=1, mids=(5.0, 4.4), a=0.44, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.5, 5.46), (-0.34, 5.02), (0.0, 4.5), (0.9, 4.1), (0.9, 5.46)], s * 0.86, s * 1.02, "hair", a=0.46, b=0.46)
		# the long mane falling past the shoulders, in heavy locks
		gem(k, "Head", f"Mane0{s}", (s * 0.92, -0.2, 5.3), (s * 1.3, -0.4, 3.5), 0.42, flat=0.42, twist=0.2, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Mane1{s}", (s * 1.0, 0.24, 5.3), (s * 1.42, 0.3, 3.18), 0.5, flat=0.42, twist=0.3, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Mane2{s}", (s * 0.8, 0.7, 5.3), (s * 1.08, 1.0, 2.86), 0.52, flat=0.42, twist=0.25, across=(1, 0, 0), a=0.48)
		# wings swept back off the temples
		gem(k, "Head", f"Sweep{s}", (s * 0.86, -0.42, 5.6), (s * 1.42, 0.34, 5.62), 0.34, flat=0.42, twist=0.25, a=0.54)
		gem(k, "Head", f"Sweep2{s}", (s * 0.66, -0.38, 5.86), (s * 1.28, 0.5, 6.04), 0.34, flat=0.42, twist=0.2, a=0.54)
	gem(k, "Head", "ManeC", (0, 0.82, 5.3), (0, 1.14, 2.7), 0.56, flat=0.4, twist=0.25, across=(1, 0, 0), a=0.48)
	# the top: swept straight back from a high forehead
	for i, (b, t, r) in enumerate(
		(
			((-0.5, -0.76, 5.54), (-0.66, -0.3, 6.32), 0.34),
			((0, -0.8, 5.56), (0, -0.22, 6.42), 0.36),
			((0.5, -0.76, 5.54), (0.66, -0.3, 6.32), 0.34),
			((-0.4, -0.1, 6.0), (-0.56, 0.8, 6.28), 0.38),
			((0.02, -0.1, 6.06), (0.02, 0.9, 6.42), 0.4),
			((0.42, -0.1, 6.0), (0.58, 0.8, 6.28), 0.38),
			((-0.32, 0.5, 5.86), (-0.46, 1.2, 5.56), 0.38),
			((0.32, 0.5, 5.86), (0.46, 1.2, 5.56), 0.38),
		)
	):
		gem(k, "Head", f"Top{i}", b, t, r, flat=0.42, twist=0.25, a=0.54)


def _beard(k):
	"""A sprawling goatee: moustache over the grin, a broad block under it, side strands on the jaw. The grin stays clear."""
	h = "Head"
	block(k, h, "Chin", 0, -0.66, 4.16, 3.74, 0.42, 0.22, "beard", ch=0.07, corner=0.3, jit=0.012, flare=-0.08, a=0.5, b=0.5)
	for s in (1, -1):
		gem(k, h, f"Jaw{s}", (s * 0.8, -0.72, 4.42), (s * 0.3, -0.86, 3.86), 0.16, ramp="beard", flat=0.5, twist=0.2, across=(0, 1, 0), a=0.5)
		gem(k, h, f"Stache{s}", (s * 0.02, -0.86, 4.6), (s * 0.56, -0.88, 4.38), 0.09, ramp="beard", flat=0.45, twist=0.15, across=(0, 0, 1), a=0.52)
	gem(k, h, "Tip", (0, -0.76, 3.96), (0, -0.86, 3.46), 0.26, ramp="beard", flat=0.6, twist=0.2, a=0.5)


def _glasses(k):
	"""Real dark wraparound lenses on a gold bar; they stand off the face and carry the look."""
	h = "Head"
	y = -0.85
	for s in (1, -1):
		prism(k, h, f"Lens{s}", [(s * 0.1, 5.0), (s * 0.82, 5.04), (s * 0.84, 4.66), (s * 0.6, 4.52), (s * 0.24, 4.54), (s * 0.08, 4.72)], y - 0.03, y + 0.02, "lens", a=0.5, b=0.42)
		block(k, h, f"Arm{s}", s * 0.91, -0.1, 4.98, 4.92, 0.03, 0.74, "frame", ch=0.012, a=0.56, b=0.4)
	block(k, h, "Bar", 0, y - 0.01, 5.06, 4.97, 0.88, 0.035, "frame", ch=0.015, a=0.6, b=0.42)
	block(k, h, "Bridge", 0, y - 0.01, 4.92, 4.8, 0.09, 0.03, "frame", ch=0.012, a=0.6, b=0.42)


def _shirt(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.05, 0.95, 0.45)], corner=0.1, nc=1)
	# bare chest and stomach, art from the atlas's Torso_F
	k.tube(t, "Chest", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.04, 0.56), (0, 0, 2.2, 1.04, 0.56), (0, 0, 2.12, 1.0, 0.5)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	# the oversized open shirt: a wide back and side shell, and two panels hanging open, wider than the body
	art_uv(block(k, t, "ShirtBody", 0, 0.24, 4.1, 1.68, 1.22, 0.46, "shirt", ch=0.05, corner=0.14, sub=1, jit=0.015, a=0.5, b=0.5), "Torso_B", rect=(-1.25, 1.25, 1.6, 4.1))
	for s in (1, -1):
		art_uv(block(k, t, f"ShirtF{s}", s * 0.97, -0.4, 4.08, 1.68, 0.27, 0.27, "shirt", ch=0.04, jit=0.012, a=0.5, b=0.5), "Torso_B", rect=(-1.25, 1.25, 1.6, 4.1))
		# the wide camp collar laid open
		prism(k, t, f"Collar{s}", [(s * 0.46, 4.1), (s * 1.0, 4.14), (s * 1.08, 3.64), (s * 0.74, 3.42), (s * 0.66, 3.74)], -0.72, -0.62, "shirt", a=0.56, b=0.48)
	block(k, t, "CollarBack", 0, 0.42, 4.36, 3.96, 0.88, 0.16, "shirt", ch=0.05, corner=0.2, flare=0.08, a=0.54, b=0.5)
	# a wide belt, cargo waist
	block(k, t, "Waist", 0, 0, 2.2, 1.9, 1.1, 0.62, "cargo", ch=0.03, corner=0.14, sub=1, a=0.44, b=0.5)
	block(k, t, "Belt", 0, 0, 2.3, 2.1, 1.12, 0.64, "boot", ch=0.025, corner=0.14, sub=1, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.645, 2.32, 2.08, 0.15, 0.02, "frame", ch=0.015, a=0.6, b=0.42)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.54
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	# a huge short sleeve, wide open; the bare forearm and the plain block fist below it
	art_uv(block(k, arm, "Sleeve", s * 1.66, 0, 4.16, 2.96, 0.68, 0.7, "shirt", ch=0.08, corner=0.18, jit=0.02, flare=0.04, sub=1, a=0.5, b=0.56), "Torso_B", rect=(-1.25, 1.25, 1.6, 4.1), dx=s * -1.2)
	block(k, arm, "Forearm", ax, 0, 3.0, 2.0, 0.54, 0.54, "skin", ch=0.08, a=0.56, b=0.36)
	block(k, arm, "Hand", ax, 0, 2.12, 1.66, 0.56, 0.56, "skin", ch=0.08, a=0.6, b=0.32)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.56
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# the beach look: wide baggy shorts past the knee, bare shins, big sandals
	block(k, leg, "Thigh", px, 0, 1.98, 1.28, 0.54, 0.62, "cargo", ch=0.05, flare=0.05, corner=0.16, jit=0.04, mids=(1.62,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Hem", px, 0, 1.32, 1.02, 0.6, 0.68, "cargo", ch=0.04, corner=0.16, jit=0.03, a=0.42, b=0.58, tone=0.05)
	block(k, leg, "Pocket", s * 1.16, 0, 1.56, 1.1, 0.05, 0.28, "pocket", ch=0.02, a=0.5, b=0.5)
	block(k, leg, "Flap", s * 1.17, 0, 1.6, 1.46, 0.06, 0.3, "cargo", ch=0.02, a=0.56, b=0.5)
	block(k, leg, "Shin", px, 0, 1.06, 0.2, 0.5, 0.52, "skin", ch=0.05, corner=0.16, a=0.56, b=0.36)
	block(k, leg, "Foot", px, -0.34, 0.34, 0.12, 0.48, 0.42, "skin", ch=0.08, corner=0.24, a=0.58, b=0.36)
	block(k, leg, "Sole", px, -0.14, 0.14, 0.0, 0.56, 0.74, "boot", ch=0.03, a=0.54)
	block(k, leg, "Strap", px, -0.4, 0.34, 0.22, 0.5, 0.38, "boot", ch=0.02, a=0.58, b=0.36)
	block(k, leg, "StrapHeel", px, 0.06, 0.3, 0.2, 0.51, 0.53, "boot", ch=0.02, a=0.54, b=0.36)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_beard(k)
	_glasses(k)
	_shirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _flower(f, cx, cy, r, petal="#f6efe0", core="#f0a630"):
	"""Our own five-petal bloom, in studs."""
	import math

	for i in range(5):
		a = i * 2 * math.pi / 5 + cx
		px, py = cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a)
		f.path(f"M{px - r * 0.42:.3f} {py:.3f}a{r * 0.42:.3f} {r * 0.42:.3f} 0 1 0 {r * 0.84:.3f} 0a{r * 0.42:.3f} {r * 0.42:.3f} 0 1 0 {-r * 0.84:.3f} 0Z", petal)
	f.path(f"M{cx - r * 0.24:.3f} {cy:.3f}a{r * 0.24:.3f} {r * 0.24:.3f} 0 1 0 {r * 0.48:.3f} 0a{r * 0.24:.3f} {r * 0.24:.3f} 0 1 0 {-r * 0.48:.3f} 0Z", core)


def _print(f):
	"""The Hawaiian-style print, sampled by position over every shirt panel: big blooms and leaves on teal."""
	rect = (-1.25, 1.25, 1.6, 4.1)
	studs(f, rect)
	f.path(rect_d(-2, 1, 2, 5), SHIRT)
	# leaves
	for (x, z, dx, dz) in ((-0.95, 3.6, 0.4, -0.26), (-0.2, 3.3, 0.36, 0.3), (0.72, 3.7, -0.4, -0.2), (0.3, 2.4, 0.42, 0.24), (-0.8, 2.3, 0.36, -0.28), (-0.46, 1.96, -0.3, 0.3), (1.0, 2.1, -0.34, 0.3)):
		f.path(f"M{x} {z}Q{x + dx * 0.6 - dz * 0.4} {z + dz * 0.6 + dx * 0.4} {x + dx} {z + dz}Q{x + dx * 0.4 + dz * 0.4} {z + dz * 0.4 - dx * 0.4} {x} {z}Z", "#0a4a54")
		f.path(f"M{x} {z}L{x + dx} {z + dz}", stroke="#2fb0a0", sw=0.03)
	# blooms
	for x, z, r, p, c in (
		(-0.86, 3.08, 0.26, "#f6efe0", "#f0a630"),
		(0.86, 3.2, 0.28, "#ff8a4a", "#fff0c0"),
		(-0.1, 3.8, 0.22, "#ff8a4a", "#fff0c0"),
		(0.2, 2.8, 0.25, "#f6efe0", "#f0a630"),
		(-0.46, 2.5, 0.26, "#ff8a4a", "#fff0c0"),
		(0.86, 2.3, 0.26, "#f6efe0", "#f0a630"),
		(-1.04, 1.92, 0.22, "#f6efe0", "#f0a630"),
		(0.2, 1.84, 0.22, "#ff8a4a", "#fff0c0"),
	):
		_flower(f, x, z, r, p, c)
	f.out.append("</g>")


def _chest(f):
	"""Skin, big muscle shapes, the in-house tribal lines down the chest."""
	f.fill(SKIN)
	# pecs and abs
	f.soft("M20 74Q60 94 96 72L98 84Q60 110 22 88Z", SKIN_D, 0.75, 2)
	f.soft("M180 74Q140 94 104 72L102 84Q140 110 178 88Z", SKIN_D, 0.75, 2)
	f.path("M100 26V180", stroke=SKIN_D, sw=2.4, opacity=0.9)
	for y in (112, 134, 156):
		f.path(f"M78 {y}Q100 {y + 6} 122 {y}", stroke=SKIN_D, sw=2.0, opacity=0.8)
	# chest hair at the top of the V
	f.soft("M78 20Q100 44 122 20Q112 58 100 64Q88 58 78 20Z", "#a8702a", 0.5, 2)
	# tribal lines: our own hooked blades from the collarbones, not any real design
	for s, x in ((1, 150), (-1, 50)):
		p = lambda d: 100 + s * d
		f.path(f"M{p(14)} 30Q{p(44)} 26 {p(76)} 44L{p(50)} 40Q{p(40)} 54 {p(52)} 72L{p(30)} 54Q{p(24)} 42 {p(14)} 30Z", "#16120e")
		f.path(f"M{p(28)} 80Q{p(52)} 88 {p(70)} 112L{p(50)} 102Q{p(42)} 116 {p(46)} 134L{p(30)} 112Q{p(30)} 94 {p(28)} 80Z", "#16120e")
	form(f, "#6e4a30", 0.32)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V16Q65 22 -5 16Z", SKIN_D, 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	for s, cx in ((-1, 38), (1, 92)):
		brow2(f, cx, 30, s, 42, 8.4, 2.6, BEARD)
	for y, d in ((14, 4), (21, 0)):
		f.path(f"M{38 + d} {y}Q65 {y + 3} {92 - d} {y}", stroke=SKIN_D, sw=1.3, opacity=0.8)
	nose(f, SKIN, y=70, h=18)
	# a huge grin under the moustache
	f.path("M34 92Q65 98 96 92Q90 114 65 114Q40 114 34 92Z", "#4a1610", stroke="#24090a", sw=1.8)
	f.path("M37 93Q65 99 93 93L91 101Q65 107 39 101Z", "#fdf8ee")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.6))
	a["Head_T"].fill("#c08a22")
	_chest(a["Torso_F"])
	_print(a["Torso_B"])
	for n in ("Torso_L", "Torso_R"):
		a[n].fill(SKIN)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(SKIN_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill("#5a5434")
		a[f"{side}Arm_T"].fill(SHIRT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill("#5a5434")
		a[f"{side}Leg_Bo"].fill("#2e1c10")
