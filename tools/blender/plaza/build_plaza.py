# Blender draft of the plaza and Dojos (design doc 4.24, WORLD_REDESIGN_SPEC 7). Headless:
#   Blender -b --factory-startup --python tools/blender/plaza/build_plaza.py -- [shot ...]
# 1 Blender unit = 1 stud. rb(x, y, z) maps Roblox world positions, so fixed positions come straight from the game.
# Writes build/plaza/plaza_draft.blend and review renders to assets/plaza_draft/. Every mesh object is one planned asset;
# prints its tri count. Context objects (Ctx_*) stand in for what stays in the game or lives elsewhere.
import hashlib
import json
import math
import os
import random
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "plaza_draft")
BLEND = os.path.join(ROOT, "build", "plaza", "plaza_draft.blend")
CHARS = os.path.join(ROOT, "assets", "characters_avatar")
TOP = 1.0  # floor top = road top (SpawnArea.TOP_Y)
rng = random.Random(7)
LOOP_H = 30  # sky loop height: clears the gate top from the spawn view (proposed)

# Fixed by the game (read from the live place 2026-11-03)
SPAWN = (0, 0)
PAD = (-84, 78)
PLOTS = {  # centre (x, z), front (x, z)
	1: ((-42, -91), (0, 1)),
	2: ((25, -107), (0, 1)),
	3: ((86, -68), (-1, 0)),
	4: ((110, 0), (-1, 0)),
	5: ((86, 68), (-1, 0)),
	6: ((25, 107), (0, -1)),
	7: ((-42, 91), (0, -1)),
}
# Service row (WORLD_REDESIGN_SPEC 7): every front stands on the line x = -72, facing +x. South to north, spaced 28.75:
# the spec's z 53 end would put the sensei's dais on the path edge, so the row ends at z 45.
ROW_X, ROW_FACE = -72, (1, 0)
SHOP = (ROW_X - 5, -70)  # stall origin: the deck front is 5 ahead
POTIONS = (ROW_X - 5, -41.25)
MARKET_STALL = (ROW_X - 5.5, -12.5)  # stall origin: the deck front is 5.5 ahead
MARKET = (MARKET_STALL[0] + 3.8, -12.5)  # the sign's plane, on the stall's lower roof
MARKET_SIGN_Y = 11.7  # board centre above the floor
INDEX = (ROW_X, 16.25)
SENSEI = (ROW_X, 45)
BEST_ROLL = (-8.5, -75)
GREAT_SAKURA = (80, 118)  # outside the ring, behind the gap between Plots 5 and 6
GROUND_Y = -2  # past the floor edge the terrain top is -1 (TerrainShape.GROUND_TOP): the trunk stands a stud into it
AXIS_LEN = math.hypot(*PAD)
AXIS = (PAD[0] / AXIS_LEN, PAD[1] / AXIS_LEN)
PERP = (AXIS[1], -AXIS[0])  # the side of the path toward Plot 7 is +PERP after the sign below
if PERP[0] * -42 + PERP[1] * 91 < 0:
	PERP = (-PERP[0], -PERP[1])


def rb(x, y, z):
	return Vector((x, -z, y))


def along(t, off=0):
	"""Roblox (x, z) at t studs along the path from the spawn, off studs to the Plot 7 side."""
	return (AXIS[0] * t + PERP[0] * off, AXIS[1] * t + PERP[1] * off)


def place(x, z, y=TOP, face=None):
	"""A matrix whose local -Y (the asset's front) points at Roblox direction face = (x, z)."""
	yaw = 0.0
	if face:
		yaw = math.atan2(face[0], face[1])  # Blender dir (fx, -fz): -Y rotated by yaw = (sin, -cos)
	return Matrix.Translation(rb(x, y, z)) @ Matrix.Rotation(yaw, 4, "Z")


def facing_point(x, z, tx, tz):
	return (tx - x, tz - z)


# --- Materials ---
PAL = {
	"stone": "#CDBB9E", "stone2": "#BFAB8E", "stone3": "#DAC9AD", "pave": "#E4D2B0", "pave2": "#D4C09C", "slab": "#94836A",
	"wood": "#8C5A36", "dark": "#4C3022", "plank": "#A9764A", "verm": "#D2341F", "verm2": "#A92617", "black": "#231F20",
	"tile": "#3B4356", "tile2": "#2C3345", "tileb": "#27427A", "tilet": "#1E5C5C", "tilew": "#59514A", "paper": "#F6ECD2", "tatami": "#CDBE7E",
	"tatami2": "#BDAE6E", "gold": "#E8B23C", "earth": "#7C6448", "grass": "#6F9A4E", "grass2": "#5E8B47", "road": "#B79C72",
	"bloom": "#FFB7D4", "bloom2": "#FF9CC4", "bloom3": "#FFD3E4", "bark": "#4A3026", "pine": "#3F6B45", "pine2": "#355B3D", "mtn": "#7C8CA8",
	"mtn2": "#94A3BC", "ctx": "#9A9AA0", "water": "#4FB3C8", "rope": "#D9C79A", "shutter": "#6B4A32", "bush": "#54853F", "rock": "#868072",
	"blue": "#2F6FE0", "purple": "#7A3FB8", "green": "#2F9E5B", "red": "#D93A2B", "orange": "#F0861E", "teal": "#1F9AA6", "deck": "#2A2C3A",
	"r_common": "#8E9AA8", "r_rare": "#3C8BE0", "r_epic": "#9A4BE0", "r_leg": "#F0B020", "r_myth": "#E8384F", "r_sec": "#F4F4F4",
}
GLOW = {
	"lamp": ("#FFB765", 1.25), "lampw": ("#FFF0D0", 1.0), "neonb": ("#39C8FF", 1.6), "neonw": ("#E8F8FF", 1.4), "neono": ("#FF8A1E", 1.6),
	"pad": ("#E8A53C", 0.75), "up": ("#46BEFF", 1.2), "zone": ("#DC3C28", 1.0), "sb": ("#3C7BFF", 1.5), "sp": ("#A75BFF", 1.5), "sg": ("#3CD07A", 1.5),
	"sr": ("#FF4A3A", 1.5), "so": ("#FF9A2E", 1.5), "st": ("#2EC8D0", 1.5),
}
_mats = {}


def rgb(h):
	def lin(c):
		c /= 255
		return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4

	return tuple(lin(int(h[i : i + 2], 16)) for i in (1, 3, 5)) + (1,)


