# Target look for kaiju_hero "Kafko", kaiju form (design doc section 5): a horned bone skull for a face with small cyan eyes and a long row of
# teeth, a dark scaled hood with spines, charcoal muscle plates split by glowing cyan seams, a bone collar line, layered armour legs.
# +X is the viewer's right in the front view. Drawn in-house.
from jk_style3 import bake, jitter
from kaiju_style3 import Kit, Ramps, big_head, block, finish, gem, prism, slab, stroke

BONE, BONE_D = "#dcdad2", "#a5a298"
DARK = "#2f3136"
CYAN = "#22e6f0"
DEFAULT = DARK
R = Ramps(
	hide=["#0e0f12", "#1d1f23", "#33363b", "#4a4e55", "#6a6f78"],
	deep=["#050506", "#0b0c0e", "#141619", "#202327"],
	plate=["#131417", "#26282d", "#3c4046", "#555a62", "#7a808a"],
	bone=["#77746c", BONE_D, BONE, "#f4f2ec", "#ffffff"],
	cyan=["#0aa0b4", "#16d0e0", CYAN, "#9cfbff", "#e8ffff"],
	ink=["#040405", "#0a0a0c"],
)
HAIR = {"colour": DARK, "locks": []}
PROPS = []
T = "UpperTorso"


