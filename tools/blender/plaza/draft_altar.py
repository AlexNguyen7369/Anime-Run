# Blender DRAFTS of a bigger Sidekick summon altar (owner 2026-11-25): renders only, no export. Headless, from the repo root:
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- ctx            (once: context models)
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- [A B C] [unlocked locked] [view ...]
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- report         (tris, size, clearances)
# 1 unit = 1 stud. Local frame: origin on the floor at the ring slot, front -Y (the spawn), +X the Team altar's side.
# Writes assets/plaza_draft2/altar/. Plaza context is build_plaza.py's own geometry. Every size here is proposed.
import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import build_plaza as bp  # noqa: E402

OUT = os.path.join(bp.ROOT, "assets", "plaza_draft2", "altar")
CTX = os.path.join(bp.ROOT, "build", "altar_ctx")
bp.CHARS = CTX
MYTHIC = "side_general"  # World 2's featured Mythic; display only, the game puts the rotation's own there
X, Z = bp.SIDEKICK_ALTAR
MAT = bp.place(X, Z, bp.TOP, bp.ALTAR_FACE)
tau, cos, sin, rad = math.tau, math.cos, math.sin, math.radians

bp.PAL.update({
	"cream": "#F3E6CB", "cream2": "#E2D0AC", "marble": "#D9CDBD", "marble2": "#BFB1A0", "burg": "#6E1B2E", "burg2": "#4A1222", "lacq": "#B3261F",
	"goldd": "#B07F22", "pk0": "#F6D3DF", "pk1": "#FFC9DC", "pk2": "#FF94BC", "pk3": "#E85A97", "pk4": "#B93778", "jade": "#2F8F86", "jade2": "#1F6A68",
	"obs": "#2B2940", "obs2": "#3B3858", "obs3": "#1D1B2E", "iron": "#5A5660", "iron2": "#77727E", "rockp": "#5A4E6E", "rockp2": "#73658A", "leaf": "#4F8A55",
	"off": "#6C6674", "dust0": "#A8949A", "dust1": "#8F7482", "dust2": "#755466", "sil": "#17151E",
})
bp.GLOW.update({
	"g_gold": ("#FFC04A", 1.5), "g_pink": ("#FF6FB0", 1.5), "g_cyan": ("#35D6E6", 1.5), "g_white": ("#FFF3DC", 1.3), "g_vio": ("#A070FF", 1.5),
	"g_paper": ("#FFD89A", 1.0),
})
OFF = {}  # locked: the glow and bright materials an asleep altar swaps


class M(bp.M):
	def __init__(self, name, locked=False):
		super().__init__(name, MAT.copy())
		self.locked = locked

	def _m(self, name):
		if self.locked:
			name = OFF_MAP.get(name, name)
		return super()._m(name)

	def prism(self, pts, z0, z1, top, side=None, inset=0.0):
		"""A flat polygon (x, y) raised from z0 to z1; its top drawn in by inset (0 to 1)."""
		n = len(pts)
		cx, cy = sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n
		hi = [(p[0] + (cx - p[0]) * inset, p[1] + (cy - p[1]) * inset) for p in pts]
		for k in range(n):
			a, b = k, (k + 1) % n
			self.face([(*pts[a], z0), (*pts[b], z0), (*hi[b], z1), (*hi[a], z1)], side or top)
		self.face([(*p, z1) for p in hi], top)
		self.face([(*p, z0) for p in pts][::-1], side or top)

	def tube(self, pts, r, material, sides=6, closed=False, r1=None, flat=1.0):
		"""A swept tube along pts; r to r1. flat squashes it across the up axis."""
		pts = [Vector(p) for p in pts]
		n = len(pts)
		rings = []
		for i, p in enumerate(pts):
			a = pts[(i - 1) % n] if closed or i else p
			b = pts[(i + 1) % n] if closed or i < n - 1 else p
			d = (b - a).normalized()
			ref = Vector((0, 1, 0)) if abs(d.y) < 0.95 else Vector((1, 0, 0))
			u = (ref - d * ref.dot(d)).normalized()
			v = d.cross(u)
			rr = r if r1 is None else r + (r1 - r) * i / (n - 1)
			rings.append([p + (u * cos(k / sides * tau) * flat + v * sin(k / sides * tau)) * rr for k in range(sides)])
		for i in range(n if closed else n - 1):
			A, B = rings[i], rings[(i + 1) % n]
			for k in range(sides):
				self.face([A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]], material)
		if not closed:
			self.face(rings[0][::-1], material)
			self.face(rings[-1], material)

	def ring3(self, c, r, t, material, rot=None, n=32, sides=6, a0=0.0, a1=tau):
		"""A hoop round local Y (upright, facing the front), turned by rot (a Matrix)."""
		rot = rot or Matrix.Identity(3)
		closed = abs(a1 - a0 - tau) < 1e-6
		steps = n if closed else n + 1
		self.tube([Vector(c) + rot @ Vector((r * cos(a0 + (a1 - a0) * k / n), 0, r * sin(a0 + (a1 - a0) * k / n))) for k in range(steps)], t, material, sides, closed)

	def gem(self, c, r, h, material, n=6, up=0.55):
		cx, cy, cz = c
		mid = [(cx + r * cos(k / n * tau), cy + r * sin(k / n * tau), cz + h * (0.5 - up) ) for k in range(n)]
		t, b = (cx, cy, cz + h / 2), (cx, cy, cz - h / 2)
		for k in range(n):
			self.face([mid[k], mid[(k + 1) % n], t], material)
			self.face([mid[(k + 1) % n], mid[k], b], material)

	def orb(self, c, r, material, n=10, rows=6):
		for i in range(rows):
			p0, p1 = math.pi * i / rows - math.pi / 2, math.pi * (i + 1) / rows - math.pi / 2
			pt = lambda p, k: (c[0] + r * cos(p) * cos(k / n * tau), c[1] + r * cos(p) * sin(k / n * tau), c[2] + r * sin(p))
			for k in range(n):
				q = [pt(p0, k), pt(p0, k + 1), pt(p1, k + 1), pt(p1, k)]
				self.face(q[:3] if i == rows - 1 else ([q[0], q[2], q[3]] if i == 0 else q), material)

	def petal(self, ang, base_r, length, width, lean, curl, z, ramp, rim=None, seg=6, thick=0.35, squeeze=0.0):
		"""A cupped petal rooted at base_r, z in direction ang. lean: degrees off vertical at the root (positive outward);
		curl: degrees more by the tip. ramp: materials root to tip. The back is one ramp step darker. rim: edge tube."""
		d = Vector((cos(ang), sin(ang), 0))
		s = Vector((-sin(ang), cos(ang), 0))
		up = Vector((0, 0, 1))
		p = d * base_r + up * z
		rows = []
		for i in range(seg + 1):
			t = i / seg
			th = rad(lean + curl * t)
			out, along = d * cos(th) - up * sin(th), d * sin(th) + up * cos(th)
			w = width / 2 * max(0.02, (math.sin(math.pi * min(1, (t * 0.86 + 0.14))) ** 0.75)) * (1 - squeeze * t)
			if i == seg:
				w = 0.06
			cup = w * 0.32
			row = []
			for j in (-1, -0.5, 0, 0.5, 1):
				row.append(p + s * (w * j) - out * (cup * j * j) * 1.0)
			rows.append((row, out))
			p = p + along * (length / seg)
		for i in range(seg):
			a, oa = rows[i]
			b, ob = rows[i + 1]
			col = ramp[min(len(ramp) - 1, int((i + 0.5) / seg * len(ramp)))]
			back = ramp[min(len(ramp) - 1, int((i + 0.5) / seg * len(ramp)) + 1)]
			taper = lambda k: thick * (1 - k / (seg + 1))
			for j in range(4):
				self.face([a[j + 1], a[j], b[j], b[j + 1]], col)
				ta, tb = oa * taper(i), ob * taper(i + 1)
				self.face([a[j] + ta, a[j + 1] + ta, b[j + 1] + tb, b[j] + tb], back)
			for j, flip in ((0, False), (4, True)):
				ta, tb = oa * taper(i), ob * taper(i + 1)
				q = [a[j], a[j] + ta, b[j] + tb, b[j]]
				self.face(q if not flip else q[::-1], back)
		if rim:
			edge = [r[0][0] for r in rows] + [r[0][4] for r in rows[::-1]]
			self.tube(edge, 0.22, rim, 3)

	def stairs(self, w, y_front, y_back, z0, z1, n, material, trim):
		for i in range(n):
			y = y_front + (y_back - y_front) * i / n
			h = z0 + (z1 - z0) * (i + 1) / n
			self.box((w, y_back - y + 0.02, h - z0), (0, (y + y_back) / 2, (z0 + h) / 2), material)
			self.box((w - 0.4, 0.3, 0.1), (0, y + 0.25, h + 0.03), trim)

	def chain(self, a, b, sag, material, link=1.1, t=0.2):
		a, b = Vector(a), Vector(b)
		n = max(4, int((b - a).length / (link * 1.25)))
		pt = lambda f: a.lerp(b, f) - Vector((0, 0, sag * 4 * f * (1 - f)))
		for i in range(n):
			p, q = pt(i / n), pt((i + 1) / n)
			d = (q - p).normalized()
			u = d.orthogonal().normalized()
			v = d.cross(u)
			side = u if i % 2 else v
			c, L = (p + q) / 2, (q - p).length * 0.62
			loop = [c + d * L * x + side * link * 0.36 * y for x, y in ((-1, 0), (-0.55, 1), (0.55, 1), (1, 0), (0.55, -1), (-0.55, -1))]
			self.tube(loop, t, material, 3, True)

	def padlock(self, c, s, body="gold", dark="burg2"):
		x, y, z = c
		self.box((4 * s, 1.6 * s, 3.4 * s), (x, y, z), body)
		self.box((3.2 * s, 1.8 * s, 2.6 * s), (x, y, z), "goldd")
		self.tube([(x + 1.3 * s * cos(k / 8 * math.pi), y, z + 1.7 * s + 1.6 * s * sin(k / 8 * math.pi)) for k in range(9)], 0.36 * s, "iron2", 6)
		for k in range(5):  # a plain five-petal keyhole rosette, no mark
			a = k / 5 * tau + math.pi / 2
			self.orb((x + 0.6 * s * cos(a), y - 0.95 * s, z + 0.6 * s * sin(a)), 0.4 * s, dark, 6, 4)


