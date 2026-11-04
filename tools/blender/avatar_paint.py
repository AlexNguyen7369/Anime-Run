# Painted characters (docs/CHARACTER_GACHA_SPEC.md "Painted textures"): 6 plain blocks UV-mapped to the atlas that
# tools/blender/paint/char_<id>.py draws, plus the character's hair and a short list of 3D props.
import importlib
import os
import sys

import bpy

import avatar_base
from avatar_base import build_pieces, rbox

HERE = os.path.dirname(os.path.abspath(__file__))
PAINT = os.path.join(HERE, "paint")
sys.path.insert(0, PAINT)
ASSETS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "characters_avatar")

# name, R15 name the block stands for, size, centre, other R15 names that alias to it
BLOCKS = (
	("Head", "Head", (1.3, 1.2, 1.3), (0, 0, 4.65), ()),
	("Torso", "UpperTorso", (2, 1, 2), (0, 0, 3), ("LowerTorso",)),
	("LeftArm", "LeftUpperArm", (1, 1, 2), (1.5, 0, 3), ("LeftLowerArm", "LeftHand")),
	("RightArm", "RightUpperArm", (1, 1, 2), (-1.5, 0, 3), ("RightLowerArm", "RightHand")),
	("LeftLeg", "LeftUpperLeg", (1, 1, 2), (0.5, 0, 1), ("LeftLowerLeg", "LeftFoot")),
	("RightLeg", "RightUpperLeg", (1, 1, 2), (-0.5, 0, 1), ("RightLowerLeg", "RightFoot")),
)
INSET = 2  # px kept from a face's edge: no bleed from its neighbour in the atlas


def atlas_path(cid):
	p = os.path.join(ASSETS, cid, "atlas.png")
	return p if os.path.exists(p) and os.path.exists(os.path.join(PAINT, f"char_{cid}.py")) else None


def _face_key(block, axis, positive):
	if axis == 2:
		return "T" if positive else "Bo"
	if axis == 1:
		return "B" if positive else "F"
	# x: Head and Torso have fixed sides; a limb's outer face points away from the body
	if block in ("Head", "Torso"):
		return "L" if positive else "R"
	outward = block.startswith("Left") == positive
	return "O" if outward else "I"


def _map_uv(o, block, size, faces, atlas_size):
	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
	clamp = lambda t: max(0.0, min(1.0, t))
	for poly in mesh.polygons:
		n = poly.normal
		axis = max(range(3), key=lambda a: abs(n[a]))
		positive = n[axis] > 0
		x0, y0, pw, ph = faces[f"{block}_{_face_key(block, axis, positive)}"][:4]
		for li in poly.loop_indices:
			c = mesh.vertices[mesh.loops[li].vertex_index].co
			if axis == 1:  # front: viewer's right is +X; back: viewer's right is -X
				u = (c.x + hx) / size[0] if not positive else (hx - c.x) / size[0]
				t = (hz - c.z) / size[2]
			elif axis == 0:  # +X side: viewer's right is +Y; -X side: viewer's right is -Y
				u = (c.y + hy) / size[1] if positive else (hy - c.y) / size[1]
				t = (hz - c.z) / size[2]
			else:
				u = (c.x + hx) / size[0]
				t = (c.y + hy) / size[1] if positive else (hy - c.y) / size[1]
			px = x0 + INSET + clamp(u) * (pw - 2 * INSET)
			py = y0 + INSET + clamp(t) * (ph - 2 * INSET)
			uv[li].uv = (px / atlas_size, 1 - py / atlas_size)


def build(cid, c):
	mod = importlib.import_module("char_" + cid)
	atlas = importlib.import_module("atlas")
	parts = {}
	for block, r15, size, at, aliases in BLOCKS:
		o = rbox(r15, size, at, "#808080", bevel=0.04)
		o["painted"] = True
		_map_uv(o, block, size, atlas.FACES, atlas.SIZE)
		parts[r15] = o
		for name in aliases:
			parts[name] = o
	hair = getattr(mod, "HAIR", c["hair"])
	build_pieces(dict(c, hair=hair, pieces=mod.PROPS, marks=getattr(mod, "MARKS", [])), parts)
	if hasattr(mod, "model"):
		mod.model(parts, avatar_base)  # bespoke meshes, parented to a part so they land in its group
	return parts


def hair_zones(cid):
	"""Upper-case hex -> (u0, u1, v0, v1) of its strand zone in the atlas, or {} if the character has none."""
	if not atlas_path(cid):
		return {}
	mod = importlib.import_module("char_" + cid)
	atlas = importlib.import_module("atlas")
	colours = getattr(mod, "HAIR_COLOURS", [])
	x, y, pw, ph = atlas.FACES["Hair"][:4]
	return {
		h.upper(): (
			(x + i * pw / len(colours) + INSET) / atlas.SIZE,
			(x + (i + 1) * pw / len(colours) - INSET) / atlas.SIZE,
			1 - (y + ph - INSET) / atlas.SIZE,
			1 - (y + INSET) / atlas.SIZE,
		)
		for i, h in enumerate(colours)
	}


def load_image(cid):
	return bpy.data.images.load(atlas_path(cid), check_existing=False)
