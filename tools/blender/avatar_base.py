# Roblox-avatar style body, face and pieces (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline").
# Front faces -Y; the character's left side is +X. Every mesh is parented to one of the 15 R15 part objects.
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector


R15_PARTS = [
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
]


def hex_rgb(h):
	h = h.lstrip("#")
	return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# Part boxes: (width, depth, z bottom, z top). R15 block proportions (proposed): legs 2, torso 2, head 1.3.
LEG_X, ARM_X = 0.5, 1.5
HEAD = (1.3, 1.2, 4.0, 5.3)
FACE_Y = -0.6  # head front plane
BOXES = {
	"UpperTorso": (2.0, 1.0, 2.5, 4.0, 0),
	"LowerTorso": (2.0, 1.0, 2.0, 2.5, 0),
	"UpperArm": (0.95, 0.95, 3.1, 4.0, ARM_X),
	"LowerArm": (0.93, 0.93, 2.25, 3.1, ARM_X),
	"Hand": (0.93, 0.93, 1.95, 2.25, ARM_X),
	"UpperLeg": (0.97, 0.97, 1.1, 2.0, LEG_X),
	"LowerLeg": (0.95, 0.95, 0.3, 1.1, LEG_X),
	"Foot": (0.97, 1.1, 0.0, 0.3, LEG_X),
}

_mats = {}


def clear_mats():
	_mats.clear()


def plastic(hexcol):
	"""Studio-style smooth plastic: Principled base colour, no shine."""
	if hexcol in _mats:
		return _mats[hexcol]
	m = bpy.data.materials.new("M_" + hexcol.lstrip("#"))
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	lin = [srgb_to_linear(c) for c in hex_rgb(hexcol)]
	bsdf.inputs["Base Color"].default_value = (*lin, 1)
	bsdf.inputs["Roughness"].default_value = 0.65
	m.diffuse_color = (*lin, 1)
	_mats[hexcol] = m
	return m


def _obj(name, mesh, colour, parent):
	o = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(o)
	mesh.materials.append(plastic(colour))
	if parent is not None:
		o.parent = parent
		o.matrix_parent_inverse = Matrix.Translation(parent.location).inverted()  # child coords stay world
	return o


def rbox(name, size, loc, colour, parent=None, bevel=0.05, segments=1, rot=(0, 0, 0)):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
	if bevel > 0:
		bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=bevel, segments=segments, affect="EDGES", profile=0.5)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	o = _obj(name, mesh, colour, parent)
	o.location = loc
	o.rotation_euler = rot
	return o


def flat(name, pts, colour, parent, y=FACE_Y - 0.004, back=False):
	"""Flat polygon in the XZ plane: painted-on face features and clothing panels."""
	mesh = bpy.data.meshes.new(name)
	verts = [(x, y, z) for x, z in pts]
	idx = list(range(len(verts)))
	# Winding: the face normal points outward (-Y for the front, +Y for the back), whichever way the points were listed.
	area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in idx)
	if (area > 0) == back:
		idx.reverse()
	mesh.from_pydata(verts, [], [idx])
	mesh.update()
	o = _obj(name, mesh, colour, parent)
	o["flat"] = True  # painted detail: no outline shell, no cel band (export)
	return o


def side_flat(name, pts, colour, parent, x):
	"""Flat polygon in the YZ plane on a part's outer side, pts = (y, z)."""
	mesh = bpy.data.meshes.new(name)
	idx = list(range(len(pts)))
	area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in idx)
	if (area > 0) != (x > 0):
		idx.reverse()
	mesh.from_pydata([(x, y, z) for y, z in pts], [], [idx])
	mesh.update()
	o = _obj(name, mesh, colour, parent)
	o["flat"] = True
	return o


def _bezier(a, b, c, t):
	return tuple((1 - t) ** 2 * a[i] + 2 * (1 - t) * t * b[i] + t * t * c[i] for i in range(3))


def lock(name, base, ctrl, tip, r, colour, parent, flatten=0.65, rings=4, sides=6):
	"""One tapered, curved hair lock: a quadratic Bezier spine, flattened oval section, pointed tip."""
	spine = [Vector(_bezier(base, ctrl, tip, i / rings)) for i in range(rings + 1)]
	bm = bmesh.new()
	prev = None
	first = None
	for i in range(rings):
		t = i / rings
		d = (spine[i + 1] - spine[i]).normalized()
		side = d.cross(Vector((0, 0, 1)))
		if side.length < 0.01:
			side = Vector((1, 0, 0))
		side.normalize()
		up = side.cross(d).normalized()
		rad = r * (1 - t) ** 0.7
		ring = [
			bm.verts.new(spine[i] + side * rad * math.cos(2 * math.pi * k / sides) + up * rad * flatten * math.sin(2 * math.pi * k / sides))
			for k in range(sides)
		]
		if prev:
			for k in range(sides):
				bm.faces.new((prev[k], prev[(k + 1) % sides], ring[(k + 1) % sides], ring[k]))
		else:
			first = ring
		prev = ring
	end = bm.verts.new(spine[-1])
	for k in range(sides):
		bm.faces.new((prev[k], prev[(k + 1) % sides], end))
	bm.faces.new(list(reversed(first)))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for p in mesh.polygons:
		p.use_smooth = True
	o = _obj(name, mesh, colour, parent)
	o["lock"] = (list(base), list(tip))  # cel band runs from root to tip (export)
	return o