def mat(name):
	if name in _mats:
		return _mats[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	if name in GLOW:
		col, strength = GLOW[name]
		bsdf.inputs["Base Color"].default_value = rgb(col)
		bsdf.inputs["Emission Color"].default_value = rgb(col)
		bsdf.inputs["Emission Strength"].default_value = strength
	else:
		bsdf.inputs["Base Color"].default_value = rgb(PAL[name])
		bsdf.inputs["Roughness"].default_value = 0.85
	_mats[name] = m
	return m


# --- Mesh builder: everything is hard-faceted, flat colour per face ---
class M:
	def __init__(self, name, matrix=None, kit=None):
		self.name, self.matrix, self.kit = name, matrix or Matrix.Identity(4), kit
		self.v, self.f, self.fm, self.mats = [], [], [], []
		self.local = Matrix.Identity(4)

	def _m(self, name):
		if name not in self.mats:
			self.mats.append(name)
		return self.mats.index(name)

	def face(self, pts, material):
		i = len(self.v)
		self.v.extend(self.local @ Vector(p) for p in pts)
		self.f.append(tuple(range(i, i + len(pts))))
		self.fm.append(self._m(material))

	def box(self, size, c, material, rot=None):
		sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
		r = rot or Matrix.Identity(3)
		cv = Vector(c)
		p = [cv + r @ Vector((a * sx, b * sy, d * sz)) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
		for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
			self.face([p[k] for k in q], material)

	def beam(self, a, b, w, material, sides=4):
		a, b = Vector(a), Vector(b)
		d = (b - a).normalized()
		u = d.orthogonal().normalized()
		v = d.cross(u)
		ring = lambda c: [c + (u * math.cos(k / sides * math.tau + math.pi / sides) + v * math.sin(k / sides * math.tau + math.pi / sides)) * w / 2 for k in range(sides)]
		ra, rb_ = ring(a), ring(b)
		for k in range(sides):
			self.face([ra[k], ra[(k + 1) % sides], rb_[(k + 1) % sides], rb_[k]], material)
		self.face(ra[::-1], material)
		self.face(rb_, material)

	def cyl(self, r, h, c, material, n=8, r2=None):
		cx, cy, cz = c
		r2 = r if r2 is None else r2
		lo = [(cx + r * math.cos(k / n * math.tau), cy + r * math.sin(k / n * math.tau), cz) for k in range(n)]
		hi = [(cx + r2 * math.cos(k / n * math.tau), cy + r2 * math.sin(k / n * math.tau), cz + h) for k in range(n)]
		for k in range(n):
			self.face([lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]], material)
		self.face(lo[::-1], material)
		if r2 > 0:
			self.face(hi, material)

	def hoop(self, r, c, w, material, n=12):
		"""A flat ring standing upright, facing local -Y: r is the mid radius, w the band width and depth."""
		cx, cy, cz = c
		corners = ((r - w / 2, -w / 2), (r + w / 2, -w / 2), (r + w / 2, w / 2), (r - w / 2, w / 2))
		pt = lambda k, q: (cx + q[0] * math.cos(k / n * math.tau), cy + q[1], cz + q[0] * math.sin(k / n * math.tau))
		for k in range(n):
			for i in range(4):
				a, b = corners[i], corners[(i + 1) % 4]
				self.face([pt(k, a), pt(k, b), pt(k + 1, b), pt(k + 1, a)], material)

	def blob(self, r, c, material, squash=0.75, jitter=0.22):
		"""A faceted lump (icosahedron subdivided once)."""
		bm = bmesh.new()
		bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1)
		cv = Vector(c)
		seen = {}
		for vert in bm.verts:
			seen[vert.index] = cv + Vector((vert.co.x * r * (1 + rng.uniform(-jitter, jitter)), vert.co.y * r * (1 + rng.uniform(-jitter, jitter)), vert.co.z * r * squash * (1 + rng.uniform(-jitter, jitter))))
		for fa in bm.faces:
			self.face([seen[vt.index] for vt in fa.verts], material)
		bm.free()

	def roof(self, cx, cy, z, w, d, h, material, ridge=0.45, lift=1.6, trim=None, hip_rings=4):
		"""A hip-and-gable roof with upturned corners and a concave slope."""
		rings, per = 4, 4
		def ring(t):
			f = t ** 0.8
			hw = w / 2 + (w * ridge / 2 - w / 2) * f
			hd = d / 2 + (0.5 - d / 2) * f
			zz = z + h * t**1.5
			pts = []
			for side in range(4):
				for k in range(per):
					s = k / per
					if side == 0:
						x, y = -hw + 2 * hw * s, -hd
					elif side == 1:
						x, y = hw, -hd + 2 * hd * s
					elif side == 2:
						x, y = hw - 2 * hw * s, hd
					else:
						x, y = -hw, hd - 2 * hd * s
					corner = abs(s * 2 - 1) ** 2.5  # 1 at the corners, 0 mid-side
					sag = -0.35 * (1 - corner) * (1 - t)
					pts.append((cx + x, cy + y, zz + corner * lift * (1 - t) ** 2 + sag))
			return pts
		rs = [ring(k / rings) for k in range(rings + 1)]
		n = 4 * per
		for k in range(rings):
			for j in range(n):
				self.face([rs[k][j], rs[k][(j + 1) % n], rs[k + 1][(j + 1) % n], rs[k + 1][j]], material)
		lip = [(p[0], p[1], p[2] - 0.5) for p in rs[0]]
		for j in range(n):
			self.face([lip[j], lip[(j + 1) % n], rs[0][(j + 1) % n], rs[0][j]], trim or "dark")
		self.face(lip[::-1], "dark")
		ridge_w = w * ridge + 0.6
		self.box((ridge_w, 1.0, 0.7), (cx, cy, z + h + 0.15), trim or "black")
		for sx in (-1, 1):
			self.box((0.9, 1.3, 1.5), (cx + sx * ridge_w / 2, cy, z + h + 0.5), trim or "black")
		for j in (0, per, 2 * per, 3 * per):  # corner hips follow the curve
			for k in range(hip_rings):
				a, b = rs[k][j], rs[k + 1][j]
				self.beam((a[0], a[1], a[2] + 0.1), (b[0], b[1], b[2] + 0.1), 0.5, trim or "black")

	def build(self, parent):
		me = bpy.data.meshes.new(self.name)
		me.from_pydata([tuple(p) for p in self.v], [], self.f)
		for n in self.mats:
			me.materials.append(mat(n))
		for i, poly in enumerate(me.polygons):
			poly.material_index = self.fm[i]
		me.update()
		ob = bpy.data.objects.new(self.name, me)
		ob.matrix_world = self.matrix
		parent.objects.link(ob)
		return ob


SHIP = []  # (M, placed in the world?): every mesh that goes in the game
SIGNS = []  # text, Roblox position, face, size


def tris(ob):
	return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# --- Props ---
def hero_torii():
	m = M("HeroTorii", place(PAD[0], PAD[1], TOP, (-AXIS[0], -AXIS[1])))
	h, w = 34, 12  # beam half-width 15.5: clears Track 1's wall (spawn_area_no_track_overlap)
	for s in (-1, 1):
		m.cyl(2.0, h, (s * w, 0, 0), "verm", n=10, r2=1.55)
		m.cyl(2.8, 1.8, (s * w, 0, 0), "black", n=10, r2=2.3)
		m.cyl(2.1, 0.8, (s * w, 0, 5), "black", n=10)
	m.box((w * 2 + 4, 1.6, 2), (0, 0, h - 7), "verm")
	seg = 12
	half = 15.5
	def top(x):
		return h + 0.4 + 2.2 * (abs(x) / half) ** 2.2
	for i in range(seg):
		a, b = -half + 2 * half * i / seg, -half + 2 * half * (i + 1) / seg
		for (x0, x1) in ((a, b),):
			za, zb = top(x0), top(x1)
			for ofs, thick, depth, mt in ((0, 1.7, 3.0, "verm"), (1.7, 1.3, 3.8, "black")):
				p = lambda x, z, y: (x, y, z)
				za0, zb0 = za + ofs, zb + ofs
				d = depth / 2
				m.face([p(x0, za0, -d), p(x1, zb0, -d), p(x1, zb0 + thick, -d), p(x0, za0 + thick, -d)], mt)
				m.face([p(x1, zb0, d), p(x0, za0, d), p(x0, za0 + thick, d), p(x1, zb0 + thick, d)], mt)
				m.face([p(x0, za0 + thick, -d), p(x1, zb0 + thick, -d), p(x1, zb0 + thick, d), p(x0, za0 + thick, d)], mt)
				m.face([p(x0, za0, d), p(x1, zb0, d), p(x1, zb0, -d), p(x0, za0, -d)], mt)
	for s in (-1, 1):  # end caps of the top beam
		z0 = top(s * half)
		xx = s * half
		m.face([(xx, -1.9, z0 + 1.7), (xx, 1.9, z0 + 1.7), (xx, 1.9, z0 + 3), (xx, -1.9, z0 + 3)], "black")
		m.face([(xx, -1.5, z0), (xx, 1.5, z0), (xx, 1.5, z0 + 1.7), (xx, -1.5, z0 + 1.7)], "verm")
	m.box((7, 0.8, 6), (0, 0, h - 3), "black")
	m.box((5.8, 0.9, 4.8), (0, 0, h - 3), "gold")
	# RACE START banner under the tie beam (design doc 4.24 Wayfinding): text is a Sign
	for s in (-1, 1):
		m.box((0.3, 0.3, 2), (s * 8.5, 0, h - 9), "gold")
	m.box((19.5, 0.5, 6), (0, 0, h - 12.4), "gold")
	m.box((18.7, 0.7, 5.2), (0, 0, h - 12.4), "black")
	return m


