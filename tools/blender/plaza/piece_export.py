"""Exports the approved spawn pieces (WORLD_REDESIGN_SPEC 4.2, docs/PLAZA_BUILD_PLAN.md) for build_gate_*, build_altar_* and
build_market_*: each script builds the approved draft's own geometry (draft_*.py, imported, never edited) and calls run().
One 64-colour palette per set, made from the colours its meshes use; a Body mesh over VERT_MAX corners is cut into Body, Body2.
Writes only build/plaza/pieces/<key>.glb and <set>.json (Hash, Parts, Pos, Face); no upload. upload_pieces.py reads them.
  -- --check   also re-imports every GLB and renders it beside the draft mesh into build/plaza/pieces/check/
"""

import hashlib
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_plaza as bp  # noqa: E402

OUT = os.path.join(bp.ROOT, "build", "plaza", "pieces")
VERT_MAX = 20000  # corners a mesh part may hold (proposed; flat shading gives every face its own)
TRI_MAX = 20000
SIZE_MAX = 2048


def joined(name, parts):
	"""One M of several in the same frame."""
	m = bp.M(name, parts[0].matrix.copy())
	for p in parts:
		base = len(m.v)
		m.v.extend(p.v)
		m.f.extend(tuple(base + i for i in f) for f in p.f)
		m.fm.extend(m._m(p.mats[i]) for i in p.fm)
	return m


def _seen(tree, at, n, dirs, reach):
	"""True when a point just off a face on its `n` side is open to the outside in some direction a player can look from."""
	for d in dirs:
		if d.dot(n) > 0.05 and tree.ray_cast(at + n * 0.01, d, reach)[0] is None:
			return True
	return False


def two_sided(m):
	"""Blender draws both sides of a face, Roblox one: a face whose back can be seen gets a reversed copy (never turned
	round: the sampling could miss its front, which would leave a hole). Returns the copies."""
	dirs = []
	for k in range(160):  # a Fibonacci sphere, the part a player's eye can be in
		z = 1 - 2 * (k + 0.5) / 160
		a = k * math.pi * (3 - math.sqrt(5))
		if z > -0.2:
			dirs.append(Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z)))
	tree = BVHTree.FromPolygons(m.v, m.f)
	copied = 0
	for i in range(len(m.f)):
		f = m.f[i]
		pts = [m.v[k] for k in f]
		n = Vector()
		for a, b in zip(pts, pts[1:] + pts[:1]):
			n += a.cross(b)
		if n.length < 1e-6:
			continue
		n.normalize()
		c = sum(pts, Vector()) / len(pts)
		spots = [c] + [c.lerp(p, 0.8) for p in pts]
		if not any(_seen(tree, p, -n, dirs, 400) for p in spots):
			continue
		base = len(m.v)
		m.v.extend(Vector(p) for p in pts[::-1])
		m.f.append(tuple(range(base, base + len(pts))))
		m.fm.append(m.fm[i])
		copied += 1
	return copied


def piece_hash(m):
	"""The geometry and the colours it is drawn with: a changed palette is a changed mesh."""
	used = sorted({m.mats[i] for i in m.fm})
	h = hashlib.sha1(bp.geometry_hash(m).encode())
	h.update(repr([(n, bp.GLOW[n][0] if n in bp.GLOW else bp.PAL[n]) for n in used]).encode())
	return h.hexdigest()[:16]