def build_body(c):
	col = c["colours"]
	parts = {}
	w, d, z0, z1 = HEAD
	parts["Head"] = rbox("Head", (w, d, z1 - z0), (0, 0, (z0 + z1) / 2), col["skin"], bevel=0.17, segments=3)
	over = c.get("boxes", {})  # per-part overrides, e.g. broad builds: {"UpperArm": [w, d, z0, z1, x]}
	for key, base in BOXES.items():
		bw, bd, b0, b1, x = over.get(key, base)
		sides = (("", 0),) if x == 0 else (("Left", 1), ("Right", -1))
		for prefix, sgn in sides:
			name = prefix + key
			# per-part colour: exact part name, then key ("UpperArm"), else skin
			colour = col.get(name) or col.get(key) or col["skin"]
			y = -0.05 if key == "Foot" else 0
			parts[name] = rbox(name, (bw, bd, b1 - b0), (sgn * x, y, (b0 + b1) / 2), colour)
	return parts


EYE = {
	# Small sharp anime eyes (owner 2026-11-03: close to the source design, not cute).
	"round": dict(w=0.25, h=0.19, slant=0.02, iris=0.08, lash=0.05),
	"sharp": dict(w=0.27, h=0.13, slant=0.07, iris=0.065, lash=0.055),
	"soft": dict(w=0.25, h=0.21, slant=0.0, iris=0.09, lash=0.05),
}