def market_sign():
	"""A merchant's roof sign: it stands on the stall's lower roof, braced back to the upper storey."""
	m = M("MarketSign", place(MARKET[0], MARKET[1], TOP, ROW_FACE))
	bw, bh = 16, 4.1
	for s in (-1, 1):
		m.box((0.5, 2, 0.5), (s * 5.5, 1, MARKET_SIGN_Y), "dark")
	m.box((bw, 0.5, bh), (0, 0, MARKET_SIGN_Y), "gold")
	m.box((bw - 0.8, 0.7, bh - 0.8), (0, 0, MARKET_SIGN_Y), "purple")
	m.box((bw + 0.8, 1.3, 0.3), (0, 0, MARKET_SIGN_Y + bh / 2 + 0.15), "black")  # a small cap keeps it from reading as a bare panel
	return m


def market_stall():
	"""The row's main building: a two-tier merchant house, open at the front, showing auras and a trail."""
	w, d = 20, 11
	m = M("MarketStall", place(MARKET_STALL[0], MARKET_STALL[1], TOP, ROW_FACE))
	front, back = -d / 2, d / 2
	m.box((w, d, 0.25), (0, 0, 0.125), "dark")
	m.box((w - 0.5, d - 0.5, 0.3), (0, 0, 0.35), "plank")
	post_h = 8.6
	bay = 6.6  # the open centre bay's half width: the prompt faces it
	for x in (-(w / 2 - 0.5), -bay, bay, w / 2 - 0.5):
		m.box((0.9, 0.9, post_h), (x, front + 0.6, post_h / 2 + 0.3), "dark")
		m.box((1.1, 1.1, 0.7), (x, front + 0.6, 0.8), "stone2")
	for sx in (-1, 1):
		m.box((0.9, 0.9, post_h), (sx * (w / 2 - 0.5), back - 0.6, post_h / 2 + 0.3), "dark")
		# The closed rear half of each side: plank skirt, paper above, one rail
		yc, yd = (back - 0.6) / 2, back - 0.6
		m.box((0.5, yd, 3.2), (sx * (w / 2 - 0.5), yc, 2.1), "plank")
		m.box((0.3, yd, 4.8), (sx * (w / 2 - 0.5), yc, 6.1), "paper")
		m.box((0.6, yd, 0.3), (sx * (w / 2 - 0.5), yc, 6.1), "dark")
		# Long curtains close the outer bays and frame the counter
		for k in (-0.5, 0.5):
			m.box((1.2, 0.12, 5.5), (sx * (bay + 1.45 + k * 1.3), front + 0.7, 5.75), "purple")
		m.box((2.5, 0.14, 0.4), (sx * (bay + 1.45), front + 0.7, 3.2), "gold")
		m.cyl(0.55, 1.2, (sx * bay, front + 0.05, 6.2), "lamp", n=6)
	# Back wall: plank and paper outside, purple cloth inside
	m.box((w - 1, 0.5, 3.2), (0, back - 0.6, 2.1), "plank")
	m.box((w - 1, 0.3, 4.8), (0, back - 0.6, 6.1), "paper")
	m.box((w - 1, 0.6, 0.3), (0, back - 0.6, 6.1), "dark")
	for x in (-bay, bay):
		m.box((0.6, 0.7, post_h), (x, back - 0.6, post_h / 2 + 0.3), "dark")
	m.box((w - 2.4, 0.12, 5.6), (0, back - 1.0, 5.2), "purple")
	m.box((w - 2.4, 0.14, 0.3), (0, back - 1.0, 7.9), "gold")
	# Counter, draped in the same cloth
	cw = bay * 2 - 1.2
	cy = front + 1.7
	m.box((cw, 2, 3.6), (0, cy, 2.3), "wood")
	m.box((cw + 0.4, 2.6, 0.35), (0, cy, 4.25), "plank")
	m.box((cw - 0.6, 0.1, 2.3), (0, cy - 1.05, 2.9), "purple")
	m.box((cw - 0.6, 0.12, 0.3), (0, cy - 1.05, 1.9), "gold")
	# Goods: halos stepping down from a tall one, and a trail ribbon falling from its own stand at the counter's far end
	for x, r, glow, stand in ((-3.7, 1.35, "lampw", 0.7), (-0.5, 1.0, "neonb", 0.45), (2.1, 0.72, "neono", 0.3)):
		m.box((0.3, 0.9, stand), (x, cy, 4.42 + stand / 2), "gold")
		m.hoop(r, (x, cy, 4.42 + stand + r), 0.24, glow)
	rx = 4.8
	m.box((0.2, 0.2, 3.3), (rx + 0.6, cy, 6.05), "gold")
	m.box((1.5, 0.2, 0.2), (rx, cy, 7.6), "gold")
	n = 8
	x = lambda t: rx + 0.35 * math.sin(t * math.tau)
	z = lambda t: 7.5 - 2.9 * t
	wd = lambda t: 0.5 - 0.42 * t  # full at the rail, thins to its tail
	for k in range(n):
		a, b = k / n, (k + 1) / n
		glow = "lampw" if k < 3 else "neonb"
		q = [(x(a) - wd(a), cy, z(a)), (x(a) + wd(a), cy, z(a)), (x(b) + wd(b), cy, z(b)), (x(b) - wd(b), cy, z(b))]
		m.face(q[::-1], glow)
		m.face(q, glow)
	# Short valance across the open bay
	m.box((bay * 2 - 0.8, 0.12, 0.7), (0, front + 0.7, 8.2), "purple")
	# Lower roof, upper storey, upper roof
	m.roof(0, 0, 8.9, w + 3.4, d + 3.6, 3.2, "tile", ridge=0.68, lift=1.2, trim="gold", hip_rings=2)
	m.box((18, 6.4, 3.4), (0, 1.2, 11.5), "paper")
	for x in (-9, 0, 9):
		m.box((0.5, 6.6, 3.4), (x, 1.2, 11.5), "dark")
	m.roof(0, 1.2, 12.7, 21, 8.6, 2.05, "tile", ridge=0.58, lift=0.9, trim="gold", hip_rings=2)
	return m


def stone_lantern(x, z, name):
	m = M(name, place(x, z))
	m.cyl(1.2, 0.6, (0, 0, 0), "stone2", n=6)
	m.cyl(0.55, 3.2, (0, 0, 0.6), "stone", n=6, r2=0.45)
	m.cyl(1.05, 0.4, (0, 0, 3.8), "stone2", n=6)
	m.cyl(0.8, 1.2, (0, 0, 4.2), "lamp", n=6)
	m.cyl(1.5, 0.9, (0, 0, 5.4), "stone", n=6, r2=0.3)
	m.cyl(0.3, 0.4, (0, 0, 6.3), "stone2", n=6, r2=0.1)
	return m


def sakura(x, z, r, h, name):
	m = M(name, place(x, z, GROUND_Y))
	fork = h * 0.55
	lean = (rng.uniform(-1, 1) * r * 0.08, rng.uniform(-1, 1) * r * 0.08)
	m.cyl(r * 0.16, h * 0.08, (0, 0, 0), "bark", n=8, r2=r * 0.11)
	m.beam((0, 0, h * 0.06), (lean[0], lean[1], fork), r * 0.19, "bark", 6)
	blobs = max(8, int(r * 1.0))
	for i in range(blobs):
		a = i / blobs * math.tau + rng.uniform(-0.2, 0.2)
		rr = r * rng.uniform(0.3, 0.72)
		tip = (rr * math.cos(a), rr * math.sin(a), h * rng.uniform(0.62, 0.86))
		m.beam((lean[0], lean[1], fork - 0.5), tip, r * 0.07, "bark", 5)
		m.blob(r * rng.uniform(0.34, 0.5), tip, rng.choice(("bloom", "bloom", "bloom2", "bloom3")))
	m.blob(r * 0.6, (0, 0, h * 0.86), "bloom")
	m.blob(r * 0.42, (r * 0.12, -r * 0.1, h * 0.97), "bloom3")
	return m