# what each material turns into while the altar is locked
OFF_MAP = {
	"g_gold": "goldd", "g_pink": "off", "g_cyan": "off", "g_white": "off", "g_vio": "off", "g_paper": "shutter",
	"pk0": "dust0", "pk1": "dust1", "pk2": "dust2", "pk3": "dust2", "pk4": "dust2", "gold": "goldd", "lamp": "shutter",
	"cream": "marble2", "lacq": "burg2", "burg": "burg2", "jade": "jade2",
}


def ngon(r, n=8, phase=None, sx=1.0, cy=0.0):
	phase = math.pi / n if phase is None else phase
	return [(sx * r * cos(k / n * tau + phase), cy + r * sin(k / n * tau + phase)) for k in range(n)]


def slab(w, d, c, cy=0.0):
	x, y = w / 2, d / 2
	return [(-x + c, cy - y), (x - c, cy - y), (x, cy - y + c), (x, cy + y - c), (x - c, cy + y), (-x + c, cy + y), (-x, cy + y - c), (-x, cy - y + c)]


def scaled(pts, k, cy=0.0):
	return [(x * k, cy + (y - cy) * k) for x, y in pts]


def lantern(m, x, y, z, s=1.0):
	bp.lantern_geo(m, x, y, z, s)


# --- A: Twin-roof shrine stage -----------------------------------------------------------------------------------------
def concept_a(locked):
	body, fx = M("A_Body", locked), M("A_Float", locked)
	m = body
	cy = 1.0
	tiers = ((64, 36, 8, 1.4, "marble"), (55, 30, 7, 2.8, "cream"), (46, 24, 6, 4.2, "marble"))
	z = 0
	for w, d, c, top, col in tiers:
		m.prism(slab(w, d, c, cy), z, top - 0.35, "marble2", "marble2")
		m.prism(slab(w + 0.7, d + 0.7, c, cy), top - 0.35, top, col, "gold")
		z = top
	fronts = [cy - d / 2 - 0.35 for _, d, *_ in tiers]
	for (f, z0, z1) in zip(fronts, (0, 1.4, 2.8), (1.4, 2.8, 4.2)):
		m.stairs(18, f - 1.9, f, z0, z1, 2, "cream2", "lacq")
	D = 4.2
	# inlaid floor and the dais
	for r, col, h in ((10.6, "gold", 0.08), (10.0, "burg", 0.14), (9.0, "gold", 0.2), (8.5, "cream", 0.26)):
		m.cyl(r, h, (0, 1, D), col, n=24)
	m.local = Matrix.Translation((0, -0.5, 0))
	m.cyl(7.2, 1.2, (0, 0, D), "lacq", n=12, r2=6.8)
	m.cyl(7.0, 0.4, (0, 0, D + 1.2), "g_pink", n=12)
	m.cyl(6.2, 1.1, (0, 0, D + 1.6), "gold", n=12, r2=5.6)
	m.cyl(5.2, 0.3, (0, 0, D + 2.7), "cream", n=12)
	for k in range(12):  # carved petals round the dais
		m.petal(k / 12 * tau + math.pi / 2, 5.6, 2.8, 2.4, 40, 18, D + 1.5, ("pk1", "pk2"), seg=3, thick=0.2)
	m.local = Matrix.Identity(4)
	spot = (0, -0.5, D + 11.6)
	# the great folding fan behind everything: pleated blades, gold ribs, a scalloped lit hem
	fy, fz, n = 12.6, 18.0, 13
	for k in range(n):
		a0, a1 = rad(23 + 134 * k / n), rad(23 + 134 * (k + 1) / n)
		am = (a0 + a1) / 2
		R = 36.0 if k % 2 == 0 else 34.4
		pt = lambda rr, a, dy: (rr * cos(a), fy + dy, fz + rr * sin(a))
		band = (("burg2", 12, 18), ("burg", 18, 25), ("pk3", 25, 29.5), ("pk1", 29.5, R))
		for col, r0, r1 in band:
			for aa, ab, da, db in ((a0, am, 0.9, 0), (am, a1, 0, 0.9)):
				f = [pt(r0, aa, da), pt(r0, ab, db), pt(r1, ab, db), pt(r1, aa, da)]
				m.face(f[::-1], col)
				m.face([(x, yy + 0.5, zz) for x, yy, zz in f], "burg2")
		f = [pt(R, a0, 0.9), pt(R, a1, 0.9), pt(R + 1.8, am, 0.2)]
		m.face(f[::-1], "g_gold")
		m.face([(x, yy + 0.5, zz) for x, yy, zz in f], "gold")
		m.tube([pt(11, a0, 0.2), pt(R + 1.2, a0, 0.2)], 0.34, "gold", 4)
		if 1 < k < n - 1 and k % 2:  # five-petal blossoms on every other blade (a plain flower, no crest)
			for j in range(5):
				b = j / 5 * tau + math.pi / 2
				c = Vector(pt(22, am, -0.35)) + Vector((1.15 * cos(b), 0, 1.15 * sin(b)))
				m.face([(c.x + 0.85 * cos(q / 6 * tau), c.y, c.z + 0.85 * sin(q / 6 * tau)) for q in range(6)], "pk1")
	m.tube([pt(11, rad(157), 0.2), pt(36.2, rad(157), 0.2)], 0.34, "gold", 4)
	# sun disc behind the model
	y, zc = 10.6, 19.5
	for k in range(24):
		a = k / 24 * tau
		r0, r1, w = 13.4, (18.6 if k % 2 == 0 else 16.2), 0.9
		d, s = Vector((cos(a), 0, sin(a))), Vector((-sin(a), 0, cos(a)))
		o = Vector((0, y, zc))
		q = [o + d * r0 - s * w, o + d * r0 + s * w, o + d * r1]
		th = Vector((0, 0.7, 0))
		mt = "gold" if k % 2 == 0 else "g_gold"
		m.face([q[1], q[0], q[2]], mt)
		m.face([q[0] + th, q[1] + th, q[2] + th], mt)
		m.face([q[0], q[0] + th, q[2] + th, q[2]], "goldd")
		m.face([q[1] + th, q[1], q[2], q[2] + th], "goldd")
	m.ring3((0, y, zc), 13.6, 1.0, "gold", n=32, sides=6)
	m.ring3((0, y - 0.4, zc), 12.2, 0.4, "g_pink", n=32, sides=4)
	for r, col, dy in ((13.2, "pk2", 0.3), (11.2, "pk1", 0.1), (8.6, "pk0", -0.05)):
		m.face([(r * cos(k / 24 * tau), y + dy, zc + r * sin(k / 24 * tau)) for k in range(24)], col)
	m.face([(13.2 * cos(-k / 24 * tau), y + 0.7, zc + 13.2 * sin(-k / 24 * tau)) for k in range(24)], "burg2")
	m.box((5, 1.6, 8), (0, y + 0.8, D + 4 - 0.2), "lacq")
	for s in (-1, 1):
		m.box((2.2, 2.2, 10), (s * 8, y + 1, D + 5), "lacq")
		m.box((2.8, 2.8, 0.8), (s * 8, y + 1, D + 0.4), "gold")
	# the two towers
	for s in (-1, 1):
		x, ty = s * 23.5, 4.0
		m.box((15, 13, 1.2), (x, ty, D + 0.6), "marble2")
		m.box((13.6, 11.6, 0.5), (x, ty, D + 1.45), "gold")
		for px in (-5.4, 5.4):
			for py in (-4.4, 4.4):
				m.cyl(1.0, 13, (x + px, ty + py, D + 1.7), "lacq", n=8, r2=0.85)
				m.cyl(1.35, 1.1, (x + px, ty + py, D + 1.7), "black", n=8)
				m.cyl(0.9, 1.2, (x + px, ty + py, D + 13.5), "gold", n=8, r2=1.5)
		m.box((9.6, 7.6, 12.6), (x, ty, D + 8), "wood")
		for gx in (-2.9, 0, 2.9):  # shoji front and sides
			m.box((2.5, 0.3, 8.6), (x + gx, ty - 3.9, D + 8), "g_paper")
			m.box((0.22, 0.4, 8.6), (x + gx, ty - 4.0, D + 8), "dark")
			for gz in (5.2, 8, 10.8):
				m.box((2.5, 0.4, 0.22), (x + gx, ty - 4.0, D + gz), "dark")
		for sx in (-1, 1):
			m.box((0.3, 5.6, 8.6), (x + sx * 4.9, ty, D + 8), "g_paper")
			for gy in (-1.4, 1.4):
				m.box((0.4, 0.22, 8.6), (x + sx * 5.0, ty + gy, D + 8), "dark")
		m.box((13, 11, 1.0), (x, ty, D + 15.1), "lacq")
		m.roof(x, ty, D + 15.8, 21, 18, 5.2, "tileb", ridge=0.5, lift=3.0, trim="gold", hip_rings=4)
		m.box((8.2, 6.6, 6.4), (x, ty, D + 23), "wood")
		for gx in (-2, 2):
			m.box((2.8, 0.3, 4), (x + gx, ty - 3.4, D + 23.4), "g_paper")
			m.box((0.2, 0.4, 4), (x + gx, ty - 3.5, D + 23.4), "dark")
		m.box((10, 8.4, 0.7), (x, ty, D + 26.3), "lacq")
		m.roof(x, ty, D + 26.6, 16, 14, 7.4, "tileb", ridge=0.4, lift=2.8, trim="gold", hip_rings=4)
		m.cyl(0.6, 3.0, (x, ty, D + 34.2), "gold", n=6, r2=0.4)
		m.gem((x, ty, D + 38.6), 1.3, 3.6, "g_pink")
		# horn: the split ridge that frames the beam
		horn = [(s * 15.5, 5, D + 17), (s * 12.6, 5, D + 24), (s * 10.8, 5, D + 31), (s * 11.0, 5, D + 38), (s * 8.6, 5, D + 46), (s * 4.6, 5, D + 52)]
		m.tube(horn, 2.0, "lacq", 8, r1=0.35)
		m.tube([(p[0] * 1.0, p[1] - 1.3 + 0.2 * i, p[2]) for i, p in enumerate(horn[1:])], 0.4, "g_gold", 4, r1=0.15)
		for i in (1, 2, 3):
			m.tube([Vector(horn[i]) - (Vector(horn[i + 1]) - Vector(horn[i])) * 0.09, Vector(horn[i]) + (Vector(horn[i + 1]) - Vector(horn[i])) * 0.09], 2.0 - 0.25 * i, "gold", 8)
		# hanging cloth
		for bx in (-5.4, 5.4):
			xx, yy = x + bx, ty - 5.6
			m.box((2.6, 0.24, 9), (xx, yy, D + 9.2), "burg")
			m.box((2.9, 0.3, 0.5), (xx, yy, D + 13.9), "gold")
			m.box((2.6, 0.3, 0.4), (xx, yy, D + 5.6), "gold")
			m.face([(xx - 1.3, yy - 0.12, D + 4.7), (xx + 1.3, yy - 0.12, D + 4.7), (xx, yy - 0.12, D + 3.2)][::1], "burg")
			m.face([(xx + 1.3, yy + 0.12, D + 4.7), (xx - 1.3, yy + 0.12, D + 4.7), (xx, yy + 0.12, D + 3.2)], "burg")
		# stair lanterns and edge lanterns
		for lx, ly, lz in ((11.2, fronts[0] + 1.6, 1.4), (11.2, fronts[1] + 1.6, 2.8), (28.5, -8.6, 1.4), (20, fronts[1] + 1.5, 2.8)):
			lantern(m, s * lx, ly, lz, 0.85)
	# garland of lamps across the front, high between the towers
	rope = [(x, -2.5, D + 28.5 - 4.0 * (1 - (x / 16) ** 2)) for x in [-16 + 32 * k / 16 for k in range(17)]]
	if not locked:
		m.tube(rope, 0.18, "rope", 4)
		for k in range(2, 15, 2):
			p = rope[k]
			m.cyl(0.75, 1.5, (p[0], p[1], p[2] - 2.0), "g_paper", n=8)
			m.cyl(0.8, 0.25, (p[0], p[1], p[2] - 0.5), "gold", n=8)
			m.cyl(0.8, 0.25, (p[0], p[1], p[2] - 2.2), "gold", n=8)
	fx.gem((0, 5, D + 57), 2.8, 9.0, "g_pink", n=8)
	fx.ring3((0, 5, D + 57), 4.8, 0.35, "gold", Matrix.Rotation(rad(74), 3, "X"), n=20, sides=4)
	rng = random.Random(3)
	if not locked:
		for k in range(8):
			a = k / 8 * tau + 0.3
			fx.gem((13.5 * cos(a), 4 + 3.0 * sin(a), D + 12 + 18 * rng.random()), 0.5, 1.6, rng.choice(("g_pink", "g_gold")))
	if locked:
		for a, b in (((-16.5, -3.5, D + 20), (16.5, -3.5, D + 3)), ((16.5, -3.5, D + 20), (-16.5, -3.5, D + 3))):
			m.chain(a, b, 1.6, "iron2", 1.7, 0.3)
		m.padlock((0, -4.4, D + 10.2), 1.0)
	return [body, fx], spot, 17.0, dict(beam=((0, 7.5, D + 2), 92, 4.4, 2.6, "g_pink"), top_fx=D + 52)