def export_mesh(m, key, pal_mat, cells):
	groups = {}
	for face, fm in zip(m.f, m.fm):
		name = m.mats[fm]
		if name in bp.GLOW:
			groups.setdefault("Glow_" + name, []).append((face, name))
			continue
		n = 1
		while True:
			part = "Body" if n == 1 else "Body%d" % n
			if sum(len(f) for f, _ in groups.get(part, ())) + len(face) <= VERT_MAX:
				break
			n += 1
		groups.setdefault(part, []).append((face, name))
	obs, parts = [], {}
	for part, faces in groups.items():
		verts, polys, uvs = [], [], []
		for face, name in faces:
			i = len(verts)
			verts.extend(tuple(m.v[k]) for k in face)
			polys.append(tuple(range(i, i + len(face))))
			uvs.extend([cells.get(name, (0.5, 0.5))] * len(face))
		for data in (bpy.data.meshes, bpy.data.objects):  # a name in use becomes "Body.001", in the upload too
			if part in data:
				data[part].name = "_used_" + part
		me = bpy.data.meshes.new(part)
		me.from_pydata(verts, [], polys)
		if part.startswith("Body"):
			layer = me.uv_layers.new(name="UVMap")
			for k, uv in enumerate(uvs):
				layer.data[k].uv = uv
			me.materials.append(pal_mat)
		me.update()
		ob = bpy.data.objects.new(part, me)
		assert ob.name == me.name == part, (ob.name, me.name)
		bpy.context.scene.collection.objects.link(ob)
		obs.append(ob)
		xs, ys, zs = zip(*verts)
		lo, hi = Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))
		size, c = hi - lo, (hi + lo) / 2
		ntris = sum(len(p) - 2 for p in polys)
		assert ntris <= TRI_MAX and len(verts) <= VERT_MAX and max(size) < SIZE_MAX, (key, part, ntris, len(verts), size)
		parts[part] = {"Size": [max(size.x, 0.05), max(size.z, 0.05), max(size.y, 0.05)], "Center": [c.x, c.z, -c.y], "Tris": ntris, "Verts": len(verts)}
		if part.startswith("Glow_"):
			parts[part]["Glow"] = bp.GLOW[part[5:]][0]
	bpy.ops.object.select_all(action="DESELECT")
	for ob in obs:
		ob.select_set(True)
	path = os.path.join(OUT, key + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, use_selection=True, export_apply=True, export_animations=False)
	data = open(path, "rb").read()
	gl = json.loads(data[20 : 20 + int.from_bytes(data[12:16], "little")])
	names = sorted(n["name"] for n in gl["nodes"] if "mesh" in n)
	assert names == sorted(parts) == sorted(n["name"] for n in gl["meshes"]), (key, names)
	for ob in obs:
		me = ob.data
		bpy.data.objects.remove(ob)
		bpy.data.meshes.remove(me)
	return parts, os.path.getsize(path)


def check(m, key, parts):
	"""Renders the draft mesh and the re-imported GLB with one camera and light; returns the mean pixel difference (0-255), and the share
	of pixels that change when back faces are not drawn, as Roblox draws none (worst of front, back and both sides)."""
	import numpy as np

	folder = os.path.join(OUT, "check")
	os.makedirs(folder, exist_ok=True)
	scene = bpy.context.scene
	for ob in list(scene.objects):
		bpy.data.objects.remove(ob)
	scene.render.resolution_x, scene.render.resolution_y = 640, 640
	scene.view_settings.view_transform = "Standard"
	scene.world = scene.world or bpy.data.worlds.new("W")
	scene.world.use_nodes = True
	scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.6, 1)
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 2.5
	sun.rotation_euler = (0.7, 0.25, 0.5)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	for ob in (sun, cam):
		scene.collection.objects.link(ob)
	scene.camera = cam
	xs, ys, zs = zip(*m.v)
	c = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
	r = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
	cam.location = c + Vector((0.55, -1.5, 0.45)) * r
	cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.clip_end = 5000

	def shot(tag):
		p = os.path.join(folder, "%s_%s.png" % (key, tag))
		scene.render.filepath = p
		bpy.ops.render.render(write_still=True)
		im = bpy.data.images.load(p)
		a = np.array(im.pixels[:]).reshape(-1, 4)[:, :3] * 255
		bpy.data.images.remove(im)
		return a

	keep, m.matrix = m.matrix, Matrix.Identity(4)
	ob = m.build(scene.collection)
	draft = shot("draft")
	bpy.data.objects.remove(ob)
	m.matrix = keep
	before = set(scene.objects)
	bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, key + ".glb"))
	names = set()
	for ob in set(scene.objects) - before:
		if ob.type != "MESH":
			continue
		name = ob.data.name.split(".")[0]
		name = name if name in parts else ob.name.split(".")[0]
		names.add(name)
		if name.startswith("Glow_"):
			ob.data.materials.clear()
			ob.data.materials.append(bp.mat(name[5:]))
		else:
			for mt in ob.data.materials:
				b = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
				b.inputs["Roughness"].default_value = 0.85
	assert names == set(parts), (key, names, set(parts))
	got = shot("glb")
	holes = 0.0
	for i, d in enumerate(((0.55, -1.5, 0.45), (-0.55, 1.5, 0.45), (1.6, 0.2, 0.3), (-1.6, 0.2, 0.3), (0.1, -1.5, 0.05))):
		cam.location = c + Vector(d) * r
		cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
		frames = []
		for cull in (False, True):
			for mt in bpy.data.materials:
				mt.use_backface_culling = cull
			frames.append(shot("view%d%s" % (i, "_culled" if cull else "")))
		holes = max(holes, float((np.abs(frames[0] - frames[1]).max(1) > 24).mean()))
	for mt in bpy.data.materials:
		mt.use_backface_culling = False
	return float(np.abs(draft - got).mean()), holes * 100