def stall(x, z, title, cloth, goods):
	m = M(title + "Stall", place(x, z, TOP, ROW_FACE))
	w, d = 14, 10
	m.box((w, d, 0.4), (0, 0, 0.2), "plank")
	m.box((w - 1, 2, 3.6), (0, -d / 2 + 1.5, 2.2), "wood")
	m.box((w - 0.4, 2.6, 0.4), (0, -d / 2 + 1.5, 4.1), "plank")
	m.box((w - 1, 0.5, 8), (0, d / 2 - 0.4, 4.2), "plank")
	for sx in (-1, 1):
		for sy in (-1, 1):
			m.box((0.8, 0.8, 9), (sx * (w / 2 - 0.5), sy * (d / 2 - 0.5), 4.7), "dark")
	m.roof(0, 0, 9.0, w + 3, d + 3.6, 3.8, "tile", ridge=0.55, lift=1.1)
	panels = 5
	for i in range(panels):
		px = -w / 2 + 1.1 + (w - 2.2) * (i + 0.5) / panels
		m.box(((w - 2.6) / panels - 0.12, 0.12, 2.1), (px, -d / 2 + 0.1, 7.7), cloth)
	for sx in (-1, 1):
		m.cyl(0.55, 1.2, (sx * (w / 2 - 0.5), -d / 2 - 0.2, 6.2), "lamp", n=6)
	if goods == "crates":
		for gx, gw, gh, gm in ((-4, 1.8, 1.2, "plank"), (-1.6, 1.4, 1.8, "r_rare"), (0.8, 1.8, 1.0, "gold"), (3.6, 1.6, 1.5, "r_myth")):
			m.box((gw, 1.5, gh), (gx, -d / 2 + 1.5, 4.3 + gh / 2), gm)
	else:
		for i, gm in enumerate(("sg", "so", "sb", "sp", "sg", "so")):
			gx = -4.5 + i * 1.8
			m.cyl(0.5, 0.9, (gx, -d / 2 + 1.5, 4.3), gm, n=6, r2=0.32)
			m.cyl(0.22, 0.5, (gx, -d / 2 + 1.5, 5.2), "plank", n=5)
	m.box((7, 0.4, 2), (0, -d / 2 - 0.6, 11.2), "black")
	return m


def index_board():
	m = M("IndexBoard", place(INDEX[0], INDEX[1], TOP, ROW_FACE))
	for sx in (-1, 1):
		m.cyl(0.8, 13, (sx * 12, 0, 0), "dark", n=6)
		m.box((2, 2, 0.8), (sx * 12, 0, 0.4), "stone")
	m.box((23, 0.6, 9.4), (0, 0, 7.2), "wood")
	m.box((22, 0.7, 8.6), (0, 0, 7.2), "paper")
	colours = ["r_common", "r_rare", "r_epic", "r_leg", "r_myth", "r_sec"]
	for i in range(8):
		for j in range(3):
			m.box((2, 0.8, 2.1), (-8.4 + i * 2.4, 0, 4.1 + j * 2.5), colours[(i * 3 + j * 5) % 6])
	m.roof(0, 0, 12.2, 27, 5.5, 2.8, "tile", ridge=0.62, lift=1.0)
	return m


def pedestal(i, x, z, glow, look=None):
	m = M(f"LegendPedestal_{i}", place(x, z, TOP, facing_point(x, z, *(look or LEGEND_LOOK))))
	m.cyl(3.8, 0.8, (0, 0, 0), "slab", n=8)
	m.cyl(3.2, 1.0, (0, 0, 0.8), "stone", n=8)
	m.cyl(3.5, 0.3, (0, 0, 1.8), glow, n=8)
	m.cyl(3.2, 0.5, (0, 0, 2.1), "stone3", n=8)
	return m


def mosaic():
	m = M("SpawnMosaic", place(0, 0, TOP + 0.1))
	n = 32
	bands = (
		(0, 8.5, ("pave", "pave2")),
		(8.5, 9.2, ("gold", "gold")),
		(9.2, 13.5, ("stone3", "slab")),
		(13.5, 14.1, ("neonb", "neono")),
		(14.1, 19, ("pave2", "stone2")),
		(19, 19.7, ("gold", "gold")),
	)
	for r0, r1, cols in bands:
		for k in range(n):
			a0, a1 = k / n * math.tau, (k + 1) / n * math.tau
			if cols[0] == "neonb":
				col = "neonb" if math.cos((a0 + a1) / 2 - 2.37) > 0 else "neono"  # blue toward the gate, as the logo
			else:
				col = cols[k % 2]
			p = [(r0 * math.cos(a0), r0 * math.sin(a0), 0), (r1 * math.cos(a0), r1 * math.sin(a0), 0), (r1 * math.cos(a1), r1 * math.sin(a1), 0), (r0 * math.cos(a1), r0 * math.sin(a1), 0)]
			if r0 == 0:
				m.face([p[0], p[1], p[2]], col)
			else:
				m.face(p, col)
	return m


def floor():
	m = M("PlazaFloor", place(0, 0, TOP))
	size = 4
	for ix in range(-24, 24):
		for iz in range(-28, 28):
			x0, z0 = ix * size, iz * size
			x1, z1 = max(min(x0 + size, 94), -94), max(min(z0 + size, 110), -110)
			x0, z0 = max(x0, -94), max(z0, -110)
			if x1 <= x0 or z1 <= z0:
				continue
			m.face([(x0, -z1, 0), (x1, -z1, 0), (x1, -z0, 0), (x0, -z0, 0)], rng.choice(("stone", "stone", "stone2", "stone3")))
	return m


def path():
	m = M("MainPath", place(0, 0, TOP + 0.08))
	stones = 20
	t0, t1 = 20, AXIS_LEN - 7
	step = (t1 - t0) / stones
	for i in range(stones):
		a = t0 + i * step + 0.2
		b = t0 + (i + 1) * step - 0.2
		col = "pave" if i % 2 == 0 else "pave2"
		q = []
		for t, off in ((a, -6), (a, 6), (b, 6), (b, -6)):
			x, z = along(t, off)
			q.append((x, -z, 0))
		n = (Vector(q[1]) - Vector(q[0])).cross(Vector(q[2]) - Vector(q[1]))
		m.face(q if n.z > 0 else q[::-1], col)
		for off0, off1, c2 in ((-7.2, -6, "slab"), (6, 7.2, "slab")):
			q = []
			for t, off in ((a, off0), (a, off1), (b, off1), (b, off0)):
				x, z = along(t, off)
				q.append((x, -z, 0))
			n = (Vector(q[1]) - Vector(q[0])).cross(Vector(q[2]) - Vector(q[1]))
			m.face(q if n.z > 0 else q[::-1], c2)
	return m


def sky_loop():
	m = M("SkyLoop", place(0, 0, 0))
	r, h, w, n = 62, LOOP_H, 5, 72
	def col(a):
		s = (math.cos(a - math.radians(137)) + 1) / 2  # blue on the gate side, orange opposite (logo colours)
		return "neonb" if s > 0.62 else ("neonw" if s > 0.38 else "neono")
	for k in range(n):
		a0, a1 = k / n * math.tau, (k + 1) / n * math.tau
		pt = lambda a, rr, z: (rr * math.cos(a), -rr * math.sin(a), z)
		ri, ro = r - w / 2, r + w / 2
		m.face([pt(a0, ri, h), pt(a0, ro, h), pt(a1, ro, h), pt(a1, ri, h)][::-1], "deck")
		m.face([pt(a0, ri, h - 0.45), pt(a0, ro, h - 0.45), pt(a1, ro, h - 0.45), pt(a1, ri, h - 0.45)], "deck")
		m.face([pt(a0, ro, h - 0.45), pt(a0, ro, h), pt(a1, ro, h), pt(a1, ro, h - 0.45)][::-1], col((a0 + a1) / 2))
		m.face([pt(a0, ri, h - 0.45), pt(a0, ri, h), pt(a1, ri, h), pt(a1, ri, h - 0.45)], col((a0 + a1) / 2))
		for rr in (ri + 0.2, ro - 0.2):  # glowing rails
			m.face([pt(a0, rr - 0.25, h + 0.04), pt(a0, rr + 0.25, h + 0.04), pt(a1, rr + 0.25, h + 0.04), pt(a1, rr - 0.25, h + 0.04)][::-1], col((a0 + a1) / 2))
	for deg in (45, 100, 200, 250, 315):  # 200, not 190: clear of the MARKET sign seen from the spawn
		a = math.radians(deg)
		x, z = r * math.cos(a), r * math.sin(a)
		pos = rb(x, TOP, z)
		m.cyl(1.2, h - TOP - 0.7, tuple(pos), "verm", n=8, r2=0.95)
		m.cyl(1.7, 0.9, tuple(pos), "black", n=8)
		m.cyl(0.95, 2.6, (pos.x, pos.y, h - 3.05), "verm2", n=8, r2=2.6)
	# The arch over the path: two posts and a beam, the ribbon rests on it
	mid = 62
	ends = []
	for s in (-1, 1):
		x, z = along(mid, s * 10.5)
		pos = rb(x, TOP, z)
		ends.append(pos)
		m.cyl(1.2, h - TOP - 0.7, tuple(pos), "verm", n=8, r2=0.95)
		m.cyl(1.7, 0.9, tuple(pos), "black", n=8)
	m.beam((ends[0].x, ends[0].y, h - 1.2), (ends[1].x, ends[1].y, h - 1.2), 1.1, "verm2", 4)
	m.beam((ends[0].x, ends[0].y, h - 4.4), (ends[1].x, ends[1].y, h - 4.4), 0.6, "verm", 4)
	return m


