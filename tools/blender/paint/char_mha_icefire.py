# Target look for mha_icefire: hair split down the middle, white on the viewer's left and red on the right, burn scar round the
# viewer's right eye, one grey eye and one turquoise, calm mouth, navy jumpsuit with silver zip and chest harness, white
# belt, wrist gear, brown boots, a few ice crystals on the viewer's left shoulder (the hair's white side).
from atlas import shade
from mha_style3 import anime_eye, block, brow_block, core, gem, hand, head_faces, nose, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f8dccb"
SKIN_D = "#e3b094"
DEFAULT = "#2a3e7a"
R = Ramps(
	white=["#8c93a4", "#c2c8d4", "#e8ebf0", "#f6f7fa", "#ffffff"],
	red=["#5a0a0e", "#801216", "#a81c20", "#c7262a", "#e04a44"],
	skin=["#c08a68", "#e6b494", "#f8dccb", "#ffeadc"],
	navy=["#141e44", "#1e2e5e", "#2a3e7a", "#3e56a0"],
	silver=["#5a606c", "#8e96a2", "#c0c6d0", "#eef1f4"],
	belt=["#8c8f98", "#c6c8ce", "#f0f0f2", "#ffffff"],
	boot=["#1e140f", "#3a2a22", "#54402f", "#6e5640"],
	ice=["#3d94c4", "#74c4e4", "#b4e6f6", "#f0fdff"],
)
HAIR = {"colour": "#F2F2F2", "locks": []}
PROPS = []


def _side(x):
	"""The part: white on the viewer's left, red on the right."""
	return "white" if x < 0 else "red"


def _hair(k):
	for s, ramp in ((-1, "white"), (1, "red")):
		# half a crown each, meeting on the centre line
		block(k, "Head", f"Dome{s}", s * 0.48, 0.06, 6.06, 5.32, 0.5, 0.92, ramp, ch=0.3, corner=0.3, jit=0.03, sub=1, mids=(5.7,), a=0.44, b=0.5)
		block(k, "Head", f"Nape{s}", s * 0.48, 0.44, 5.7, 4.5, 0.5, 0.5, ramp, ch=0.07, corner=0.2, jit=0.03, a=0.44, b=0.4)
		# soft layered mass, tips swept down and out; short, not a burst
		for i, (tip, r) in enumerate((((0.36, -0.42, 6.56), 0.34), ((0.88, -0.3, 6.32), 0.36), ((1.26, 0.0, 5.72), 0.34), ((0.34, 0.34, 6.72), 0.38), ((0.94, 0.42, 6.34), 0.36), ((1.14, 0.78, 5.32), 0.32), ((0.48, 1.08, 5.82), 0.38), ((0.42, 1.1, 5.08), 0.34))):
			tx, ty, tz = tip
			gem(k, "Head", f"Lay{s}{i}", (s * tx * 0.34, ty * 0.3, 5.72), (s * tx, ty, tz), r, ramp=ramp, bend=0.08, twist=0.3 + 0.13 * i % 0.5)
		# the fringe falls straight from the centre part, longer towards the side
		for i, (x, ztip, r) in enumerate(((0.2, 4.96, 0.26), (0.52, 5.0, 0.28), (0.86, 4.92, 0.26))):
			gem(k, "Head", f"Fringe{s}{i}", (s * x * 0.86, -0.6, 5.86), (s * x, -0.94, ztip), r, ramp=ramp, flat=0.5, twist=0.2 + 0.25 * i, bend=0.14)
		for i, (y, z0, r) in enumerate(((-0.5, 4.46, 0.25), (-0.12, 4.4, 0.27), (0.26, 4.42, 0.3))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.88, y, 5.45), (s * 1.0, y + 0.02, z0), r, ramp=ramp, flat=0.5, twist=0.25 + 0.2 * i, across=(0, 1, 0))
		for i, x in enumerate((0.24, 0.68)):
			gem(k, "Head", f"NapeS{s}{i}", (s * x, 0.74, 5.05), (s * x * 1.1, 0.96, 4.24 + 0.06 * i), 0.3, ramp=ramp, flat=0.5, twist=0.3, across=(1, 0, 0))


