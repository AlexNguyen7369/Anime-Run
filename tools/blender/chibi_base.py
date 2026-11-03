# Shared chibi body, toon materials, outfit pieces and accessories (docs/CHARACTER_GACHA_SPEC.md "Draft pipeline").
# Every mesh is parented to one of the 15 R15 part objects so a later import can map them onto an R15 rig.
import math

import bpy

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

# Heights in Blender units (front faces -Y). Head ~1/3 of the body height (chibi 1:3, placeholder).
HEAD_Z, HEAD_R = 2.28, 0.72
TORSO_TOP, WAIST, HIP = 1.62, 1.16, 0.88
KNEE, ANKLE = 0.48, 0.18
SHOULDER_X, LEG_X = 0.44, 0.17

_mats = {}


def hex_rgb(h):
	h = h.lstrip("#")
	return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def toon(hexcol, name=None):
	"""Flat two-band toon material (Shader to RGB -> constant ramp -> emission). Nodes are found by type."""
	key = name or hexcol
	if key in _mats:
		return _mats[key]
	m = bpy.data.materials.new("M_" + key.lstrip("#"))
	m.use_nodes = True
	nt = m.node_tree
	for n in list(nt.nodes):
		nt.nodes.remove(n)
	lin = [srgb_to_linear(c) for c in hex_rgb(hexcol)]
	diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
	diffuse.inputs["Color"].default_value = (1, 1, 1, 1)
	torgb = nt.nodes.new("ShaderNodeShaderToRGB")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	ramp.color_ramp.interpolation = "CONSTANT"
	ramp.color_ramp.elements[0].position = 0.0
	ramp.color_ramp.elements[0].color = (0.62, 0.6, 0.7, 1)
	ramp.color_ramp.elements[1].position = 0.28
	ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
	mix = nt.nodes.new("ShaderNodeMix")
	mix.data_type = "RGBA"
	mix.blend_type = "MULTIPLY"
	mix.inputs["Factor"].default_value = 1.0
	mix.inputs[6].default_value = (*lin, 1)
	emit = nt.nodes.new("ShaderNodeEmission")
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(diffuse.outputs[0], torgb.inputs[0])
	nt.links.new(torgb.outputs["Color"], ramp.inputs["Fac"])
	nt.links.new(ramp.outputs["Color"], mix.inputs[7])
	nt.links.new(mix.outputs[2], emit.inputs["Color"])
	nt.links.new(emit.outputs[0], out.inputs["Surface"])
	m.diffuse_color = (*lin, 1)
	_mats[key] = m
	return m


def _finish(obj, name, mat, parent):
	obj.name = name
	obj.data.name = name
	if mat is not None:
		obj.data.materials.clear()
		obj.data.materials.append(mat)
	if parent is not None:
		obj.parent = parent
		obj.matrix_parent_inverse = parent.matrix_world.inverted()
	for p in obj.data.polygons:
		p.use_smooth = False
	return obj


def box(name, size, loc, mat, parent=None, rot=(0, 0, 0), bevel=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.scale = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if bevel > 0:
		mod = o.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel
		mod.segments = 1
		bpy.ops.object.modifier_apply(modifier=mod.name)
	return _finish(o, name, mat, parent)


def cyl(name, r, depth, loc, mat, parent=None, rot=(0, 0, 0), verts=8, r2=None):
	if r2 is None:
		bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
	else:
		bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
	return _finish(bpy.context.active_object, name, mat, parent)


def cone(name, r, depth, loc, mat, parent=None, rot=(0, 0, 0), verts=6):
	bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0, depth=depth, location=loc, rotation=rot)
	return _finish(bpy.context.active_object, name, mat, parent)


