# Blender draft of the mage boss colosseum (goal boss-mage, m3). Owner look reference only: nothing here ships. Headless:
#   Blender -b --factory-startup --python tools/blender/arena/build_colosseum.py -- [--r-in 50] [shot ...]
# 1 Blender unit = 1 stud, floor at z = 0, ring centre at the origin. Runs counter-clockwise from above.
# Writes build/arena/colosseum_draft.blend and renders to assets/arena_draft/. Prints the boss's on-screen size and a part estimate.
import math
import os
import random
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_arena as ba  # noqa: E402  (guarded main: importing only defines its helpers)
from build_arena import aim, pol, tangent, tris  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
R_IN = float(ARGV[ARGV.index("--r-in") + 1]) if "--r-in" in ARGV else 70.0
LANES, WIDTH = 7, 56.0
LANE_W = WIDTH / LANES
R_OUT = R_IN + WIDTH
R_WALL = R_OUT + 6  # inner wall face; the pillars stand on the 6 stud walkway
WALL_H = 70.0
N = 96  # ring segments
PIECES = 16  # wall pieces, cloned around
TILES = 32  # motif repeats around the wall
TILE_W = math.tau * R_WALL / TILES
CHAR_H = 5.5
BOSS_H, BOSS_HOVER = 4 * CHAR_H, 8.0
TH0 = math.radians(-41)  # the followed runner, rear of the three on lane 4; puts its pulled-in camera between two pillars
GAME_YAW, GAME_PITCH, CAM_BACK = 75, 4, 40.0  # yaw: BOSS_EVENT_SPEC's proposed inward turn; distance locked at 40
DOOR_A, DISC_A = math.radians(90), math.radians(-90)
PILLAR_AS = [math.radians(22.5 + 45 * k) for k in range(8)]
RES = (1280, 720)

ba.PAL.update(
	{
		"ochre": "#9A6A45", "ochre2": "#8A5C3C", "ochreLo": "#6E4A33", "pale": "#D9BE96", "pale2": "#C7A57C", "recess": "#3E4150",
		"floorA": "#CDBFA6", "floorB": "#8C7A68", "laneA": "#B89A78", "laneB": "#AA8C6C", "laneLine": "#E2CFAE", "walk": "#A88763",
		"bronze": "#6E5634", "gold": "#C99A4A", "iron": "#2F2F33", "iron2": "#5E5D62", "iron3": "#1E1E22", "rivet": "#77736A",
		"dome": "#2E2C35", "dome2": "#3A3742", "crack": "#24180F", "rubble": "#A07A55", "rubble2": "#7D6047",
		"dress": "#F2F0EA", "trim": "#C9A04A", "skin": "#F1D6C0", "hair": "#E6E6EC", "tights": "#2B2830", "staff": "#7A4B2A", "gem": "#C0242C",
		"run1": "#E05A3A", "run2": "#3A7BE0", "run3": "#45B060", "runSkin": "#E8C2A0", "runDark": "#2A2A33",
	}
)
_parts = {}  # rough Roblox part count per category, for the primitive rebuild estimate