# --- B: Great lotus ------------------------------------------------------------------------------------------------------
def concept_b(locked):
	body, pet, fx = M("B_Body", locked), M("B_Petals", locked), M("B_Float", locked)
	m = body
	z = 0
	for r, top, col in ((18.4, 1.2, "marble"), (16.0, 2.4, "cream"), (12.6, 3.6, "marble")):
		m.cyl(r - 0.3, top - z - 0.3, (0, 0, z), "marble2", n=32)
		m.cyl(r, 0.3, (0, 0, top - 0.3), col, n=32)
		bp.ring_band(m, r - 0.5, r, top - 0.05, top + 0.06, "gold")
		z = top
	for r, z0, z1 in ((18.4, 0, 1.2), (16.0, 1.2, 2.4), (12.6, 2.4, 3.6)):
		m.stairs(11, -(r * cos(5.5 / r)) - 1.0, -(r * cos(5.5 / r)) + 0.3, z0, z1, 2, "cream2", "pk2")
	D = 3.6
	bp.ring_band(m, 13.4, 15.2, 2.35, 2.52, "g_cyan")  # water light ring
	# seed pod pedestal
	for r0, r1, z0, h, col in ((6.4, 4.6, D, 1.6, "jade2"), (4.6, 6.6, D + 1.6, 3.0, "jade"), (6.8, 6.8, D + 4.6, 0.5, "gold"), (6.2, 6.0, D + 5.1, 0.4, "g_gold")):
		m.cyl(r0, h, (0, 0, z0), col, n=16, r2=r1)
	for k in range(12):
		a = k / 12 * tau + 0.13
		m.gem((5.9 * cos(a), 5.9 * sin(a), D + 3.6), 0.8, 1.6, "g_gold", 6)
	spot = (0, 0, D + 13.1)
	for k in range(14):  # stamens
		a = k / 14 * tau
		if abs(math.atan2(sin(a + math.pi / 2), cos(a + math.pi / 2))) < rad(34):
			continue
		lean = 1.0 if not locked else 0.35
		p = [(cos(a) * r, sin(a) * r, h) for r, h in ((7.4, D), (8.2 + 0.6 * lean, D + 4), (8.6 + 1.6 * lean, D + 7.5 + (k % 3)))]
		m.tube(p, 0.22, "gold", 3, r1=0.14)
		m.orb(p[-1], 0.6, "g_gold", 6, 4)
	front = -math.pi / 2
	delta = lambda a: abs(math.atan2(sin(a - front), cos(a - front)))
	full = ("pk0", "pk0", "pk1", "pk1", "pk2", "pk3")
	soft = ("pk0", "pk0", "pk1", "pk2")
	# outer, splayed: none over the stairs or near the sky-loop post
	for k in range(13):
		a = front + math.pi / 13 + k / 13 * tau
		if delta(a) < rad(42):
			continue
		if not locked:
			pet.petal(a, 13.2, 18.0, 13.2, 34, 46, 2.3, full, "gold")
		else:
			pet.petal(a, 13.2, 17.0, 9.6, 4, -18, 2.3, full, "gold")
	# middle
	for k in range(11):
		a = front + k / 11 * tau
		if delta(a) < rad(40 if locked else 60):
			continue
		if not locked:
			pet.petal(a, 10.8, 15.0 + 9.0 * delta(a) / math.pi, 12.8, 24, 34, D - 0.4, full, "gold")
		else:
			pet.petal(a, 10.8, 24.0, 10.4, 0, -28, D - 0.4, full, "gold", squeeze=0.2)
	# inner back fan: the tall crown that frames the model
	for da, L, w in ((-74, 34, 11), (74, 34, 11), (-38, 46, 14), (38, 46, 14), (0, 58, 17)):
		a = math.pi / 2 + rad(da)
		if not locked:
			pet.petal(a, 9.6, L, w, 2 + 4 * (abs(da) > 50), 16, D - 0.4, soft, "gold", seg=8)
		else:
			pet.petal(a, 9.6, L * 0.9, w, 0, -28, D - 0.4, soft, "gold", squeeze=0.2)
	# small sepals under the outer layer
	for k in range(16):
		a = front + k / 16 * tau
		if delta(a) < rad(30):
			continue
		pet.petal(a, 15.6, 8.0, 5.2, 66, 34, 1.4, ("jade", "jade2"), seg=4, thick=0.25)
	# twin pools of bud lamps at the sides, on their own lily pads
	for s in (-1, 1):
		for lx, ly, r in ((25.5, -8.5, 3.6), (30.5, 1.5, 2.6)):
			m.cyl(r, 0.5, (s * lx, ly, 0), "jade2", n=12)
			m.cyl(r * 0.92, 0.2, (s * lx, ly, 0.5), "jade", n=12)
			m.tube([(s * lx, ly, 0.5), (s * (lx + 0.3), ly, 2.6)], 0.45, "jade2", 6)
			m.local = Matrix.Translation((s * lx, ly, 0))
			for k in range(6):
				m.petal(k / 6 * tau, 0.7, r * 1.1, r * 0.8, 22 if not locked else 2, 24 if not locked else -20, 2.4, ("pk0", "pk1", "pk2"), seg=3, thick=0.18)
			m.local = Matrix.Identity(4)
			m.orb((s * lx, ly, 4.0), 0.9, "g_pink", 6, 4)
	# floating: two thin orbit rings and bud lights
	if not locked:
		c = (0, 1, D + 15)
		fx.ring3(c, 13.0, 0.28, "g_gold", Matrix.Rotation(rad(68), 3, "X") @ Matrix.Rotation(rad(12), 3, "Z"), n=32, sides=4)
		fx.ring3((0, 3, D + 46), 7.5, 0.28, "g_gold", Matrix.Rotation(rad(80), 3, "X"), n=24, sides=4)
		fx.ring3((0, 3, D + 60), 4.6, 0.24, "g_pink", Matrix.Rotation(rad(80), 3, "X"), n=20, sides=4)
		for k in range(8):
			a = k / 8 * tau
			fx.gem((13.0 * cos(a), 1 + 12 * sin(a), D + 15 + 4.4 * sin(a)), 0.7, 2.0, "g_pink" if k % 2 else "g_white")
	else:
		for zz, r in ((7.5, 15.6),):
			pts = [(r * cos(front + rad(34) + (tau - rad(68)) * k / 22), r * sin(front + rad(34) + (tau - rad(68)) * k / 22), zz) for k in range(23)]
			for p, q in zip(pts, pts[1:]):
				m.chain(p, q, 0.1, "iron2", 2.4, 0.34)
		m.chain((-8.8, -13.0, 7.5), (8.8, -13.0, 7.5), 2.2, "iron2", 2.2, 0.34)
		m.padlock((0, -13.4, 4.6), 0.75)
	return [body, pet, fx], spot, 15.0, dict(beam=((0, 6.5, D + 2), 92, 4.0, 2.4, "g_pink"), top_fx=D + 42)


