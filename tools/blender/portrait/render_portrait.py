# Digital art portrait of a character: head and upper torso as a flat cel "sticker" drawing, from our own models and
# atlases only. A pipeline step for every character (docs/CHARACTER_GACHA_SPEC.md "Digital art portrait"):
#   Blender -b --factory-startup --python tools/blender/portrait/render_portrait.py -- [<id> ...]
# No ids: every character in src/shared/Characters that has a model, plus the review sheet assets/portraits/_all_sheet.png.
# --sheet: also writes assets/portraits/_pilot_sheet.png of the named ids (512 and 110 px, orange and dark).
# --sheet=<name>: also writes assets/portraits/<name>.png of the named ids (256 px, labelled).
# --save-blend: also saves assets/characters_avatar/<id>/portrait.blend (git-ignored). Named ids only, never in bulk.
# Writes assets/characters_avatar/<id>/portrait.png (512x512, transparent) and head.png (256x256, the Head part alone down
# to just under the chin, for the Team minibar), and on a no-ids run also assets/portraits/_heads_sheet.png.
# Cycles only renders raw data (atlas colour, normal, depth, part id) with no lights; the drawing is done in numpy.
import glob
import os
import re
import struct
import sys
import tempfile
import time
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
AVATARS = os.path.join(REPO, "assets", "characters_avatar")
SHEETS = os.path.join(REPO, "assets", "portraits")
CHARACTERS = os.path.join(REPO, "src", "shared", "Characters")
SIZE = 512
SS = 4  # supersample: every line width below is in render px, SIZE * SS wide
TURN = 28  # degrees of three-quarter turn
ELEVATION = 3
MARGIN = 0.012  # frame fraction left clear outside the die-cut edge
CUT_Z = 3.0  # straight cut under the chest (rig: torso 2..4, neck 4)
INK = np.array((0.055, 0.04, 0.085))
INK_R, DIE_R, LINE_R, SLIVER_R = 26, 22, 4, 8
LIGHT = np.array((-0.38, 0.68, 0.62))  # camera space: upper left, the side the face turns to
LIGHT_AT, SHADE_AT = 0.86, 0.28  # N.L bands
MIN_LINE = 44 * SS # inner ink shorter than this (render px) is texture scratch, not form
BUSY = 0.35  # share of raw line pixels in a neighbourhood above which it counts as texture
PALETTE = 20 # colours in a character's fills, before the tone ramp
MAX_BYTES = 150_000
HEAD_SIZE = 256
HEAD_INK_R, HEAD_DIE_R = 40, 28  # bolder than the portrait's, in render px: the head is seen at 60 px
HEAD_MAX_BYTES = 60_000
HEAD_CUT_Z = 3.5  # just under the chin (rig: head block 4..5.3): long hair stops here, or it would shrink the face to fit


def camera_axes():
	az, el = np.radians(TURN), np.radians(ELEVATION)
	back = Vector((np.sin(az) * np.cos(el), -np.cos(az) * np.cos(el), np.sin(el)))  # towards the camera
	right = Vector((0, 0, 1)).cross(back).normalized()
	return right, back.cross(right).normalized(), back


def strip_ink(o):
	# Drops the baked ink hull and the rig's 2 bounding triangles (avatar_merge.merge_group): both map every corner to
	# one ink UV, the last vertex's. Lines come from draw() here; the hull's slivers broke up into dashes.
	bm = bmesh.new()
	bm.from_mesh(o.data)
	uv = bm.loops.layers.uv.active
	bm.verts.ensure_lookup_table()
	ink = bm.verts[-1].link_loops[0][uv].uv.copy()  # triangulate reorders faces, not verts
	drop = [f for f in bm.faces if all(l[uv].uv == ink for l in f.loops)]
	assert len(drop) >= 2, o.name
	bmesh.ops.delete(bm, geom=list({v for f in drop for v in f.verts}), context="VERTS")
	bm.to_mesh(o.data)
	bm.free()


def touches_frame(alpha):
	return max(alpha[0].max(), alpha[-1].max(), alpha[:, 0].max(), alpha[:, -1].max()) > 0


