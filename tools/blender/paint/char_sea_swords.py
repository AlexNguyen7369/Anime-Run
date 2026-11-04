# Target look for sea_swords (design doc section 5): short green hair, one sharp eye, the other shut under a long scar, three
# gold earrings, long open dark-green coat, red sash, black trousers and boots, black arm band, three swords on the left hip.
from atlas import INK, shade
from sea_style3 import bake, block, eye, gem, hand, head_base, head_sides, jitter, leg, mirror, prism, rod
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#eebf92"
SKIN_D = "#c68d60"
SKIN_L = "#f8d4ac"
GREEN = "#4c9a3e"
GREEN_D = "#2c6a26"
SCAR = "#a2574c"
DEFAULT = "#22432a"
R = Ramps(
	hair=["#1c4a1a", "#2f7a2a", "#4ea23e", "#6dbf52", "#95d874"],
	skin=["#b67e52", "#dca878", "#eebf92", "#f8d4ac"],
	coat=["#0e2414", "#1a3a20", "#285430", "#3a7044", "#54905e"],
	trim=["#07140a", "#102414", "#1a3820", "#2a5230"],
	sash=["#5c0c12", "#961820", "#c82a30", "#e45048", "#f4806e"],
	pant=["#08080c", "#14141a", "#24242e", "#3a3a48"],
	boot=["#050507", "#101014", "#22222a", "#3c3c48"],
	band=["#040406", "#0e0e12", "#1e1e26", "#34343e"],
	gold=["#94600a", "#d09e18", "#f4cc3c", "#fff09a"],
	white=["#9c9ca8", "#d8d8e0", "#f2f2f6", "#ffffff"],
	black=["#050507", "#121216", "#26262e", "#44444e"],
	crim=["#4a0a10", "#801420", "#b0242c", "#d84a48"],
	steel=["#4a4e58", "#868c98", "#bcc2cc", "#eef0f4"],
)
HAIR = {"colour": GREEN, "locks": []}
PROPS = []


def _hair(k):
	# a low close cap, then many short blunt tufts: this hair is the shortest of the series
	bake(k, k.lathe("Head", "Crown", [(0.92, 5.28, 0.5), (0.98, 5.46, 0.5), (0.93, 5.74, 0.5), (0.58, 5.94, 0.5), (0.14, 6.0, 0.5)], "hair", n=10, at=(0, 0.03, 0), squash=0.92, outline=0), "hair", a=0.5, b=0.4)
	nape = k.tube("Head", "Nape", [(0, 0.4, 5.3, 0.94, 0.47), (0, 0.4, 4.9, 0.945, 0.47), (0, 0.4, 4.62, 0.8, 0.38)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.018)
	bake(k, nape, "hair", a=0.42, b=0.36)
	# few broad clumps lying back over the skull: rising from the brow and combed outwards
	tufts = (
		(-0.56, -0.6, 5.25, -0.96, -0.93, 5.74),
		(0.0, -0.62, 5.28, -0.04, -1.0, 5.84),
		(0.56, -0.6, 5.25, 0.96, -0.93, 5.74),
		(-0.46, -0.1, 5.7, -0.78, -0.3, 6.18),
		(0.34, -0.14, 5.72, 0.5, -0.32, 6.22),
		(-0.76, 0.2, 5.44, -1.12, 0.26, 5.86),
		(0.76, 0.2, 5.44, 1.12, 0.26, 5.86),
		(-0.34, 0.5, 5.56, -0.62, 0.92, 5.94),
		(0.34, 0.5, 5.56, 0.62, 0.92, 5.94),
	)
	for i, (x0, y0, z0, x1, y1, z1) in enumerate(tufts):
		gem(k, "Head", f"Tuft{i}", (x0, y0, z0), (x1, y1, z1), 0.42, flat=0.55, twist=0.2 + 0.17 * i)
	for s in (1, -1):
		for i, (y, z) in enumerate(((-0.3, 4.78), (0.1, 4.6))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.88, y, 5.34), (s * 0.97, y + 0.04, z), 0.24, flat=0.42, twist=0.3 + 0.2 * i, across=(0, 1, 0))
	# three gold earrings on the viewer's right: the character's left ear
	k.blob("Head", "Ear1", (0.93, 0.02, 4.64), (0.09, 0.17, 0.2), "skin", v=0.55, rings=3, n=6, outline=0)
	k.blob("Head", "Ear-1", (-0.93, 0.02, 4.64), (0.09, 0.17, 0.2), "skin", v=0.55, rings=3, n=6, outline=0)
	for i, z in enumerate((4.56, 4.42, 4.28)):
		rod(k, "Head", f"Earring{i}", (0.99, -0.14 + 0.13 * i, z + 0.08), (0.99, -0.14 + 0.13 * i, z - 0.08), 0.045, "gold", n=6, a=0.72, b=0.3)