# --- C: Astral orrery ------------------------------------------------------------------------------------------------------
def concept_c(locked):
	body, isl, rings, fx = M("C_Body", locked), M("C_Island", locked), M("C_Rings", locked), M("C_Float", locked)
	m = body
	z = 0
	A = 1 / cos(math.pi / 8)
	for ap, top, col in ((18.0, 1.3, "obs2"), (15.4, 2.6, "obs"), (12.6, 3.9, "obs2")):
		m.prism(ngon((ap - 0.3) * A), z, top - 0.35, "obs3", "obs3")
		m.prism(ngon(ap * A), top - 0.35, top, col, "gold")
		z = top
	for ap, z0, z1 in ((18.0, 0, 1.3), (15.4, 1.3, 2.6), (12.6, 2.6, 3.9)):
		m.stairs(10, -ap - 1.2, -ap, z0, z1, 2, "obs2", "g_cyan")
	D = 3.9
	# floor star: an eight-point inlay of light round the well
	for k in range(8):
		a = k / 8 * tau
		p = lambda r, t: (r * cos(a + t), r * sin(a + t), D + 0.06)
		m.face([p(5.4, -0.12), p(11.4, 0), p(5.4, 0.12)], "g_cyan" if k % 2 else "g_gold")
	bp.ring_band(m, 4.6, 5.2, D, D + 0.5, "gold")
	bp.ring_band(m, 11.6, 12.0, D, D + 0.12, "g_vio")
	m.cyl(4.6, 0.15, (0, 0, D), "g_vio", n=24)
	# obelisks: four on the diagonals, two giants on their own plinths at the sides
	posts = [(13.2, -10.6, 1.3, 20, 1.5), (13.6, 12.0, 1.3, 30, 1.8), (27.0, 1.5, 0.0, 38, 2.6)]
	tips = []
	for s in (-1, 1):
		for x, y, z0, h, r in posts:
			big = r > 2
			if big:
				m.prism(ngon(6.4, 8, None, 1, 0) and [(s * x + px, y + py) for px, py in ngon(6.2)], 0, 1.4, "obs2", "obs3")
				m.prism([(s * x + px, y + py) for px, py in ngon(4.8)], 1.4, 2.8, "obs", "gold")
				z1 = 2.8
			else:
				m.prism([(s * x + px, y + py) for px, py in ngon(r * 1.7)], z0, z0 + 1.4, "obs2", "gold")
				z1 = z0 + 1.4
			lean = s * h * 0.05
			a, b = Vector((s * x, y, z1)), Vector((s * x + lean, y, z1 + h * 0.8))
			m.tube([a, a.lerp(b, 0.12), a.lerp(b, 0.14), b], r * 1.25, "obs", 4, r1=r * 0.8)
			m.tube([a.lerp(b, 0.30), a.lerp(b, 0.36)], r * 1.3, "gold", 4)
			m.tube([a.lerp(b, 0.93), b + Vector((0, 0, 0.3))], r * 1.05, "gold", 4)
			for q in (0.46, 0.60, 0.74):  # light slots on the front face
				c = a.lerp(b, q)
				m.box((r * 0.55, 0.3, h * 0.07), (c.x, c.y - r * 0.82, c.z), "g_cyan")
			top = b + Vector((0, 0, h * 0.14))
			fx.gem(top, r * 0.85, h * 0.22, "g_vio" if big else "g_cyan", n=6)
			tips.append(b)
	# the floating island
	c0 = Vector((0, 2.0, 0))
	top_z = 13.0 if not locked else 10.5
	lay = [(9.6, top_z), (9.9, top_z - 1.0), (7.0, top_z - 2.0), (7.6, top_z - 3.0), (4.2, top_z - 4.4), (4.6, top_z - 5.2), (0.8, top_z - 7.4 if not locked else top_z - 6.2)]
	rnd = random.Random(11)
	n = 14
	ringpts = [[(c0.x + r * (1 + rnd.uniform(-0.09, 0.09)) * cos(k / n * tau), c0.y + r * (1 + rnd.uniform(-0.09, 0.09)) * sin(k / n * tau), zz) for k in range(n)] for r, zz in lay]
	isl.face(ringpts[0], "pk1")
	for i in range(len(lay) - 1):
		for k in range(n):
			isl.face([ringpts[i + 1][k], ringpts[i + 1][(k + 1) % n], ringpts[i][(k + 1) % n], ringpts[i][k]], "pk2" if i == 0 else rnd.choice(("rockp", "rockp2")))
	for k in range(7):  # crystals under it
		a = k / 7 * tau
		rr = rnd.uniform(2, 5.6)
		isl.gem((c0.x + rr * cos(a), c0.y + rr * sin(a), top_z - 4.2 - (5.6 - rr) * 0.4), 0.8, 4.0, "g_vio" if k % 2 else "g_cyan", up=0.3)
	for r, h, col in ((5.4, 0.5, "cream"), (4.8, 1.0, "gold"), (4.2, 1.3, "g_white")):
		isl.cyl(r, h, (c0.x, c0.y, top_z), col, n=12)
	for s in (-1, 1):  # two small blossom trees on the island
		isl.beam((s * 7.0, 4.4, top_z), (s * 7.6, 4.8, top_z + 4), 0.7, "bark", 5)
		for dx, dz, r in ((0, 4.6, 2.0), (s * 1.3, 4.0, 1.4), (-s * 1.0, 3.9, 1.3)):
			isl.blob(r, (s * 7.6 + dx, 4.8, top_z + dz), "pk2" if dx else "pk1")
	spot = (c0.x, c0.y, top_z + 8.9)
	c = (0, 4.0, 29.5) if not locked else (0, 16.0, 26.5)
	if not locked:
		specs = ((23.5, 1.5, "gold", 10, 14), (19.4, 1.0, "burg", 32, -14), (15.6, 0.8, "gold", 20, 30))
	else:  # stopped: the rings lie slack on the side plinths and the tier
		specs = ((23.5, 1.5, "gold", 4, 0), (19.4, 1.0, "burg", 7, 0), (15.6, 0.8, "gold", 10, 0))
	for (r, t, col, tx, tz), glow in zip(specs, ("g_gold", "g_cyan", "g_pink")):
		if locked:
			c = (0, 16.0, 3.0 + r + t)  # slack: all three hang to the bottom of the stack
		rot = Matrix.Rotation(rad(tz), 3, "Z") @ Matrix.Rotation(rad(tx), 3, "X")
		rings.ring3(c, r, t, col, rot, n=40, sides=6)
		inner = [Vector(c) + rot @ Vector(((r - t * 0.95) * cos(k / 40 * tau), 0, (r - t * 0.95) * sin(k / 40 * tau))) for k in range(40)]
		rings.tube(inner, t * 0.3, glow, 4, True)
		for k in range(8):
			a = k / 8 * tau
			p = Vector(c) + rot @ Vector((r * cos(a), 0, r * sin(a)))
			d = rot @ Vector((cos(a), 0, sin(a)))
			if k % 2 == 0:
				rings.tube([p - d * t * 1.5, p + d * t * 1.5], t * 0.75, "gold", 6)
			else:
				rings.tube([p - d * t * 1.2, p + d * t * 1.8], t * 0.5, glow, 4, r1=0.05)
		if not locked:
			a = rad((-28 if r > 20 else 205) + r * 3)
			p = Vector(c) + rot @ Vector((r * cos(a), 0, r * sin(a)))
			rings.orb(p, t * 2.0, glow, 10, 6)
	# crown
	cz = 60.5 if not locked else 56.0
	cy = 4 if not locked else 16
	fx.gem((0, cy, cz), 2.6, 10.0, "g_vio", n=8)
	fx.ring3((0, cy, cz), 4.6, 0.3, "gold", Matrix.Rotation(rad(76), 3, "X"), n=20, sides=4)
	for k in range(10):  # floating stones round the sides
		s = -1 if k % 2 else 1
		x, y, zz = s * rnd.uniform(20.5, 25.5), rnd.uniform(4, 10), rnd.uniform(8, 34) if not locked else 0.8
		fx.blob(rnd.uniform(0.7, 1.4), (x, y, zz), rnd.choice(("rockp", "rockp2")), 0.9)
	for s in (-1, 1):  # gold chains that hold the island
		m.chain((s * 14.0, 12.0, 18), (s * 8.4, 5.5, top_z - 1), 1.0, "gold", 1.3, 0.2)
		if locked:
			m.chain((s * 26.5, -1, 18), (0, -8.8, 8.0), 2.4, "iron2", 1.7, 0.3)
	if locked:
		m.padlock((0, -8.8, 6.2), 0.8)
	return [body, isl, rings, fx], spot, 15.0, dict(beam=((0, 9.0, D), 92, 3.8, 2.4, "g_vio"), top_fx=58)


