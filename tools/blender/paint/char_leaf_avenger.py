# Target look for leaf_avenger (design doc section 5): big head, blue-black duck-tail spikes and long side bangs, white short-sleeved
# high collar shirt closed over a dark undershirt, purple rope belt with a big bow, navy hip cloth, arm guards, straight sword at the back.
from leaf_common import ell
from leaf_style3 import back_panel, block, dark_eye, gem, hand, head_sides, jitter, bake, rope, sandal, shard, skin_face, stroke, true_face_uv, xf
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f8e2d2"
SKIN_D = "#deb49c"
DEFAULT = "#2e2e3a"
R = Ramps(
	hair=["#0a0c16", "#151a2c", "#232b46", "#37436a", "#55648f"],
	skin=["#c99b82", "#ecc5ad", "#f8e2d2", "#fff0e4"],
	shirt=["#9c9eb0", "#d4d5de", "#f2f2f4", "#ffffff"],
	under=["#10101a", "#1c1c2a", "#2a2a3a"],
	pants=["#12121c", "#212130", "#2e2e3e", "#454558"],
	cloth=["#14162a", "#22253f", "#2f3354", "#42466e"],
	rope=["#2f1858", "#4c2a84", "#6b3fa0", "#8c5ec4", "#ab84dc"],
	guard=["#10101a", "#20202e", "#32323f", "#4a4a5a"],
	sole=["#0b0a0e", "#19171d", "#2b2830", "#3d3a44"],
	sheath=["#0e0e12", "#222228", "#3a3a42", "#5a5a64"],
	hilt=["#3c3c48", "#6a6a78", "#a4a4b0", "#d6d6e0"],
	steel=["#59606c", "#8f96a2", "#c2c8d0", "#eef1f4"],
)
HAIR = {"colour": "#1E2333", "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.42, 0.6), (0, 0, 4.16, 0.7, 0.78), (0, 0, 4.46, 0.88, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.9, 5.2, 0.5), (0.99, 5.5, 0.5), (0.92, 5.86, 0.5), (0.5, 6.14, 0.5), (0.14, 6.2, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.98, outline=0)
	bake(k, dome, "hair", a=0.4, b=0.34)
	# a cap of hair over the head's upper corners, down to the hairline
	block(k, "Head", "Cap", 0, 0, 5.74, 5.24, 0.935, 0.85, "hair", ch=0.05, corner=0.2, jit=0.015, a=0.36, b=0.4)
	root = (0, 0.25, 5.55)

	def from_root(tip, f=0.3):
		return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))

	# the duck tail: broad wedges thrown backward and up from the crown, fanning round the back of the head
	spikes = (((0.0, 1.72, 6.3), 0.44), ((-0.62, 1.56, 6.16), 0.42), ((0.62, 1.56, 6.16), 0.42), ((-1.06, 1.3, 5.76), 0.36), ((1.06, 1.3, 5.76), 0.36), ((0.0, 1.86, 5.72), 0.46), ((-0.56, 1.72, 5.46), 0.42), ((0.56, 1.72, 5.46), 0.42), ((-0.98, 1.26, 5.12), 0.32), ((0.98, 1.26, 5.12), 0.32), ((0.0, 1.5, 5.02), 0.38))
	for i, (tip, r) in enumerate(spikes):
		gem(k, "Head", f"Back{i}", from_root(tip), tip, r, bend=0.05, twist=0.3 + 0.13 * i % 0.5, a=0.42, b_=0.72)
	# the crown stands up towards the back
	for i, (tip, r) in enumerate((((-0.46, 0.46, 6.5), 0.36), ((0.1, 0.66, 6.62), 0.4), ((0.56, 0.46, 6.46), 0.34))):
		gem(k, "Head", f"Top{i}", (tip[0] * 0.5, 0.2, 5.8), tip, r, twist=0.5 + 0.2 * i, a=0.42, b_=0.72)
	# the sides of the head and the nape
	nape = k.tube("Head", "Nape", [(0, 0.36, 5.66, 0.9, 0.52), (0, 0.36, 5.3, 0.97, 0.56), (0, 0.36, 4.7, 0.96, 0.54), (0, 0.4, 4.34, 0.88, 0.48)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.03)
	bake(k, nape, "hair", a=0.36, b=0.36)
	for s in (1, -1):
		# the long bangs: from the parting, out over the temple and down to a point at the jaw, framing the face
		shard(k, f"Bang{s}", ((s * 0.14, -0.86, 5.82, 0.16), (s * 0.6, -0.98, 5.56, 0.3), (s * 0.82, -1.0, 5.0, 0.26), (s * 0.84, -0.96, 4.4, 0.2), (s * 0.72, -0.93, 3.92, 0.01)), a=0.42, b_=0.62)
		# the mass behind them, along the side of the head
		shard(k, f"Side{s}", ((s * 0.74, -0.5, 5.7, 0.26), (s * 1.02, -0.52, 5.2, 0.34), (s * 1.04, -0.44, 4.66, 0.24), (s * 0.96, -0.38, 4.2, 0.01)), a=0.36, b_=0.62)
		shard(k, f"SideB{s}", ((s * 0.8, -0.05, 5.6, 0.3), (s * 1.06, -0.05, 5.1, 0.38), (s * 1.08, 0.0, 4.62, 0.28), (s * 1.0, 0.04, 4.22, 0.01)), a=0.34, b_=0.62)
		shard(k, f"SideC{s}", ((s * 0.72, 0.5, 5.4, 0.28), (s * 1.0, 0.55, 4.96, 0.32), (s * 0.94, 0.6, 4.54, 0.2), (s * 0.82, 0.66, 4.2, 0.01)), a=0.32, b_=0.62)
		# the hairline above the bangs
		shard(k, f"Fringe{s}", ((s * 0.34, -0.66, 6.02, 0.2), (s * 0.5, -0.92, 5.72, 0.3), (s * 0.46, -0.95, 5.4, 0.2), (s * 0.4, -0.92, 5.14, 0.01)), a=0.46, b_=0.6)
	# the strands that fall onto the forehead from the parting
	shard(k, "Centre", ((0.02, -0.72, 6.04, 0.2), (-0.06, -0.96, 5.72, 0.26), (-0.12, -0.96, 5.34, 0.15), (-0.18, -0.92, 4.98, 0.01)), a=0.5, b_=0.6)
	for i, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
		gem(k, "Head", f"NapeS{i}", (x, 0.66, 4.8), (x * 1.05, 0.9, 4.1 + 0.08 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0), a=0.38, b_=0.7)


def _shirt(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, t, "Shirt", 0, 0, 3.98, 2.3, 1.06, 0.57, "shirt", ch=0.06, jit=0.02, sub=1, mids=(3.2,), a=0.62, b=0.36, g=0.08)
	back_panel(k, t, 3.92, 2.5, 1.04, 0.54, "shirt", a=0.62, b=0.36)
	# the opening: a dark V closed over the chest, a raised white lapel down each side, crossing at the base
	verts, faces = [], []
	for y in (-0.5, -0.615):
		verts += [(-0.52, y, 3.96), (0.52, y, 3.96), (0.0, y, 2.78)]
	faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
	bake(k, k._mesh("Under", t, verts, faces, (), 0), "under", a=0.5, b=0.3, g=0.2)
	for s in (1, -1):
		verts = []
		for y in (-0.5, -0.665):
			verts += [(s * 0.46, y, 4.0), (s * 0.78, y, 4.0), (s * 0.18, y, 2.72), (s * -0.02, y, 2.86)]
		faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
		bake(k, k._mesh(f"Lapel{s}", t, verts, faces, (), 0), "shirt", a=0.68, b=0.32)
	# the high collar stands round the neck and opens at the front
	c = k.band(t, "Collar", (0, 0.02, 3.96), 0.86, 0.7, -58, 238, lambda a: (-0.04, 0.34 - 0.2 * max(0.0, 1 - abs((a + 90) if a < 90 else (a - 270)) / 42)), "shirt", thick=0.09, e=0.62, n=18, flare=0.08, outline=0)
	bake(k, c, "shirt", a=0.64, b=0.34)
	# the neck in the opening
	block(k, t, "Neck", 0, -0.04, 4.1, 3.9, 0.5, 0.42, "skin", ch=0.02, a=0.32, b=0.1, g=0.0)


def _belt(k):
	t = "UpperTorso"
	# under the rope the hip cloth starts; the hips belong to the torso (a leg mesh stays at z <= 2)
	block(k, t, "Hips", 0, 0, 2.42, 1.88, 1.1, 0.61, "cloth", ch=0.03, a=0.46, b=0.5, g=0.1)
	rope(k, t, "RopeA", 2.5, 1.09, 0.6, 0.135, "rope", a=0.54, b=0.46, g=0.0)
	rope(k, t, "RopeB", 2.27, 1.1, 0.61, 0.135, "rope", a=0.5, b=0.46, g=0.0)
	# the big bow at the back, the sword thrust under it
	by, bz = 0.86, 2.36
	shard(k, "BowKnot", ((0, by - 0.1, bz + 0.16, 0.2), (0, by + 0.04, bz, 0.24), (0, by - 0.1, bz - 0.16, 0.18)), ramp="rope", part=t, flat=0.9, centre=(0, 0, bz), a=0.46, b_=0.5)
	for s in (1, -1):
		shard(k, f"BowLoop{s}", ((s * 0.1, by, bz, 0.12), (s * 0.5, by + 0.06, bz + 0.2, 0.2), (s * 0.74, by + 0.03, bz + 0.1, 0.2), (s * 0.84, by, bz - 0.06, 0.02)), ramp="rope", part=t, flat=0.9, centre=(0, 0, bz), a=0.48, b_=0.5)
		shard(k, f"BowTail{s}", ((s * 0.08, by, bz - 0.06, 0.12), (s * 0.22, by + 0.05, bz - 0.34, 0.11), (s * 0.3, by + 0.04, bz - 0.56, 0.08), (s * 0.34, by + 0.04, bz - 0.62, 0.01)), ramp="rope", part=t, flat=0.9, centre=(0, 0, bz), a=0.44, b_=0.5)


def _sword(k):
	"""The straight sword, close to the back: sheath from the viewer's right low to the hilt at the viewer's left high."""
	t = "UpperTorso"
	y = 0.74
	piv = (0, y, 2.62)
	ang = 34
	s = block(k, t, "Sheath", 0.02, y, 1.82 + 0.04, 0.62 + 0.04, 0.078, 0.06, "sheath", ch=0.02, a=0.5, b=0.5, g=0.0)
	# built standing, then swung; the long axis runs through the pivot
	for v in s.data.vertices:
		v.co.z += 1.0
	block_parts = [s]
	block_parts.append(block(k, t, "Tip", 0.02, y, 1.74, 1.62, 0.085, 0.066, "steel", ch=0.02, a=0.5, b=0.4, g=0.0))
	block_parts.append(block(k, t, "Guard", 0.02, y, 2.96, 2.9, 0.15, 0.11, "steel", ch=0.015, a=0.5, b=0.4, g=0.0))
	block_parts.append(block(k, t, "Hilt", 0.02, y, 3.52, 2.96, 0.06, 0.055, "hilt", ch=0.015, a=0.5, b=0.4, g=0.0))
	block_parts.append(block(k, t, "Pommel", 0.02, y, 3.56, 3.5, 0.07, 0.062, "steel", ch=0.012, a=0.5, b=0.4, g=0.0))
	for o in block_parts:
		xf(o, piv, ry=-ang)


def _arm(k, s, side):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	# the short loose sleeve, with a turned hem
	block(k, arm, "Sleeve", ax, 0, 4.02, 3.14, 0.53, 0.53, "shirt", ch=0.09, corner=0.18, jit=0.02, flare=0.02, sub=1, a=0.62, b=0.38)
	block(k, arm, "SleeveHem", ax, 0, 3.22, 3.08, 0.565, 0.565, "shirt", ch=0.03, corner=0.18, a=0.7, b=0.3)
	# the long dark arm guard, elbow to wrist, with a strap at each end
	block(k, arm, "Guard", ax, 0, 3.14, 2.34, 0.525, 0.525, "guard", ch=0.05, corner=0.16, jit=0.01, a=0.5, b=0.56)
	for i, z in enumerate((2.98, 2.42)):
		block(k, arm, f"GuardStrap{i}", ax, 0, z + 0.04, z - 0.04, 0.54, 0.54, "sheath", ch=0.015, corner=0.16, a=0.4, b=0.4)
	hand(k, arm, ax)


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	x = s * 0.5
	px = s * 0.54
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# the loose trousers under the cloth
	block(k, leg, "Pants", px, 0, 1.95, 0.72, 0.5, 0.55, "pants", ch=0.04, flare=0.04, corner=0.16, jit=0.04, mids=(1.3,), a=0.44, b=0.62, g=0.1, tone=0.06)
	# the hip cloth: wraps each thigh, open at the centre front, its hem cut on a slant
	cloth = block(k, leg, "Cloth", px, 0.03, 1.95, 1.02, 0.56, 0.62, "cloth", ch=0.03, flare=0.06, corner=0.14, jit=0.035, mids=(1.5,), a=0.48, b=0.6, g=0.14, tone=0.05)
	for v in cloth.data.vertices:
		if v.co.z < 1.2:
			v.co.z += 0.16 * (1 - abs(v.co.x) / 1.1)
	cloth.data.update()
	block(k, leg, "Shaft", px, 0.02, 0.88, 0.5, 0.5, 0.56, "guard", ch=0.05, flare=0.02, a=0.54)
	sandal(k, leg, px, "guard", "sole")


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	true_face_uv(parts["Head"])
	_hair(k)
	_shirt(k)
	_belt(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, top=36)
	for s, x in ((-1, 38), (1, 92)):
		dark_eye(f, x, 62, s, w=31, up=9, dn=7, tilt=8, heavy=2)
		# level, thin, slightly angled brows
		ib, ob = 65 + s * 10, 65 + s * 40
		f.path(f"M{ib} 49L{ib + s * 1} 45Q{65 + s * 26} 39 {ob} 37L{ob - s * 1} 41Q{65 + s * 24} 44 {ib} 49Z", "#1a1f30")
	# a small straight nose and a closed, unsmiling mouth
	stroke(f, ((66, 76), (67.5, 84), (65, 87)), 0.9, "#c58f76")
	f.path("M56 104Q65 102.5 74 104", stroke="#7c4f42", sw=1.5)
	f.soft("M58 109Q65 111 72 109Q65 114 58 109Z", SKIN_D, 0.6, 1)
	# the back: the shirt's white with the red-over-white fan high on it
	f = a["Torso_B"]
	f.fill("#f2f2f4")
	f.soft("M-5 90Q100 104 205 90V205H-5Z", "#c4c5d0", 0.7, 5)
	cx, cy, r = 100, 34, 27
	f.path(f"M{cx} {cy + r + 14}V{cy + r - 2}", stroke="#2c2c3a", sw=8)
	f.path(f"M{cx - r - 2} {cy}A{r + 2} {r + 2} 0 0 1 {cx + r + 2} {cy}A{r + 2} {r + 2} 0 0 1 {cx - r - 2} {cy}Z", "#2c2c3a")
	f.path(f"M{cx - r} {cy}A{r} {r} 0 0 1 {cx + r} {cy}Z", "#c4141e")
	f.path(f"M{cx - r} {cy}A{r} {r} 0 0 0 {cx + r} {cy}Z", "#ffffff")
	f.path(ell(cx, cy, 1, 1), "#c4141e")
	head_sides(a, SKIN, SKIN_D)