def frame(parts, right, up, crossings):
	"""Square frame holding all of the figure above the cut: hair, hat and the full square shoulders, never cropped."""
	kept = []
	for o in parts:
		world = [o.matrix_world @ v.co for v in o.data.vertices]
		kept += [p for p in world if p.z > CUT_Z]
		for a, b in (e.vertices for e in o.data.edges) if crossings else ():
			# A flared shape (long hair, robe) is widest where it crosses the cut, not at a vertex above it.
			if (world[a].z > CUT_Z) != (world[b].z > CUT_Z):
				kept.append(world[a].lerp(world[b], (CUT_Z - world[a].z) / (world[b].z - world[a].z)))
	xs = [p.dot(right) for p in kept]
	ys = [p.dot(up) for p in kept]
	cut_y = Vector((0, 0, CUT_Z)).dot(up)
	edge = MARGIN + (INK_R + DIE_R) / (SIZE * SS)  # frame fraction taken by the outline and the clear margin
	side = max(max(xs) - min(xs), max(ys) - cut_y) / (1 - 2 * edge)
	return (max(xs) + min(xs)) / 2, cut_y - edge * side + side / 2, side, edge


def data_material(image):
	"""One emission material; render_passes relinks its colour."""
	image.colorspace_settings.name = "Non-Color"
	mat = bpy.data.materials.new("PortraitData")
	mat.use_nodes = True
	nt = mat.node_tree
	nt.nodes.clear()
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = image
	tex.interpolation = "Linear"
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	half = nt.nodes.new("ShaderNodeVectorMath")
	half.operation = "MULTIPLY_ADD"
	half.inputs[1].default_value = (0.5, 0.5, 0.5)
	half.inputs[2].default_value = (0.5, 0.5, 0.5)
	nt.links.new(geo.outputs["Normal"], half.inputs[0])
	cam = nt.nodes.new("ShaderNodeCameraData")
	info = nt.nodes.new("ShaderNodeObjectInfo")
	data = nt.nodes.new("ShaderNodeCombineXYZ")
	nt.links.new(cam.outputs["View Z Depth"], data.inputs[0])
	nt.links.new(info.outputs["Object Index"], data.inputs[1])
	emit = nt.nodes.new("ShaderNodeEmission")
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
	nt.links.new(emit.outputs[0], mix.inputs[1])
	nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
	return mat, {"albedo": tex.outputs["Color"], "normal": half.outputs[0], "data": data.outputs[0]}, emit


def read_exr(path):
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	px = np.empty(w * h * 4, np.float32)
	img.pixels.foreach_get(px)
	bpy.data.images.remove(img)
	return px.reshape(h, w, 4)[::-1]  # row 0 is the top from here on


def render_passes(mat, sources, emit, tmp):
	scene = bpy.context.scene
	out = {}
	for name, socket in sources.items():
		mat.node_tree.links.new(socket, emit.inputs["Color"])
		scene.render.filepath = os.path.join(tmp, name + ".exr")
		bpy.ops.render.render(write_still=True)
		out[name] = read_exr(scene.render.filepath)
	return out


def setup_scene(cam_pos, rot, side):
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = 1
	scene.cycles.use_denoising = False
	scene.cycles.pixel_filter_type = "BOX"
	scene.cycles.filter_width = 0.01  # one clean sample per pixel: passes hold exact values, numpy does the AA
	scene.cycles.max_bounces = 0
	scene.cycles.transparent_max_bounces = 128
	scene.render.film_transparent = True
	scene.render.resolution_x = scene.render.resolution_y = SIZE * SS
	scene.render.image_settings.file_format = "OPEN_EXR"
	scene.render.image_settings.color_depth = "32"
	scene.view_settings.view_transform = "Raw"
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = side
	cam.location = cam_pos
	cam.rotation_mode = "QUATERNION"
	cam.rotation_quaternion = rot
	scene.collection.objects.link(cam)
	scene.camera = cam


def dilate(mask, r):
	y, x = np.ogrid[-r : r + 1, -r : r + 1]
	k = np.zeros(mask.shape, np.float32)
	k[: 2 * r + 1, : 2 * r + 1] = x * x + y * y <= r * r + r * 0.5
	kf = np.fft.rfft2(np.roll(k, (-r, -r), (0, 1)))
	return np.fft.irfft2(np.fft.rfft2(mask.astype(np.float32)) * kf, s=mask.shape) > 0.5