def _head(k):
	h = "Head"
	# the dark scaled hood over the top, sides and back
	for name, rows in (
		("Hood", [(0, 0.16, 5.98, 0.34, 0.32), (0, 0.2, 5.84, 0.66, 0.58), (0, 0.22, 5.5, 0.9, 0.74), (0, 0.22, 4.9, 0.98, 0.76), (0, 0.22, 4.4, 0.94, 0.7), (0, 0.2, 3.96, 0.78, 0.54)]),
		("HoodTop", [(0, -0.12, 5.86, 0.46, 0.4), (0, -0.12, 5.74, 0.74, 0.62), (0, -0.1, 5.44, 0.9, 0.72), (0, -0.1, 5.3, 0.9, 0.72)]),
	):
		o = k.tube(h, name, rows, "hide", corner=0.6, nc=2, sub=1, outline=0)
		jitter(o, 0.03)
		bake(o, "hide", k, a=0.48, b=0.5, tone=0.05)
	# spines marching over the crown and down the back
	for i, (y0, z0, y1, z1, r) in enumerate(((0.1, 5.7, 0.4, 6.3, 0.26), (0.5, 5.6, 1.0, 6.04, 0.28), (0.74, 5.2, 1.4, 5.5, 0.28), (0.8, 4.7, 1.44, 4.86, 0.28), (0.8, 4.3, 1.3, 4.3, 0.24))):
		gem(k, h, f"Spine{i}", (0, y0, z0), (0, y1, z1), r, "plate", flat=0.5, across=(1, 0, 0), a=0.5)
	for s in (1, -1):
		for i, (y0, z0, y1, z1) in enumerate(((0.3, 5.5, 0.6, 6.0), (0.7, 5.1, 1.2, 5.44), (0.76, 4.6, 1.24, 4.76))):
			gem(k, h, f"Scale{s}{i}", (s * 0.6, y0, z0), (s * 0.92, y1, z1), 0.24, "hide", flat=0.5, across=(1, 0, 0), a=0.54)
		# the bone horn: root on the brow, up and forward
		# low on the brow, heavy at the root, sweeping out and back to a point, ridged
		gem(k, h, f"Horn{s}", (s * 0.42, -0.8, 5.16), (s * 1.02, -0.3, 6.28), 0.33, "bone", flat=0.8, twist=0.2, bend=0.1, a=0.52)
		gem(k, h, f"HornStep{s}", (s * 0.34, -0.86, 5.0), (s * 0.68, -0.82, 5.82), 0.22, "bone", flat=0.6, twist=0.2, a=0.6)
		block(k, h, f"HornRoot{s}", s * 0.52, -0.62, 5.5, 5.16, 0.34, 0.3, "bone", ch=0.08, corner=0.3, a=0.52, b=0.46)
		# brow ridge and cheekbone, raised bone
		prism(k, h, f"Brow{s}", [(s * 0.04, 4.86), (s * 0.84, 5.18), (s * 0.94, 5.36), (s * 0.5, 5.46), (s * 0.04, 5.22)], -1.02, -0.8, "bone", a=0.56, b=0.46)
		prism(k, h, f"Cheek{s}", [(s * 0.3, 4.6), (s * 0.94, 4.78), (s * 0.95, 4.54), (s * 0.56, 4.42)], -0.95, -0.8, "bone", a=0.56, b=0.4)
		# teeth run right round to the side of the head
		for i, y in enumerate((-0.6, -0.4, -0.2, 0.0)):
			gem(k, h, f"SideTooth{s}{i}", (s * 0.94, y, 4.5), (s * 0.97, y, 4.2), 0.1, "bone", flat=0.5, across=(0, 1, 0), a=0.7)
			gem(k, h, f"SideToothLow{s}{i}", (s * 0.94, y - 0.06, 4.08), (s * 0.97, y - 0.06, 4.32), 0.09, "bone", flat=0.5, across=(0, 1, 0), a=0.6)
		slab(k, f"Gum{s}", [(-0.78, 4.46), (0.14, 4.4), (0.14, 4.16), (-0.78, 4.1)], *sorted((s * 0.86, s * 0.935)), "ink", a=0.5, b=0.1)
		slab(k, f"SideBone{s}", [(-0.8, 5.34), (-0.3, 5.3), (-0.12, 4.9), (0.2, 4.56), (0.14, 4.42), (-0.8, 4.48)], *sorted((s * 0.86, s * 1.02)), "bone", a=0.54, b=0.4)
	block(k, h, "Forehead", 0, -0.62, 5.5, 5.1, 0.3, 0.24, "bone", ch=0.08, corner=0.3, a=0.52, b=0.46)
	prism(k, h, "NoseRidge", [(-0.1, 4.96), (0.1, 4.96), (0.13, 4.72), (-0.13, 4.72)], -0.96, -0.8, "bone", a=0.62, b=0.3)
	# the dark mouth and its interlocking teeth, four of them long fangs
	prism(k, h, "Mouth", [(-0.86, 4.46), (0.86, 4.46), (0.8, 4.12), (-0.8, 4.12)], -0.86, -0.8, "ink", a=0.5, b=0.1)
	for i in range(-4, 5):
		x = i * 0.185
		ln = 0.34 if abs(i) in (2,) else 0.23
		prism(k, h, f"ToothU{i}", [(x - 0.088, 4.48), (x + 0.088, 4.48), (x + 0.05, 4.48 - ln * 0.7), (x, 4.48 - ln), (x - 0.05, 4.48 - ln * 0.7)], -0.95, -0.85, "bone", a=0.74, b=0.2)
	for i in range(-4, 4):
		x = i * 0.185 + 0.09
		ln = 0.32 if i in (-4, 3) else 0.2
		prism(k, h, f"ToothL{i}", [(x - 0.08, 4.08), (x + 0.08, 4.08), (x, 4.08 + ln)], -0.93, -0.84, "bone", a=0.6, b=0.2)
	# the jaw: a hinge at each side, tapering to a narrow chin
	prism(k, h, "Jaw", [(-0.84, 4.14), (0.84, 4.14), (0.7, 3.96), (0.36, 3.82), (-0.36, 3.82), (-0.7, 3.96)], -0.94, -0.4, "bone", a=0.52, b=0.46)
	prism(k, h, "Chin", [(-0.24, 4.06), (0.24, 4.06), (0.3, 3.86), (-0.3, 3.86)], -1.0, -0.9, "bone", a=0.58, b=0.4)
	for s in (1, -1):
		slab(k, f"JawSide{s}", [(-0.9, 4.12), (0.1, 4.34), (0.22, 4.1), (0.0, 3.96), (-0.8, 3.86)], *sorted((s * 0.8, s * 0.94)), "bone", a=0.5, b=0.4)