class MU(ba.M):
	"""build_arena's mesh builder plus per-face UVs and a part counter."""

	def __init__(self, name, cat=None):
		super().__init__(name)
		self.uv, self.cat, self.parts = [], cat or name, 0

	def face(self, pts, material, uv=None):
		super().face(pts, material)
		self.uv.append(uv)

	def box(self, size, c, material):
		self.parts += 1
		super().box(size, c, material)

	def beam(self, a, b, w, material):
		self.parts += 1
		super().beam(a, b, w, material)

	def cyl(self, *a, **k):
		self.parts += 1
		super().cyl(*a, **k)

	def obox(self, size, mtx, material):
		"""A box turned by mtx (its centre is mtx's translation)."""
		self.parts += 1
		sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
		p = [mtx @ Vector((a * sx, b * sy, d * sz)) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
		for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
			self.face([p[k] for k in q], material)

	def cylx(self, r, x0, x1, cy, cz, material, n=12):
		"""A cylinder along X: wall discs facing the centre when built at angle 0."""
		self.parts += 1
		ring = lambda x: [(x, cy + r * math.cos(k / n * math.tau), cz + r * math.sin(k / n * math.tau)) for k in range(n)]
		a, b = ring(x0), ring(x1)
		for k in range(n):
			self.face([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], material)
		self.face(a[::-1], material)
		self.face(b, material)

	def build(self, parent):
		ob = super().build(parent)
		if any(self.uv):
			layer = ob.data.uv_layers.new()
			for poly, uv in zip(ob.data.polygons, self.uv):
				for li, q in zip(poly.loop_indices, uv or [(0, 0)] * poly.loop_total):
					layer.data[li].uv = q
		return ob


# --- Materials the palette cannot give: the drawn wall texture and the glows ---
def draw_tile():
	"""One motif repeat, drawn in sRGB: rows 0-33 studs the motif wall, rows 33-41 the diamond frieze. 16 px per stud."""
	px = 16
	w, h = round(TILE_W * px), 41 * px
	u = (np.arange(w) + 0.5) / px
	v = (np.arange(h) + 0.5) / px
	U, V = np.meshgrid(u, v)
	mask = np.zeros((h, w), bool)

	def seg(p, q, th):
		(x1, y1), (x2, y2) = p, q
		dx, dy = x2 - x1, y2 - y1
		t = np.clip(((U - x1) * dx + (V - y1) * dy) / max(dx * dx + dy * dy, 1e-9), 0, 1)
		mask[:] |= (U - x1 - t * dx) ** 2 + (V - y1 - t * dy) ** 2 <= (th / 2) ** 2

	def poly(pts, th=0.8):
		for p, q in zip(pts, pts[1:]):
			seg(p, q, th)

	def diamond(cx, cy, dw, dh):
		mask[:] |= np.abs(U - cx) / (dw / 2) + np.abs(V - cy) / (dh / 2) <= 1

	cx = TILE_W / 2
	side = [(0.1, 0), (0.55, 0.07), (0.88, 0.22), (1, 0.4), (0.9, 0.58), (0.6, 0.76), (0.26, 0.89), (0.06, 0.97), (0, 1)]
	for scale, v0, hh, a in ((1.0, 14, 17, 7.6), (0.62, 16.2, 11.5, 4.7)):  # the onion and its inner line
		right = [(cx + x * a, v0 + y * hh) for x, y in side]
		left = [(cx - x * a, v0 + y * hh) for x, y in side]
		poly(right[::-1] + left)
		poly([right[0], left[0]])
	poly([(cx, 17.5), (cx, 25)], 0.6)  # leaf vein inside
	for k in range(4):
		y = 18.5 + k * 1.8
		poly([(cx, y), (cx - 1.8 + k * 0.25, y + 1.3)], 0.55)
		poly([(cx, y), (cx + 1.8 - k * 0.25, y + 1.3)], 0.55)
	diamond(cx, 26.6, 1.8, 2.6)  # the eye
	poly([(cx, 14), (cx, 1)], 0.9)  # stem and foot
	poly([(cx - 2.5, 1), (cx + 2.5, 1)], 0.8)
	for s in (-1, 1):  # curling branches with the hanging diamond clusters
		poly([(cx, 10.5), (cx + s * 2.6, 12.6), (cx + s * 5.4, 12.6), (cx + s * 7.2, 11.0), (cx + s * 7.6, 8.6), (cx + s * 7.4, 7.4)], 0.8)
		poly([(cx + s * 0.4, 14.3), (cx + s * 3.0, 15.4), (cx + s * 4.6, 14.8)], 0.7)
		for ox, oy in ((0, 1.25), (-0.95, 0), (0.95, 0), (0, -1.25)):
			diamond(cx + s * 7.4 + ox, 5.2 + oy, 1.7, 2.3)
	for ex in (0, TILE_W):  # small diamonds between the motifs, split across the tile edge so they wrap
		diamond(ex, 25.5, 2.6, 3.6)
		diamond(ex, 31.0, 1.6, 2.2)
		diamond(ex, 7.0, 1.6, 2.2)
	motif = mask.copy()

	base = np.array([0x9A, 0x6A, 0x45], float) / 255
	img = np.tile(base, (h, w, 1))
	rng = np.random.default_rng(3)
	for row in range(5):  # masonry: shaded blocks, staggered joints, in the motif zone only
		y0, y1 = row * 6.6, (row + 1) * 6.6
		off = (row % 2) * TILE_W / 4
		for col in range(-1, 3):
			x0 = off + col * TILE_W / 2
			sel = (V >= y0) & (V < y1) & (U >= x0) & (U < x0 + TILE_W / 2)
			img[sel] *= rng.uniform(0.9, 1.07)
			img[(np.abs(U - x0) < 0.12) & (V >= y0) & (V < y1)] *= 0.8
		img[np.abs(V - y0) < 0.12] *= 0.8
	img *= (1 + rng.normal(0, 0.025, (h, w)))[..., None]
	pale = np.array([0xE6, 0xCC, 0xA4], float) / 255
	img[motif & (V < 33)] = pale
	# The frieze: pale diamonds in two offset rows on a muted mauve stone
	fz = V >= 33
	img[fz] = np.array([0x8E, 0x74, 0x6A], float) / 255
	mask[:] = False
	dw = TILE_W / 8
	for k in range(-1, 9):
		diamond((k + 0.5) * dw, 35.0, dw * 0.86, 3.3)
		diamond(k * dw, 39.0, dw * 0.86, 3.3)
	img[fz & mask] = np.array([0xDF, 0xD2, 0xBE], float) / 255
	img[fz & (np.abs(V - 37) < 0.1)] *= 0.85
	img = np.clip(img, 0, 1)
	bimg = bpy.data.images.new("ColosseumWallTile", w, h, alpha=False)
	bimg.pixels.foreach_set(np.concatenate([img, np.ones((h, w, 1))], axis=2).astype(np.float32).ravel())
	bimg.pack()
	return bimg


def textured(name, image):
	m = bpy.data.materials.new(name)
	nt = m.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = image
	tex.interpolation = "Closest"  # crisp engraved edges at a distance
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.9
	ba._mats[name] = m


def glow(name, color, strength):
	m = bpy.data.materials.new(name)
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = ba.rgb(color)
	bsdf.inputs["Emission Color"].default_value = ba.rgb(color)
	bsdf.inputs["Emission Strength"].default_value = strength
	ba._mats[name] = m


# --- Placement: one mesh built around +X, cloned by rotation. Every object keeps its angle for the cutaway ---
PLACED = []  # (object, angle or None)


def place(m, angles, parent):
	ob = m.build(parent)
	ob.matrix_world = Matrix.Rotation(angles[0], 4, "Z")
	obs = [ob]
	for a in angles[1:]:
		o = ob.copy()
		o.matrix_world = Matrix.Rotation(a, 4, "Z")
		parent.objects.link(o)
		obs.append(o)
	PLACED.extend(zip(obs, angles))
	_parts[m.cat] = _parts.get(m.cat, 0) + m.parts * len(angles)
	return obs


def put(m, parent, angle=None):
	ob = m.build(parent)
	PLACED.append((ob, angle))
	_parts[m.cat] = _parts.get(m.cat, 0) + m.parts
	return ob


def lane_r(i):
	return R_IN + (i - 0.5) * LANE_W


def ring(m, r1, r2, z, material_pair, n=N, uv=None):
	for k in range(n):
		a, b = k / n * math.tau, (k + 1) / n * math.tau
		m.face([pol(r1, a, z), pol(r2, a, z), pol(r2, b, z), pol(r1, b, z)], material_pair[k % len(material_pair)])


# --- The room ---
def floor():
	m = MU("ColosseumFloor", "floor")
	# Centre: a polar checker of two stones, like the reference's spell floor
	rings = [20, 30, 40, 50, 60, R_IN] if R_IN > 60 else [20, 28, 36, 44, R_IN]
	for i, (r1, r2) in enumerate(zip(rings, rings[1:])):
		n = 24 + 8 * i
		for k in range(n):
			a, b = k / n * math.tau, (k + 1) / n * math.tau
			m.face([pol(r1, a, 0), pol(r2, a, 0), pol(r2, b, 0), pol(r1, b, 0)], "floorA" if (k + i) % 2 else "floorB")
		m.parts += n // 2  # the dark squares as thin wedges over one light disc
	m.cyl(20, 0.3, (0, 0, -0.3), "bronze", n=24)  # rayed disc under the boss
	m.cyl(17.5, 0.2, (0, 0, 0), "pale2", n=24)
	m.cyl(14, 0.25, (0, 0, 0), "bronze", n=24)
	m.cyl(4.5, 0.6, (0, 0, 0), "gold", n=12)
	for k in range(16):
		a = k / 16 * math.tau
		w = math.radians(6 if k % 2 else 9)
		tip = 19.5 if k % 2 == 0 else 16.0
		m.face([pol(5, a - w, 0.32), pol(tip, a, 0.32), pol(5, a + w, 0.32)], "gold")
		m.parts += 1
	# The 7 lanes: two alternating tones, a pale line between each
	for i in range(1, LANES + 1):
		r1, r2 = R_IN + (i - 1) * LANE_W, R_IN + i * LANE_W
		pair = ("laneA",) if i % 2 else ("laneB",)
		ring(m, r1, r2 - 0.4, 0, pair)
		ring(m, r2 - 0.4, r2, 0.03, ("laneLine",))
		m.parts += 2
	ring(m, R_IN - 0.6, R_IN, 0.03, ("laneLine",))
	ring(m, R_OUT, R_WALL + 1, 0.5, ("walk",))  # walkway step at the wall foot
	ba.loft(m, [(R_OUT, 0), (R_OUT, 0.5)], "pale2", n=N)
	m.parts += 2
	return m


def wall_piece():
	"""One 22.5 degree stretch of wall around +X: dado, ledge, motif wall, bands, recess, frieze, cornice."""
	m = MU("ColosseumWall", "wall")
	span = math.tau / PIECES
	segs = N // PIECES
	R = R_WALL

	def strip(r, z1, z2, material, v1=None, v2=None):
		for k in range(segs):
			a, b = -span / 2 + span * k / segs, -span / 2 + span * (k + 1) / segs
			uv = None
			if v1 is not None:  # 2 tiles per piece, u runs across them
				ua, ub = k / segs * 2, (k + 1) / segs * 2
				uv = [(ua, v1), (ua, v2), (ub, v2), (ub, v1)]
			m.face([pol(r, a, z1), pol(r, a, z2), pol(r, b, z2), pol(r, b, z1)], material, uv)

	def ledge(r_front, z1, z2, material):
		"""A band standing out from the wall face."""
		ba.arc_box(m, r_front, R + 0.01, z1, z2, -span / 2, span / 2, material, segs)
		m.parts += 1

	strip(R, 0, 10, "ochreLo")
	ledge(R - 1.6, 9, 12, "pale")
	strip(R, 12, 45, "wallTex", 0, 33 / 41)
	ledge(R - 1.2, 45, 47.5, "pale")
	strip(R + 2, 47.5, 56, "recess")  # the dark recessed band
	ba.arc_box(m, R, R + 2, 47.5, 56, -span / 2, span / 2, "recess", segs)
	ledge(R - 1.0, 56, 58, "pale")
	strip(R - 0.4, 58, 66, "wallTex", 33 / 41, 1)
	ledge(R - 2.2, 66, 70, "pale2")
	m.parts += 2  # the motif and frieze as decals or textured faces
	return m


def pillar():
	"""Square pillar on the wall face at +X: plinth with a glowing doorway, sun disc, torch, winged oval relief, dentil capital."""
	m = MU("ColosseumPillar", "pillars")
	R = R_WALL
	f = R - 5  # shaft front face
	m.box((5.5, 13, 56), (f + 2.75, 0, 28), "ochre2")
	m.box((7, 17, 11), (R - 3.5, 0, 5.5), "pale2")  # plinth
	m.box((1, 18, 1.2), (R - 7.2, 0, 11.2), "pale")
	m.box((0.4, 5.4, 8.4), (R - 7.1, 0, 4.4), "glowDoor")  # glowing doorway in the plinth
	m.box((0.6, 6.6, 0.8), (R - 7.2, 0, 9.0), "pale")
	m.cylx(4.6, f - 0.9, f, 0, 16.5, "pale", n=16)  # sun disc
	m.cylx(3.8, f - 1.0, f - 0.9, 0, 16.5, "bronze", n=16)
	for k in range(8):
		a = k / 8 * math.tau
		w = 0.22 if k % 2 else 0.35
		r = 3.7 if k % 2 == 0 else 2.6
		p = lambda rr, aa: (f - 1.15, rr * math.cos(aa), 16.5 + rr * math.sin(aa))
		m.face([p(0.9, a - w), p(r, a), p(0.9, a + w)], "gold")
	m.cylx(1.0, f - 1.3, f - 0.9, 0, 16.5, "gold", n=8)
	m.parts += 8
	# Torch on a bracket, between the disc and the relief
	m.box((2.2, 1.2, 1.2), (f - 1.1, 0, 22.6), "iron")
	m.box((1.4, 1.4, 1.6), (f - 2.4, 0, 23.6), "iron2")
	m.box((1.0, 1.0, 1.6), (f - 2.4, 0, 25.1), "flame")
	# Oval frame and a faceted winged figure, raised from the shaft
	cz, ry, rz, x = 37.5, 4.6, 9.0, f - 0.35
	pts = [Vector((x, ry * math.cos(k / 14 * math.tau), cz + rz * math.sin(k / 14 * math.tau))) for k in range(15)]
	for p, q in zip(pts, pts[1:]):
		m.beam(p, q, 0.8, "pale")
	m.box((0.5, 8.6, 18.6), (f - 0.1, 0, cz), "ochre")  # recessed field
	x = f - 0.6
	m.box((0.8, 2.6, 7.5), (x, 0, cz - 2.2), "pale2")  # robe
	m.box((0.8, 3.6, 2.2), (x, 0, cz - 6.5), "pale2")  # hem
	m.box((0.9, 1.7, 1.9), (x - 0.1, 0, cz + 3.0), "pale2")  # head
	m.box((0.6, 2.2, 0.7), (x - 0.1, 0, cz + 4.3), "pale")  # crown
	for s in (-1, 1):  # wings: two quads fanning up and out from the shoulders
		m.face([(x - 0.2, s * 1.3, cz + 1.5), (x - 0.2, s * 3.9, cz + 5.6), (x - 0.2, s * 4.0, cz - 1.0), (x - 0.2, s * 1.3, cz - 3.0)], "pale")
		m.face([(x - 0.4, s * 2.0, cz + 1.0), (x - 0.4, s * 3.5, cz + 3.8), (x - 0.4, s * 3.6, cz - 0.4), (x - 0.4, s * 2.0, cz - 1.8)], "pale2")
		m.parts += 1
	# Panel lines on the shaft face
	for s in (-1, 1):
		m.box((0.3, 0.6, 46), (f - 0.1, s * 5.5, 32), "pale2")
	# Capital: necking, dentils, block, slab
	m.box((7.5, 15, 2), (R - 3.75, 0, 57), "pale")
	for k in range(9):
		y = -6.4 + k * 1.6
		m.box((0.9, 0.9, 1.3), (R - 7.6, y, 58.6), "pale2")
	for s in (-1, 1):
		for k in range(4):
			m.box((0.9, 0.9, 1.3), (R - 6.6 + k * 1.7, s * 7.6, 58.6), "pale2")
	m.box((8.5, 17, 3.5), (R - 4.25, 0, 61), "ochre2")
	m.box((9.5, 19, 1.6), (R - 4.75, 0, 63.5), "pale")
	m.box((9, 18, 5.5), (R - 4.5, 0, 67), "ochre2")
	return m


def great_doors():
	"""The double doors at +X: a pale portal, two dark metal leaves with square and diamond panels, rivets."""
	m = MU("ColosseumDoors", "doors")
	R, hw, hh = R_WALL, 15.0, 42.0
	for s in (-1, 1):
		m.box((5, 6, hh + 4), (R - 2.5, s * (hw + 3), (hh + 4) / 2), "pale2")  # jambs
	m.box((6, 2 * hw + 12, 6), (R - 3, 0, hh + 5), "pale")  # lintel
	m.box((4, 2 * hw + 8, 4), (R - 2, 0, hh + 10), "ochre2")
	for s in (-1, 1):
		cy = s * hw / 2
		x = R - 1.2
		m.box((1.2, hw - 0.2, hh), (x, cy, hh / 2), "iron2")
		for z in (6.5, 21, 35.5):  # deep square panels
			m.box((0.4, hw * 0.62, 9.5), (x - 0.75, cy, z), "iron3")
			m.box((0.3, hw * 0.74, 0.8), (x - 0.75, cy, z + 5.4), "iron")
		for z in (13.75, 28.25):  # diamond panels between them
			m.obox((0.5, 5.2, 5.2), Matrix.Translation((x - 0.8, cy, z)) @ Matrix.Rotation(math.pi / 4, 4, "X"), "iron3")
			for t in (-1, 1):
				m.obox((0.4, 3.0, 3.0), Matrix.Translation((x - 0.75, cy + t * hw * 0.32, z)) @ Matrix.Rotation(math.pi / 4, 4, "X"), "iron")
		m.box((0.5, 0.8, hh), (x - 0.7, s * (hw - 0.4), hh / 2), "iron")  # outer stile
		for z in range(3, int(hh), 6):
			m.box((0.5, 0.6, 0.6), (x - 0.9, s * (hw - 0.4), z), "rivet")
	m.box((0.6, 0.5, hh), (R - 1.9, 0, hh / 2), "iron3")  # the meeting line
	for s in (-1, 1):
		m.cylx(0.9, R - 2.4, R - 1.8, s * 1.6, 20, "rivet", n=8)  # ring pulls
	return m


def disc_door():
	"""The round rayed door at +X, in a portal with a sun lunette above, like the far door in the references."""
	m = MU("ColosseumDiscDoor", "disc door")
	R, cz, r = R_WALL, 15.5, 14.5
	for s in (-1, 1):
		m.box((5, 5, 36), (R - 2.5, s * (r + 4.5), 18), "pale2")
		m.box((6, 6, 3), (R - 3, s * (r + 4.5), 37.5), "pale")
	m.box((6, 2 * r + 15, 4), (R - 3, 0, 33), "pale")
	m.cylx(r + 1.2, R - 1.6, R, 0, cz, "pale", n=24)
	m.cylx(r, R - 2.0, R - 1.6, 0, cz, "bronze", n=24)
	m.cylx(r - 2.5, R - 2.2, R - 2.0, 0, cz, "iron", n=24)
	for k in range(16):
		a = k / 16 * math.tau
		w, tip = (0.2, r - 0.6) if k % 2 == 0 else (0.13, r - 4)
		p = lambda rr, aa: (R - 2.35, rr * math.cos(aa), cz + rr * math.sin(aa))
		m.face([p(3, a - w), p(tip, a), p(3, a + w)], "gold")
		m.parts += 1
	m.cylx(3.2, R - 2.8, R - 2.0, 0, cz, "gold", n=12)
	# Lunette: half a rayed disc over the portal
	m.cylx(8, R - 1.4, R - 0.6, 0, 42, "pale2", n=16)
	for k in range(7):
		a = math.pi * (k + 0.5) / 7
		p = lambda rr, aa: (R - 1.5, rr * math.cos(aa), 42 + rr * math.sin(aa))
		m.face([p(1.5, a - 0.12), p(7.2, a), p(1.5, a + 0.12)], "gold")
	return m


def dome():
	"""Two stepped tiers and a squashed dome, dark, with a broken hole off-centre and missing patches."""
	m = MU("ColosseumDome", "dome")
	rng = random.Random(11)
	R = R_WALL
	ba.loft(m, [(R + 0.1, 70), (R - 6, 70), (R - 6, 77), (R - 11, 77), (R - 11, 83), (R - 15, 83)], "dome2", n=N)
	m.parts += 6
	rd, z0, hgt, rows = R - 15, 83.0, 60.0, 9
	hole = pol(rd * 0.3, math.radians(150), 0)

	def broken(c):
		t = math.atan2(c.y - hole.y, c.x - hole.x)
		return (c - hole).length < rd * 0.26 * (1 + 0.22 * math.sin(5 * t) + 0.12 * math.sin(13 * t + 1))
	for i in range(rows):
		p1, p2 = i / rows * math.pi / 2, (i + 1) / rows * math.pi / 2
		for k in range(N):
			a, b = k / N * math.tau, (k + 1) / N * math.tau
			c = pol(rd * math.cos((p1 + p2) / 2), (a + b) / 2, 0)
			if broken(c) or (i >= 3 and rng.random() < 0.04):
				continue  # broken away
			mm = "dome" if (k // 3 + i) % 2 else "dome2"
			m.face([pol(rd * math.cos(p1), a, z0 + hgt * math.sin(p1)), pol(rd * math.cos(p1), b, z0 + hgt * math.sin(p1)), pol(rd * math.cos(p2), b, z0 + hgt * math.sin(p2)), pol(rd * math.cos(p2), a, z0 + hgt * math.sin(p2))], mm)
	m.parts += 120  # a dome of wedges and slabs, roughly
	for _ in range(10):  # cracks running up the dome
		a, i = rng.uniform(0, math.tau), 0.0
		pts = []
		for s in range(5):
			ph = (0.03 + s * 0.1) * math.pi / 2
			a += rng.uniform(-0.06, 0.06)
			pts.append(pol((rd - 0.6) * math.cos(ph), a, z0 + (hgt - 0.6) * math.sin(ph)))
		for p, q in zip(pts, pts[1:]):
			m.beam(p, q, 0.7, "crack")
	return m


def wall_cracks(parent):
	"""Jagged dark lines down the wall, each its own object so the cutaway can hide it."""
	rng = random.Random(5)
	for _ in range(14):
		a0 = rng.uniform(0, math.tau)
		m = MU("ColosseumCrack", "cracks")
		z, a = rng.uniform(32, 44.5), a0
		pts = [pol(R_WALL - 0.3, a, z)]
		for _ in range(rng.randint(3, 5)):  # inside the motif wall, where the face is flat behind it
			z -= rng.uniform(3, 6)
			a += rng.uniform(-4, 4) / R_WALL
			pts.append(pol(R_WALL - 0.3, a, max(z, 12.5)))
		for p, q in zip(pts, pts[1:]):
			m.beam(p, q, 0.55, "crack")
		put(m, parent, a0)


def rubble(parent):
	"""Fallen blocks: piles at the wall foot and on the centre floor, clear of the lanes."""
	rng = random.Random(9)
	piles = [(R_WALL - 3, a, 10) for a in (math.radians(40), math.radians(200), math.radians(-120))]
	piles += [(R_IN * 0.62, math.radians(a), 14) for a in (20, 140, 260)]
	for r0, a0, n in piles:
		m = MU("ColosseumRubble", "rubble")
		for _ in range(n):
			s = rng.uniform(1.4, 4.5) * (0.7 if r0 > R_IN else 1)
			rr = r0 + rng.uniform(-4, 4) * (0.4 if r0 > R_IN else 1.5)
			c = pol(min(rr, R_WALL - s / 2), a0 + rng.uniform(-6, 6) / r0, s * 0.35)
			mt = Matrix.Translation(c) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "X")
			m.obox((s * rng.uniform(0.8, 1.4), s, s * rng.uniform(0.6, 1.0)), mt, rng.choice(("rubble", "rubble2", "ochre")))
		put(m, parent, a0)


def boss(parent):
	"""Stand-in: plain blocks, 22 studs from her feet to the top of her hair, hovering. Front faces -Y before turning."""
	b, f = MU("MageStandIn", "boss stand-in"), BOSS_HOVER
	b.box((1.0, 1.0, 4.0), (-0.9, 0, f + 2), "tights")
	b.box((1.0, 1.0, 4.0), (0.9, 0, f + 2), "tights")
	b.cyl(4.6, 0.6, (0, 0, f + 3.4), "trim", n=8)
	b.cyl(4.4, 9.0, (0, 0, f + 4.0), "dress", n=8, r2=2.2)  # skirt
	b.box((4.2, 2.8, 4.0), (0, 0, f + 14.6), "dress")  # bodice
	b.box((6.4, 3.6, 2.4), (0, 0, f + 16.0), "dress")  # capelet
	b.box((6.6, 3.8, 0.4), (0, 0, f + 14.8), "trim")
	for s in (-1, 1):
		b.box((1.2, 1.2, 4.6), (s * 3.6, 0, f + 13.0), "dress")
	b.box((3.4, 3.2, 3.6), (0, 0, f + 19.0), "skin")  # head
	b.box((3.8, 3.6, 1.3), (0, 0.1, f + 21.35), "hair")  # top of the hair: 22 studs
	b.box((3.8, 1.0, 3.0), (0, 1.4, f + 19.6), "hair")
	b.box((3.8, 0.5, 1.0), (0, -1.6, f + 20.3), "hair")  # fringe
	for s in (-1, 1):  # twin tails, long, from high on the head
		b.obox((1.3, 1.3, 15.5), Matrix.Translation((s * 2.6, 0.8, f + 13.0)) @ Matrix.Rotation(s * 0.08, 4, "Y"), "hair")
		b.box((1.0, 1.0, 1.0), (s * 2.1, 0.6, f + 20.6), "gem")  # hair ties
	staff = MU("MageStaffStandIn", "boss stand-in")
	staff.beam((4.6, -0.8, f + 1.0), (4.6, -0.8, f + 24.5), 0.6, "staff")
	staff.cyl(1.4, 0.5, (4.6, -0.8, f + 24.2), "trim", n=8)
	staff.box((1.1, 1.1, 1.6), (4.6, -0.8, f + 25.3), "gem")
	turn = Matrix.Rotation(TH0 + math.pi / 2, 4, "Z")  # front toward the followed runner
	obs = [put(b, parent), put(staff, parent)]
	for o in obs:
		o.matrix_world = turn
	return obs


def runners(parent):
	"""Three 5.5 stud blocky runners in a line on lane 4, facing the running direction."""
	obs = []
	for k, col in enumerate(("run1", "run2", "run3")):
		m = MU("RunnerStandIn", "runners")
		for s in (-1, 1):
			m.box((0.9, 0.9, 2.5), (s * 0.5, 0, 1.25), "runDark")
			m.box((0.8, 0.8, 2.0), (s * 1.4, 0, 3.4), col)
		m.box((2.0, 1.0, 2.0), (0, 0, 3.5), col)
		m.box((1.2, 1.2, 1.2), (0, 0, 5.0), "runSkin")
		m.box((1.3, 1.3, 0.4), (0, 0.05, 5.5 - 0.2), "runDark")
		a = TH0 + k * 8 / lane_r(4)
		ob = put(m, parent, a)
		ob.matrix_world = Matrix.Translation(pol(lane_r(4), a, 0)) @ Matrix.Rotation(a + math.pi, 4, "Z")  # -Y front along the run
		obs.append(ob)
	return obs


# --- Lights and cameras ---
LIGHTS = []


def setup(scene):
	for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = eng
			break
		except TypeError:
			pass
	scene.eevee.taa_render_samples = 48
	scene.render.resolution_x, scene.render.resolution_y = RES
	scene.render.image_settings.file_format = "PNG"
	try:
		scene.view_settings.view_transform = "AgX"
	except TypeError:
		scene.view_settings.view_transform = "Filmic"
	world = bpy.data.worlds.new("ColosseumAir")
	scene.world = world
	nt = world.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	mix = nt.nodes.new("ShaderNodeMix")  # the camera sees a night sky through the broken dome; the light it casts is the room's ambience
	mix.data_type = "RGBA"
	mix.name = "SkyMix"
	nt.links.new(nt.nodes.new("ShaderNodeLightPath").outputs["Is Camera Ray"], mix.inputs["Factor"])
	nt.links.new(mix.outputs["Result"], bg.inputs["Color"])
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.sensor_fit = "VERTICAL"
	cam.data.clip_start = 0.3
	cam.data.clip_end = 3000
	scene.collection.objects.link(cam)
	scene.camera = cam
	for a in PILLAR_AS:  # torch and doorway glow at every pillar
		for r, z, kind in ((R_WALL - 8.5, 25.5, "torch"), (R_WALL - 9.5, 4.5, "door")):
			light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "POINT"))
			light.location = pol(r, a, z)
			light.data.shadow_soft_size = 1.5
			scene.collection.objects.link(light)
			LIGHTS.append((light, kind))
	top = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
	top.data.shape, top.data.size = "DISK", R_WALL * 1.4
	top.location = (0, 0, 100)
	scene.collection.objects.link(top)
	LIGHTS.append((top, "fill"))
	return cam