def _coat(k):
	t = "UpperTorso"
	# the chest shows in a deep V, the back and shoulders are one chunky mass
	k.reshape(t, "Torso", [(0, 0, 3.98, 0.98, 0.5), (0, 0, 2.02, 0.98, 0.5)], corner=0.1, nc=1)
	block(k, t, "CoatBack", 0, 0.26, 3.99, 2.05, 1.05, 0.31, "coat", ch=0.05, jit=0.012, mids=(3.2,), a=0.5, b=0.56, g=0.1, tone=0.03)
	panel = [(0.5, 3.99), (1.05, 3.99), (1.05, 2.5), (0.04, 2.5)]
	prism(k, t, "PanelL", panel, -0.57, 0.0, "coat", a=0.5, b=0.56, g=0.12)
	prism(k, t, "PanelR", mirror(panel), -0.57, 0.0, "coat", a=0.5, b=0.56, g=0.12)
	trim = [(0.5, 3.99), (0.7, 3.99), (0.24, 2.5), (0.04, 2.5)]
	prism(k, t, "TrimL", trim, -0.62, -0.5, "trim", a=0.5, b=0.56)
	prism(k, t, "TrimR", mirror(trim), -0.62, -0.5, "trim", a=0.5, b=0.56)
	# a standing collar round the back of the neck and down the shoulders
	block(k, t, "Collar", 0, 0.38, 4.28, 3.94, 0.84, 0.2, "trim", ch=0.04, a=0.56, b=0.56)
	for s in (1, -1):
		prism(k, t, f"CollarS{s}", [(s * 0.5, 3.99), (s * 0.92, 3.99), (s * 0.92, 4.24), (s * 0.62, 4.16)], -0.6, 0.4, "trim", a=0.5, b=0.56)
	# trousers and hips inside the coat, the coat's hem round them
	block(k, t, "Hips", 0, 0, 2.3, 1.88, 1.0, 0.52, "pant", ch=0.03, a=0.48)
	for s in (1, -1):
		pts = [(s * 1.05, 2.5), (s * 0.34, 2.5), (s * 0.36, 1.9), (s * 1.06, 1.9)]
		prism(k, t, f"Skirt{s}", pts if s > 0 else pts[::-1], -0.59, -0.5, "coat", a=0.48, b=0.56, g=0.1)
	block(k, t, "SkirtBack", 0, 0.48, 2.5, 1.9, 1.06, 0.12, "coat", ch=0.02, a=0.46, b=0.56, g=0.1)
	# the red sash: a thick faceted wrap with a knot and a tail on the viewer's left
	block(k, t, "Sash", 0, 0, 2.66, 2.2, 1.09, 0.62, "sash", ch=0.05, corner=0.2, sub=2, jit=0.028, a=0.52, b=0.6, tone=0.06)
	block(k, t, "SashKnot", -0.62, -0.66, 2.62, 2.26, 0.2, 0.09, "sash", ch=0.04, jit=0.02, a=0.62, b=0.56)
	prism(k, t, "SashTail", [(-0.76, 2.34), (-0.42, 2.34), (-0.38, 2.0), (-0.8, 2.0)], -0.69, -0.61, "sash", a=0.56, b=0.5, g=0.1)
	prism(k, "RightUpperLeg", "SashTail2", [(-0.8, 2.0), (-0.38, 2.0), (-0.34, 1.32), (-0.58, 1.42), (-0.84, 1.3)], -0.69, -0.61, "sash", a=0.52, b=0.5, g=0.12)