CONCEPTS = {"A": concept_a, "B": concept_b, "C": concept_c}
NAMES = {"A": "twin_roof_stage", "B": "great_lotus", "C": "astral_orrery"}


# --- Context ---------------------------------------------------------------------------------------------------------------
def make_context_models():
	"""The models the renders stand in the scene (build/altar_ctx, not shipped): a Mythic, the Saitamo pedestal's and a runner."""
	import build_avatar
	import build_boss_event as be
	be.OUT = CTX
	be.load_sidekick_files() if hasattr(be, "load_sidekick_files") else None
	for cid in (MYTHIC, "punch_hero", "leaf_hero"):
		build_avatar.reset()
		os.makedirs(os.path.join(CTX, cid), exist_ok=True)
		if cid.startswith("side_"):
			be.MODELS[cid]().finish()
		else:
			build_avatar.placed(cid, build_avatar.load_data()[cid])
		for i in bpy.data.images:
			if i.filepath and not i.packed_file:
				i.pack()
		bpy.context.preferences.filepaths.save_version = 0
		bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CTX, cid, cid + ".blend"))
		print("CTX", cid)


def beam_mat(name, colour, strength, alpha):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	o = nt.nodes.new("ShaderNodeOutputMaterial")
	mix = nt.nodes.new("ShaderNodeMixShader")
	tr = nt.nodes.new("ShaderNodeBsdfTransparent")
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = bp.rgb(colour)
	em.inputs["Strength"].default_value = strength
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	mul = nt.nodes.new("ShaderNodeMath")
	mul.operation = "MULTIPLY"
	inv = nt.nodes.new("ShaderNodeMath")
	inv.operation = "SUBTRACT"
	inv.inputs[0].default_value = 1.0
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs["Z"], inv.inputs[1])
	nt.links.new(inv.outputs[0], mul.inputs[0])
	mul.inputs[1].default_value = alpha
	nt.links.new(mul.outputs[0], mix.inputs[0])
	nt.links.new(tr.outputs[0], mix.inputs[1])
	nt.links.new(em.outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], o.inputs[0])
	if hasattr(m, "surface_render_method"):
		m.surface_render_method = "BLENDED"
	m.use_backface_culling = True
	return m