def lighting(mode):
	"""warm: torches and a low amber ambience. lightning: blue-violet room, bright violet-white light from above the boss."""
	warm = mode == "warm"
	nt = bpy.context.scene.world.node_tree
	mix = nt.nodes["SkyMix"]
	mix.inputs["A"].default_value = ba.rgb("#4A3426" if warm else "#2C2490")
	mix.inputs["B"].default_value = ba.rgb("#0E1322" if warm else "#2A2060")
	next(n for n in nt.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.5 if warm else 1.3
	for ob, kind in LIGHTS:
		d = ob.data
		if kind == "torch":
			d.color, d.energy = ((1.0, 0.55, 0.22), 26000) if warm else ((0.45, 0.32, 1.0), 30000)
		elif kind == "door":
			d.color, d.energy = ((1.0, 0.65, 0.3), 4000) if warm else ((0.7, 0.6, 1.0), 3000)
		else:
			d.color, d.energy = ((1.0, 0.78, 0.55), 170000) if warm else ((0.48, 0.38, 1.0), 650000)
	for name, (wc, lc) in {"flame": ("#FFB04A", "#D9C8FF"), "glowDoor": ("#FFB45A", "#C6B4FF")}.items():
		bsdf = next(n for n in ba._mats[name].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		c = ba.rgb(wc if warm else lc)
		bsdf.inputs["Base Color"].default_value = c
		bsdf.inputs["Emission Color"].default_value = c


def player_pose(lane, yaw=GAME_YAW, pitch=GAME_PITCH):
	"""The follow camera CAM_BACK behind a runner on lane, turned yaw inward. Pulled in where the wall would block it, as Roblox's camera does."""
	run = pol(lane_r(lane), TH0, 0)
	y = math.radians(yaw)
	d = (tangent(TH0) * math.cos(y) - pol(1, TH0, 0) * math.sin(y)).normalized()
	back = CAM_BACK
	while back > 1 and (run - d * back).length > R_WALL - 2.5:
		back -= 0.25
	eye = run - d * back + Vector((0, 0, CHAR_H + 3))
	return eye, eye + d * 100 + Vector((0, 0, 100 * math.tan(math.radians(pitch)))), back


def shots():
	if R_IN != 70:
		e, l, _ = player_pose(4)
		return [(f"colosseum_02d_player_view_r{R_IN:.0f}", e, l, 100, "warm", False)]
	(e4, l4, _), (e1, l1, _), (e7, l7, _) = player_pose(4), player_pose(1), player_pose(7)
	pa = PILLAR_AS[7]  # -22.5 degrees
	return [
		("colosseum_01_overview", pol(250, math.radians(-155), 230), Vector((0, 25, 0)), 50, "warm", True),
		("colosseum_02_player_view", e4, l4, 100, "warm", False),
		("colosseum_02b_player_view_lane1", e1, l1, 100, "warm", False),
		("colosseum_02c_player_view_lane7", e7, l7, 100, "warm", False),
		("colosseum_03_door", Vector((0, 22, 12)), pol(R_WALL, DOOR_A, 24), 62, "warm", False),
		("colosseum_04_wall_detail", pol(R_WALL - 42, pa - math.radians(14), 26), pol(R_WALL - 6, pa - math.radians(4), 34), 60, "warm", False),
		("colosseum_05_lightning", e4, l4, 100, "lightning", False),
	]


def cutaway(cam_eye, on):
	"""Hide the dome and the wall nearest the camera."""
	az = math.atan2(cam_eye.y, cam_eye.x)
	for ob, a in PLACED:
		hide = False
		if on:
			hide = ob.name.startswith("ColosseumDome") or (a is not None and abs((a - az + math.pi) % math.tau - math.pi) < math.radians(50) and not ob.name.startswith(("Runner", "ColosseumFloor")))
		ob.hide_render = hide
	for ob, _ in LIGHTS:
		a = math.atan2(ob.location.y, ob.location.x)
		ob.hide_render = on and ob.location.length > 1 and abs((a - az + math.pi) % math.tau - math.pi) < math.radians(50)


def boss_px(cam, obs):
	"""Rows the boss spans at RES, and whether all of her sits in frame below the top 20% (the HP bar)."""
	q = [world_to_camera_view(bpy.context.scene, cam, o.matrix_world @ v.co) for o in obs for v in o.data.vertices]
	ys, xs = [c.y for c in q], [c.x for c in q]
	ok = all(c.z > 0 for c in q) and min(ys) >= 0 and max(ys) <= 0.8 and min(xs) >= 0 and max(xs) <= 1
	return (max(ys) - min(ys)) * RES[1], ok, max(ys)


def main():
	argv = [a for i, a in enumerate(ARGV) if a != "--r-in" and (i == 0 or ARGV[i - 1] != "--r-in")]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	ba._mats.clear()
	os.makedirs(ba.OUT, exist_ok=True)
	os.makedirs(ba.BUILD, exist_ok=True)
	scene = bpy.context.scene
	coll = scene.collection
	textured("wallTex", draw_tile())
	glow("flame", "#FFB04A", 40)
	glow("glowDoor", "#FFB45A", 12)

	put(floor(), coll)
	piece_as = [k / PIECES * math.tau for k in range(PIECES)]
	place(wall_piece(), piece_as, coll)
	place(pillar(), PILLAR_AS, coll)
	place(great_doors(), [DOOR_A], coll)
	place(disc_door(), [DISC_A], coll)
	put(dome(), coll)
	wall_cracks(coll)
	rubble(coll)
	boss_obs = boss(coll)
	body = boss_obs[0]
	runners(coll)

	n_tris = sum(tris(o) for o, _ in PLACED)
	print(f"TRIS scene: {n_tris}; objects {len(PLACED)}")
	for k, v in sorted(_parts.items()):
		print(f"PARTS {k}: {v}")
	print(f"PARTS total (primitive rebuild, rough): {sum(_parts.values())}")
	zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
	print(f"BOSS stand-in: feet {min(zs):.1f} to hair top {max(zs):.1f} = {max(zs) - min(zs):.1f} studs")

	cam = setup(scene)
	bpy.context.preferences.filepaths.save_version = 0
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ba.BUILD, f"colosseum_draft_r{R_IN:.0f}.blend"))
	for lane in (1, 4, 7):
		e, l, back = player_pose(lane)
		aim(cam, e, l, 100)
		h, ok, top = boss_px(cam, [body])
		hs, oks, tops = boss_px(cam, boss_obs)
		print(f"PX R_IN {R_IN:.0f} lane {lane}: camera {back:.1f} studs back (wall pull-in from {CAM_BACK:.0f}); boss body {h:.0f}px tall at {RES[0]}x{RES[1]}, top at {1 - top:.0%} from the frame top, clear of the bar {ok}; with staff {hs:.0f}px, clear {oks}")
	for name, eye, look, fov, mode, cut in shots():
		if argv and name not in argv:
			continue
		lighting(mode)
		cutaway(Vector(eye), cut)
		aim(cam, eye, look, fov)
		scene.render.filepath = os.path.join(ba.OUT, name + ".png")
		bpy.ops.render.render(write_still=True)
		print("SHOT", scene.render.filepath)


if __name__ == "__main__":
	main()