def _swords(k):
	"""Three hilts stand forward from the sash on the character's left; the scabbards run back through the coat and out behind."""
	t = "UpperTorso"
	for i, (x, ramp, wrap) in enumerate(((0.46, "white", "steel"), (0.73, "black", "gold"), (1.0, "crim", "gold"))):
		z = 3.12 - 0.04 * i
		# the hilt rises more steeply than the scabbard; the bend is hidden inside the sash
		front, guard, end = (x, -1.02, z), (x, -0.64, z - 0.5), (x, 1.82, z - 1.92)
		rod(k, t, f"Hilt{i}", front, guard, 0.075, ramp, n=6, a=0.56, b=0.46)
		rod(k, t, f"Pommel{i}", (x, -1.07, z + 0.065), front, 0.085, wrap, n=6, a=0.62, b=0.4)
		rod(k, t, f"Guard{i}", (x, -0.67, z - 0.46), (x, -0.63, z - 0.52), 0.15, wrap, n=8, a=0.66, b=0.36)
		rod(k, t, f"Scabbard{i}", guard, end, 0.075, ramp, n=6, r1=0.06, a=0.52, b=0.46)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 4.04, 2.56, 0.515, 0.515, "coat", ch=0.1, corner=0.18, sub=1, jit=0.02, mids=(3.3,), a=0.5, b=0.56, g=0.1, tone=0.03)
	block(k, arm, "SleeveCuff", ax, 0, 2.66, 2.52, 0.54, 0.54, "trim", ch=0.03, corner=0.18, a=0.5, b=0.5)
	hand(k, arm, ax)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	px = s * 0.52
	leg(k, side, s)
	block(k, part, "Trousers", px, 0, 1.97, 0.78, 0.47, 0.5, "pant", ch=0.03, flare=0.03, corner=0.14, jit=0.018, mids=(1.3,), a=0.46, b=0.56, g=0.1, tone=0.03)
	# the coat's open skirt on this leg: a back and side wall, and the front edge only on the outer half
	block(k, part, "SkirtBack", s * 0.53, 0.56, 1.97, 0.9, 0.45, 0.075, "coat", ch=0.015, flare=0.012, a=0.46, b=0.56, g=0.12)
	block(k, part, "SkirtSide", s * 0.95, 0, 1.97, 0.9, 0.04, 0.62, "coat", ch=0.01, flare=0.012, corner=0.1, a=0.46, b=0.56, g=0.12)
	pts = [(s * 0.34, 1.97), (s * 0.99, 1.97), (s * 1.0, 0.9), (s * 0.4, 0.9)]
	prism(k, part, "SkirtFront", pts, -0.62, -0.52, "coat", a=0.48, b=0.56, g=0.12)
	edge = [(s * 0.34, 1.97), (s * 0.45, 1.97), (s * 0.51, 0.9), (s * 0.4, 0.9)]
	prism(k, part, "SkirtEdge", edge, -0.65, -0.58, "trim", a=0.5, b=0.56)
	block(k, part, "BootTop", px, 0.02, 0.86, 0.3, 0.5, 0.56, "boot", ch=0.05, flare=0.015, corner=0.14, a=0.5, b=0.56)
	block(k, part, "BootCuff", px, 0.02, 0.9, 0.76, 0.52, 0.58, "boot", ch=0.02, a=0.68, b=0.46)
	block(k, part, "Foot", px, -0.14, 0.36, 0.1, 0.51, 0.66, "boot", ch=0.07, corner=0.24, a=0.56, b=0.5)
	block(k, part, "Sole", px, -0.14, 0.12, 0.0, 0.54, 0.72, "boot", ch=0.02, a=0.28, b=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_coat(k)
	_swords(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	# the black band tied on the character's left upper arm, its knot on the outside
	block(k, "LeftUpperArm", "ArmBand", 1.5, 0, 3.66, 3.32, 0.545, 0.545, "band", ch=0.03, corner=0.18, a=0.5, b=0.5)
	block(k, "LeftUpperArm", "ArmKnot", 2.04, -0.06, 3.58, 3.4, 0.06, 0.1, "band", ch=0.02, a=0.6, b=0.5)
	rod(k, "LeftUpperArm", "ArmTail", (2.06, -0.06, 3.44), (2.18, -0.16, 3.08), 0.05, "band", n=4, r1=0.03, a=0.52, b=0.5)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=18)
	# a straight hairline the buzz cut grows from
	f.path("M-5-5H135V14L118 10L102 16L84 11L65 17L46 11L28 16L12 10L-5 14Z", GREEN_D)
	# the open eye on the viewer's left: narrow and hard
	eye(f, 38, 60, -1, "#27241f", "#0a0908", "#6a6050", w=31, up=15, down=9, inner=3, outer=-6, wing=3.2, lid=6, ry=10.5)
	# the shut eye on the viewer's right: a heavy lid line; the scar crosses it from brow to cheek
	f.path("M78 62Q93 68 110 58L110 62Q93 73 78 66Z", INK)
	f.path("M78 56Q93 54 110 50", stroke=shade(SKIN, 0.68), sw=1.6)
	for s, x in ((-1, 38), (1, 93)):
		ib, ob = 65 + s * 8, 65 + s * 49
		f.path(f"M{ib} 49L{ib + s * 2} 37Q{65 + s * 26} 33 {ob} 27L{ob - s * 1} 36Q{65 + s * 24} 40 {ib + s} 49Z", GREEN_D, stroke="#1a4a18", sw=0.8)
	f.path("M94 26L92 104", stroke=shade(SCAR, 0.72), sw=4.6)
	f.path("M94 26L92 104", stroke=SCAR, sw=2.6)
	# a short nose and a hard, faintly smirking line, one small fang
	f.soft("M59 80L65 72L71 80Q65 85 59 80Z", SKIN_D, 0.75, 1)
	f.path("M60 83Q65 85.5 70 83", stroke=shade(SKIN, 0.5), sw=1.1)
	f.path("M44 104Q66 108 86 99", stroke=INK, sw=2.6)
	f.path("M74 103L77 110L80 101.5Z", "#fffdf8", stroke=INK, sw=0.9)
	f.path("M54 114Q66 117 76 113", stroke=shade(SKIN, 0.62), sw=1.3)
	head_sides(a, SKIN, SKIN_D)
	# the close-cut hair round the head sides, a clean line above the ear
	a["Head_L"].path("M-5-5H125V68L80 62L58 48L30 40L-5 34Z", GREEN_D)
	a["Head_R"].path("M125-5H-5V68L40 62L62 48L90 40L125 34Z", GREEN_D)
	for n in ("Head_B", "Head_T"):
		a[n].fill(GREEN_D)
	# the chest in the V: skin, soft shadow from the coat, the long diagonal scar from the character's left shoulder down
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M-5-5H205V22Q100 40 -5 22Z", SKIN_D, 0.7, 5)
	f.soft("M-5-5H62L100 150L-5 150Z", SKIN_D, 0.75, 5)
	f.soft("M205-5H138L100 150L205 150Z", SKIN_D, 0.75, 5)
	f.path("M82 62Q92 72 98 66", stroke=shade(SKIN, 0.72), sw=2.2)
	f.path("M118 62Q108 72 102 66", stroke=shade(SKIN, 0.72), sw=2.2)
	f.path("M100 68V132", stroke=shade(SKIN, 0.72), sw=1.8)
	f.path("M144 10L58 136", stroke=shade(SCAR, 0.72), sw=5)
	f.path("M144 10L58 136", stroke=SCAR, sw=3)