def plain(name, colour, text=False):
	if name in bpy.data.materials:
		return bpy.data.materials[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = bp.rgb(colour)
	b.inputs["Roughness"].default_value = 0.9
	if text:
		b.inputs["Emission Color"].default_value = bp.rgb(colour)
		b.inputs["Emission Strength"].default_value = 1.0
	return m


def local(p):
	return MAT @ Vector(p)


def rbx(p):
	"""Roblox (x, y, z) of a local point."""
	w = local(p)
	return (w.x, w.z, -w.y)


def mythic(col, spot, size, locked):
	path = os.path.join(CTX, MYTHIC, MYTHIC + ".blend")
	with bpy.data.libraries.load(path) as (src, dst):
		dst.objects = list(src.objects)
	obs = [o for o in dst.objects if o and o.type in ("MESH", "EMPTY")]
	for o in obs:
		col.objects.link(o)
	bpy.context.view_layer.update()
	pts = [o.matrix_world @ Vector(c) for o in obs if o.type == "MESH" for c in o.bound_box]
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	s = size / max(hi - lo)
	root = bpy.data.objects.new("MythicRoot", None)
	col.objects.link(root)
	for o in obs:
		if o.parent is None:
			o.parent = root
	# stands with its box centred on the ModelSpot, turned a little so its shape shows
	root.matrix_world = MAT @ Matrix.Translation(spot) @ Matrix.Rotation(rad(14), 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation(-(lo + hi) / 2)
	if locked:
		sil = plain("Silhouette", bp.PAL["sil"])
		for o in obs:
			if o.type == "MESH":
				o.data = o.data.copy()
				o.data.materials.clear()
				o.data.materials.append(sil)
	return (hi.z - lo.z) * s / 2


def text(col, body, pos_local, size, colour, name, face_cam=False):
	cu = bpy.data.curves.new(name, "FONT")
	cu.body, cu.size, cu.align_x, cu.align_y, cu.extrude = body, size, "CENTER", "CENTER", 0.04
	cu.materials.append(plain("T_" + colour, colour, True))
	ob = bpy.data.objects.new(name, cu)
	ob.matrix_world = MAT @ Matrix.Translation(pos_local) @ (Matrix.Identity(4) if face_cam else Matrix.Rotation(math.pi / 2, 4, "X"))
	col.objects.link(ob)
	return ob


def teardown():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bp._mats.clear()
	bp._chars.clear()
	bp.SHIP.clear()
	bp.SIGNS.clear()
	bp.rng.seed(7)


def context_scene():
	teardown()
	scene = bpy.context.scene
	cam = bp.setup_world(scene)
	scene.render.resolution_x, scene.render.resolution_y = 1280, 720
	scene.render.threads_mode, scene.render.threads = "FIXED", 2
	scene.render.image_settings.quality = 88
	cam.data.clip_start = 0.3
	if hasattr(scene, "eevee"):
		scene.eevee.taa_render_samples = 24
	bp.build(scene)
	fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))  # sky bounce on the altar's front, no shadow
	fill.data.energy, fill.data.color, fill.data.use_shadow = 0.9, (1.0, 0.86, 0.78), False
	fill.rotation_euler = (rad(55), 0, rad(138))
	scene.collection.objects.link(fill)
	ctx = bpy.data.collections["Context"]
	bpy.data.objects.remove(bpy.data.objects["Ctx_Kept"])
	k = bp.M("N_BestRoll", bp.place(*bp.BEST_ROLL))
	for r, z0, h, mt in ((9, 0, 0.8, "slab"), (8.8, 0.8, 0.4, "gold"), (9, 1.2, 0.8, "stone")):
		k.cyl(r, h, (0, 0, z0), mt, n=24)
	k.build(ctx)
	t = bp.M("N_TeamAltar", bp.place(*bp.ring_spot(7)[0], bp.TOP, bp.ring_spot(7)[1]))
	t.cyl(6 / cos(math.pi / 8), 1.6, (0, 0, 0), "dark", n=8)
	t.cyl(5.8, 0.1, (0, 0, 1.6), "bloom2", n=8)
	t.build(ctx)
	p = bp.M("N_StartPad")
	p.box((16, 16, 0.4), tuple(bp.rb(bp.PAD[0], bp.TOP + 0.2, bp.PAD[1])), "pad")
	p.build(ctx)
	wg = bp.M("N_WorldGate", bp.place(76, -96, bp.TOP, bp.to_spawn(76, -96)))
	wg.cyl(15 / cos(math.pi / 8), 1.2, (0, 0, 0), "stone2", n=8)
	wg.build(ctx)
	return scene, cam