def _body(k):
	k.reshape(T, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, T, "Trunk", 0, 0.02, 4.02, 1.94, 1.04, 0.56, "hide", ch=0.08, jit=0.02, mids=(3.4, 2.8), a=0.42, b=0.5)
	block(k, T, "Neck", 0, 0, 4.16, 3.86, 0.66, 0.6, "deep", ch=0.05, corner=0.3, a=0.6, b=0.5)
	# the glowing bed the abdomen plates sit on, so every gap shines
	prism(k, T, "Bed", [(-0.62, 3.1), (0, 3.2), (0.62, 3.1), (0.56, 2.1), (-0.56, 2.1)], -0.62, -0.5, "cyan", a=0.62, b=0.2)
	for s in (1, -1):
		prism(k, T, f"Pec{s}", [(s * 0.03, 3.82), (s * 0.5, 3.9), (s * 1.04, 3.86), (s * 1.06, 3.36), (s * 0.66, 3.14), (s * 0.03, 3.22)], -0.76, -0.5, "hide", a=0.56, b=0.5, g=0.24)
		# the bone line over the collar
		prism(k, T, f"Collar{s}", [(s * 0.08, 3.66), (s * 0.08, 3.5), (s * 0.5, 3.74), (s * 0.98, 4.0), (s * 1.0, 4.14), (s * 0.46, 3.88)], -0.84, -0.7, "bone", a=0.66, b=0.36)
		for i, (z1, z0, w) in enumerate(((3.02, 2.76, 0.46), (2.68, 2.44, 0.44), (2.36, 2.14, 0.4))):
			block(k, T, f"Ab{s}{i}", s * 0.27, -0.62, z1, z0, 0.2, 0.08, "hide", ch=0.03, corner=0.3, a=0.54, b=0.5)
		# flank plates, stepped
		for i, (z1, z0) in enumerate(((3.1, 2.76), (2.8, 2.46), (2.5, 2.1))):
			block(k, T, f"Flank{s}{i}", s * 0.84, -0.04, z1, z0, 0.26, 0.6, "plate", ch=0.04, flare=0.03, a=0.48, b=0.5)
	prism(k, T, "Groin", [(-0.44, 2.28), (0.44, 2.28), (0.3, 1.96), (-0.3, 1.96)], -0.72, -0.55, "plate", a=0.52, b=0.5)
	for i, z in enumerate((3.86, 3.4, 2.94, 2.48)):
		gem(k, T, f"BackSpine{i}", (0, 0.5, z), (0, 0.98, z - 0.1 + 0.2), 0.2, "bone", flat=0.6, across=(1, 0, 0), a=0.6)
		for s in (1, -1):
			block(k, T, f"BackPlate{s}{i}", s * 0.52, 0.58, z + 0.16, z - 0.24, 0.42, 0.07, "hide", ch=0.04, a=0.48, b=0.5)


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Core", ax, 0, 3.9, 1.9, 0.47, 0.47, "cyan", ch=0.04, corner=0.2, a=0.6, b=0.2)
	# dark muscle plates with the glow left showing between them
	block(k, arm, "Delt", s * 1.54, 0, 4.2, 3.5, 0.6, 0.62, "hide", ch=0.16, corner=0.26, sub=1, jit=0.03, a=0.48, b=0.52)
	for x0, x1, tag in ((-0.56, 0.06, "A"), (0.14, 0.56, "B")):
		cx, hw = ax + s * (x0 + x1) / 2, (x1 - x0) / 2
		block(k, arm, f"Up{tag}", cx, 0, 3.42, 2.96, hw, 0.54, "hide", ch=0.05, jit=0.015, a=0.5, b=0.52)
		block(k, arm, f"Fore{tag}", cx, 0, 2.86, 2.3, hw, 0.55, "hide", ch=0.06, jit=0.015, a=0.5, b=0.52)
	block(k, arm, "Wrist", ax, 0, 2.36, 2.28, 0.52, 0.52, "cyan", ch=0.02, a=0.66, b=0.2)
	block(k, arm, "Hand", ax, 0, 2.28, 1.78, 0.53, 0.53, "hide", ch=0.06, a=0.56, b=0.5)
	block(k, arm, "HandSeam", ax, 0, 2.06, 2.0, 0.54, 0.54, "cyan", ch=0.02, a=0.64, b=0.2)