def span_diff(a, k):
	"""Largest change of a across k px each way, horizontally or vertically (h,w or h,w,c)."""
	dx, dy = np.zeros(a.shape), np.zeros(a.shape)
	dx[:, k:-k] = a[:, 2 * k :] - a[:, : -2 * k]
	dy[k:-k] = a[2 * k :] - a[: -2 * k]
	if a.ndim == 3:
		return np.maximum(np.linalg.norm(dx, axis=2), np.linalg.norm(dy, axis=2))
	return np.maximum(np.abs(dx), np.abs(dy))


def box_mean(mask, r):
	"""Share of mask inside the (2r+1) square round each pixel."""
	c = np.pad(np.pad(mask.astype(np.float64), r, mode="edge"), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
	n = 2 * r + 1
	return (c[n:, n:] - c[:-n, n:] - c[n:, :-n] + c[:-n, :-n]) / n**2


def long_lines(line, min_line=MIN_LINE):
	"""Keeps the connected lines at least min_line across. Union-find over row runs, at 1/SS scale."""
	h, w = line.shape
	small = line.reshape(h // SS, SS, w // SS, SS).any(axis=(1, 3))
	parent, box, prev, rows = [], [], [], []

	def find(i):
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i

	for y, row in enumerate(small):
		edges = np.flatnonzero(np.diff(np.concatenate(([0], row.astype(np.int8), [0]))))
		runs = []
		for a, b in zip(edges[::2].tolist(), edges[1::2].tolist()):
			i = len(parent)
			parent.append(i)
			box.append([a, b, y, y])
			for pa, pb, pi in prev:
				if pa <= b and pb >= a:  # touching, diagonals included
					r, q = find(pi), find(i)
					if r != q:
						parent[q] = r
						bq, br = box[q], box[r]
						box[r] = [min(bq[0], br[0]), max(bq[1], br[1]), min(bq[2], br[2]), max(bq[3], br[3])]
			runs.append((a, b, i))
		rows.append(runs)
		prev = runs
	keep = np.zeros(small.shape, bool)
	for y, runs in enumerate(rows):
		for a, b, i in runs:
			x0, x1, y0, y1 = box[find(i)]
			if max(x1 - x0, y1 - y0 + 1) * SS >= min_line:
				keep[y, a:b] = True
	return line & keep.repeat(SS, 0).repeat(SS, 1)


def grade(a, lut=None):
	"""Bright, saturated, flat fills. Value moves with the hue held, so skin does not clip to yellow."""
	v = np.maximum(a.max(axis=2, keepdims=True), 1e-4)
	a = a * (np.minimum(v**0.72 * 1.06, 1) / v)
	grey = a.mean(axis=2, keepdims=True)
	a = np.clip(grey + (a - grey) * 1.3, 0, 1)
	# Black hair goes slate, so it still separates from the ink.
	a = a + np.array((0.07, 0.08, 0.13)) * np.clip(1 - a.max(axis=2, keepdims=True) / 0.4, 0, 1)
	return paint_by_numbers(a, lut)


def vivid(c):
	# Colour distance that weighs hue over value, so a skin shadow never lands in a grey cluster with the white props.
	return c + 2 * (c - c.mean(axis=1, keepdims=True))


def paint_by_numbers(a, lut=None):
	"""Snaps fills to one small palette (k-means on the 5-bit colour histogram): atlas gradients and blush go flat.
	Returns the fills and the colour table; pass that table back to paint another view in the same palette."""
	bins = np.round(np.clip(a, 0, 1) * 31).astype(np.int32)
	key = bins[..., 0] * 1024 + bins[..., 1] * 32 + bins[..., 2]
	if lut is not None:
		return lut[key], lut
	used, counts = np.unique(key, return_counts=True)
	colours = np.stack((used // 1024, used // 32 % 32, used % 32), axis=1) / 31
	weight = np.sqrt(counts)  # sqrt: small features such as eyes keep a colour of their own
	centres = colours[np.random.RandomState(0).choice(len(colours), min(PALETTE, len(colours)), False, weight / weight.sum())]
	# Pinned ends: eyes, teeth and white props stay white, never averaged into a grey.
	centres[0], centres[1] = colours[np.argmax(colours.sum(axis=1))], colours[np.argmin(colours.sum(axis=1))]
	for _ in range(12):
		nearest = np.argmin(((vivid(colours)[:, None] - vivid(centres)[None]) ** 2).sum(axis=2), axis=1)
		for i in range(2, len(centres)):
			if (nearest == i).any():
				centres[i] = np.average(colours[nearest == i], axis=0, weights=weight[nearest == i])
	every = np.stack(np.meshgrid(*[np.arange(32)] * 3, indexing="ij"), axis=3).reshape(-1, 3) / 31
	lut = centres[np.argmin(((vivid(every)[:, None] - vivid(centres)[None]) ** 2).sum(axis=2), axis=1)]  # hair under the cut
	lut[used] = centres[nearest]
	return lut[key], lut


def draw(p, to_cam, side, lut=None, scale=1):
	"""The drawing inside the silhouette: cel fills and inner ink. p holds top-down float passes. scale widens every
	pixel-sized line constant for a tighter frame, and lut reuses a palette. Returns the fills, the mask and the palette."""
	w = p["albedo"].shape[1]
	solid = p["albedo"][..., 3] > 0.5
	rgb = p["albedo"][..., :3].astype(np.float64)
	normal = (p["normal"][..., :3].astype(np.float64) - 0.5) * 2 @ to_cam.T
	far = float(p["data"][..., 0][solid].max())
	depth = np.where(solid, p["data"][..., 0], far).astype(np.float64)
	part = np.where(solid, p["data"][..., 1], 0).astype(np.float64)

	fill, lut = grade(rgb, lut)
	d = normal @ (LIGHT / np.linalg.norm(LIGHT))

	# Drawn cast shadow under fringes, chin and props: hard edged, offset away from the light, no scene lighting.
	studs = side / w
	shifted = np.roll(np.roll(np.where(solid, depth, np.inf), int(0.12 / studs), 0), int(0.09 / studs), 1)
	cast = solid & (shifted < depth - 0.08)

	shade = (d < SHADE_AT) | cast
	light = (d > LIGHT_AT) & ~cast
	out = fill.copy()
	out[shade] = fill[shade] * np.array((0.78, 0.64, 0.70))
	out[light] = fill[light] + (1 - fill[light]) * 0.16 + 0.03
	out = np.clip(out, 0, 1)

	# Inner ink: depth steps, part borders, hard creases.
	step = (span_diff(depth, 2) > 0.2) | (span_diff(part, 2) > 0.5)
	crease = span_diff(normal, 12 * scale) > 1.0
	inner = ~dilate(~solid, 6 * scale)  # the silhouette's own step belongs to the outline, and would join every line into one
	raw = (step | crease) & inner
	# A tight mesh of lines is texture (straw, frayed rims)
	long = long_lines(raw & ~(box_mean(raw, 40 * scale) > BUSY), MIN_LINE * scale)
	out[dilate(long & step, LINE_R * scale) | (long & crease)] = INK
	return out, solid, lut


def finish(out, solid, cut_row, ink_r=INK_R, die_r=DIE_R, sliver_r=SLIVER_R):
	keep = solid.copy()
	keep[cut_row:] = False  # straight across the image: the outline below then closes along one straight bottom
	keep = dilate(~dilate(~keep, sliver_r), sliver_r)  # opening: thin geometry slivers would ink into specks and burrs
	ink = dilate(keep, ink_r)
	die = dilate(ink, die_r)
	# Pockets closed on all 4 sides go ink, as if behind the figure: one outer edge, no bg through small holes.
	seen = lambda axis: np.logical_or.accumulate(die, axis) & np.flip(np.logical_or.accumulate(np.flip(die, axis), axis), axis)
	pocket = (seen(0) & seen(1)) & ~die
	ink, die = ink | dilate(pocket, die_r + 2), die | pocket
	rgba = np.ones((*solid.shape, 4))
	rgba[..., 3] = die
	rgba[ink, :3] = INK
	rgba[keep, :3] = out[keep]
	return rgba


def downsample(rgba, n):
	"""Exact area average to n x n on premultiplied colour, straight alpha out. Transparent stays white: no dark fringe."""
	pm = np.concatenate((rgba[..., :3] * rgba[..., 3:], rgba[..., 3:]), axis=2)
	for axis in (0, 1):
		m = pm.shape[axis]
		c = np.concatenate((np.zeros_like(np.take(pm, [0], axis)), np.cumsum(pm, axis)), axis)
		e = np.linspace(0, m, n + 1)
		i = np.minimum(e.astype(int), m - 1)
		f = (e - i).reshape([-1 if a == axis else 1 for a in range(3)])
		at = np.take(c, i, axis) * (1 - f) + np.take(c, i + 1, axis) * f
		pm = np.diff(at, axis=axis) / (m / n)
	a = pm[..., 3:]
	col = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 1.0)
	return np.clip(np.concatenate((col, a), axis=2), 0, 1)


def write_png(path, rgba):
	# By hand: exact straight-alpha bytes with no colour management, 'Up' filtered, max deflate.
	u8 = np.round(rgba * 255).astype(np.uint8)
	h, w = u8.shape[:2]
	up = u8.copy()
	up[1:] = u8[1:] - u8[:-1]
	raw = np.concatenate((np.full((h, 1), 2, np.uint8), up.reshape(h, w * 4)), axis=1).tobytes()
	chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def check(path, rgba, size=SIZE, max_bytes=MAX_BYTES):
	"""Self-check: a framing or size failure stops the batch rather than ship."""
	a = rgba[..., 3]
	assert rgba.shape == (size, size, 4), rgba.shape
	assert not touches_frame(a), f"{path}: figure touches the frame"
	assert 0.2 < (a > 0.5).mean() < 0.95, f"{path}: coverage {(a > 0.5).mean():.2f}"
	assert ((a > 0.02) & (a < 0.98)).mean() < 0.05, f"{path}: alpha edge not crisp"
	assert os.path.getsize(path) < max_bytes, f"{path}: {os.path.getsize(path)} bytes"


def portrait_path(cid):
	return os.path.join(AVATARS, cid, "portrait.png")


def head_frame(head, right, up):
	"""Tight centred square round the Head mesh above HEAD_CUT_Z, with room for its outline. Also the row of that cut."""
	world = [head.matrix_world @ v.co for v in head.data.vertices]
	# Measured along the camera's up, as the cut is a row of the image: at this slight elevation depth moves a vertex's row.
	cut_y = Vector((0, 0, HEAD_CUT_Z)).dot(up)
	ys = [p.dot(up) for p in world]
	kept = [p for p, y in zip(world, ys) if y > cut_y]
	for a, b in (e.vertices for e in head.data.edges):
		if (ys[a] > cut_y) != (ys[b] > cut_y):
			kept.append(world[a].lerp(world[b], (cut_y - ys[a]) / (ys[b] - ys[a])))
	cut_needed = min(ys) < cut_y
	xs = [p.dot(right) for p in kept]
	ys = [p.dot(up) for p in kept]
	edge = MARGIN + (HEAD_INK_R + HEAD_DIE_R) / (SIZE * SS)
	side = max(max(xs) - min(xs), max(ys) - min(ys)) / (1 - 2 * edge)
	cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
	n = SIZE * SS
	cut_row = round((cy + side / 2 - cut_y) / side * n) if cut_needed else n
	return cx, cy, side, cut_row


def render_head(cid, parts, mat, sources, emit, axes, lut, portrait_side):
	"""head.png. The Head rendered alone: the part id pass can't serve, a collar or shoulder hides its chin and long hair."""
	head = next(o for o in parts if o.name.startswith("Head"))
	for o in parts:
		o.hide_render = o is not head
	right, up, back = axes
	cx, cy, side, cut_row = head_frame(head, right, up)
	setup_scene(right * cx + up * cy + back * 40, (-back).to_track_quat("-Z", "Y"), side)
	with tempfile.TemporaryDirectory() as tmp:
		passes = render_passes(mat, sources, emit, tmp)
	scale = max(1, round(portrait_side / side))
	out, solid, _ = draw(passes, np.array([list(right), list(up), list(back)]), side, lut, scale)
	rgba = downsample(finish(out, solid, cut_row, HEAD_INK_R, HEAD_DIE_R, SLIVER_R * scale), HEAD_SIZE)
	rgba[..., :3] = np.round(rgba[..., :3] * 31) / 31
	path = os.path.join(AVATARS, cid, "head.png")
	write_png(path, rgba)
	try:
		check(path, rgba, HEAD_SIZE, HEAD_MAX_BYTES)
	except AssertionError:
		os.remove(path)
		raise
	print(f"HEAD {cid} {os.path.getsize(path)} bytes frame={side:.2f}", flush=True)
	return rgba


def render(cid, model, c, save_blend):
	"""cid names the file, model the data: a character can wear another's model (soul_hollow wears foe_soul)."""
	t0 = time.time()
	build_avatar.reset()
	avatar_merge.BANDS = ((1.0, 1.0, 0.0),)  # flat swatches, in memory only: the tones come from the ramp in draw()
	build_avatar.build(model, c)
	merged, _ = avatar_merge.merge(model)
	image = next(n for n in merged["Head"].data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image
	mat, sources, emit = data_material(image)
	parts = []
	for i, (name, o) in enumerate(merged.items()):
		if "Leg" in name:
			continue
		strip_ink(o)
		o.data.materials[0] = mat
		o.location = avatar_merge.GROUPS[name][0]
		o.pass_index = i + 1
		bpy.context.scene.collection.objects.link(o)
		parts.append(o)
	bpy.context.view_layer.update()

	right, up, back = camera_axes()
	# Tight frame first, wider only if the figure hits it: a portrait that fits keeps its exact bytes, so no re-upload.
	for crossings in (False, True):
		cx, cy, side, edge = frame(parts, right, up, crossings)
		setup_scene(right * cx + up * cy + back * 40, (-back).to_track_quat("-Z", "Y"), side)
		with tempfile.TemporaryDirectory() as tmp:
			passes = render_passes(mat, sources, emit, tmp)
		out, solid, lut = draw(passes, np.array([list(right), list(up), list(back)]), side)
		cut_row = round(SIZE * SS * (1 - edge))
		rgba = downsample(finish(out, solid, cut_row), SIZE)
		if not touches_frame(rgba[..., 3]):
			break
	rgba[..., :3] = np.round(rgba[..., :3] * 31) / 31  # flat art loses nothing at 5 bits; deflate gains a lot
	path = portrait_path(cid)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	write_png(path, rgba)
	try:
		check(path, rgba)
	except AssertionError:
		os.remove(path)  # the uploader takes every portrait.png it finds: a failed one must not stay
		raise
	if save_blend:
		bpy.context.preferences.filepaths.save_version = 0
		bpy.ops.wm.save_as_mainfile(filepath=os.path.join(AVATARS, cid, "portrait.blend"))
	head = render_head(cid, parts, mat, sources, emit, (right, up, back), lut, side)
	print(f"PORTRAIT {cid} {os.path.getsize(path)} bytes {time.time() - t0:.1f}s frame={side:.2f}", flush=True)
	return rgba, head


def over(canvas, img, x, y):
	h, w = img.shape[:2]
	a = img[..., 3:]
	canvas[y : y + h, x : x + w] = img[..., :3] * a + canvas[y : y + h, x : x + w] * (1 - a)


def sheet(images):
	gap, small = 16, 110
	band = SIZE + small + 3 * gap
	out = np.ones((band * 2, (SIZE + gap) * len(images) + gap, 3))
	for b, bg in enumerate((np.array((0.93, 0.55, 0.2)), np.array((0.09, 0.09, 0.13)))):
		out[b * band : (b + 1) * band] = bg
		for i, img in enumerate(images):
			x = gap + i * (SIZE + gap)
			over(out, img, x, b * band + gap)
			over(out, downsample(img, small), x + (SIZE - small) // 2, b * band + SIZE + 2 * gap)
	save_sheet(out, "_pilot_sheet.png")


def save_sheet(out, name):
	os.makedirs(SHEETS, exist_ok=True)
	path = os.path.join(SHEETS, name)
	write_png(path, np.concatenate((out, np.ones((*out.shape[:2], 1))), axis=2))
	print("SHEET", path, os.path.getsize(path), flush=True)


def text_mask(w, h, labels):
	"""Alpha of labels [(text, x centre, y top)] on a w x h canvas, drawn by Cycles at 2x: no font library in Blender."""
	build_avatar.reset()
	mat = bpy.data.materials.new("Label")
	mat.use_nodes = True
	mat.node_tree.nodes.clear()
	emit = mat.node_tree.nodes.new("ShaderNodeEmission")
	mat.node_tree.links.new(emit.outputs[0], mat.node_tree.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
	for text, x, y in labels:
		curve = bpy.data.curves.new(text, "FONT")
		curve.body = text
		curve.size = 17
		curve.align_x = "CENTER"
		curve.align_y = "TOP"
		curve.materials.append(mat)
		o = bpy.data.objects.new(text, curve)
		o.location = (x, -y, 0)
		bpy.context.scene.collection.objects.link(o)
	setup_scene(Vector((w / 2, -h / 2, 50)), (1, 0, 0, 0), max(w, h))
	scene = bpy.context.scene
	scene.render.resolution_x, scene.render.resolution_y = w * 2, h * 2
	with tempfile.TemporaryDirectory() as tmp:
		scene.render.filepath = os.path.join(tmp, "labels.exr")
		bpy.ops.render.render(write_still=True)
		a = read_exr(scene.render.filepath)[..., 3]
	return a.reshape(h, 2, w, 2).mean(axis=(1, 3))


def all_sheet(ids, images, name="_all_sheet"):
	tile, gap, label, cols = 256, 12, 26, 6
	rows = -(-len(ids) // cols)
	w, h = cols * (tile + gap) + gap, rows * (tile + label + gap) + gap
	out = np.ones((h, w, 3)) * np.array((0.45, 0.53, 0.6))
	cells = [(gap + i % cols * (tile + gap), gap + i // cols * (tile + label + gap)) for i in range(len(ids))]
	for img, (x, y) in zip(images, cells):
		over(out, downsample(img, tile), x, y)
	mask = text_mask(w, h, [(cid, x + tile / 2, y + tile + 3) for cid, (x, y) in zip(ids, cells)])[..., None]
	save_sheet(out * (1 - mask) + INK * mask, name + ".png")


def heads_sheet(ids, heads):
	tile, small, gap, label, cols = HEAD_SIZE, 60, 12, 26, 8
	rows = -(-len(ids) // cols)
	cell_h = tile + small + label + 2 * gap
	w, h = cols * (tile + gap) + gap, rows * cell_h + gap
	out = np.ones((h, w, 3)) * np.array((0.45, 0.53, 0.6))
	cells = [(gap + i % cols * (tile + gap), gap + i // cols * cell_h) for i in range(len(ids))]
	for img, (x, y) in zip(heads, cells):
		over(out, img, x, y)
		over(out, downsample(img, small), x + (tile - small) // 2, y + tile + gap // 2)
	labels = [(cid, x + tile / 2, y + tile + small + gap // 2 + 2) for cid, (x, y) in zip(ids, cells)]
	mask = text_mask(w, h, labels)[..., None]
	save_sheet(out * (1 - mask) + INK * mask, "_heads_sheet.png")


def catalog():
	"""Id -> Model override (or None) for every character file: the same files CharacterCatalog auto-loads."""
	models = {}
	for path in sorted(glob.glob(os.path.join(CHARACTERS, "*.luau"))):
		with open(path) as f:
			found = re.search(r'^\s*Model\s*=\s*"(\w+)"', f.read(), re.M)
		models[os.path.basename(path)[:-5]] = found and found.group(1)
	assert models, CHARACTERS
	return models


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	save_blend = "--save-blend" in argv
	ids = [a for a in argv if not a.startswith("--")]
	bulk = not ids
	assert not (bulk and save_blend), "--save-blend needs named ids: never in bulk"
	data = build_avatar.load_data()
	models = catalog()
	if bulk:
		ids = sorted(models)
	images, heads, done = [], [], []
	for cid in ids:
		model = models.get(cid) or cid
		if model in data:
			portrait, head = render(cid, model, data[model], save_blend)
			images.append(portrait)
			heads.append(head)
			done.append(cid)
		elif bulk:
			print(f"SKIP {cid}: no model data yet", flush=True)  # event characters awaiting a model
		else:
			raise SystemExit(f"{cid}: no model data for {model}")
	if bulk:
		all_sheet(done, images)
		heads_sheet(done, heads)
	for a in argv:
		if a.startswith("--sheet="):
			all_sheet(done, images, a[8:])
	if "--sheet" in argv:
		sheet(images)


if __name__ == "__main__":  # the palette-path test imports this file
	main()
