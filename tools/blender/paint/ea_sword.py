# Ea, The Golden King's sword (design doc 4.37 Third boss; docs/char_evidence/boss_king.md "Ea"; owner 2026-11-11: "massive").
# A pillar, not a sword: three stacked dark red-black drums, each its own diameter and its own red cuneiform ribbon pattern
# (zigzag strips on the surface, never real text), thin gold spacer rings between them, a blunt gold chisel tip; a gold
# flared-cup guard with two wing plates, a long gold grip, a round pommel. Drawn upright at the origin, pommel at z 0, so
# char_boss_king.py can move it to the hand. Pieces are named <part>_<PREFIX><rest> so build_boss_king.py can join them into
# four objects, Ea_Grip (grip, guard, spacer rings: still) and Ea_Drum1-3 (each spins on its own; the top one carries the
# tip), under one empty. The ribbons carry material index 1: the render gives them an emissive material. Sizes against the
# king: blade (drums and tip) BLADE = 8.8, about 1.3 x his 6.6 height; drums about 0.65 x his 2.06 torso width (owner: "massive",
# not a staff). Budget 700.
import math

from char_boss_mage import rod
from jk_style3 import bake, prism

PARTS = ("Ea_Grip", "Ea_Drum1", "Ea_Drum2", "Ea_Drum3")
GRIP_Z = (0.12, 1.2)  # the grip's run: the R15 hand (0.44 tall) sits at 0.35 with room either side
BLADE = 8.8
# drums bottom to top: (z0, z1, radius); the spacer rings sit in the 0.14 gaps
DRUMS = ((1.9, 4.7, 0.675), (4.84, 7.6, 0.625), (7.74, 10.3, 0.575))
TIP = 0.4  # the chisel tip's run above the top drum (the pillar ends at 10.7)
# cuneiform ribbons per drum: (angle offset degrees, fraction along the drum) nodes, one pattern per ribbon
RIBBONS = (
	(((0, 0), (0, 0.22), (16, 0.36), (16, 0.52), (0, 0.66), (0, 1)), ((0, 0), (14, 0.18), (-14, 0.4), (14, 0.62), (-14, 0.84), (0, 1)), ((0, 0), (0, 0.4), (-18, 0.54), (0, 0.68), (0, 1))),
	(((0, 0), (12, 0.2), (-12, 0.44), (12, 0.68), (0, 0.84), (0, 1)), ((0, 0), (0, 0.3), (18, 0.42), (18, 0.6), (0, 0.72), (0, 1)), ((0, 0), (-14, 0.22), (14, 0.5), (-14, 0.78), (0, 1))),
	(((0, 0), (0, 0.26), (-16, 0.4), (-16, 0.56), (0, 0.7), (0, 1)), ((0, 0), (16, 0.24), (-16, 0.48), (16, 0.72), (0, 1)), ((0, 0), (0, 0.36), (18, 0.5), (0, 0.64), (0, 1))),
)


def _ribbon(k, part, name, nodes, r, z0, z1, base, hw=0.12):
	"""One red strip on a drum's surface: a quad per segment, single sided, facing out. Material index 1 (the glow)."""
	import bmesh
	from mathutils import Vector

	rr = r + 0.012
	da = hw / rr
	verts = []
	for ang, f in nodes:
		a = base + math.radians(ang)
		z = z0 + f * (z1 - z0)
		for s in (-1, 1):
			verts.append((rr * math.cos(a + s * da), rr * math.sin(a + s * da), z))
	faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(nodes) - 1)]
	o = k._mesh(name, part, verts, faces, range(len(faces)), outline=0)
	bm = bmesh.new()
	bm.from_mesh(o.data)
	out = [f for f in bm.faces if f.normal.dot(Vector((f.calc_center_median().x, f.calc_center_median().y, 0))) < 0]
	bmesh.ops.reverse_faces(bm, faces=out)
	bm.to_mesh(o.data)
	bm.free()
	bake(o, "glow", k, a=0.92, b=0.0, g=0.0)
	for p in o.data.polygons:
		p.material_index = 1
	return o


def build(k, part="RightHand", small=False):
	"""Every Ea piece on part, upright at the origin. small (the Sidekick): one drum, no ribbons, no wings."""
	g = "EaGrip"
	# the round pommel, the long gold grip with a navy wrap band, the flared cup guard, the two wing plates
	o = k.lathe(part, g + "Pommel", [(0.07, -0.16, 0.5), (0.17, -0.04, 0.5), (0.11, 0.16, 0.5)], "gold", n=8, outline=0)
	bake(o, "gold", k, a=0.6, b=0.42)
	rod(k, part, g + "Shaft", [(0, 0, GRIP_Z[0]), (0, 0, GRIP_Z[1])], 0.11, "gold", n=8, a=0.58, b=0.42)
	o = k.lathe(part, g + "Guard", [(0.13, 1.2, 0.5), (0.4, 1.3, 0.5), (1.1, 1.8, 0.5), (0.8, 1.92, 0.5)], "gold", n=8, outline=0)
	bake(o, "gold", k, a=0.62, b=0.42, g=0.1)
	if not small:
		for s in (1, -1):
			prism(k, part, f"{g}Wing{s}", [(s * 0.5, 1.36), (s * 1.0, 1.7), (s * 1.6, 2.9), (s * 1.36, 3.0), (s * 0.6, 2.0)], -0.14, 0.14, "gold", a=0.62, b=0.42)
			prism(k, part, f"{g}WingCut{s}", [(s * 1.0, 1.9), (s * 1.36, 2.6), (s * 0.8, 2.1)], -0.152, 0.152, "navy", a=0.44, b=0.3)
	drums = DRUMS[:1] if small else DRUMS
	for i, (z0, z1, r) in enumerate(drums):
		d = f"EaDrum{i + 1}"
		# the drum, a hair wider at its middle; the ring above it belongs to the grip (still)
		o = k.lathe(part, d + "Body", [(r - 0.03, z0, 0.5), (r, (z0 + z1) / 2, 0.5), (r - 0.03, z1, 0.5)], "ea", n=10, outline=0)
		bake(o, "ea", k, a=0.5, b=0.46, g=0.06)
		if not small:
			for j, nodes in enumerate(RIBBONS[i]):
				_ribbon(k, part, f"{d}Line{j}", nodes, r, z0 + 0.2, z1 - 0.2, 2 * math.pi * j / 3 + i * 0.7)
		if i + 1 < len(drums):
			rod(k, part, f"{g}Ring{i + 1}", [(0, 0, z1 - 0.1), (0, 0, z1 + 0.24)], r + 0.06, "gold", n=8, a=0.62, b=0.42)
	# the blunt chisel tip on the top drum
	top = drums[-1][1]
	rod(k, part, f"EaDrum{len(drums)}Cap", [(0, 0, top - 0.1), (0, 0, top + 0.16)], drums[-1][2] + 0.06, "gold", n=8, a=0.62, b=0.42)
	# a real wedge: full drum width at its base, a blunt edge across x at the top
	prism(k, part, f"EaDrum{len(drums)}Tip", [(-0.56, top + 0.12), (0.56, top + 0.12), (0.5, top + TIP), (-0.5, top + TIP)], -0.5, 0.5, "gold", a=0.6, b=0.42)
	prism(k, part, f"EaDrum{len(drums)}Edge", [(-0.5, top + TIP - 0.02), (0.5, top + TIP - 0.02), (0.0, top + TIP + 0.3)], -0.5, 0.5, "gold", a=0.62, b=0.42)