def add_concept(key, locked):
	scene = bpy.context.scene
	col = bpy.data.collections.new("Altar")
	scene.collection.children.link(col)
	parts, spot, size, info = CONCEPTS[key](locked)
	obs = [m.build(col) for m in parts if m.f]
	half = mythic(col, spot, size, locked)
	p = rbx((7.5, -21.5, 0))  # a runner for scale
	bp.put_char(col, "leaf_hero", p[0], bp.TOP, p[2], (-bp.ALTAR_FACE[0], -bp.ALTAR_FACE[1]), bp.RUNNER_H, "Scale_runner")
	if not locked:
		(bx, by, bz), h, r0, r1, mt = info["beam"]
		colr = bp.GLOW[mt][0]
		for i, (f, a) in enumerate(((1.0, 0.30), (0.45, 0.38))):
			b = bp.M(f"FX_Beam{i}", MAT)
			b.cyl(r1 * f, h - bz, (bx, by, bz), "g_pink", n=20, r2=r0 * f)
			ob = b.build(col)
			ob.data.materials.clear()
			ob.data.materials.append(beam_mat(f"Beam{i}", colr if i == 0 else "#FFF0F6", 1.4, a))
		lt = bpy.data.objects.new("FX_Light", bpy.data.lights.new("FX_Light", "POINT"))
		lt.data.energy, lt.data.color, lt.data.shadow_soft_size = 3200, (1.0, 0.86, 0.84), 2.0
		lt.matrix_world = MAT @ Matrix.Translation((spot[0], spot[1] - 11, spot[2] + 5))
		col.objects.link(lt)
		rnd = random.Random(5)
		pm = M("FX_Motes")  # 60 of the proposed about 90 particles alive
		for _ in range(60):
			a, rr = rnd.uniform(0, tau), rnd.uniform(5, 15)
			p = Vector((rr * cos(a), 2 + rr * sin(a) * 0.8, rnd.uniform(5, 34)))
			s = rnd.uniform(0.18, 0.4)
			pm.gem(p, s, s * 2.6, rnd.choice(("g_pink", "g_white", "g_gold")), n=4)
		pm.build(col)
	else:
		# stand-in for the game's existing "Rebirth 2" BillboardGui (Client/SidekickAltarView): not part of any mesh
		text(col, "Rebirth 2", (spot[0], spot[1] - 9.5, spot[2] - half - 1.4), 2.4, "#FFFFFF", "UI_RebirthLabel")
	return col, obs, spot, info


# --- Views: eye and target in local studs (the last two in Roblox world) -------------------------------------------------
def view(cam, name, key):
	scene = bpy.context.scene
	cam.data.type = "PERSP"
	for o in scene.objects:
		if o.name.startswith(("SkyLoop", "RunnerTrails", "Runner_", "TOP_")):
			o.hide_render = o.name.startswith("TOP_")
	if name == "front":  # the sky loop (hidden here only) would cross the picture
		for o in scene.objects:
			if o.name.startswith(("SkyLoop", "RunnerTrails", "Runner_")):
				o.hide_render = True
		eye, look, fov = rbx((0, -80, 20)), rbx((0, 0, 26.5)), 50
	elif name == "threeq":
		eye, look, fov = rbx((56, -36, 25)), rbx((0, 2, 24)), 62  # outside the loop
	elif name == "close":
		eye, look, fov = rbx((7.5, -19, 9.5)), rbx((0, 2, 15.5)), 70
	elif name == "spawn":  # a 70 degree Roblox camera 12 behind and 4 above a player on the walk spawn, turned to the altar
		f = Vector((X, Z)).normalized()
		eye, look, fov = (-f.x * 12, bp.SPAWN_TOP + 8.5, -f.y * 12), (X, 15, Z), 70
	elif name == "spawnside":  # the same camera with the player 8 studs to the Team altar's side of the walk spawn
		f = Vector((X, Z)).normalized()
		sx, sz = -f.y * 8, f.x * 8
		eye, look, fov = (-f.x * 12 + sx, bp.SPAWN_TOP + 8.5, -f.y * 12 + sz), (X, 15, Z), 70
	elif name == "top":
		for o in scene.objects:
			if o.name.startswith("TOP_"):
				o.hide_render = False
		cam.data.type = "ORTHO"
		cam.data.sensor_fit = "VERTICAL"
		cam.data.ortho_scale = 150
		cam.location = bp.rb(45, 300, 45)
		cam.rotation_euler = (0, 0, 0)
		return
	e, l = bp.rb(*eye), bp.rb(*look)
	cam.location = e
	cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = rad(fov)
	if "UI_RebirthLabel" in scene.objects:  # a billboard faces the camera
		o = scene.objects["UI_RebirthLabel"]
		o.matrix_world = Matrix.Translation(o.matrix_world.translation) @ cam.rotation_euler.to_matrix().to_4x4()


