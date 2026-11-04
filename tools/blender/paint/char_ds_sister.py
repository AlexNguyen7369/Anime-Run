# Painted look for ds_sister: pink hemp-leaf kimono, dark coat, checked sash, bamboo bit, hair to the thighs.
from atlas import INK, face_base, paint_hair, shade
from ds_common import L, asanoha, checks, clip, coat, dome, fore, hairline, haori_body, head_sides, shades, sharp_eye, sleeve, tip_tone, tone, unclip

SKIN = "#f7dfcf"
HAIRC = "#1E1720"
TIP = "#e8602c"
PINK = "#f2a9bd"
PINK_D = "#cf5f85"
DEFAULT = PINK
SHORT = "#1E1721"  # no orange: only the long lengths run to it
HAIR_COLOURS = [HAIRC, SHORT]
BOW = "#F28FB0"
BOW_D = "#D65F88"

HAIR = {
	"colour": "#0e0a10",
	"cap": {"size": [1.34, 1.26, 0.54], "at": [0, 0.02, 5.04], "bevel": 0.24},
	"locks": tone(
		[
			# blunt fringe, a few thin strands falling between the eyes
			fore(-0.5, 4.82, 0.27, -0.42, colour=SHORT),
			fore(-0.22, 4.86, 0.27, colour=SHORT),
			fore(0.03, 4.7, 0.16, colour=SHORT),
			fore(0.26, 4.86, 0.27, colour=SHORT),
			fore(0.5, 4.82, 0.27, 0.42, colour=SHORT),
			# side locks, past the jaw, tips going orange
			L([0.56, -0.2, 5.46], [0.82, -0.78, 5.1], [0.76, -0.68, 3.9], 0.22, flatten=0.5, mirror=True),
			L([0.62, -0.05, 5.3], [0.9, -0.3, 4.7], [0.86, -0.32, 3.7], 0.25, flatten=0.55, mirror=True),
			# crown over the top, short and black
			*dome(top=5.8, colour=SHORT),
			# long curtain down the back to the thighs: wide flat locks, overlapping, tips fanning
			*[L([x, 0.42, 5.36 if abs(x) < 0.5 else 5.12], [x * 1.28, 1.08, 3.9], [x * 1.3 + (0.08 if x > 0 else -0.08), 0.92, tz], 0.42, flatten=0.42) for x, tz in ((-0.62, 1.66), (-0.3, 1.32), (0.0, 1.2), (0.3, 1.34), (0.62, 1.7))],
			*[L([x, 0.56, 5.1], [x * 1.25, 1.16, 3.6], [x * 1.25, 1.04, tz], 0.34, flatten=0.42) for x, tz in ((-0.46, 1.9), (-0.15, 1.62), (0.15, 1.6), (0.46, 1.92))],
			L([0.66, 0.3, 4.98], [1.0, 0.46, 3.8], [1.1, 0.5, 2.42], 0.26, flatten=0.5, mirror=True),
		],
		HAIRC,
	),
}

PROPS = [
	# ribbon on the character's left, high at the back of the head: two broad loops, a knot, two tails
	{"part": "Head", "box": [0.56, 0.3, 0.34], "at": [1.02, 0.3, 5.3], "rot": [0, -0.5, 0], "colour": BOW, "bevel": 0.05},
	{"part": "Head", "box": [0.5, 0.3, 0.3], "at": [1.0, 0.3, 4.86], "rot": [0, 0.55, 0], "colour": BOW, "bevel": 0.05},
	{"part": "Head", "box": [0.2, 0.2, 0.2], "at": [0.76, 0.3, 5.08], "colour": BOW_D, "bevel": 0.06},
	{"part": "Head", "lock": [[0.76, 0.34, 5.04], [0.96, 0.5, 4.74], [1.16, 0.66, 4.42]], "r": 0.12, "colour": BOW_D, "flatten": 0.3},
	{"part": "Head", "lock": [[0.74, 0.38, 5.04], [0.7, 0.7, 4.72], [0.86, 0.9, 4.34]], "r": 0.12, "colour": BOW_D, "flatten": 0.3},
	# cord that holds the bit, round the back of the head
	{"part": "Head", "box": [1.34, 1.24, 0.05], "at": [0, 0, 4.25], "colour": "#C42A2A", "bevel": 0.01},
	{"part": "UpperTorso", "box": [1.24, 1.08, 0.12], "at": [0, 0, 4.03], "colour": "#3A1A1E", "bevel": 0.04},
]
COATC, COATD = "#4e1f24", "#2e1216"


def coat_cloth(f):
	checks(f, COATC, COATD, 30, ox=(f.w % 60) / 2, wob=0.6)


def kimono(f):
	f.fill(PINK)
	asanoha(f, PINK_D, 26, 0.85)
	f.soft(f"M{f.w * 0.75}-5H{f.w + 5}V{f.h + 5}H{f.w * 0.85}Z", "#70304e", 0.3, 4)


