# Void Saitamo (punch_void): the punch_hero suit in a purple aura (owner 2026-11-05). The only build entry for this id:
#   Blender -b --factory-startup --python tools/blender/portrait/void_glow.py
# Run tools/blender/paint/atlas.py punch_void first. Writes <id>.blend and review/ with the separate AuraShell* meshes, then
# portrait.png and head.png with the aura drawn behind the figure. render_portrait.py alone draws them with no aura.
# The AuraShell* meshes never reach the export: avatar_merge keeps only the 6 body parts. In game they are for ParticleEmitters.
import math
import os
import random
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.dirname(HERE)]
import build_avatar  # noqa: E402
import render_portrait as rp  # noqa: E402

ID = "punch_void"
SEED = 7
VIOLET_LIN = (0.42, 0.05, 1.0)  # linear, for the shaders
DEEP, MID, BRIGHT, CORE = (np.array(c) / 255 for c in ((58, 12, 140), (112, 32, 224), (178, 100, 255), (238, 212, 255)))
DIE = np.array((232, 200, 255)) / 255
# z, half width, half depth: faceted shells round the rig, feet at z 0. The review camera sees z -1 to 7.2.
SHELLS = (
	("AuraShellOuter", ((0, 2.5, 1.9), (1.6, 2.9, 2.1), (3.6, 3.05, 2.2), (5.2, 2.5, 1.9), (6.2, 1.5, 1.2)), 7.05, 12, 0.42, VIOLET_LIN),
	("AuraShellInner", ((0, 2.05, 1.5), (1.8, 2.35, 1.6), (3.8, 2.45, 1.65), (5.4, 1.75, 1.35), (6.0, 1.05, 0.9)), 6.65, 10, 0.34, VIOLET_LIN),
)
# tongues standing off the shells: base x, y, z, base radius, height, lean x
FLAMES = (
	(2.3, 0.2, 3.7, 0.55, 2.2, 0.35),
	(-2.3, 0.1, 3.5, 0.55, 2.4, -0.35),
	(1.2, -0.7, 5.3, 0.42, 1.7, 0.1),
	(-1.15, 0.6, 5.4, 0.42, 1.6, -0.15),
	(2.2, -0.4, 1.3, 0.4, 2.0, 0.3),
	(-2.25, -0.3, 1.1, 0.38, 2.1, -0.3),
	(0.1, -0.5, 5.6, 0.36, 1.45, 0.1),
	(0.5, 0.8, 5.0, 0.4, 1.95, 0.1),
)