def trails(runner_degs):
	m = M("RunnerTrails")
	r, h = 62, LOOP_H + 0.6
	for deg, col, off in runner_degs:
		for k in range(14):
			a0 = math.radians(deg + 2 + k * 3)  # trail behind a runner going in decreasing angle
			a1 = math.radians(deg + 2 + (k + 1) * 3)
			wd = 0.42 * (1 - k / 14) + 0.03
			z0, z1 = h + 1.6 + off * 0.5, h + 1.6 + off * 0.5
			pt = lambda a, rr, z: (rr * math.cos(a), -rr * math.sin(a), z)
			m.face([pt(a0, r, z0 - wd), pt(a1, r, z1 - wd), pt(a1, r, z1 + wd), pt(a0, r, z0 + wd)], col)
			m.face([pt(a0, r, z0 + wd), pt(a1, r, z1 + wd), pt(a1, r, z1 - wd), pt(a0, r, z0 - wd)], col)
	return m


# --- Dojo kit ---
ROOF_BY_LEVEL = {0: "tilew", 1: "tile", 4: "tileb", 7: "tilet", 10: "tile2"}


def dojo(plot_c, front, level, name, stat="lamp"):
	"""level 0 = a free plot's closed shell; 1, 4, 7, 10 = the owned tiers. Local -Y = open front (hub side)."""
	m = M(name, place(plot_c[0], plot_c[1], TOP, front))
	half = 18
	gold = level >= 7
	beam = "dark"
	m.box((48, 48, 0.2), (0, 0, 0.0), "earth")
	# Front path to the hub edge
	for i in range(3):
		m.box((7.5, 1.6, 0.1), (0, -24 + 1 + i * 2.1, 0.13), "pave")
	if level == 0:
		m.box((36, 36, 0.3), (0, 0, 0.15), "wood")
	else:
		m.box((36, 36, 0.3), (0, 0, 0.15), "tatami")
		for ix in range(4):  # tatami mats
			for iy in range(4):
				if (ix + iy) % 2 == 0:
					m.box((8.6, 8.6, 0.05), (-13.5 + ix * 9, -13.5 + iy * 9, 0.32), "tatami2")
	wh = 12.2
	# Walls: plaster skirt, paper panels, post and beam (back and sides; the front stays open)
	for side, (cx, cy, sx, sy) in {"back": (0, half - 0.5, 36, 1), "left": (-half + 0.5, 0, 1, 36), "right": (half - 0.5, 0, 1, 36)}.items():
		m.box((sx, sy, 2.4), (cx, cy, 1.5), "dark" if level == 0 else "plank")
		m.box((sx * 0.98 if sx > 1 else 0.6, sy * 0.98 if sy > 1 else 0.6, wh - 2.8), (cx, cy, 2.7 + (wh - 2.8) / 2), "shutter" if level == 0 else "paper")
	for x in (-18, -12, -6, 0, 6, 12, 18):
		m.box((0.9, 1.1, wh), (x * 0.97, half - 0.5, wh / 2 + 0.2), beam)
		m.box((1.1, 0.9, wh), (-half + 0.5, x * 0.97, wh / 2 + 0.2), beam)
		m.box((1.1, 0.9, wh), (half - 0.5, x * 0.97, wh / 2 + 0.2), beam)
	for z in (4.5, 7.5):  # shoji rails
		m.box((35, 1.15, 0.25), (0, half - 0.5, z), beam)
		m.box((1.15, 35, 0.25), (-half + 0.5, 0, z), beam)
		m.box((1.15, 35, 0.25), (half - 0.5, 0, z), beam)
	for s in (-1, 1):  # front posts
		m.box((1.4, 1.4, wh), (s * (half - 0.5), -half + 0.6, wh / 2 + 0.2), "verm" if level >= 4 else beam)
	m.box((36, 1.3, 1.2), (0, -half + 0.6, wh - 0.3), "verm" if level >= 4 else beam)
	if level == 0:
		for i in range(6):  # closed sliding shutters
			x = -15 + i * 6
			m.box((5.8, 0.6, wh - 2.4), (x, -half + 0.8, (wh - 2.4) / 2 + 0.3), "shutter")
			m.box((0.25, 0.7, wh - 2.4), (x + 2.9, -half + 0.8, (wh - 2.4) / 2 + 0.3), "dark")
			for z in (3, 6.5):
				m.box((5.6, 0.7, 0.25), (x, -half + 0.8, z), "dark")
		m.box((8, 0.3, 2.6), (0, -half - 0.1, 8.6), "paper")  # the FREE DOJO sign board
		m.box((8.6, 0.25, 3.2), (0, -half + 0.05, 8.6), "dark")
	else:
		# Showcase pedestals and upgrade pad stay where the game has them (WorkshopConfig.SHOWCASE_Z)
		for x in (-10, 0, 10):
			m.box((7, 9, 0.3), (x, 11, 0.45), "dark")  # top 0.6, as WorkshopBuilder's showcase pedestal: rigs stand on it
			m.box((6.2, 8.2, 0.02), (x, 11, 0.6), "verm2" if level >= 4 else "plank")
		m.box((10, 6, 0.25), (0, -21, 0.2), "up")
		# Zone outline
		for (sx, sy, cx, cy) in ((32, 0.3, 0, -16), (32, 0.3, 0, 16), (0.3, 32, -16, 0), (0.3, 32, 16, 0)):
			m.box((sx, sy, 0.05), (cx, cy, 0.36), "zone")
		# Training dummies
		for s in (-1, 1):
			px, py = s * 12, -6
			m.cyl(0.55, 5.4, (px, py, 0.3), "wood", n=6)
			m.box((3.4, 0.5, 0.5), (px, py, 4.0), "plank")
			m.box((2.2, 0.5, 0.5), (px, py, 2.6), "plank")
			m.cyl(0.8, 1.2, (px, py, 5.6), "rope", n=6)
		# Weapon rack on the back wall
		m.box((8, 0.4, 0.4), (0, half - 1.4, 7.8), "dark")
		for x in (-3, -1, 1, 3):
			m.beam((x, half - 1.4, 2.8), (x + 0.2, half - 1.6, 9.2), 0.2, "plank", 4)
		# Entrance lanterns take the colour of the chosen stat
		for s in (-1, 1):
			m.cyl(0.8, 1.7, (s * 10, -half + 0.2, 8.6), stat, n=6)
			m.box((0.12, 0.12, 1.8), (s * 10, -half + 0.2, 11.2), "dark")
		m.box((16, 0.3, 2.2), (0, -half + 0.1, 10.0), "black")  # lintel banner for the owner's name
	# Roof tiers
	base = wh + 0.1
	r0 = ROOF_BY_LEVEL[level]
	trim = "gold" if gold else None
	m.box((37, 37, 0.7), (0, 0, base + 0.2), beam)
	m.roof(0, 0, base + 0.5, 43, 43, 8.5, r0, ridge=0.42, lift=2.4, trim=trim)
	if level >= 4:
		# A second tier
		m.box((18, 18, 2.6), (0, 0, base + 8.6), "verm2" if level >= 7 else beam)
		m.roof(0, 0, base + 9.8, 25, 25, 5.5, r0, ridge=0.3, lift=1.7, trim=trim)
		for sx in (-1, 1):  # side banners
			m.cyl(0.2, 15, (sx * 23, -21, 0.1), "dark", n=5)
			m.box((2.6, 0.12, 8.5), (sx * 21.5, -21, 10.2), "verm")
			m.box((2.8, 0.2, 0.25), (sx * 21.5, -21, 14.4), "dark")
	if level >= 7:
		m.box((12, 12, 2.4), (0, 0, base + 15.2), "gold")
		m.roof(0, 0, base + 16.2, 17, 17, 4.5, r0, ridge=0.2, lift=1.3, trim="gold")
		for sx, sy in ((-21, 21), (21, 21)):  # back corner bushes and rocks
			m.blob(2.2, (sx, sy, 1.2), "bush")
			m.blob(1.2, (sx + 1.2, sy - 2, 0.7), "rock")
		for s in (-1, 1):  # front stone lanterns
			x = s * 21
			m.cyl(0.9, 0.5, (x, -14, 0.1), "stone2", n=6)
			m.cyl(0.4, 2.6, (x, -14, 0.6), "stone", n=6)
			m.cyl(0.6, 0.9, (x, -14, 3.2), stat, n=6)
			m.cyl(1.1, 0.7, (x, -14, 4.1), "stone", n=6, r2=0.2)
	if level >= 10:
		m.box((8, 8, 2.2), (0, 0, base + 20.6), "verm")
		m.roof(0, 0, base + 21.6, 12, 12, 4, r0, ridge=0.12, lift=1.1, trim="gold")
		m.cyl(0.5, 5.5, (0, 0, base + 25.3), "gold", n=8, r2=0.05)  # finial
		for k in range(3):
			m.cyl(0.9 - k * 0.2, 0.3, (0, 0, base + 26 + k * 1.2), "gold", n=8)
		# Koi pond in the front corners
		for s in (-1, 1):
			m.box((13, 4.6, 0.12), (s * 14, -21.2, 0.18), "water")
			m.box((14, 5.6, 0.12), (s * 14, -21.2, 0.12), "stone")
			for k in range(3):
				m.box((0.9, 0.35, 0.05), (s * (11 + k * 3), -21 + (k % 2), 0.26), "orange" if k != 1 else "paper")
		m.blob(2.6, (21, 21, 1.5), "bloom")
		m.blob(2.6, (-21, 21, 1.5), "bloom")
	return m