def torso_inner(f):
	kimono(f)
	# crossed collar, white underlayer at the neck
	f.path("M72-5L100 44L128-5Z", "#f8f2ea", stroke=INK, sw=1.4)
	f.path("M82-5L100 30L118-5Z", SKIN)
	f.path("M60-5L102 50L114 36L80-5Z", shade(PINK, 0.86), stroke=INK, sw=1.3)
	shades(f, 3, 0.2, 0.5, (100, 100), op=0.24)
	# wide checked sash with a cord
	f.path("M-5 106H205V168H-5Z", "#c9772a", stroke=INK, sw=1.6)
	sash_checks(f)


def sash_checks(f):
	for j, y in enumerate(range(106, 168, 15)):
		for i in range(-1, 15):
			if (i + j) % 2 == 0:
				x = i * 15 + 5
				f.path(f"M{x} {y}H{x + 15}V{min(y + 15, 168)}H{x}Z", "#7c2c1c")
	f.path("M-5 134H205V141H-5Z", "#9bc46a", stroke=INK, sw=1)
	f.path("M90 130H110V146H90Z", "#7fa650", stroke=INK, sw=1)
	f.soft("M-5 106H205V112H-5Z", "#000000", 0.4, 2)


def coat_skirt(f):
	"""Coat ends at mid-thigh, the kimono runs on to the knee below it."""
	clip(f, "M-5 54H305V110H-5Z")
	kimono(f)
	unclip(f)
	f.ink("M-5 54H305", 2.2)
	f.soft("M-5 55H305V61H-5Z", "#3c1a2a", 0.5, 2)


def paint(a):
	paint_hair(a, ["#332a3a", "#332a3a"])
	tip_tone(a, 0, 2, TIP, 32, 0.95)
	# a sheen band so black strands still read
	a["Hair"].path("M-5 44H1030V54H-5Z", "#7c6e90", opacity=0.55, blur=2)
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=34)
	hairline(f, "#14101a", 20)
	# wide pink eyes, heavy lids, slit pupil: a demon held in check
	for sgn, ix, ox in ((-1, 51, 16), (1, 79, 114)):
		sharp_eye(f, ix, 70, ox, 62, 8.8, 8.0, "#e8559a", "#7e1a55", "#ffb6d6", 11.5, dx=-sgn, dy=1, pupil=0, lid=3.0, shine=1.8, flick=3)
		cx, cy = (ix + ox) / 2 - sgn, 67
		f.path(f"M{cx} {cy - 8}Q{cx + 2.2} {cy} {cx} {cy + 8}Q{cx - 2.2} {cy} {cx} {cy - 8}Z", "#2a0620")
		f.taper(ix + sgn * 2, 49, (ix + ox) / 2, 44, ox + sgn * 2, 48, 1.1, "#2a1a20")
	# the bit leaves only a trace of the mouth; a hard shadow falls under it
	f.path("M26 110H104V118Q65 122 26 118Z", shade(SKIN, 0.68), opacity=0.8)
	head_sides(a, SKIN, "#1c141e", "#54405c")
	haori_body(a, coat_cloth, SKIN, inner=torso_inner, cuff=PINK, trouser=PINK, trouser_l="#ffd8e4", wrap_top=100, strap="#c42a2a", coat_open=34, lapel="#1a0a0e", coat_hem=coat_skirt, hem_y=54)
	f = a["Coat"]
	clip(f, "M-5 -5H34V105H-5Z")
	kimono(f)
	unclip(f)
	f.soft("M-5 96H305V105H-5Z", "#000000", 0.35, 1)
	f.ink("M-5 98H305", 1.4)
	a["CoatIn"].fill(shade(PINK, 0.55))


def model(parts, kit):
	coat(kit, parts, 0.98, 0.11)
	sleeve(kit, parts, 2.28, 0.08)
	head = parts["Head"]
	# bamboo bit: a round tube across the mouth with cut ends and two nodes
	bm = kit.bmesh.new()
	kit.bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.085, radius2=0.085, depth=1.32)
	bm.transform(kit.Matrix.Rotation(1.5708, 4, "Y"))
	mesh = kit.bpy.data.meshes.new("Head_Bit")
	bm.to_mesh(mesh)
	bm.free()
	for p in mesh.polygons:
		p.use_smooth = True
	o = kit._obj("Head_Bit", mesh, "#8FB25A", head)
	o.location = (0, -0.68, 4.26)
	for x in (-0.28, 0.28):
		kit.rbox("Head_BitNode", (0.03, 0.18, 0.18), (x, -0.68, 4.26), "#5F8A3C", head, bevel=0.01)
	for x in (-0.66, 0.66):
		kit.rbox("Head_BitEnd", (0.01, 0.13, 0.13), (x, -0.68, 4.26), "#D8DE96", head, bevel=0)