def _suit(k):
	t = "UpperTorso"
	block(k, t, "Body", 0, 0, 3.98, 2.0, 1.06, 0.57, "navy", ch=0.08, flare=0.02, jit=0.03, mids=(3.4, 2.7), a=0.46, b=0.6, tone=0.04)
	block(k, t, "Collar", 0, -0.02, 4.16, 3.9, 0.72, 0.54, "navy", ch=0.05, corner=0.3, a=0.52, b=0.6)
	# silver zip down the centre
	block(k, t, "Zip", 0, -0.59, 4.14, 2.44, 0.05, 0.03, "silver", ch=0.012, a=0.62)
	block(k, t, "Pull", 0, -0.63, 4.14, 3.92, 0.06, 0.02, "silver", ch=0.01, a=0.8)
	# chest harness: silver straps over the shoulders to a plate
	for s in (1, -1):
		strip(k, t, f"Harness{s}", (s * 0.7, 3.96), (s * 0.34, 3.2), 0.09, -0.63, 0.06, "silver", a=0.55)
		strip(k, t, f"HarnessB{s}", (s * 0.7, 3.96), (s * 0.34, 3.2), 0.09, 0.57, 0.06, "silver", a=0.42)
	block(k, t, "Plate", 0, -0.6, 3.3, 3.06, 0.46, 0.05, "silver", ch=0.03, a=0.58)
	block(k, t, "PlateB", 0, 0.6, 3.3, 3.06, 0.46, 0.05, "silver", ch=0.03, a=0.42)
	block(k, t, "Belt", 0, 0, 2.44, 2.14, 1.1, 0.62, "belt", ch=0.04, a=0.56, b=0.45)
	block(k, t, "Buckle", 0, -0.635, 2.42, 2.16, 0.2, 0.03, "silver", ch=0.02, a=0.42)
	for i, x in enumerate((-0.82, -0.52, 0.52, 0.82)):
		block(k, t, f"Pouch{i}", x, -0.67, 2.46, 2.1, 0.13, 0.1, "belt", ch=0.03, a=0.5, b=0.45)
	block(k, t, "Hips", 0, 0, 2.14, 1.88, 1.08, 0.585, "navy", ch=0.02, a=0.44, b=0.62)


def _ice(k):
	"""A few crystals standing on the viewer's left shoulder, close to the body."""
	arm = "RightUpperArm"
	for i, (b, t, r) in enumerate((((-1.7, 0.0, 3.96), (-1.82, 0.02, 4.68), 0.2), ((-1.42, -0.14, 3.96), (-1.36, -0.22, 4.38), 0.15), ((-1.8, 0.28, 3.96), (-2.02, 0.32, 4.34), 0.15), ((-1.4, 0.24, 3.96), (-1.34, 0.34, 4.26), 0.12))):
		gem(k, arm, f"Ice{i}", b, t, r, ramp="ice", flat=0.9, twist=0.4, a=0.56, b_=0.5)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.0, 2.84, 0.52, 0.52, "navy", ch=0.09, corner=0.18, jit=0.03, sub=1, mids=(3.4,), a=0.46, b=0.6)
	block(k, arm, "Fore", ax, 0, 2.92, 2.46, 0.52, 0.52, "navy", ch=0.06, corner=0.18, jit=0.02, a=0.46, b=0.6)
	block(k, arm, "Wrist", ax, 0, 2.66, 2.36, 0.56, 0.56, "silver", ch=0.05, corner=0.2, a=0.46, b=0.5)
	hand(k, arm, ax, "skin", z1=2.42)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 0.9, 0.525, 0.57, "navy", ch=0.04, flare=0.04, corner=0.16, jit=0.05, mids=(1.45,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Shaft", x, 0.02, 1.02, 0.14, 0.54, 0.6, "boot", ch=0.05, flare=0.015, a=0.52, b=0.55)
	block(k, leg, "Toe", x, -0.28, 0.5, 0.14, 0.55, 0.52, "boot", ch=0.09, corner=0.25, a=0.56, b=0.55)
	block(k, leg, "Sole", x, -0.16, 0.17, 0.0, 0.57, 0.76, "boot", ch=0.03, a=0.28, b=0.3)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_ice(k)
	finish()


def paint(a):
	R.paint(a)
	f = head_faces(a, SKIN, SKIN_D, "#F2F2F2")
	# the burn round the viewer's right eye
	f.path("M74 30L84 38L92 26L106 34L120 28L126 46L122 58L128 70L114 80L104 76L94 84L84 74L76 76L78 58L72 46Z", "#b04c44", blur=1)
	f.soft("M82 40L104 38L118 46L118 66L104 72L86 68L80 54Z", "#963228", 0.7, 2)
	anime_eye(f, 37, 60, -1, "#8a8f98", w=35, up=13, dn=12, lift=5, lt=3.0, wing=2.5, ir=11.5, low=shade(SKIN, 0.42))
	f.skin = "#a8403a"
	anime_eye(f, 93, 60, 1, "#23b8c8", w=35, up=13, dn=12, lift=5, lt=3.0, wing=2.5, ir=11.5)
	f.skin = SKIN
	brow_block(f, -1, 12, 42, 43, 39, 2.8, "#8e94a0")
	brow_block(f, 1, 12, 42, 43, 39, 2.8, "#6e1216")
	nose(f, SKIN_D, 82)
	# flat, calm mouth
	f.path("M55 102Q65 104 75 102", stroke="#6a3a30", sw=1.6)