# --- Context: not part of the asset list ---
def context(col):
	g = M("Ctx_Ground", place(0, 0, 0))
	g.face([(-1500, -1500, -0.02), (1500, -1500, -0.02), (1500, 1500, -0.02), (-1500, 1500, -0.02)], "grass")
	g.build(col)
	r = M("Ctx_Roads")
	segs = [((-118, 80), (-118, -130)), ((-125, -200), (130, -200)), ((210, -130), (210, 140)), ((140, 210), (60, 210)), ((-90, 210), (-190, 210)), ((-268, 130), (-268, -230))]
	for a, b in segs:
		pa, pb = rb(a[0], TOP - 0.5, a[1]), rb(b[0], TOP - 0.5, b[1])
		mid = (pa + pb) / 2
		l = (pb - pa).length
		rot = Matrix.Rotation(math.atan2((pb - pa).y, (pb - pa).x), 3, "Z")
		r.box((l, 40, 1), tuple(mid), "road", rot)
	r.build(col)
	c = M("Ctx_Backdrop")
	for _ in range(420):  # the track's forest beyond the plaza
		a = rng.uniform(0, math.tau)
		dist = rng.uniform(150, 560)
		x, z = dist * math.cos(a), dist * math.sin(a)
		onroad = any(abs((pb[0] - pa[0]) * (z - pa[1]) - (pb[1] - pa[1]) * (x - pa[0])) / math.hypot(pb[0] - pa[0], pb[1] - pa[1]) < 28 for pa, pb in segs)
		if onroad or (abs(x) < 145 and abs(z) < 145):
			continue
		p = rb(x, 0, z)
		h = rng.uniform(24, 46)
		w = h * 0.26
		c.cyl(w * 0.2, h * 0.2, tuple(p), "bark", n=5)
		pm = rng.choice(("pine", "pine2"))
		for tier in range(3):
			c.cyl(w * (1 - tier * 0.24), h * 0.46, (p.x, p.y, p.z + h * (0.14 + tier * 0.27)), pm, n=6, r2=0)
	for k in range(26):  # far mountains
		a = k / 26 * math.tau + rng.uniform(-0.1, 0.1)
		d = rng.uniform(900, 1250)
		p = rb(d * math.cos(a), 0, d * math.sin(a))
		h = rng.uniform(110, 210)
		c.cyl(h * 0.95, h, tuple(p), rng.choice(("mtn", "mtn2")), n=7, r2=h * 0.06)
	c.build(col)
	k = M("Ctx_Kept")  # what stays: the Best Roll pedestal
	k.cyl(9, 2, tuple(rb(BEST_ROLL[0], TOP, BEST_ROLL[1])), "ctx", n=16)
	k.box((16, 16, 0.4), tuple(rb(PAD[0], TOP + 0.2, PAD[1])), "pad")
	k.box((12, 12, 0.1), tuple(rb(0, TOP + 0.06, 0)), "slab")
	k.build(col)
	s = M("Sensei_Dais", place(SENSEI[0], SENSEI[1]))
	s.cyl(4, 0.6, (0, 0, 0), "stone", n=8)
	s.build(col)


def petals(col):
	m = M("Ctx_Petals")
	def petal(p, size):
		a = rng.uniform(0, math.tau)
		u = Vector((math.cos(a), math.sin(a), rng.uniform(-0.6, 0.6))).normalized()
		v = u.orthogonal().normalized()
		pv = Vector(p)
		m.face([pv + u * size, pv + v * size * 0.55, pv - u * size * 0.4], rng.choice(("bloom", "bloom3")))
		m.face([pv - u * size * 0.4, pv + v * size * 0.55, pv + u * size], rng.choice(("bloom", "bloom3")))
	for _ in range(1100):  # in the air
		x, z = rng.uniform(-96, 96), rng.uniform(-110, 110)
		if math.hypot(x - along(-12)[0], z - along(-12)[1]) < 30:
			continue
		p = rb(x, rng.uniform(1.5, 34), z)
		petal(p, rng.uniform(0.2, 0.36))
	for cx, cz, r in ((GREAT_SAKURA[0], GREAT_SAKURA[1], 26),):
		for _ in range(150):
			a, d = rng.uniform(0, math.tau), r * math.sqrt(rng.random())
			p = rb(cx + d * math.cos(a), TOP + 0.06, cz + d * math.sin(a))
			m.face([tuple(p), (p.x + 0.45, p.y + 0.1, p.z), (p.x + 0.1, p.y + 0.4, p.z)], rng.choice(("bloom", "bloom3", "bloom2")))
	m.build(col)


# --- Characters: real models from assets/characters_avatar, as collection instances ---
_chars = {}


def char_collection(cid, height):
	key = cid
	if key not in _chars:
		path_ = os.path.join(CHARS, cid, cid + ".blend")
		cc = bpy.data.collections.new("Char_" + cid)
		with bpy.data.libraries.load(path_) as (src, dst):
			dst.objects = list(src.objects)
		obs = [o for o in dst.objects if o is not None and o.type in ("MESH", "EMPTY")]
		for o in obs:
			cc.objects.link(o)
		bpy.context.scene.collection.children.link(cc)
		bpy.context.view_layer.update()
		lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
		for o in obs:
			if o.type == "MESH":
				for c in o.bound_box:
					w = o.matrix_world @ Vector(c)
					lo = Vector(map(min, lo, w))
					hi = Vector(map(max, hi, w))
		bpy.context.scene.collection.children.unlink(cc)
		_chars[key] = (cc, lo, hi)
	cc, lo, hi = _chars[key]
	return cc, lo, hi