def _leg(k, side, s):
	leg, x, px = f"{side}UpperLeg", s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Core", px, 0, 1.96, 0.2, 0.46, 0.5, "deep", ch=0.04, a=0.5, b=0.5)
	# overlapping armour of uneven plates: long curved thigh shells with a pointed front, shorter shin shells
	for i, (z1, z0, fl) in enumerate(((1.98, 1.5, 0.05), (1.56, 1.18, 0.08))):
		block(k, leg, f"Thigh{i}", px, 0.02, z1, z0, 0.47, 0.52, "plate", ch=0.05, flare=fl, corner=0.2, a=0.46 + 0.06 * i, b=0.54)
		prism(k, leg, f"ThighV{i}", [(px - 0.42, z1 - 0.08), (px + 0.42, z1 - 0.08), (px + 0.46, z0 + 0.1), (px + s * 0.12, z0 - 0.1), (px - 0.46, z0 + 0.1)], -0.66, -0.5, "plate", a=0.56, b=0.5, g=0.2)
	block(k, leg, "Knee", px, -0.5, 1.2, 0.9, 0.3, 0.2, "hide", ch=0.07, corner=0.3, a=0.62, b=0.5)
	for i, (z1, z0, fl) in enumerate(((1.0, 0.7, 0.04), (0.72, 0.4, 0.08))):
		block(k, leg, f"Shin{i}", px, 0.02, z1, z0, 0.46, 0.5, "plate", ch=0.05, flare=fl, corner=0.2, a=0.46 + 0.06 * i, b=0.54)
		prism(k, leg, f"ShinV{i}", [(px - 0.36, z1 - 0.04), (px, z1 - 0.14), (px + 0.36, z1 - 0.04), (px + 0.3, z0 + 0.08), (px, z0 - 0.06), (px - 0.3, z0 + 0.08)], -0.66, -0.5, "plate", a=0.58, b=0.5, g=0.2)
	block(k, leg, "Foot", px, -0.22, 0.4, 0.0, 0.52, 0.66, "hide", ch=0.1, corner=0.22, a=0.52, b=0.5)
	for i, dx in enumerate((-0.36, -0.12, 0.12, 0.36)):
		block(k, leg, f"Toe{i}", px + dx, -0.9, 0.2, 0.0, 0.1, 0.12, "hide", ch=0.04, a=0.5, b=0.5)
		block(k, leg, f"ToeGlow{i}", px + dx, -0.68, 0.39, 0.16, 0.045, 0.22, "cyan", ch=0.02, a=0.64, b=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_head(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.fill(BONE)
	f.soft("M-5 70H14Q20 100 34 135H-5Z", BONE_D, 0.6, 3)
	f.soft("M135 70H116Q110 100 96 135H135Z", BONE_D, 0.7, 3)
	for s, cx in ((-1, 36), (1, 94)):
		# a deep black socket cut under the brow, one small burning eye
		f.path(f"M{cx - s * 22} 48L{cx + s * 24} 32L{cx + s * 26} 58L{cx + s * 12} 72L{cx - s * 10} 74L{cx - s * 22} 62Z", "#08080a")
		f.path(f"M{cx - s * 12} 56L{cx + s * 11} 48L{cx + s * 10} 60L{cx - s * 6} 65Z", CYAN)
		f.path(f"M{cx - s * 4} 56L{cx + s * 5} 53L{cx + s * 4} 60L{cx - s * 3} 61Z", "#e8ffff")
		# the crack running down from the socket
		stroke(f, f"M{cx + s * 2} 72L{cx} 82L{cx + s * 4} 90", "#1a1a1c", 2.0)
		stroke(f, f"M{cx - s * 12} 72L{cx - s * 14} 80", "#1a1a1c", 1.6)
		# the nose hole
		f.path(f"M{65 + s * 2} 72L{65 + s * 9} 86L{65 + s * 2} 84Z", "#0a0a0c")
	for n in list(a.faces):
		if n == "Hair" or n == "Head_F":
			continue
		a[n].fill(DARK)