def aura_material(name, colour, alpha):
	"""Emissive haze: thin where it faces the camera, thick at the grazing facets, so the figure stays readable inside."""
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nt = mat.node_tree
	nt.nodes.clear()
	emit = nt.nodes.new("ShaderNodeEmission")
	emit.inputs["Color"].default_value = (*colour, 1)
	emit.inputs["Strength"].default_value = 1.6
	layer = nt.nodes.new("ShaderNodeLayerWeight")
	layer.inputs["Blend"].default_value = 0.45
	fac = nt.nodes.new("ShaderNodeMath")
	fac.operation = "MULTIPLY"
	fac.inputs[1].default_value = alpha
	nt.links.new(layer.outputs["Facing"], fac.inputs[0])
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(fac.outputs[0], mix.inputs[0])
	nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs[0], mix.inputs[1])
	nt.links.new(emit.outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
	mat.surface_render_method = "BLENDED"
	mat.show_transparent_back = True
	mat.use_backface_culling = False
	return mat


def loft(name, rows, apex, n, mat, rng, root):
	"""Faceted cone, open at the base: rings of n points, every other one pushed out so a section reads as a flame, up to one apex. Returns its tris."""
	verts, faces = [], []
	for r, (cx, cy, z, rx, ry) in enumerate(rows):
		for j in range(n):
			t = 2 * math.pi * (j + r * 0.35 + rng.uniform(-0.18, 0.18)) / n  # each ring turns a little: facets spiral up
			k = rng.uniform(0.92, 1.08) * (1.14 if j % 2 else 0.86)
			verts.append((cx + rx * k * math.cos(t), cy + ry * k * math.sin(t), z + rng.uniform(-0.12, 0.12) * (r > 0)))
		if r:
			at = r * n
			faces += [(at - n + j, at - n + (j + 1) % n, at + (j + 1) % n, at + j) for j in range(n)]
	top = len(verts)
	verts.append(apex)
	faces += [(top - n + j, top - n + (j + 1) % n, top) for j in range(n)]
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(verts, [], faces)
	mesh.materials.append(mat)
	o = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(o)
	o.parent = root
	return sum(len(f) - 2 for f in faces)


def add_shells(root):
	rng = random.Random(SEED)
	tris = 0
	for name, rows, top, n, alpha, colour in SHELLS:
		mat = aura_material(name, colour, alpha)
		tris += loft(name, [(0, 0, z, rx, ry) for z, rx, ry in rows], (rng.uniform(-0.2, 0.2), 0, top), n, mat, rng, root)
	mat = aura_material("AuraShellFlame", VIOLET_LIN, 0.95)
	for i, (x, y, z, r, h, lean) in enumerate(FLAMES, 1):
		rows = [(x + lean * t * t, y, z + h * t, r * (1 - t * 0.75), r * (1 - t * 0.75)) for t in (0, 0.3, 0.65)]
		tris += loft(f"AuraShellFlame{i}", rows, (x + lean, y, z + h), 5, mat, rng, root)
	return tris


def tongues(cx, cy, reach, n, base, height, rng, canvas):
	"""One closed zigzag silhouette round (cx, cy): valleys off the figure, tips licking up."""
	pts = []
	margin = canvas * 0.012
	for i in range(n):
		for step, is_tip in ((0.0, False), (0.5, True)):
			t = 2 * math.pi * (i + step + rng.uniform(-0.12, 0.12)) / n
			bin_r = reach[int(t / (2 * math.pi) * len(reach)) % len(reach)]
			tall = height * rng.uniform(0.55, 1.15) * (1 + 0.9 * max(0, -math.sin(t)))  # image y runs down: tallest over the head
			r = bin_r + base * rng.uniform(0.85, 1.1) + (tall if is_tip else 0)
			x, y = cx + r * math.cos(t), cy + r * math.sin(t)
			if is_tip:  # flames rise: lift the tip, and lean it towards the vertical
				y -= height * 0.55
				x += (cx - x) * 0.1
			pts.append((min(max(x, margin), canvas - margin), min(max(y, margin), canvas - margin)))
	return pts


def fan(pts, cx, cy, size):
	"""Mask of the union of triangles (centre, p, next p): tips may cross, a union leaves no holes."""
	mask = np.zeros((size, size), bool)
	for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
		lo_x, hi_x = int(min(cx, x0, x1)), int(max(cx, x0, x1)) + 2
		lo_y, hi_y = int(min(cy, y0, y1)), int(max(cy, y0, y1)) + 2
		ys, xs = np.mgrid[lo_y:hi_y, lo_x:hi_x]
		side = lambda ax, ay, bx, by: (bx - ax) * (ys - ay) - (by - ay) * (xs - ax)
		a, b, c = side(cx, cy, x0, y0), side(x0, y0, x1, y1), side(x1, y1, cx, cy)
		hit = ((a >= 0) & (b >= 0) & (c >= 0)) | ((a <= 0) & (b <= 0) & (c <= 0))
		mask[lo_y:hi_y, lo_x:hi_x] |= hit
	return mask


def box_blur(a, r):
	for axis in (0, 1):
		c = np.cumsum(np.concatenate((np.zeros_like(np.take(a, [0], axis)), a), axis), axis)
		n = a.shape[axis]
		hi, lo = np.minimum(np.arange(n) + r + 1, n), np.maximum(np.arange(n) - r, 0)
		a = (np.take(c, hi, axis) - np.take(c, lo, axis)) / (2 * r + 1)
	return a


def over(under, top):
	"""Straight-alpha over."""
	a = top[..., 3:] + under[..., 3:] * (1 - top[..., 3:])
	rgb = (top[..., :3] * top[..., 3:] + under[..., :3] * under[..., 3:] * (1 - top[..., 3:])) / np.maximum(a, 1e-4)
	return np.concatenate((np.where(a > 1e-4, rgb, 1.0), a), axis=2)


def layer(mask, colour):
	out = np.ones((*mask.shape, 4))
	out[..., :3] = colour
	out[..., 3] = mask
	return out


def shrink_figure(rgba, scale, die_px):
	"""The figure smaller on the same straight bottom, its die-cut edge turned lilac, its alpha kept."""
	n = rgba.shape[0]
	bottom = np.nonzero(rgba[..., 3].max(axis=1))[0].max() + 1
	m = round(n * scale)
	small = rp.downsample(rgba, m)
	y0, x0 = bottom - round(bottom * scale), (n - m) // 2
	fig = np.ones((n, n, 4))
	fig[..., 3] = 0
	fig[y0 : y0 + m, x0 : x0 + m] = small
	inner = ~rp.dilate(fig[..., 3] < 0.5, die_px)
	edge = (fig[..., 3] > 0) & ~inner & (fig[..., :3].min(axis=2) > 0.6)
	fig[edge, :3] = DIE
	return fig, bottom


def glow(rgba, scale, tips, die_px, seed, sparks):
	"""The drawn figure over stepped cel flames over a soft haze. Same canvas, straight bottom, clear of the frame."""
	n = rgba.shape[0]
	fig, bottom = shrink_figure(rgba, scale, die_px)
	ss = 3
	size = n * ss
	ys, xs = np.nonzero(fig[..., 3] > 0.5)
	cx, cy = n / 2, (ys.min() + bottom) * 0.55
	angle = np.arctan2(ys + 0.5 - cy, xs + 0.5 - cx) % (2 * math.pi)
	bins = np.zeros(144)
	np.maximum.at(bins, (angle / (2 * math.pi) * len(bins)).astype(int) % len(bins), np.hypot(xs + 0.5 - cx, ys + 0.5 - cy))
	reach = np.maximum.reduce([np.roll(bins, s) for s in range(-3, 4)]) * ss
	rng = random.Random(seed)
	unit = n * ss
	out = np.ones((size, size, 4))
	out[..., 3] = 0
	union = None
	for colour, base, height in ((DEEP, 0.062, 0.1), (MID, 0.04, 0.078), (BRIGHT, 0.022, 0.05), (CORE, 0.008, 0.026)):
		pts = tongues(cx * ss, cy * ss, reach, tips, unit * base, unit * height, rng, size)
		mask = fan(pts, cx * ss, cy * ss, size)
		mask[bottom * ss :] = False
		union = mask if union is None else union
		out = over(out, layer(mask.astype(float), colour))
	small = rp.downsample(out, n)
	# the haze: soft violet past the flames, fading out before the frame
	aura_a = rp.downsample(layer(union.astype(float), DEEP), n)[..., 3]
	haze = box_blur(box_blur(aura_a, round(n * 0.04)), round(n * 0.04))
	fade = np.minimum.reduce(np.meshgrid(*[np.minimum(np.arange(n), n - 1 - np.arange(n))] * 2)) / (n * 0.05)
	haze = np.clip(haze * 1.5, 0, 1) * np.clip(fade - 0.15, 0, 1) * 0.9
	haze[bottom:] = 0
	result = over(layer(np.round(haze * 31) / 31, MID), small)
	for _ in range(sparks):  # motes drifting off the flames, only where the outer flame has stopped
		for _try in range(40):
			x, y = rng.uniform(0.06, 0.94) * n, rng.uniform(0.04, 0.8) * n
			if 0.02 < haze[int(y), int(x)] and aura_a[int(y), int(x)] < 0.01:
				break
		else:
			continue
		r = rng.uniform(0.008, 0.016) * size
		mote = fan([(x * ss, y * ss - 2 * r), (x * ss + r, y * ss), (x * ss, y * ss + 2 * r), (x * ss - r, y * ss)], x * ss, y * ss, size)
		result = over(result, rp.downsample(layer(mote.astype(float), CORE), n))
	result = over(result, fig)
	# the glow spills onto the figure's edges, so he stands in it instead of on it
	solid = fig[..., 3] > 0.5
	spill = box_blur(box_blur((~solid).astype(float), round(n * 0.025)), round(n * 0.025))
	spill = np.round(np.clip(spill * 1.1 - 0.1, 0, 0.5) * 31) / 31 * solid
	spill[bottom:] = 0
	result = over(result, layer(spill, MID))
	result[..., :3] = np.round(result[..., :3] * 31) / 31
	result[result[..., 3] <= 0, :3] = 1.0
	return result


def write_checked(path, rgba, size, max_bytes):
	rp.write_png(path, rgba)
	assert rgba.shape == (size, size, 4), rgba.shape
	assert not rp.touches_frame(rgba[..., 3]), f"{path}: aura touches the frame"
	assert os.path.getsize(path) < max_bytes, f"{path}: {os.path.getsize(path)} bytes"
	print(f"VOID GLOW {path} {os.path.getsize(path)} bytes", flush=True)


def main():
	data = build_avatar.load_data()[ID]
	plain_placed = build_avatar.placed

	def placed_with_aura(cid, c, keep=()):
		root, tris = plain_placed(cid, c, keep)
		return root, tris + add_shells(root)

	build_avatar.placed = placed_with_aura  # merge() deletes every loose object, so the shells go in after it
	build_avatar.build_one(ID, data)
	build_avatar.placed = plain_placed
	portrait, head = rp.render(ID, ID, data, False)
	folder = os.path.join(rp.AVATARS, ID)
	write_checked(rp.portrait_path(ID), glow(portrait, 0.72, 15, 6, SEED, 9), rp.SIZE, rp.MAX_BYTES)
	write_checked(os.path.join(folder, "head.png"), glow(head, 0.7, 13, 4, SEED + 1, 5), rp.HEAD_SIZE, rp.HEAD_MAX_BYTES)


main()
