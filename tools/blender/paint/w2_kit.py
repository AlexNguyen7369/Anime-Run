# Shared kit for the World 2 drafts (docs/WORLD2_CAST.md): block limbs, base paint and a small sharp face, on the solo_style3 solids.
from atlas import shade
from ds_style3 import eye
from jk_common import brow2, form
from jk_style3 import crown
from sea_style3 import rod  # noqa: F401
from solo_style3 import Kit, Ramps, T, art_jacket, big_head, block, boot, collar, ears, finish, gem, head_rest, prism, rblock, slab  # noqa: F401


def ramp(base):
	return [shade(base, 0.52), shade(base, 0.76), base, shade(base, 1.2)]


def start(kit, parts, R, ear=True):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	if ear:
		ears(k)
	return k


def arms(k, segs, sides=((1, "Left"), (-1, "Right"))):
	"""segs = (name, z1, z0, half size, ramp)."""
	for s, side in sides:
		arm, x = f"{side}UpperArm", s * 1.5
		k.reshape(arm, f"{side}Arm", [(x, 0, 3.9, 0.42, 0.42), (x, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
		for n, z1, z0, h, r in segs:
			block(k, arm, n, x, 0, z1, z0, h, h, r, ch=0.05, corner=0.16, a=0.5, b=0.48)


def legs(k, segs, shoe=None):
	for s, side in ((1, "Left"), (-1, "Right")):
		leg, x = f"{side}UpperLeg", s * 0.535
		k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.42, 0.42), (s * 0.5, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
		for n, z1, z0, h, r in segs:
			block(k, leg, n, x, 0, z1, z0, min(h, 0.5), h + 0.04, r, ch=0.04, corner=0.16, a=0.48, b=0.54)
		if shoe:
			top, r, sole = shoe
			boot(k, leg, x, r, sole, top=top)


def locks(k, tag, rows, ramp_name="hair", part="Head", mirror=False, flat=0.6, bend=0.0):
	"""rows = (root, tip, radius); mirror adds the other side."""
	for i, (b, t, r) in enumerate(rows):
		for s in (1, -1) if mirror else (1,):
			gem(k, part, f"{tag}{i}{s}", (b[0] * s, b[1], b[2]), (t[0] * s, t[1], t[2]), r, ramp_name, flat=flat, bend=bend, twist=0.25 + 0.04 * i, across=(1, 0, 0) if abs(t[1] - b[1]) > 0.2 else None)


def face(f, skin, iris, brow_c, lash="#1a1020", w=32, up=12, dn=9, inner=4, outer=-4, lid=0.3, tilt=2.0, thick=4.0, by=46, mouth="flat", white="#fbf7f2", line="#6a3428", ir=(9.6, 12), pu=(3, 4.6), wing=5):
	f.fill(skin)
	d = shade(skin, 0.82)
	f.soft("M-5-5H135V28Q65 34 -5 28Z", d, 0.6, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", d, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", d, 0.65, 5)
	for s, cx in ((-1, 37), (1, 93)):
		eye(f, cx, 67, s, iris, w=w, up=up, dn=dn, inner=inner, outer=outer, lid=lid, lash=lash, white=white, ir=ir, pu=pu, wing=wing)
		if brow_c:
			brow2(f, cx, by, s, 30, thick, tilt, brow_c, arc=-1.5)
	f.path("M62 88L65 92L69 89", stroke=shade(skin, 0.62), sw=1.2)
	if mouth == "flat":
		f.path("M54 107Q65 109 76 107", stroke=line, sw=1.8)
	elif mouth == "frown":
		f.path("M52 110Q65 103 78 110", stroke=line, sw=2)
	elif mouth == "smirk":
		f.path("M52 106Q68 113 80 102", stroke=line, sw=2)
	elif mouth == "smile":
		f.path("M50 104Q65 116 80 104", stroke=line, sw=2)
	elif mouth == "grin":
		f.path("M42 102Q65 108 88 100Q84 120 65 121Q48 120 42 102Z", "#fff8ee")
		f.path("M42 102Q65 108 88 100Q84 120 65 121Q48 120 42 102Z", stroke=line, sw=1.8)
		f.path("M46 111Q65 115 85 109", stroke=line, sw=1.1)


def base(a, skin, torso, arm, leg, hand=None, hair=None):
	head_rest(a, shade(skin, 0.86), shade(skin, 0.64))
	a["Head_T"].fill(hair or shade(skin, 0.64))
	if hair:  # no bare scalp between the locks: the block under them takes the hair's colour
		a["Head_B"].fill(hair)
		for n, d in (("Head_L", "M0 0H120V130H66V34H0Z"), ("Head_R", "M0 0H120V34H54V130H0Z")):
			a[n].path(d, hair)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T", "Torso_Bo"):
		a[n].fill(torso)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R"):
		form(a[n], shade(torso, 0.35), 0.5)
	for side in ("Left", "Right"):
		for key in ("F", "B", "O", "I", "T", "Bo"):
			a[f"{side}Arm_{key}"].fill(arm if key != "Bo" else hand or arm)
			a[f"{side}Leg_{key}"].fill(leg)


def back_hair(k, low=4.3, ramp_name="hair", w=0.96):
	"""A layered backing under the back locks, skull to nape."""
	block(k, "Head", "BackA", 0, 0.52, 5.64, low + 0.3, w, 0.44, ramp_name, ch=0.1, corner=0.28, jit=0.02, mids=(5.0,))
	for i, x in enumerate((-0.7, -0.35, 0, 0.35, 0.7)):
		gem(k, "Head", f"NapeL{i}", (x * 0.9, 0.78, low + 0.7), (x * 1.05, 1.0, low - 0.16 - 0.1 * (i % 2)), 0.28, ramp_name, flat=0.5, across=(1, 0, 0))


def jacket_lines(a, light, dark):
	"""Seams and folds on the torso faces, so dark cloth still reads."""
	for n in ("Torso_F", "Torso_B"):
		f = a[n]
		for s in (-1, 1):
			f.path(f"M{100 + s * 30} 10Q{100 + s * 46} 90 {100 + s * 34} 190", stroke=light, sw=3, opacity=0.5)
			f.path(f"M{100 + s * 80} 50Q{100 + s * 60} 90 {100 + s * 88} 120", stroke=dark, sw=4, opacity=0.7)
		f.path("M100 8V192", stroke=dark, sw=2.5, opacity=0.8)


def back_panel(k, ramp_name, trim=None):
	"""Yoke, centre seam and hem pleats on the back."""
	block(k, T, "Yoke", 0, 0.62, 3.9, 3.36, 0.92, 0.05, ramp_name, ch=0.02, a=0.66)
	for s in (1, -1):
		prism(k, T, f"BackP{s}", [(s * 0.08, 3.3), (s * 0.92, 3.3), (s * 0.84, 2.3), (s * 0.08, 2.3)], 0.6, 0.66, ramp_name, a=0.62)
	if trim:
		block(k, T, "YokeTrim", 0, 0.66, 3.4, 3.32, 0.94, 0.03, trim, ch=0.01, a=0.6)
