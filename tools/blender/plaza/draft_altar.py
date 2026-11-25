# Blender DRAFTS of a bigger Sidekick summon altar (owner 2026-11-25): renders only, no export. Headless, from the repo root:
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- ctx            (once: context models)
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- [A B C] [unlocked locked] [view ...]
#   blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_altar.py -- report         (tris, size, clearances)
#   ... -- dusk A [unlocked locked] [view ...]   (World 2's dusk plaza; files end in _dusk)
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
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "world2"))
import build_plaza as bp  # noqa: E402
import plaza_w2 as pw  # noqa: E402  (imported, never edited: World 2's dusk for the _dusk renders)

OUT = os.environ.get("ALTAR_OUT") or os.path.join(bp.ROOT, "assets", "plaza_draft2", "altar")
CTX = os.path.join(bp.ROOT, "build", "altar_ctx")
bp.CHARS = CTX
MYTHIC = "side_general"  # World 2's featured Mythic; display only, the game puts the rotation's own there
X, Z = bp.SIDEKICK_ALTAR
MAT = bp.place(X, Z, bp.TOP, bp.ALTAR_FACE)
tau, cos, sin, rad = math.tau, math.cos, math.sin, math.radians



def ramp15(name, stops):
	"""Eight stops and the seven colours between them: name0 to name14."""
	c = [[int(h[k : k + 2], 16) for k in (1, 3, 5)] for h in stops]
	out = {}
	for k in range(15):
		a, b = c[k // 2], c[min(7, k // 2 + k % 2)]
		out[f"{name}{k}"] = "#%02X%02X%02X" % tuple((x + y) // 2 for x, y in zip(a, b))
	return out


ALT_PAL = {
	"cream": "#F3E6CB", "cream2": "#E2D0AC", "marble": "#D9CDBD", "marble2": "#BFB1A0", "burg": "#6E1B2E", "burg2": "#4A1222", "lacq": "#B3261F",
	"goldd": "#B07F22", "pk0": "#F6D3DF", "pk1": "#FFC9DC", "pk2": "#FF94BC", "pk3": "#E85A97", "pk4": "#B93778", "jade": "#2F8F86", "jade2": "#1F6A68",
	"obs": "#2B2940", "obs2": "#3B3858", "obs3": "#1D1B2E", "iron": "#5A5660", "iron2": "#77727E", "rockp": "#5A4E6E", "rockp2": "#73658A", "leaf": "#4F8A55",
	"off": "#6C6674", "rose": "#B06A7E", "rose2": "#8C4458", "dust0": "#A8949A", "dust1": "#8F7482", "dust2": "#755466", "sil": "#17151E",
	# B's petals, root to tip (cool magenta: clear of the peach sky and the Great Sakura), and the same steps asleep
	**ramp15("lo", ("#FFD0E2", "#FFB0D0", "#FB8CBC", "#F066A6", "#DA4592", "#B82A7C", "#8E1A64", "#5E1048")),
	**ramp15("ld", ("#C9A6B2", "#BA94A2", "#AA8292", "#987083", "#855F73", "#704E62", "#5A3D50", "#46303F")),
}
ALT_GLOW = {
	"g_gold": ("#FFC04A", 1.5), "g_pink": ("#FF6FB0", 1.5), "g_cyan": ("#35D6E6", 1.5), "g_white": ("#FFF3DC", 1.3), "g_vio": ("#A070FF", 1.5),
	"g_paper": ("#FFD89A", 1.0), "g_dim": ("#C98A46", 0.45), "g_cream": ("#FFE9C8", 0.7),
}
bp.PAL.update(ALT_PAL)
bp.GLOW.update(ALT_GLOW)
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

	def lotus(self, ang, base_r, length, width, lean, curl, z, c0, c1, seg=6, thick=0.4, cup=0.3, tip=0.0, band=0.5):
		"""B's petal, one closed shell: a lit centre and two darker flanks inside a flat gold hem, so it needs no edge tube.
		Colour runs step c0 at the root to c1 at the tip (0 to 7); the back is two steps deeper. tip: degrees the last third
		flicks outward. cup: how far the edges fold in."""
		d, s = Vector((cos(ang), sin(ang), 0)), Vector((-sin(ang), cos(ang), 0))
		up = Vector((0, 0, 1))
		p, rows = d * base_r + up * z, []
		for i in range(seg + 1):
			t = i / seg
			th = rad(lean + curl * t + tip * max(0.0, t - 0.66) / 0.34)
			out, along = d * cos(th) - up * sin(th), d * sin(th) + up * cos(th)
			w = width / 2 * max(0.03, math.sin(math.pi * min(1, t * 0.82 + 0.18)) ** 0.8) if i < seg else 0.3
			js = (-1, -max(0.5, 1 - band / w), 0, max(0.5, 1 - band / w), 1)
			th_ = thick * (1 - 0.5 * t)
			fr = [p + s * (w * j) - out * (cup * w * j * j) for j in js]
			fold = out * 0.06 * w  # the midrib, both faces
			fr[2] = fr[2] + fold
			rows.append((fr, [p + s * (w * j) - out * (cup * w * j * j) + out * th_ + fold * (1 - abs(j)) for j in (-1, 0, 1)]))
			p = p + along * (length / seg)
		step = lambda v: f"lo{max(0, min(14, round(2 * v)))}"
		for i in range(seg):
			(a, ab), (b, bb) = rows[i], rows[i + 1]
			v = c0 + (c1 - c0) * (i + 0.5) / seg
			for j in range(4):
				self.face([a[j + 1], a[j], b[j], b[j + 1]], "gold" if j in (0, 3) else step(v + 0.5 * (j == 2)))
			for j in range(2):
				self.face([ab[j], ab[j + 1], bb[j + 1], bb[j]], step(v + 2 + 0.5 * j))
			self.face([a[0], ab[0], bb[0], b[0]], "goldd")
			self.face([ab[2], a[4], b[4], bb[2]], "goldd")
		fr, bk = rows[-1]
		self.face([fr[0], fr[1], fr[2], fr[3], fr[4], bk[2], bk[1], bk[0]][::-1], "goldd")
		fr, bk = rows[0]
		self.face([fr[0], fr[1], fr[2], fr[3], fr[4], bk[2], bk[1], bk[0]], "goldd")

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
		self.orb((x, y - 0.8 * s, z + 0.35 * s), 0.62 * s, dark, 10, 6)  # a plain keyhole: no flower, no mark
		self.box((0.6 * s, 0.6 * s, 1.5 * s), (x, y - 0.8 * s, z - 0.5 * s), dark)


# what each material turns into while the altar is locked
OFF_MAP = {
	"g_gold": "goldd", "g_pink": "off", "g_cyan": "off", "g_white": "off", "g_vio": "off", "g_paper": "shutter", "g_dim": "shutter", "g_cream": "marble2", "rose": "dust1", "rose2": "dust2",
	"pk0": "dust0", "pk1": "dust1", "pk2": "dust2", "pk3": "dust2", "pk4": "dust2", "gold": "goldd", "lamp": "shutter",
	"cream": "marble2", "lacq": "burg2", "burg": "burg2", "jade": "jade2", **{f"lo{k}": f"ld{k}" for k in range(15)},
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
def deck(hw, front, back, fc, bc):
	return [(-hw + fc, front), (hw - fc, front), (hw, front + fc), (hw, back - bc), (hw - bc, back), (-hw + bc, back), (-hw, back - bc), (-hw, front + fc)]


def concept_a(locked):
	body, fx = M("A_Body", locked), M("A_Float", locked)
	m = body
	fronts = (-16.0, -13.0, -10.2)
	z = 0
	for hw, f, back, top, col in ((33.4, fronts[0], 19.2, 1.4, "marble"), (32.2, fronts[1], 18.4, 2.8, "cream"), (31, fronts[2], 17.6, 4.2, "marble")):
		m.prism(deck(hw - 0.35, f + 0.35, back - 0.35, 9, 6), z, top - 0.35, "marble2", "marble2")
		m.prism(deck(hw, f, back, 9, 6), top - 0.35, top, col, "gold")
		z = top
	for f, z0, z1 in zip(fronts, (0, 1.4, 2.8), (1.4, 2.8, 4.2)):
		m.stairs(18, f - 1.8, f, z0, z1, 2, "cream2", "lacq")
	D, sy = 4.2, -0.8
	# the dais: three drums, so the Mythic stands 4.3 over the deck
	m.local = Matrix.Translation((0, sy, 0))
	for r, col, h in ((9.2, "gold", 0.1), (8.8, "burg", 0.18)):
		m.cyl(r, h, (0, 0, D), col, n=24)
	for r, r2, z0, h, col in ((7.8, 7.2, 0, 1.4, "lacq"), (7.4, 7.4, 1.4, 0.35, "g_pink"), (6.6, 5.6, 1.75, 1.6, "gold"), (6.0, 6.8, 3.35, 0.7, "lacq"), (6.8, 6.8, 4.05, 0.3, "g_cream")):
		m.cyl(r, h, (0, 0, D + z0), col, n=16, r2=r2)
	for k in range(12):
		m.petal(k / 12 * tau + math.pi / 2, 5.8, 2.9, 2.6, 40, 18, D + 1.6, ("rose", "rose2"), seg=3, thick=0.2)
	m.local = Matrix.Identity(4)
	size = 25.0
	spot = (0, sy, D + 4.35 + size / 2)
	# folding fan, dimmed: plain pleats, gold ribs, no flowers
	fy, fz, n = 16.4, 19.0, 11
	for k in range(n):
		a0, a1 = rad(30 + 120 * k / n), rad(30 + 120 * (k + 1) / n)
		am = (a0 + a1) / 2
		R = 33.0
		pt = lambda rr, a, dy: (rr * cos(a), fy + dy, fz + rr * sin(a))
		for col, r0, r1 in (("burg2", 14, 22), ("burg", 22, 27), ("rose2", 27, 30.5), ("rose", 30.5, R)):
			for aa, ab, da, db in ((a0, am, 0.9, 0), (am, a1, 0, 0.9)):
				f = [pt(r0, aa, da), pt(r0, ab, db), pt(r1, ab, db), pt(r1, aa, da)]
				m.face(f[::-1], col)
				m.face([(x, yy + 0.5, zz) for x, yy, zz in f], "burg2")
		f = [pt(R, a0, 0.9), pt(R, a1, 0.9), pt(R + 1.5, am, 0.2)]
		m.face(f[::-1], "gold")
		m.face([(x, yy + 0.5, zz) for x, yy, zz in f], "goldd")
	for k in (0, n):
		a0 = rad(30 + 120 * k / n)
		m.tube([pt(12, a0, 0.2), pt(R + 0.6, a0, 0.2)], 0.5, "goldd", 4)
	# the disc behind the model: dark field, one lit ring, standing in a solid plinth
	y, zc = 14.6, D + 4.35 + size / 2 - 0.5
	R = 16.0
	m.ring3((0, y, zc), R, 1.1, "gold", n=36, sides=6)
	m.ring3((0, y - 0.5, zc), R - 1.5, 0.42, "g_pink", n=36, sides=4)
	for r, col, dy in ((R - 0.4, "burg", 0.3), (R - 3.4, "burg2", 0.1)):
		m.face([(r * cos(k / 32 * tau), y + dy, zc + r * sin(k / 32 * tau)) for k in range(32)], col)
	m.face([((R - 0.4) * cos(-k / 32 * tau), y + 0.8, zc + (R - 0.4) * sin(-k / 32 * tau)) for k in range(32)], "burg2")
	m.box((17, 4.4, 2.6), (0, y + 0.6, D + 1.2), "lacq")
	m.box((17.8, 5.0, 0.5), (0, y + 0.6, D + 2.7), "gold")
	# crown: a mast off the fan's apex carries a cradle and the crystal, all joined
	top = fz + 33.0
	m.tube([(0, fy - 0.2, zc + R), (0, fy - 0.2, top - 2), (0, fy + 0.4, top + 3.2)], 1.1, "gold", 8, r1=0.8)
	m.cyl(1.6, 1.4, (0, fy + 0.4, top + 2.4), "gold", n=8, r2=3.4)
	for k in range(4):  # claws of the cradle: from the cup up round the crystal's foot
		a = k / 4 * tau + math.pi / 4
		m.tube([(r * cos(a), fy + 0.4 + r * sin(a), top + h) for r, h in ((2.2, 3.2), (5.8, 5.8), (6.8, 10.0), (5.4, 14.4))], 0.8, "gold", 5, r1=0.15)
	m.gem((0, fy + 0.4, top + 13.0), 5.0, 19.0, "g_pink", n=8)
	# the two pavilions: smaller, set back and turned in
	for s in (-1, 1):
		m.local = Matrix.Translation((s * 24.4, 7.0, 0)) @ Matrix.Rotation(rad(-24 * s), 4, "Z") @ Matrix.Translation((0, 0, D)) @ Matrix.Scale(0.72, 4)
		m.box((14.6, 12.6, 1.2), (0, 0, 0.6), "marble2")
		m.box((13.4, 11.4, 0.5), (0, 0, 1.45), "gold")
		for px in (-5.4, 5.4):
			for py in (-4.4, 4.4):
				m.cyl(1.0, 13, (px, py, 1.7), "lacq", n=8, r2=0.85)
				m.cyl(1.35, 1.1, (px, py, 1.7), "black", n=8)
				m.cyl(0.9, 1.2, (px, py, 13.5), "gold", n=8, r2=1.5)
		m.box((9.6, 7.6, 12.6), (0, 0, 8), "wood")
		for gx in (-2.9, 0, 2.9):
			m.box((2.5, 0.3, 8.6), (gx, -3.9, 8), "g_dim")
			m.box((0.22, 0.4, 8.6), (gx, -4.0, 8), "dark")
			for gz in (5.2, 8, 10.8):
				m.box((2.5, 0.4, 0.22), (gx, -4.0, gz), "dark")
		for sx in (-1, 1):
			m.box((0.3, 5.6, 8.6), (sx * 4.9, 0, 8), "g_dim")
			for gy in (-1.4, 1.4):
				m.box((0.4, 0.22, 8.6), (sx * 5.0, gy, 8), "dark")
		m.box((13, 11, 1.0), (0, 0, 15.1), "lacq")
		m.roof(0, 0, 15.8, 20, 17, 5.2, "tileb", ridge=0.5, lift=3.0, trim="gold", hip_rings=4)
		m.box((8.2, 6.6, 6.4), (0, 0, 23), "wood")
		for gx in (-2, 2):
			m.box((2.8, 0.3, 4), (gx, -3.4, 23.4), "g_dim")
			m.box((0.2, 0.4, 4), (gx, -3.5, 23.4), "dark")
		m.box((10, 8.4, 0.7), (0, 0, 26.3), "lacq")
		m.roof(0, 0, 26.6, 15, 13, 7.4, "tileb", ridge=0.4, lift=2.8, trim="gold", hip_rings=4)
		m.cyl(0.6, 3.0, (0, 0, 34.2), "gold", n=6, r2=0.4)
		m.gem((0, 0, 38.4), 1.3, 3.4, "gold")
		for sx in (-1, 1):  # eave lanterns in place of the rope of lamps
			m.box((0.16, 0.16, 1.6), (sx * 7.4, -6.2, 14.6), "dark")
			m.cyl(0.95, 1.9, (sx * 7.4, -6.2, 11.9), "g_dim", n=8)
			m.cyl(1.1, 0.35, (sx * 7.4, -6.2, 13.7), "gold", n=8)
			m.cyl(1.1, 0.35, (sx * 7.4, -6.2, 11.6), "gold", n=8)
		m.local = Matrix.Identity(4)
		for lx, ly, lz in ((10.8, fronts[0] + 1.4, 1.4), (10.8, fronts[1] + 1.3, 2.8), (26.5, -8.6, 1.4)):
			lantern(m, s * lx, ly, lz, 0.85)
		# four bollards on the deck: the locked chains hang from these
		for bx, by in ((12.5, -6.6), (15.0, 5.0)):
			m.cyl(0.95, 4.4, (s * bx, by, D), "lacq", n=8, r2=0.75)
			m.cyl(1.15, 0.7, (s * bx, by, D + 4.4), "gold", n=8, r2=0.7)
	rng = random.Random(3)
	if not locked:
		for k in range(6):
			a = k / 6 * tau + 0.3
			fx.gem((15.0 * cos(a), 4 + 4.0 * sin(a), D + 8 + 20 * rng.random()), 0.5, 1.6, "g_pink")
	if locked:
		lock = (0, sy - 8.9, D + 2.4)
		for s in (-1, 1):
			m.chain((s * 12.5, -6.6, D + 4.2), (s * 1.0, lock[1], D + 3.8), 1.2, "iron2", 1.7, 0.3)
			m.chain((s * 12.5, -6.6, D + 4.2), (s * 15.0, 5.0, D + 4.2), 1.1, "iron2", 1.7, 0.3)
			m.chain((s * 15.0, 5.0, D + 4.2), (s * (R + 0.3), y - 0.6, zc - 1), 1.0, "iron2", 1.7, 0.3)
			m.orb((s * (R + 0.2), y - 0.6, zc - 1), 1.0, "gold", 8, 4)  # the boss the chain ends in
		m.padlock(lock, 0.85)
	return [body, fx], spot, size, dict(beam=((0, fy + 0.4, top + 16), 140, 4.6, 3.2, "g_pink"), key=True, label=(0, -17.2, 4.0))


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
	# seed pod pedestal, taller than round 5's so the Mythic stands clear of the front petals
	for r0, r1, z0, h, col in ((6.6, 4.8, D, 1.6, "jade2"), (4.8, 6.6, D + 1.6, 4.2, "jade"), (6.9, 6.9, D + 5.8, 0.5, "gold"), (6.2, 6.0, D + 6.3, 0.4, "g_gold")):
		m.cyl(r0, h, (0, 0, z0), col, n=16, r2=r1)
	for k in range(12):
		a = k / 12 * tau + 0.13
		m.gem((6.0 * cos(a), 6.0 * sin(a), D + 4.6), 0.8, 1.6, "g_gold", 6)
	size = 17.5
	spot = (0, 0, D + 6.7 + size / 2)
	front = -math.pi / 2
	delta = lambda a: abs(math.atan2(sin(a - front), cos(a - front)))
	for k in range(14):  # stamens: only behind the pod, never in front of it
		a = front + (k + 0.5) / 14 * tau
		if delta(a) < rad(112):
			continue
		lean = 0.6 if locked else 1.0
		h = 8.5 + (k % 3)
		pts = [(cos(a) * r, sin(a) * r, zz) for r, zz in ((6.9, D), (7.3, D + h * 0.5), (7.3 + 0.8 * lean, D + h))]
		m.tube(pts, 0.4, "gold", 5, r1=0.24)
		m.orb(pts[-1], 0.75, "g_gold", 8, 5)
	if not locked:
		# outer, splayed; toward the front they lie nearly flat, so every approach sees the whole Mythic
		for k in range(13):
			a = front + math.pi / 13 + k / 13 * tau
			dl = delta(a)
			if dl < rad(42):
				continue
			low = dl < rad(100)
			pet.lotus(a, 13.2, 16.5 if low else 17.8, 12.6, 52 if low else 36, 24 if low else 44, 2.3, 1, 5.5, tip=-30 if low else 0)
		for k in range(11):  # middle
			a = front + k / 11 * tau
			dl = delta(a)
			if dl < rad(60):
				continue
			low = dl < rad(102)
			pet.lotus(a, 11.4, (11.0 if dl < rad(80) else 18.0) if low else 24.0, 11.6 if low else 12.8, 46 if low else 26, 20 if low else 32, D - 0.4, 0.5, 5, tip=-16 if low else 0)
		# a deep plum row behind the crown: the dark edge that cuts it out of the sky and the Great Sakura
		for da, L, w in ((-52, 38, 13), (52, 38, 13), (-19, 52, 15), (19, 52, 15)):
			pet.lotus(math.pi / 2 + rad(da), 13.0, L, w, 8 if abs(da) > 50 else 5, 18, D - 0.4, 4.2, 6.6)
		# the crown that frames the model: pale behind it, deep at the tips
		for da, L, w in ((-66, 34, 13), (66, 34, 13), (-36, 44, 14.5), (36, 44, 14.5), (0, 58, 17.5)):
			pet.lotus(math.pi / 2 + rad(da), 10.4, L, w, (2, 6, 19)[(abs(da) > 20) + (abs(da) > 50)], 15.5, D - 0.4, 0, 5.4, seg=9)
		# the halo: one hoop set into the crown on two stems from the pod, not hung in the air
		hz, hy, hr = spot[2] + 1.6, 6.5, 9.7
		m.ring3((0, hy, hz), hr, 0.42, "gold", n=36, sides=6)
		m.ring3((0, hy - 0.42, hz), hr, 0.2, "g_gold", n=36, sides=4)
		for s in (-1, 1):
			m.tube([(s * 5.0, 4.2, D + 5.9), (s * 5.4, hy, hz - sin(math.acos(5.4 / hr)) * hr)], 0.4, "gold", 6)
		for k in range(8):  # dew lights on the halo
			a = k / 8 * tau + tau / 16
			m.gem((hr * cos(a), hy - 0.5, hz + hr * sin(a)), 0.75, 2.0, "g_pink", 6)
	else:
		# the same lotus asleep: a full closed bud as broad as the flower's heart, parted only at the front. The parted lip is
		# short, so the dark Mythic shows from the front and from both sides.
		for da, L, w in ((-72, 54, 17), (72, 54, 17), (-37, 57, 18), (37, 57, 18), (0, 60, 19)):
			pet.lotus(math.pi / 2 + rad(da), 11.6, L, w, 36, -100, D - 0.4, 0.6, 5.0, seg=9, cup=0.34, tip=6)
		for da, L, w in ((-54, 36, 15), (54, 36, 15), (-18, 40, 16), (18, 40, 16)):
			pet.lotus(math.pi / 2 + rad(da), 13.6, L, w, 37, -66, 2.0, 1.4, 5.2, seg=7, cup=0.36, tip=16)
		for da, L in ((-104, 12.5), (104, 12.5), (-82, 18), (82, 18)):
			pet.lotus(math.pi / 2 + rad(da), 13.6, L, 11.5, 36, -46, 2.3, 2.0, 4.6, seg=5, cup=0.36)
		for da in (-128, 128):
			pet.lotus(math.pi / 2 + rad(da), 11.0, 6.5, 8.0, 28, -40, D - 0.4, 2.0, 4.0, seg=4, cup=0.36)
	# sepals under the outer layer
	for k in range(16):
		a = front + k / 16 * tau
		if delta(a) < rad(30):
			continue
		pet.petal(a, 15.6, 8.0, 5.2, 66, 34, 1.4, ("jade", "jade2"), seg=4, thick=0.25)
	# bud lamps at the sides, on their own lily pads
	for s in (-1, 1):
		for lx, ly, r in ((25.5, -8.5, 3.6), (30.5, 1.5, 2.6)):
			m.cyl(r, 0.5, (s * lx, ly, 0), "jade2", n=12)
			m.cyl(r * 0.92, 0.2, (s * lx, ly, 0.5), "jade", n=12)
			m.tube([(s * lx, ly, 0.5), (s * (lx + 0.3), ly, 2.6)], 0.45, "jade2", 6)
			m.local = Matrix.Translation((s * lx, ly, 0))
			for k in range(6):
				m.lotus(k / 6 * tau, 0.7, r * 1.1, r * 0.8, 22 if not locked else 4, 24 if not locked else -26, 2.4, 2, 5, seg=3, thick=0.2, band=0.14)
			m.local = Matrix.Identity(4)
			m.orb((s * lx, ly, 4.0), 0.9, "g_pink", 6, 4)
		# two bollards beside the stairs: the locked chain hangs from them
		m.cyl(0.95, 3.6, (s * 8.2, -11.4, 2.4), "burg", n=8, r2=0.75)
		m.cyl(1.2, 0.7, (s * 8.2, -11.4, 6.0), "gold", n=8, r2=0.7)
	if locked:
		for s in (-1, 1):
			m.chain((s * 8.0, -11.9, 5.7), (s * 1.3, -13.6, 5.1), 0.9, "iron2", 1.5, 0.27)
		m.padlock((0, -13.6, 3.6), 0.75)
	return [body, pet, fx], spot, size, dict(beam=((0, 7.9, D + 6.2), 110, 4.0, 2.4, "g_pink"), key=0.3, label=(0, -12.8, 9.4))


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


def context_scene(dusk=False):
	teardown()
	if dusk:
		pw.reset(pw.VARIANTS["B"])
		bp.PAL.update(ALT_PAL)
		bp.GLOW.update(ALT_GLOW)
	scene = bpy.context.scene
	cam = bp.setup_world(scene)
	scene.render.resolution_x, scene.render.resolution_y = 1280, 720
	scene.render.threads_mode, scene.render.threads = "FIXED", 2
	scene.render.image_settings.quality = 88
	cam.data.clip_start = 0.3
	if hasattr(scene, "eevee"):
		scene.eevee.taa_render_samples = 24
	bp.build(scene)
	if dusk:  # as plaza_w2's Rift Shrine variant
		pw.build_track.bloom(scene)
		pw.sky(scene, pw.VARIANTS["B"])
		w2 = bpy.data.collections.new("World2")
		scene.collection.children.link(w2)
		for m in pw.accents() + [pw.world_gate(), pw.sensei_standin(), pw.rift(pw.VARIANTS["B"])] + pw.islands():
			m.build(w2)
		for x, z in pw.lantern_spots():
			pw.point(w2, (x, bp.TOP + 5, z), "#FFB765", pw.VARIANTS["B"]["lamp_w"])
		rx, rz = bp.along(bp.AXIS_LEN + 80)
		pw.point(w2, (rx, 70, rz), "#7A7CFF", 80000, 20)
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
		if info.get("key"):  # the second light of the budget: both aimed at the Mythic, so it is the brightest thing here
			for lx, e in ((-9, 32000 * info["key"]), (10, 26000 * info["key"])):
				k = bpy.data.objects.new("FX_Key", bpy.data.lights.new("FX_Key", "SPOT"))
				k.data.energy, k.data.color, k.data.spot_size, k.data.spot_blend, k.data.shadow_soft_size = e, (1.0, 0.93, 0.9), rad(54), 0.5, 1.0
				k.data.use_shadow = False
				w = MAT @ Vector((spot[0] + lx, spot[1] - 24, spot[2] + 8))
				k.matrix_world = Matrix.Translation(w) @ ((MAT @ Vector(spot)) - w).to_track_quat("-Z", "Y").to_matrix().to_4x4()
				col.objects.link(k)
			lt.data.energy = 0
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
		text(col, "Rebirth 2\n(game label)", info.get("label", (spot[0], spot[1] - 9.5, spot[2] - half - 1.4)), 1.7 if "label" in info else 2.4, "#FFFFFF", "UI_RebirthLabel")
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
		eye, look, fov = rbx((0, -80, 20)), rbx((0, 0, 31 if key == "A" else 26.5)), 56 if key == "A" else 50
	elif name == "threeq":
		eye, look, fov = rbx((56, -36, 25)), rbx((0, 2, 32 if key == "A" else 24)), 74 if key == "A" else 62  # outside the loop
	elif name == "close" and key == "A":
		eye, look, fov = rbx((13, -27.5, 12)), rbx((0, 0, 14)), 80
	elif name == "close":
		eye, look, fov = rbx((7.5, -19, 9.5)), rbx((0, 2, 15.5)), 70
	elif name in ("spawn", "option_statue8", "spawn_nostatue"):  # a 70 degree Roblox camera 12 behind and 4 above a player on the walk spawn, turned to the altar
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


def statue_option(cam, gone=False):
	"""OWNER OPTION render only: the Saitamo pedestal 8 studs along its own step, toward Best Roll. Undone after the shot.
	gone (owner 2026-11-25: the statue may move; layout pending): it is far below the floor instead."""
	turn = Matrix.Rotation(2 * math.asin(4 / math.hypot(*bp.PEDESTAL[:2])), 4, "Z")
	out = []
	for o in bpy.context.scene.objects:
		if o.name.startswith(("LegendPedestal", "Exclusive_")):
			out.append((o, o.matrix_world.copy()))
			o.matrix_world = Matrix.Translation((0, 0, -500)) @ o.matrix_world if gone else turn @ o.matrix_world
	cu = bpy.data.curves.new("OptText", "FONT")
	cu.body, cu.size, cu.align_x = "OWNER OPTION: statue moved 8 studs aside (not in the normal set)", 0.034, "CENTER"
	if gone:
		cu.body = "LAYOUT PENDING: statue removed for this view only"
	cu.materials.append(plain("T_#101018", "#101018", True))
	t = bpy.data.objects.new("OptText", cu)
	t.matrix_world = Matrix.Translation(cam.location) @ cam.rotation_euler.to_matrix().to_4x4() @ Matrix.Translation((0, 0.62, -1))
	bpy.context.scene.collection.objects.link(t)
	out.append((t, None))
	return out


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
	views = [a for a in argv if a in ("front", "threeq", "close", "spawn", "spawnside", "top", "option_statue8", "spawn_nostatue")] or ["front", "threeq", "close", "spawn", "spawnside", "top"]
	dusk = "_dusk" if "dusk" in argv else ""
	scene, cam = context_scene(bool(dusk))
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
				extra = statue_option(cam, v == "spawn_nostatue") if v in ("option_statue8", "spawn_nostatue") else []
				scene.render.filepath = os.path.join(OUT, f"{k}_{NAMES[k]}_{st}_{v}{dusk}.jpg")
				bpy.ops.render.render(write_still=True)
				print("SHOT", scene.render.filepath, flush=True)
				for o, mw in extra:
					if mw is None:
						bpy.data.objects.remove(o)
					else:
						o.matrix_world = mw
			for o in list(col.objects):
				bpy.data.objects.remove(o)
			bpy.data.collections.remove(col)


if __name__ == "__main__":
	main()