def sphere(name, r, loc, mat, parent=None, scale=(1, 1, 1), seg=12, rings=8, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.scale = scale
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return _finish(o, name, mat, parent)


def torus(name, r, thick, loc, mat, parent=None, rot=(0, 0, 0), scale=(1, 1, 1)):
	bpy.ops.mesh.primitive_torus_add(
		major_radius=r, minor_radius=thick, major_segments=16, minor_segments=4, location=loc, rotation=rot
	)
	o = bpy.context.active_object
	o.scale = scale
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return _finish(o, name, mat, parent)


def aim_rot(direction):
	"""Euler rotation that points a +Z primitive along direction (x, y, z)."""
	x, y, z = direction
	length = math.sqrt(x * x + y * y + z * z) or 1
	x, y, z = x / length, y / length, z / length
	pitch = math.acos(max(-1, min(1, z)))
	yaw = math.atan2(y, x)
	return (0, pitch, yaw)


def build_body(c):
	"""The 15 R15 parts. c = one characters.json entry. Returns {part name: object}."""
	skin = toon(c["skin"], "skin_" + c["skin"])
	o = c.get("outfit", {})
	top = toon(o.get("top", c["skin"]))
	sleeve = toon(o.get("sleeve", c["skin"])) if o.get("sleeve") else skin
	pants = toon(o.get("pants", "#333344"))
	shoes = toon(o.get("shoes", "#222222"))
	hands = toon(o["gloves"]) if o.get("gloves") else skin
	bulk = c.get("bulk", 1.0)  # >1 for muscular builds (All-Mighty-style)
	parts = {}
	sw = 0.36 * bulk
	parts["UpperTorso"] = box("UpperTorso", (sw * 2, 0.42 * bulk, TORSO_TOP - WAIST), (0, 0, (TORSO_TOP + WAIST) / 2), top, bevel=0.06)
	parts["LowerTorso"] = box(
		"LowerTorso", (0.62 * bulk, 0.4 * bulk, WAIST - HIP + 0.04), (0, 0, (WAIST + HIP) / 2), toon(o.get("belt", o.get("pants", "#333344"))), bevel=0.05
	)
	head_scale = c.get("head_scale", 1.0)
	parts["Head"] = sphere("Head", HEAD_R * head_scale, (0, 0, HEAD_Z), skin, scale=(1, 0.95, 0.92), seg=14, rings=10)
	sx = SHOULDER_X * bulk + 0.06 * (bulk - 1)
	for side, sgn in (("Left", -1), ("Right", 1)):
		# The character faces -Y, so its left side is +X.
		x = -sgn * sx
		ar = 0.11 * bulk
		parts[side + "UpperArm"] = cyl(side + "UpperArm", ar, 0.28, (x, 0, TORSO_TOP - 0.16), sleeve)
		parts[side + "LowerArm"] = cyl(
			side + "LowerArm", ar * 0.92, 0.26, (x, 0, TORSO_TOP - 0.43), toon(o["forearm"]) if o.get("forearm") else sleeve if o.get("long_sleeves") else skin
		)
		parts[side + "Hand"] = sphere(side + "Hand", 0.12 * bulk, (x, 0, TORSO_TOP - 0.62), hands, seg=8, rings=6)
		lx = -sgn * LEG_X * max(1, bulk * 0.9)
		parts[side + "UpperLeg"] = cyl(side + "UpperLeg", 0.13 * bulk, HIP - KNEE, (lx, 0, (HIP + KNEE) / 2), pants)
		parts[side + "LowerLeg"] = cyl(
			side + "LowerLeg", 0.12 * bulk, KNEE - ANKLE, (lx, 0, (KNEE + ANKLE) / 2), toon(o["shin"]) if o.get("shin") else pants
		)
		parts[side + "Foot"] = box(side + "Foot", (0.22, 0.34, ANKLE), (lx, -0.05, ANKLE / 2), shoes, bevel=0.05)
	return parts


def build_face(c, head):
	f = c.get("face", {})
	eye_col = toon(c.get("eyes", "#2b2b2b"), "iris_" + c.get("eyes", "#2b2b2b"))
	white = toon("#ffffff", "white")
	black = toon("#111111", "black")
	r = HEAD_R * c.get("head_scale", 1.0)
	fy = -r * 0.9
	ez = HEAD_Z - r * 0.08
	# per-eye state: "open", "closed" or "hidden"; sgn -1 = character's right eye, +1 = left eye
	state = {-1: f.get("right_eye", f.get("eyes", "open")), 1: f.get("left_eye", f.get("eyes", "open"))}
	for sgn in (-1, 1):
		x = sgn * r * 0.36
		if state[sgn] == "closed":
			box(f"Head_Lid{sgn}", (r * 0.3, 0.03, 0.035), (x, fy - 0.02, ez - 0.02), black, head)
		if state[sgn] != "open":
			continue
		sphere(f"Head_Eye{sgn}", r * 0.2, (x, fy, ez), white, head, scale=(0.75, 0.25, 1.0), seg=10, rings=6)
		sphere(f"Head_Iris{sgn}", r * 0.15, (x, fy - 0.03, ez - 0.02), eye_col, head, scale=(0.7, 0.2, 0.95), seg=10, rings=6)
		sphere(f"Head_Pupil{sgn}", r * 0.06, (x, fy - 0.06, ez - 0.03), black, head, scale=(0.8, 0.3, 1.1), seg=8, rings=4)
		sphere(f"Head_Shine{sgn}", r * 0.035, (x + sgn * 0.03, fy - 0.08, ez + 0.05), white, head, seg=6, rings=4)
		brow = f.get("brow", "normal")
		tilt = {"angry": 0.35, "sad": -0.3}.get(brow, 0.0) * -sgn
		box(f"Head_Brow{sgn}", (r * 0.32, 0.03, 0.04), (x, fy - 0.02, ez + r * 0.3), toon(c.get("brow_col", c["hair"]["colour"])), head, rot=(0, tilt, 0))
	mouth = f.get("mouth", "smile")
	if mouth == "none":
		return
	mw = {"grin": 0.3, "smile": 0.18, "flat": 0.14, "open": 0.18}.get(mouth, 0.16) * r
	mh = {"grin": 0.07, "open": 0.12}.get(mouth, 0.035)
	box("Head_Mouth", (mw, 0.03, mh), (0, fy + 0.07, HEAD_Z - r * 0.48), toon("#7a2a2a", "mouth"), head)


def mark_mesh(name, shape, size, loc, mat, parent, rot=(math.pi / 2, 0, 0)):
	"""Altered-mark geometry (owner 2026-11-03): simple made-up shapes, never an official symbol."""
	if shape == "ring":
		return torus(name, size * 0.4, size * 0.1, loc, mat, parent, rot=rot)
	if shape == "diamond":
		return cyl(name, size * 0.5, 0.02, loc, mat, parent, rot=rot, verts=4)
	if shape == "triangle":
		return cyl(name, size * 0.5, 0.02, loc, mat, parent, rot=rot, verts=3)
	if shape == "pentagon":
		return cyl(name, size * 0.5, 0.02, loc, mat, parent, rot=rot, verts=5)
	if shape == "hex":
		return cyl(name, size * 0.5, 0.02, loc, mat, parent, rot=rot, verts=6)
	if shape == "bar":
		return box(name, (size, 0.02, size * 0.25), loc, mat, parent)
	if shape == "dot":
		return cyl(name, size * 0.3, 0.02, loc, mat, parent, rot=rot, verts=10)
	if shape == "diamond_bar":
		o = cyl(name, size * 0.5, 0.02, loc, mat, parent, rot=rot, verts=4)
		box(name + "Bar", (size * 1.1, 0.03, size * 0.12), (loc[0], loc[1] - 0.012, loc[2]), toon("#333333", "markbar"), parent)
		return o
	if shape == "sunburst":
		o = cyl(name, size * 0.28, 0.02, loc, mat, parent, rot=rot, verts=10)
		for i in range(8):
			a = i * math.pi / 4
			box(f"{name}Ray{i}", (size * 0.08, 0.02, size * 0.22), (loc[0] + math.cos(a) * size * 0.42, loc[1], loc[2] + math.sin(a) * size * 0.42), mat, parent, rot=(0, -a + math.pi / 2, 0))
		return o
	if shape in ("crescent", "bolt", "chevron"):
		segs = {
			"crescent": [(-0.32, 0.12, 0.7), (-0.12, 0.3, 0.25), (0.12, 0.3, -0.25), (0.32, 0.12, -0.7)],
			"bolt": [(-0.1, 0.3, 0.5), (0.05, 0.0, -0.6), (0.0, -0.3, 0.5)],
			"chevron": [(-0.17, 0.0, -0.8), (0.17, 0.0, 0.8)],
		}[shape]
		first = None
		for i, (dx, dz, ang) in enumerate(segs):
			o = box(f"{name}_{i}", (size * 0.55, 0.02, size * 0.16), (loc[0] + dx * size, loc[1], loc[2] + dz * size), mat, parent, rot=(0, ang, 0))
			first = first or o
		return first
	raise ValueError("unknown mark shape " + shape)