def clear(m):
	"""What of a piece, at its place, leaves the floor or meets the sky loop's ribbon or its posts (LOOP_POSTS); [] when clear."""
	posts = [(62 * math.cos(math.radians(d)), 62 * math.sin(math.radians(d))) for d in bp.LOOP_POSTS]
	bad, gap, edge = set(), 1e9, 1e9
	for v in m.v:
		p = m.matrix @ v
		x, z, y = p.x, -p.y, p.z
		edge = min(edge, 94 - abs(x), 110 - abs(z))
		r = math.hypot(x, z)
		if 59.4 < r < 64.6 and 28 < y < 31:
			bad.add("sky loop ribbon")
		if y < 30:
			gap = min(gap, min(math.hypot(x - a, z - b) for a, b in posts) - 1.7)
	if gap < 0:
		bad.add("loop post")
	if edge < 0:
		bad.add("floor edge")
	return sorted(bad), gap, edge


def run(name, pieces):
	"""pieces: [(key, M)] of one set. `name`: the set."""
	os.makedirs(OUT, exist_ok=True)
	used = {m.mats[i] for _, m in pieces for i in m.fm}
	glow, body = sorted(n for n in used if n in bp.GLOW), sorted(n for n in used if n not in bp.GLOW)
	missing = [n for n in body if n not in bp.PAL]
	assert not missing and len(body) <= bp.CELLS**2, (name, missing, len(body))
	full, bp.PAL = bp.PAL, {n: bp.PAL[n] for n in body}
	pal_mat, cells = bp.palette()
	bp.PAL = full
	print("SET %s palette %d of %d, glow %s" % (name, len(body), bp.CELLS**2, glow))
	out = {}
	for key, m in pieces:
		sides = two_sided(m)
		parts, size = export_mesh(m, key, pal_mat, cells)
		p, front = m.matrix.translation, m.matrix.to_3x3() @ Vector((0, -1, 0))
		out[key] = {"Hash": piece_hash(m), "Parts": parts, "Pos": [p.x, p.z, -p.y], "Face": [front.x, -front.y]}
		xs, ys, zs = zip(*m.v)
		dims = "%.1f x %.1f x %.1f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
		line = "PIECE %s copied %d faces, tris %d corners %s box %s z %.2f..%.2f %d KB hash %s" % (key, sides, sum(q["Tris"] for q in parts.values()), {k: q["Verts"] for k, q in parts.items()}, dims, min(zs), max(zs), size // 1024, out[key]["Hash"])
		if key != "SkyLoop":
			line += " | clear %s, nearest loop post %.1f, floor edge %.1f" % clear(m)
		if "--check" in sys.argv:
			line += " | render diff %.2f of 255, back faces seen %.2f%% of pixels" % check(m, key, parts)
		print(line, flush=True)
	with open(os.path.join(OUT, name + ".json"), "w") as f:
		json.dump(out, f, indent=1)
	return out