def _ellipse(cx, cz, rx, rz, n=10):
	return [(cx + rx * math.cos(2 * math.pi * i / n), cz + rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


def build_face(c, head):
	f = c["face"]
	e = EYE[f.get("eye", "round")]
	ez = f.get("eye_z", 4.62)
	ex = f.get("eye_x", 0.28)
	lash = f.get("lash", "#1a1a1a")
	for sgn, tag in ((1, "L"), (-1, "R")):
		w, h, s = e["w"], e["h"], e["slant"]
		x0 = ex - w / 2  # inner corner
		x1 = ex + w / 2  # outer corner
		pts = [(x0, ez - h * 0.15), (x0 + w * 0.2, ez + h * 0.42), (x1 - w * 0.2, ez + h * 0.5 + s), (x1, ez + h * 0.1 + s), (x1 - w * 0.15, ez - h * 0.42), (x0 + w * 0.2, ez - h * 0.5)]
		mirror = lambda ps: [(sgn * x, z) for x, z in ps]
		flat(f"Head_Eye{tag}", mirror(pts), "#ffffff", head)
		cx = ex - w * 0.03
		cz = ez - h * 0.02 + s * 0.3
		flat(f"Head_Iris{tag}", mirror(_ellipse(cx, cz, e["iris"], min(h * 0.5, e["iris"] * 1.25))), c["colours"]["eyes"], head, y=FACE_Y - 0.008)
		flat(f"Head_Pupil{tag}", mirror(_ellipse(cx, cz, e["iris"] * 0.5, min(h * 0.33, e["iris"] * 0.72), 8)), "#141018", head, y=FACE_Y - 0.012)
		flat(f"Head_Shine{tag}", mirror(_ellipse(cx - w * 0.08, cz + h * 0.17, 0.035, 0.04, 6)), "#ffffff", head, y=FACE_Y - 0.016)
		t = e["lash"]
		flat(
			f"Head_Lash{tag}",
			mirror([(x0 - 0.01, ez + h * 0.02), (x0 + w * 0.2, ez + h * 0.42 + t), (x1 - w * 0.2, ez + h * 0.5 + s + t), (x1 + 0.05, ez + h * 0.08 + s), (x1 - w * 0.2, ez + h * 0.42 + s), (x0 + w * 0.2, ez + h * 0.36)]),
			lash,
			head,
			y=FACE_Y - 0.014,
		)
		# Heavy brows set low over the eye; brow_lift is relative to the 0.33 default in the data.
		bz = ez + h * 0.5 + 0.075 + (f.get("brow_lift", 0.33) - 0.33) * 0.5 + s
		tilt = f.get("brow_tilt", 0.0) + 0.012  # >0 = angry (inner end low)
		flat(f"Head_Brow{tag}", mirror([(x0 - 0.02, bz - tilt * 2), (x1 + 0.03, bz + tilt * 2), (x1 + 0.03, bz + tilt * 2 + 0.03), (x0 - 0.02, bz - tilt * 2 + 0.075)]), f.get("brow", lash), head, y=FACE_Y - 0.016)
		flat(f"Head_Under{tag}", mirror([(x0 + 0.03, ez - h * 0.62), (x1 - 0.02, ez - h * 0.62), (x1 - 0.02, ez - h * 0.62 - 0.012), (x0 + 0.03, ez - h * 0.62 - 0.012)]), "#b98a70", head)
		for i in range(f.get("whiskers", 0)):
			wz = 4.36 - i * 0.075
			flat(f"Head_Whisker{tag}{i}", mirror([(0.36, wz), (0.58, wz + 0.03), (0.58, wz + 0.052), (0.36, wz + 0.018)]), f.get("whisker_colour", "#4a2f22"), head)
	flat("Head_Nose", [(0.0, 4.5), (0.035, 4.39), (-0.04, 4.37), (-0.02, 4.4)], f.get("nose", "#b98a70"), head)
	m = f.get("mouth", "smile")
	if m == "grin":
		flat("Head_Mouth", [(-0.2, 4.31), (0.2, 4.31), (0.14, 4.17), (0, 4.13), (-0.14, 4.17)], "#5a1e22", head)
		flat("Head_Teeth", [(-0.18, 4.305), (0.18, 4.305), (0.15, 4.26), (-0.15, 4.26)], "#ffffff", head, y=FACE_Y - 0.008)
	elif m == "smirk":
		flat("Head_Mouth", [(-0.09, 4.255), (0.1, 4.28), (0.1, 4.255), (-0.09, 4.23)], "#5a2a2a", head)
	else:
		flat("Head_Mouth", [(-0.09, 4.27), (0, 4.24), (0.09, 4.27), (0, 4.22)], "#a0434a", head)


def _swirl(size, cx, cz, turns=2.25, n=26):
	"""Ribbon spiral, outer point last."""
	outer, inner = [], []
	for i in range(n + 1):
		t = i / n
		a = t * turns * 2 * math.pi
		r = size * (0.08 + 0.42 * t)
		half = size * 0.05
		outer.append((cx + (r + half) * math.cos(a), cz + (r + half) * math.sin(a)))
		inner.append((cx + (r - half) * math.cos(a), cz + (r - half) * math.sin(a)))
	return [(outer[i], outer[i + 1], inner[i + 1], inner[i]) for i in range(n)]


def build_mark(name, m, part):
	"""Near-copy marks modelled in-house (design doc 5, owner 2026-11-03)."""
	kind, size, (cx, y, cz), colour = m["kind"], m["size"], m["at"], m["colour"]
	back = y > 0
	if kind == "swirl":
		for i, q in enumerate(_swirl(size, cx, cz)):
			flat(f"{name}_{i}", q, colour, part, y=y, back=back)
		if m.get("tip"):  # triangle at the spiral's outer point, the leaf tip
			flat(f"{name}_Tip", [(cx + size * 0.06, cz + size * 0.42), (cx + size * 0.52, cz + size * 0.34), (cx + size * 0.28, cz + size * 0.74)], colour, part, y=y, back=back)
	elif kind == "ring":
		for i in range(16):
			a0, a1 = 2 * math.pi * i / 16, 2 * math.pi * (i + 1) / 16
			q = [(cx + size * math.cos(a0), cz + size * math.sin(a0)), (cx + size * math.cos(a1), cz + size * math.sin(a1)), (cx + size * 0.7 * math.cos(a1), cz + size * 0.7 * math.sin(a1)), (cx + size * 0.7 * math.cos(a0), cz + size * 0.7 * math.sin(a0))]
			flat(f"{name}_{i}", q, colour, part, y=y, back=back)
	elif kind == "fan":
		lower = m["lower"]
		flat(f"{name}_Top", _ellipse(cx, cz + size * 0.15, size * 0.5, size * 0.42, 14), colour, part, y=y, back=back)
		flat(f"{name}_Low", [(cx - size * 0.5, cz + size * 0.15), (cx + size * 0.5, cz + size * 0.15), (cx + size * 0.32, cz - size * 0.2), (cx - size * 0.32, cz - size * 0.2)], lower, part, y=y + (0.003 if back else -0.003), back=back)
		flat(f"{name}_Handle", [(cx - size * 0.06, cz - size * 0.2), (cx + size * 0.06, cz - size * 0.2), (cx + size * 0.06, cz - size * 0.6), (cx - size * 0.06, cz - size * 0.6)], lower, part, y=y + (0.003 if back else -0.003), back=back)
	else:
		raise ValueError("unknown mark " + kind)


def build_pieces(c, parts):
	hair_col = c["hair"]["colour"]
	h = c["hair"]
	head = parts["Head"]
	cap = h.get("cap")
	if cap:
		rbox("Head_HairCap", cap["size"], cap["at"], hair_col, head, bevel=cap.get("bevel", 0.2), segments=3)
	for i, l in enumerate(h["locks"]):
		sides = (1, -1) if l.get("mirror") else (1,)
		for sgn in sides:
			b, m, t = [[sgn * p[0], p[1], p[2]] for p in (l["b"], l["c"], l["t"])]
			lock(f"Head_Lock{i}{'L' if sgn > 0 else 'R'}", b, m, t, l["r"], l.get("colour", hair_col), head, flatten=l.get("flatten", 0.65))
	for i, p in enumerate(c.get("pieces", [])):
		name = f"{p['part']}_Piece{i}"
		part = parts[p["part"]]
		sides = (1, -1) if p.get("mirror") else (1,)
		for sgn in sides:
			suffix = "" if sgn > 0 else "M"
			if "poly" in p:
				pts = [(sgn * x, z) for x, z in p["poly"]]
				flat(name + suffix, pts, p["colour"], part, y=p["y"], back=p["y"] > 0)
			elif "box" in p:
				at = [sgn * p["at"][0], p["at"][1], p["at"][2]]
				rot = p.get("rot", (0, 0, 0))
				rot = (rot[0], sgn * rot[1], sgn * rot[2])
				rbox(name + suffix, p["box"], at, p["colour"], part, bevel=p.get("bevel", 0.02), rot=rot)
			elif "lock" in p:
				b, m, t = [[sgn * q[0], q[1], q[2]] for q in p["lock"]]
				lock(name + suffix, b, m, t, p["r"], p["colour"], part, flatten=p.get("flatten", 0.35))
	for i, m in enumerate(c.get("marks", [])):
		build_mark(f"{m['part']}_Mark{i}", m, parts[m["part"]])


def _darker(hexcol, k):
	return "#%02x%02x%02x" % tuple(int(255 * c * k) for c in hex_rgb(hexcol))


def _stroke(x0, z0, x1, z1, w):
	"""Tapered ink stroke, thick in the middle."""
	dx, dz = x1 - x0, z1 - z0
	n = math.hypot(dx, dz) or 1
	nx, nz = -dz / n * w, dx / n * w
	mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
	return [(x0, z0), (mx + nx, mz + nz), (x1, z1), (mx - nx, mz - nz)]


def build_folds(cid, c, parts):
	"""Auto-drawn cloth folds and skin creases on every body part, seeded by Id so a rebuild is identical."""
	rng = random.Random(cid)
	over = c.get("boxes", {})
	col = c["colours"]
	for key, base in BOXES.items():
		if key in ("Hand", "Foot"):
			continue
		bw, bd, b0, b1, x = over.get(key, base)
		for prefix, sgn in (("", 0),) if x == 0 else (("Left", 1), ("Right", -1)):
			name = prefix + key
			colour = col.get(name) or col.get(key) or col["skin"]
			dark = _darker(colour, 0.6)
			cx = sgn * x
			for side, y in (("F", -bd / 2 - 0.002), ("B", bd / 2 + 0.002)):
				for i in range(3 if b1 - b0 > 0.6 else 1):
					z = rng.uniform(b0 + 0.08, b1 - 0.08)
					edge = rng.choice((-1, 1))
					xa = cx + edge * bw * 0.46
					xb = cx + edge * bw * rng.uniform(0.02, 0.3)
					zb = z + rng.uniform(-0.2, 0.2)
					zb = max(b0 + 0.02, min(b1 - 0.02, zb))
					flat(f"{name}_Fold{side}{i}", _stroke(xa, z, xb, zb, 0.018), dark, parts[name], y=y, back=y > 0)
			if x != 0:  # outer side of a limb
				for i in range(2):
					z = rng.uniform(b0 + 0.08, b1 - 0.08)
					zb = max(b0 + 0.02, min(b1 - 0.02, z + rng.uniform(-0.15, 0.15)))
					ya, yb = -bd * 0.46, bd * rng.uniform(-0.2, 0.2)
					side_flat(f"{name}_FoldS{i}", _stroke(ya, z, yb, zb, 0.018), dark, parts[name], sgn * (x + bw / 2 + 0.002))
