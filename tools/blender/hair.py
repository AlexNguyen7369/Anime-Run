# Parametric hair presets on the chibi head (docs/CHARACTER_GACHA_SPEC.md "Draft pipeline").
# h = characters.json "hair": {style, colour, tips?, count?, length?, fringe?, up?, tilt?, back?, side_locks?, ...}
import math
import random

from chibi_base import HEAD_R, HEAD_Z, aim_rot, box, cone, cyl, sphere, toon

STYLES = ["spiky", "wild", "flame", "short_messy", "bob", "long_straight", "ponytail", "twin_buns", "bald"]


def _dir(elev_deg, az_deg):
	e, a = math.radians(elev_deg), math.radians(az_deg)
	# azimuth 0 = back (+Y), 90 = character's left (+X), 180 = front (-Y)
	return (math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e))


def _spike(name, d, r, length, base, mat, head, tilt=0.0):
	x, y, z = d
	x += tilt * z
	n = math.sqrt(x * x + y * y + z * z)
	d = (x / n, y / n, z / n)
	c = (d[0] * (r * 0.82 + length / 2), d[1] * (r * 0.82 + length / 2), HEAD_Z + d[2] * (r * 0.82 + length / 2))
	return cone(name, base, length, c, mat, head, rot=aim_rot(d), verts=4)


def build_hair(cid, h, head, head_scale=1.0):
	style = h["style"]
	assert style in STYLES, "unknown hair style " + style
	if style == "bald":
		return
	rng = random.Random(cid)
	r = HEAD_R * head_scale
	main = toon(h["colour"], "hair_" + cid)
	tips = toon(h["tips"], "tips_" + cid) if h.get("tips") else main
	tilt = h.get("tilt", 0.0)
	up = h.get("up", 0.0)
	# Cap: covers the skull, pushed back and up so the face stays clear.
	cap = sphere("Head_HairCap", r * 1.07, (0, r * 0.12, HEAD_Z + r * 0.12), main, head, scale=(1.02, 1.0, 0.95), seg=14, rings=10)
	split = toon(h["split"], "split_" + cid) if h.get("split") else None
	if split is not None:  # two-tone split down the centre: the character's left (+X) half uses "split"
		cap.data.materials.append(split)
		for poly in cap.data.polygons:
			if poly.center.x > 0:
				poly.material_index = 1

	def spikes(count, length, base, elev=(15, 75), back=1.0, mat=None, front_gap=55):
		for i in range(count):
			az = rng.uniform(-180, 180)
			if abs(abs(az) - 180) < front_gap * back:  # keep the face clear
				az = rng.choice([-1, 1]) * rng.uniform(90, 180 - front_gap * back)
			el = rng.uniform(*elev) + up * 20
			L = length * rng.uniform(0.8, 1.2)
			m = mat if mat is not None else (tips if rng.random() < 0.5 else main)
			if split is not None and mat is None:
				m = split if _dir(el, az)[0] > 0 else main
			_spike(f"Head_HairSpike{i}", _dir(el, az), r, L, base, m, head, tilt)

	n = h.get("count")
	L = h.get("length")
	if style == "spiky":
		spikes(n or 11, L or 0.55, 0.17)
	elif style == "wild":
		spikes(n or 8, L or 0.9, 0.24, elev=(5, 80), front_gap=40)
	elif style == "flame":
		spikes(n or 16, L or 0.6, 0.16, elev=(25, 85))
		_spike("Head_HairCrest", (0, 0.2, 1), r, (L or 0.6) * 1.2, 0.2, tips, head, tilt)
	elif style == "short_messy":
		spikes(n or 16, L or 0.28, 0.13, elev=(0, 70))
	elif style == "bob":
		lz = h.get("drop", 0.55)
		for sgn in (-1, 1):
			box(f"Head_HairSide{sgn}", (0.2, r * 1.2, r * lz * 2), (sgn * r * 0.9, r * 0.15, HEAD_Z - r * lz * 0.5), main, head, bevel=0.05)
		box("Head_HairBack", (r * 1.9, 0.22, r * lz * 2), (0, r * 0.85, HEAD_Z - r * lz * 0.5), main, head, bevel=0.05)
	elif style == "long_straight":
		drop = L or 1.6
		box("Head_HairBack", (r * 1.8, 0.24, drop), (0, r * 0.8, HEAD_Z - drop / 2 + r * 0.3), main, head, bevel=0.06)
		for sgn in (-1, 1):
			box(f"Head_HairSide{sgn}", (0.16, r * 0.9, drop * 0.7), (sgn * r * 0.92, 0, HEAD_Z - drop * 0.35 + r * 0.2), main, head, bevel=0.04)
	elif style == "ponytail":
		tl = L or 1.0
		sphere("Head_HairTie", r * 0.2, (0, r * 1.22, HEAD_Z + r * 0.1), tips, head, seg=8, rings=6)
		cyl("Head_HairTail", r * 0.28, tl, (0, r * 1.3, HEAD_Z + r * 0.1 - tl / 2), main, head, verts=6, r2=r * 0.06)
	elif style == "twin_buns":
		for sgn in (-1, 1):
			sphere(f"Head_HairBun{sgn}", r * 0.32, (sgn * r * 0.6, r * 0.3, HEAD_Z + r * 0.85), main, head, seg=10, rings=6)
	if h.get("spikes_back"):
		spikes(h["spikes_back"], h.get("spikes_back_len", 0.4), 0.14, elev=(-20, 30), front_gap=100)
	# Fringe: cones hanging over the forehead.
	fr = h.get("fringe", 3)
	flen = h.get("fringe_len", 0.32)
	for i in range(fr):
		t = (i - (fr - 1) / 2) / max(1, fr - 1)
		x = t * r * 1.1
		side = h.get("fringe_side", 0.0)  # sweep fringe to one side
		z = HEAD_Z + r * 0.62
		fm = split if (split is not None and x > 0) else main
		cone(f"Head_HairFringe{i}", 0.15, flen, (x + side * 0.15, -r * 0.78, z - flen * 0.35), fm, head, rot=(math.pi - 0.35, side * 0.4 + t * 0.3, 0), verts=4)
	if h.get("eye_curtain"):  # long fringe panel over one eye: "right" or "left"
		sgn = -1 if h["eye_curtain"] == "right" else 1
		box("Head_HairCurtain", (r * 0.6, 0.12, r * 0.75), (sgn * r * 0.38, -r * 0.88, HEAD_Z + r * 0.05), main, head, rot=(0.15, 0, 0), bevel=0.04)
	if h.get("side_locks"):
		for sgn in (-1, 1):
			cone(f"Head_HairLock{sgn}", 0.13, h.get("side_locks"), (sgn * r * 0.82, -r * 0.35, HEAD_Z - r * 0.2), main, head, rot=(math.pi, 0, 0), verts=4)