def top_marks(scene):
	"""Plan-view labels and the limits: shown only in the top view (Roblox x right, z down)."""
	col = bpy.data.collections.new("TopMarks")
	scene.collection.children.link(col)

	def ring(x, z, r, colour, w=0.5, h=130):
		m = bp.M("TOP_ring")
		mtx = bp.rb(x, h, z)
		for k in range(72):
			a, b = k / 72 * tau, (k + 1) / 72 * tau
			m.face([(mtx.x + rr * cos(t), mtx.y + rr * sin(t), mtx.z) for rr, t in ((r - w, a), (r, a), (r, b), (r - w, b))], "g_white")
		o = m.build(col)
		o.data.materials.clear()
		o.data.materials.append(plain("T_" + colour, colour, True))

	ring(X, Z, 16, "#00E5FF")  # today's altar, about 32 across
	ring(X, Z, LIMIT_ROUND, "#FF2D2D")  # the round footprint limit set by the sky-loop post
	ring(0, 0, 64.5, "#FFD400")  # the sky loop's outer edge: above y 28 everything stays outside it
	for t, x, z in (("BEST ROLL", 83.9, 3.1), ("TEAM ALTAR", -3.1, 83.9), ("SPAWN", 0, -5), ("SAITAMO", 11.6, 22), ("GREAT SAKURA", 80, 112), ("SKY LOOP", 30, 62), ("POST", 43.8, 41)):
		cu = bpy.data.curves.new("TOP_t", "FONT")
		cu.body, cu.size, cu.align_x = t, 4.2, "CENTER"
		cu.materials.append(plain("T_#101018", "#101018", True))
		o = bpy.data.objects.new("TOP_" + t, cu)
		o.location = bp.rb(x, 135, z)
		col.objects.link(o)


# The sky-loop post at 45 degrees: centre (43.84, 43.84), base radius 1.7
POST = (62 * cos(rad(45)), 62 * sin(rad(45)))
LIMIT_ROUND = math.hypot(X - POST[0], Z - POST[1]) - 1.7


# --- Clearances ----------------------------------------------------------------------------------------------------------
def bvh(ob):
	mw = ob.matrix_world
	vs = [mw @ v.co for v in ob.data.vertices]
	return BVHTree.FromPolygons(vs, [tuple(p.vertices) for p in ob.data.polygons])


def samples(obs, step=0.6):
	for ob in obs:
		mw = ob.matrix_world
		vs = [mw @ v.co for v in ob.data.vertices]
		for p in ob.data.polygons:
			q = [vs[i] for i in p.vertices]
			for i in range(1, len(q) - 1):
				a, b, c = q[0], q[i], q[i + 1]
				n = max(1, int(max((b - a).length, (c - a).length, (c - b).length) / step))
				for u in range(n + 1):
					for v in range(n + 1 - u):
						yield a + (b - a) * (u / n) + (c - a) * (v / n)


def report(key, locked):
	col, obs, spot, info = add_concept(key, locked)
	bpy.context.view_layer.update()
	out = {"concept": key, "name": NAMES[key], "state": "locked" if locked else "unlocked", "tris": {}, "materials": {}}
	for o in obs:
		out["tris"][o.name] = bp.tris(o)
		out["materials"][o.name] = len(o.data.materials)
	out["tris_total"] = sum(out["tris"].values())
	out["mesh_parts"] = sum(1 + len({m.name for m in o.data.materials if m.name in bp.GLOW}) for o in obs)  # Body + one per glow colour
	inv = MAT.inverted()
	pts = list(samples(obs))
	lo = [min((inv @ p)[i] for p in pts) for i in range(3)]
	hi = [max((inv @ p)[i] for p in pts) for i in range(3)]
	out["size_w_d_h"] = [round(hi[i] - lo[i], 1) for i in range(3)]
	out["local_min_max"] = [[round(a, 1) for a in lo], [round(a, 1) for a in hi]]
	out["model_spot_roblox"] = [round(v, 1) for v in rbx(spot)]
	cl = {}
	sc = bpy.data.objects
	for nm in ("SkyLoop", "N_BestRoll", "N_TeamAltar", "GreatSakura", "Showpiece", "MainPath", "IndexBoard", "HeroTorii", "N_StartPad", "N_WorldGate", "MarketStall"):
		t = bvh(sc[nm])
		d, where = min(((t.find_nearest(p)[3], p) for p in pts), key=lambda q: q[0])
		cl[nm] = [round(d, 2), [round(v, 1) for v in (where.x, where.z, -where.y)]]
	# runners on the loop: 5.6 tall on a deck 5 wide at y 30
	env = [math.hypot(max(0, abs(math.hypot(p.x, p.y) - 62) - 2.5), max(0, 29.5 - p.z, p.z - 36.5)) for p in pts]
	cl["sky_loop_runner_envelope"] = [round(min(env), 2)]
	cl["floor_edge_x94"] = [round(min(94 - p.x for p in pts), 2)]
	cl["floor_edge_z110"] = [round(min(110 + p.y for p in pts), 2)]
	out["clearance_studs"] = cl
	out["below_floor"] = round(min(p.z for p in pts) - bp.TOP, 2)
	return out


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	os.makedirs(OUT, exist_ok=True)
	if argv == ["ctx"]:
		make_context_models()
		return
	keys = [a for a in argv if a in CONCEPTS] or list(CONCEPTS)
	states = [a for a in argv if a in ("unlocked", "locked")] or ["unlocked", "locked"]
	views = [a for a in argv if a in ("front", "threeq", "close", "spawn", "spawnside", "top")] or ["front", "threeq", "close", "spawn", "spawnside", "top"]
	scene, cam = context_scene()
	if "report" in argv:
		rows = []
		for k, st in [(k, st) for k in keys for st in states]:
			rows.append(report(k, st == "locked"))
			for o in list(bpy.data.collections["Altar"].objects):
				bpy.data.objects.remove(o)
			bpy.data.collections.remove(bpy.data.collections["Altar"])
		limits = {
			"slot": [round(X, 1), round(Z, 1)], "sky_loop_post_centre": [round(v, 2) for v in POST],
			"round_limit_radius": {"sky_loop_post": round(LIMIT_ROUND, 2), "floor_edge_x94": round(94 - X, 2), "floor_edge_z110": round(110 - Z, 2),
				"sky_loop_deck (only above y 28)": round(84 - 64.5, 2), "best_roll_edge": round(math.dist((X, Z), bp.BEST_ROLL) - 9, 2),
				"team_altar_edge": round(math.dist((X, Z), bp.ring_spot(7)[0]) - 6.5, 2), "terrace_edge": round(84 - 26, 2),
				"path_edge": round(84 - 7.2, 2)},
		}
		t = bvh(bpy.data.objects["GreatSakura"])
		limits["round_limit_radius"]["great_sakura (any height)"] = round(min(t.find_nearest(Vector((X, -Z, y)))[3] for y in range(1, 50)), 2)
		# from the spawn: what the sky loop and the Saitamo model cover at the altar's distance
		eye = bp.SPAWN_TOP + 5
		limits["spawn_view"] = {"sky_loop_hides_y_at_altar": [round(eye + (y - eye) * 84 / r, 1) for y, r in ((29.55, 64.5), (30.0, 59.5))],
			"saitamo_top_y": 14.2, "saitamo_hides_below_y_at_altar": round(eye + (14.2 - eye) * 84 / 17.05, 1), "saitamo_width_at_altar_if_4_wide": round(4 * 84 / 17.05, 1)}
		for r in rows + [limits]:
			print(json.dumps(r, indent=1))
		with open(os.path.join(OUT, "report.json"), "w") as f:
			json.dump({"limits": limits, "concepts": rows}, f, indent=1)
		return
	top_marks(scene)
	for k in keys:
		for st in states:
			col, *_ = add_concept(k, st == "locked")
			for v in views:
				view(cam, v, k)
				scene.render.filepath = os.path.join(OUT, f"{k}_{NAMES[k]}_{st}_{v}.jpg")
				bpy.ops.render.render(write_still=True)
				print("SHOT", scene.render.filepath, flush=True)
			for o in list(col.objects):
				bpy.data.objects.remove(o)
			bpy.data.collections.remove(col)


if __name__ == "__main__":
	main()
