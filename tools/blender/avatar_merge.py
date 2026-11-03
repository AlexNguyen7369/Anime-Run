# Merges a built character into the 6 RunnerFactory parts with one painted palette texture: cel bands and an
# inverted-hull ink outline (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline"). Used by the renders and the export.
import bmesh
import bpy
from mathutils import Vector

from avatar_base import R15_PARTS, hex_rgb

# RunnerFactory.PARTS centres in rig units (feet at z 0). RunnerVisual poses by these fixed centres.
GROUPS = {
	"Head": ((0, 0, 5), ["Head"]),
	"Torso": ((0, 0, 3), ["UpperTorso", "LowerTorso"]),
	"LeftArm": ((1.4, 0, 3), ["LeftUpperArm", "LeftLowerArm", "LeftHand"]),
	"RightArm": ((-1.4, 0, 3), ["RightUpperArm", "RightLowerArm", "RightHand"]),
	"LeftLeg": ((0.5, 0, 1), ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]),
	"RightLeg": ((-0.5, 0, 1), ["RightUpperLeg", "RightLowerLeg", "RightFoot"]),
}
CELLS = 8  # swatches per side
CELL_PX = 32
INK = "#120e16"
OUTLINE = 0.028
# Cel bands painted down each swatch, v = 0 (shadow end) .. 1 (light end): (up to v, brightness, cool tint)
BANDS = ((0.2, 0.68, 0.06), (0.8, 1.0, 0.0), (1.0, 1.14, 0.0))


def r15_of(o):
	while o is not None and o.name not in R15_PARTS:
		o = o.parent
	return o.name if o else None


def palette_image(name, swatches):
	size = CELLS * CELL_PX
	img = bpy.data.images.new(name, size, size, alpha=False)
	px = [1.0] * (size * size * 4)
	for hexcol, i in swatches.items():
		cy, cx = divmod(i, CELLS)
		r, g, b = hex_rgb(hexcol)  # the image is sRGB: raw values
		for row in range(CELL_PX):
			v = (row + 0.5) / CELL_PX
			k, cool = next((b2, c2) for top, b2, c2 in BANDS if v <= top)
			col = (min(1, r * k), min(1, g * k), min(1, b * k + cool * k))
			y = cy * CELL_PX + row
			for x in range(cx * CELL_PX, cx * CELL_PX + CELL_PX):
				o = (y * size + x) * 4
				px[o : o + 3] = col
	img.pixels = px
	img.pack()
	return img


def _cell_uv(i, v):
	cy, cx = divmod(i, CELLS)
	margin = 0.06  # stays inside the swatch: no bleed from the neighbour
	return ((cx + 0.5) / CELLS, (cy + margin + v * (1 - 2 * margin)) / CELLS)


def _shade(o, co, lo, hi):
	"""Cel band position 0..1 for one vertex: root to tip on locks, bottom to top elsewhere."""
	if o.get("flat") or o.name == "Head":
		return 0.55  # painted detail keeps its own colour; a band across the face would read as a beard
	if o.get("lock"):
		base, tip = (Vector(p) for p in o["lock"])
		span = tip - base
		t = (co - base).dot(span) / max(span.length_squared, 1e-6)
		return 0.1 + 0.85 * max(0.0, min(1.0, t))
	return (co.z - lo) / max(hi - lo, 1e-6)


def merge_group(name, centre, members, swatches, mat):
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	ink = swatches.setdefault(INK, len(swatches))
	bpy.context.view_layer.update()
	for o in bpy.data.objects:
		if o.type != "MESH" or r15_of(o) not in members:
			continue
		hexcol = "#" + o.data.materials[0].name[2:]
		i = swatches.setdefault(hexcol, len(swatches))
		assert i < CELLS * CELLS, "palette full"
		tmp = bmesh.new()
		tmp.from_mesh(o.data)
		tmp.transform(o.matrix_world)
		tmp.normal_update()
		lo = min(v.co.z for v in tmp.verts)
		hi = max(v.co.z for v in tmp.verts)
		vmap = {v: bm.verts.new(v.co) for v in tmp.verts}
		for f in tmp.faces:
			nf = bm.faces.new([vmap[v] for v in f.verts])
			nf.smooth = f.smooth
			for l, src in zip(nf.loops, f.loops):
				l[uv].uv = _cell_uv(i, _shade(o, src.vert.co, lo, hi))
		if not o.get("flat"):  # ink shell: pushed out, faces flipped, only its far side shows
			hull = {v: bm.verts.new(v.co + v.normal * OUTLINE) for v in tmp.verts}
			for f in tmp.faces:
				nf = bm.faces.new([hull[v] for v in reversed(f.verts)])
				for l in nf.loops:
					l[uv].uv = _cell_uv(ink, 0.5)
		tmp.free()
	# Centre on the rig part, then add two tiny triangles at opposite corners. Roblox centres a MeshPart on its bounding
	# box, so this keeps the rig centre fixed whatever the hair or cape adds (RunnerVisual poses by fixed centres).
	# shortcut: Size grows with the farthest vertex, fine for non-colliding parts; upgrade if per-part pivots are added.
	for v in bm.verts:
		v.co -= Vector(centre)
	ext = [max(abs(v.co[a]) for v in bm.verts) for a in range(3)]
	for sgn in (1, -1):
		c = Vector((sgn * ext[0], sgn * ext[1], sgn * ext[2]))
		d = 0.004
		f = bm.faces.new([bm.verts.new(c), bm.verts.new(c - Vector((sgn * d, 0, 0))), bm.verts.new(c - Vector((0, sgn * d, 0)))])
		for l in f.loops:
			l[uv].uv = _cell_uv(ink, 0.5)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.materials.append(mat)
	return bpy.data.objects.new(name + "_merged", mesh), (2 * ext[0], 2 * ext[2], 2 * ext[1])  # Roblox: x, y up, z depth


def merge(cid, keep=()):
	"""Replaces the built parts of the current scene by the 6 merged parts. keep = objects from other characters."""
	mat = bpy.data.materials.new("Palette_" + cid)
	mat.use_nodes = True
	mat.use_backface_culling = True  # the outline needs it; also exported as doubleSided false
	nt = mat.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Roughness"].default_value = 0.8
	swatches, merged, sizes = {}, {}, {}
	for name, (centre, members) in GROUPS.items():
		merged[name], size = merge_group(name, centre, members, swatches, mat)
		sizes[name] = [round(s, 3) for s in size]
	for o in list(bpy.data.objects):
		if o not in merged.values() and o not in keep:
			bpy.data.objects.remove(o)
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = palette_image("Palette_" + cid, swatches)
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	return merged, sizes