def put_char(col, cid, x, y, z, face, height, name):
	cc, lo, hi = char_collection(cid, height)
	s = height / (hi.z - lo.z)
	e = bpy.data.objects.new(name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = cc
	yaw = math.atan2(face[0], face[1])
	foot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	e.matrix_world = Matrix.Translation(rb(x, y, z)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation(-foot)
	col.objects.link(e)
	return e


def add_text(col, text, matrix, size, material, name):
	if not name.startswith("Sign_Plot"):
		p = matrix.translation
		front = matrix.to_3x3() @ Vector((0, -1, 0))
		SIGNS.append({"Text": text, "Pos": [p.x, p.z, -p.y], "Face": [front.x, -front.y], "Size": size, "Color": PAL[material]})
	cu = bpy.data.curves.new(name, "FONT")
	cu.body = text
	cu.size = size
	cu.align_x = "CENTER"
	cu.align_y = "CENTER"
	cu.extrude = 0.05
	cu.materials.append(mat(material))
	ob = bpy.data.objects.new(name, cu)
	ob.matrix_world = matrix @ Matrix.Rotation(math.pi / 2, 4, "X")
	col.objects.link(ob)


# --- Scene ---
def setup_world(scene):
	for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
		try:
			scene.render.engine = eng
			break
		except TypeError:
			pass
	scene.render.resolution_x, scene.render.resolution_y = 1600, 900
	scene.render.image_settings.file_format = "JPEG"
	scene.render.image_settings.quality = 90
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("GoldenHour")
	world.use_nodes = True
	nt = world.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
	cr = ramp.color_ramp
	cr.elements[0].position, cr.elements[0].color = 0.0, rgb("#FFD9A8")
	cr.elements[1].position, cr.elements[1].color = 0.6, rgb("#86A6DC")
	mid = cr.elements.new(0.1)
	mid.color = rgb("#FFC890")
	mid2 = cr.elements.new(0.28)
	mid2.color = rgb("#F4BFA6")
	nt.links.new(ramp.outputs[0], bg.inputs["Color"])
	bg.inputs["Strength"].default_value = 1.0
	scene.world = world
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 3.4
	sun.data.color = (1.0, 0.82, 0.62)
	sun.data.angle = math.radians(4)
	# Low sun from behind the spawn, so the gate side is lit toward the player's view
	sun.rotation_euler = (math.radians(62), 0, math.radians(-62))
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.sensor_fit = "VERTICAL"
	cam.data.angle_y = math.radians(70)  # Roblox default field of view
	cam.data.clip_end = 6000
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def shoot(cam, eye, look, name, fov=70):
	e, l = rb(*eye), rb(*look)
	cam.location = e
	cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(fov)
	bpy.context.scene.render.filepath = os.path.join(OUT, name + ".jpg")
	bpy.ops.render.render(write_still=True)
	print("SHOT", name)


LEGENDS = [  # one each side of the gate (x, z), glow ring in a logo colour
	("db_hero", -71.5, 94, "so"),
	("mha_symbol", -89.5, 61.5, "sb"),
]
# The Robux-exclusive runner's pedestal (design doc 4.35), not a Legend: in the gap between Plots 6 and 7 as seen from the
# spawn, so every Dojo stays visible (4.24 Clear plaza), facing the spawn. Position proposed.
EXCLUSIVE = ("punch_hero", -4.5, 36, "so")
LEGEND_LOOK = along(75)  # both turn toward a player coming up the path
LEGEND_H = 9.0  # studs; about 1.6x a runner (proposed)
RUNNER_H = 5.6


def build(scene):
	world = bpy.data.collections.new("Plaza")
	ctx = bpy.data.collections.new("Context")
	line = bpy.data.collections.new("DojoLineup")
	for c in (world, ctx, line):
		scene.collection.children.link(c)
	context(ctx)
	petals(ctx)
	obs = []
	def add(m, ship=True):
		obs.append(m.build(world))
		if ship:
			SHIP.append((m, True))
	add(floor(), False)
	add(path())
	add(mosaic())
	add(hero_torii())
	add(market_sign())
	# t 87 not 92: on the Plot 7 side, t 88 to 99 stands on the plot's corner
	for i, t in enumerate((87, 100)):
		for s in (-1, 1):
			x, z = along(t, s * 8.6)
			add(stone_lantern(x, z, f"Lantern_{i}_{s}"))
	add(sakura(GREAT_SAKURA[0], GREAT_SAKURA[1], 20, 44, "GreatSakura"))
	add(stall(SHOP[0], SHOP[1], "SHOP", "blue", "crates"))
	add(stall(POTIONS[0], POTIONS[1], "POTIONS", "purple", "bottles"))
	add(market_stall())
	add(index_board())
	add(sky_loop())
	for i, (cid, x, z, glow) in enumerate(LEGENDS):
		add(pedestal(i, x, z, glow))
		put_char(world, cid, x, TOP + 2.6, z, facing_point(x, z, *LEGEND_LOOK), LEGEND_H, "Legend_" + cid)
	cid, x, z, glow = EXCLUSIVE
	add(pedestal(len(LEGENDS), x, z, glow, look=SPAWN))
	put_char(world, cid, x, TOP + 2.6, z, facing_point(x, z, *SPAWN), LEGEND_H, "Exclusive_" + cid)
	# Sky-loop runners: the 3 starters' models, racing with blue and orange trails
	runners = [(205, "neonb", 0, "leaf_hero"), (20, "neono", 1, "sea_captain"), (95, "neonb", 0, "db_hero")]
	add(trails([(d, c, o) for d, c, o, _ in runners]), False)
	for deg, _, _, cid in runners:
		a = math.radians(deg)
		x, z = 62 * math.cos(a), 62 * math.sin(a)
		# tangent, running toward decreasing angle
		put_char(world, cid, x, LOOP_H + 0.05, z, (math.sin(a), -math.cos(a)), RUNNER_H, f"Runner_{cid}")
	# Sensei stand-in
	put_char(ctx, "leaf_copycat", SENSEI[0], TOP + 0.6, SENSEI[1], ROW_FACE, 5.8, "Ctx_Sensei")
	# The Dojo ring as a new player sees it: their own level 1, the rest free
	for i, (c, f) in PLOTS.items():
		level = 1 if i == 1 else 0
		add(dojo(c, f, level, f"Dojo_Plot{i}_L{level}"), False)
		if level == 0:
			mx = place(c[0], c[1], TOP, f) @ Matrix.Translation((0, -18.3, 8.6))
			add_text(world, "FREE DOJO", mx, 0.95, "dark", f"Sign_Plot{i}")
	# Signs
	for txt, (x, z), w in (("SHOP", SHOP, 1.6), ("POTIONS", POTIONS, 1.25)):
		mx = place(x, z, TOP, ROW_FACE) @ Matrix.Translation((0, -5.85, 11.2))
		add_text(world, txt, mx, w, "paper", "Sign_" + txt)
	mx = place(INDEX[0], INDEX[1], TOP, ROW_FACE) @ Matrix.Translation((0, -0.45, 10.6))
	add_text(world, "RUNNER INDEX", mx, 0.85, "verm2", "Sign_Index")
	# Wayfinding: the bold signs on the two landmarks
	mx = place(PAD[0], PAD[1], TOP, (-AXIS[0], -AXIS[1])) @ Matrix.Translation((0, -0.45, 21.6))
	add_text(world, "RACE START", mx, 2.4, "gold", "Sign_RaceStart")
	mx = place(MARKET[0], MARKET[1], TOP, ROW_FACE) @ Matrix.Translation((0, -0.45, MARKET_SIGN_Y))
	add_text(world, "MARKET", mx, 3.0, "gold", "Sign_Market")
	# Tier lineup, far from the plaza
	lx, lz = 1600, 0
	lg = M("Ctx_LineupGround", place(lx, lz, TOP - 0.05))
	lg.box((1000, 700, 0.1), (0, 0, 0), "grass2")
	lg.build(ctx)
	# The L7 and L10 kits' bushes draw from rng: replay where it stood before them, so their meshes and hashes stay
	rng.seed(11)
	burn = M("Burn")
	burn.blob(1, (0, 0, 0), "bush")
	for _ in range(6):
		rng.uniform(-0.3, 0.3)
		rng.uniform(-0.3, 0.5)
		rng.choice(("bloom", "bloom2", "bloom3"))
		burn.blob(1, (0, 0, 0), "bloom")
	for i, level in enumerate((0, 1, 4, 7, 10)):
		kit = dojo((lx - 120 + i * 60, lz), (0, 1), level, f"DojoKit_L{level}")
		kit.build(line)
		SHIP.append((kit, False))
	for cid, x in (("leaf_hero", -10), ("sea_captain", 0), ("db_hero", 10)):
		put_char(line, cid, lx + 120 + x, TOP + 0.9, lz - 11, (0, 1), RUNNER_H, f"Squad_{cid}")
	print("TRIS")
	total = 0
	for ob in list(world.objects) + list(line.objects):
		if ob.type == "MESH":
			n = tris(ob)
			total += n
			print(f"  {ob.name}: {n}")
	print("  total", total)


# --- Export: one GLB per unique mesh, named parts Body (palette texture) and Glow_<name> (Neon in game) ---
CELLS, CELL_PX = 8, 16


def palette():
	import numpy as np

	names = sorted(PAL)
	assert len(names) <= CELLS * CELLS
	size = CELLS * CELL_PX
	img = bpy.data.images.new("PlazaPalette", size, size, alpha=False)
	px = np.ones((size, size, 4), dtype=np.float32)
	for i, n in enumerate(names):
		cy, cx = divmod(i, CELLS)
		h = PAL[n]
		col = [int(h[k : k + 2], 16) / 255 for k in (1, 3, 5)]
		px[cy * CELL_PX : (cy + 1) * CELL_PX, cx * CELL_PX : (cx + 1) * CELL_PX, :3] = col
	img.pixels.foreach_set(px.ravel())
	img.pack()
	m = bpy.data.materials.new("PlazaPalette")
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	tex = m.node_tree.nodes.new("ShaderNodeTexImage")
	tex.image = img
	tex.interpolation = "Closest"
	m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	return m, {n: ((i % CELLS + 0.5) / CELLS, (i // CELLS + 0.5) / CELLS) for i, n in enumerate(names)}


def geometry_hash(m):
	h = hashlib.sha1()
	for p in m.v:
		h.update(b"%.3f,%.3f,%.3f;" % (p.x, p.y, p.z))
	h.update(repr(m.f).encode())
	h.update(repr([m.mats[i] for i in m.fm]).encode())
	return h.hexdigest()[:16]


def export_asset(m, key, pal_mat, cells, out):
	groups = {}
	for face, fm in zip(m.f, m.fm):
		name = m.mats[fm]
		groups.setdefault(("Glow_" + name) if name in GLOW else "Body", []).append((face, name))
	obs, parts = [], {}
	for part, faces in groups.items():
		verts, polys, uvs = [], [], []
		for face, name in faces:
			i = len(verts)
			verts.extend(tuple(m.v[k]) for k in face)
			polys.append(tuple(range(i, i + len(face))))
			uvs.extend([cells.get(name, (0.5, 0.5))] * len(face))
		me = bpy.data.meshes.new(part)
		me.from_pydata(verts, [], polys)
		if part == "Body":
			layer = me.uv_layers.new(name="UVMap")
			for k, uv in enumerate(uvs):
				layer.data[k].uv = uv
			me.materials.append(pal_mat)
		me.update()
		ob = bpy.data.objects.new(part, me)
		bpy.context.scene.collection.objects.link(ob)
		obs.append(ob)
		xs, ys, zs = zip(*verts)
		lo, hi = Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))
		size, c = hi - lo, (hi + lo) / 2
		parts[part] = {"Size": [max(size.x, 0.05), max(size.z, 0.05), max(size.y, 0.05)], "Center": [c.x, c.z, -c.y], "Tris": sum(len(p) - 2 for p in polys)}
		if part != "Body":
			parts[part]["Glow"] = GLOW[part[5:]][0]
	bpy.ops.object.select_all(action="DESELECT")
	for ob in obs:
		ob.select_set(True)
	bpy.ops.export_scene.gltf(filepath=os.path.join(out, key + ".glb"), export_format="GLB", export_yup=True, use_selection=True, export_apply=True, export_animations=False)
	for ob in obs:
		me = ob.data
		bpy.data.objects.remove(ob)
		bpy.data.meshes.remove(me)
	return parts


def export_all():
	out = os.path.join(ROOT, "build", "plaza", "glb")
	os.makedirs(out, exist_ok=True)
	pal_mat, cells = palette()
	seen, assets, placed, tiers = {}, {}, [], {}
	for m, is_placed in SHIP:
		h = geometry_hash(m)
		if h not in seen:
			key = re.sub(r"(_-?\d+)+$", "", m.name)
			while key in assets:
				key += "x"
			seen[h] = key
			assets[key] = {"Hash": h, "Parts": export_asset(m, key, pal_mat, cells, out)}
		key = seen[h]
		tier = re.match(r"DojoKit_L(\d+)", m.name)
		if tier:
			tiers[tier.group(1)] = key
		else:
			p = m.matrix.translation
			front = m.matrix.to_3x3() @ Vector((0, -1, 0))
			placed.append({"Key": key, "Pos": [p.x, p.z, -p.y], "Face": [front.x, -front.y]})
	legends = []
	for cid, x, z, _ in LEGENDS:
		legends.append({"Id": cid, "Pos": [x, TOP + 2.6, z], "Face": list(facing_point(x, z, *LEGEND_LOOK))})
	cid, x, z, _ = EXCLUSIVE
	exclusive = {"Id": cid, "Pos": [x, TOP + 2.6, z], "Face": list(facing_point(x, z, *SPAWN))}
	layout = {"Assets": assets, "Placed": placed, "Tiers": tiers, "Legends": legends, "Exclusive": exclusive, "Signs": SIGNS, "LoopRadius": 62, "LoopHeight": LOOP_H, "Landmarks": {"RaceStart": [PAD[0], 60, PAD[1]], "Market": [MARKET_STALL[0], 50, MARKET_STALL[1]]}, "SenseiLocal": [SENSEI[0] + 118, SENSEI[1] - 80]}
	with open(os.path.join(ROOT, "build", "plaza", "layout.json"), "w") as f:
		json.dump(layout, f, indent=1)
	print("EXPORT", len(assets), "assets", sum(p["Tris"] for a in assets.values() for p in a["Parts"].values()), "unique tris")
	for k, a in assets.items():
		print(" ", k, a["Hash"], {n: p["Tris"] for n, p in a["Parts"].items()})


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	if "--export" in argv:
		bpy.ops.wm.read_factory_settings(use_empty=True)
		setup_world(bpy.context.scene)
		build(bpy.context.scene)
		export_all()
		return
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	cam = setup_world(scene)
	build(scene)
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	back = along(-12)
	shots = {
		"01_spawn_view": ((back[0], TOP + 7.5, back[1]), (PAD[0], TOP + 14, PAD[1])),  # default camera behind a new player
		"02_aerial": ((115, 92, -125), (-12, 0, 12)),
		"09_exclusive": ((0, TOP + 7.5, -2), (-4.5, TOP + 8, 36)),
		"10_exclusive_close": ((3, TOP + 7, 18), (-4.5, TOP + 7.5, 36)),
		"11_spawn_ring_north": ((0, TOP + 7.5, -8), (0, TOP + 8, 100)),
		"03_gate_back": ((-104, TOP + 9, 96), (0, TOP + 8, 0)),
		"04_reveal_start": ((-185, 95, 170), (-20, 8, 15)),
		"06_dojo_ring": ((-5, TOP + 7, -5), (-42, TOP + 9, -91)),
		"07_dojo_tiers": ((1600, 34, 205), (1600, 20, 0)),
		"08_shops": ((-42, TOP + 8, -40), (ROW_X, TOP + 7, -41)),
		"09_top": ((0, 240, 0), (0, 0, 0.01)),
		"10_row": ((0, TOP + 8, 0), (ROW_X, TOP + 8, -12.5)),
		"11_market": ((ROW_X + 21, TOP + 6, MARKET[1] + 13), (MARKET_STALL[0], TOP + 8, MARKET[1])),
		"12_gate": ((along(AXIS_LEN - 40)[0], TOP + 7, along(AXIS_LEN - 40)[1]), (PAD[0], TOP + 13, PAD[1])),
		"13_market_back": ((ROW_X - 26, TOP + 7, MARKET[1] + 14), (MARKET_STALL[0], TOP + 8, MARKET[1])),
		"14_market_side": ((ROW_X - 3, TOP + 7, MARKET[1] - 18.5), (MARKET_STALL[0], TOP + 8, MARKET[1])),
	}
	for name, (eye, look) in shots.items():
		if not argv or name in argv:
			shoot(cam, eye, look, name, 45 if name == "07_dojo_tiers" else 70)


main()
