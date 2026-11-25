"""Blender DRAFTS (renders only) of the plaza's markets and merchants (owner 2026-11-25; design doc 4.24, 4.43, 4.47).

Nothing here ships: no export, no upload, no game data. build_plaza.py and plaza_w2.py are imported, never edited.
  A  Dojo market: the plaza's own wood, tile, plaster and silk, in World 1's golden hour.
  B  Rift-shrine market: dark stone, crystal, vermilion and cyan seams, in World 2's dusk.
  C  current: today's meshes, same cameras, for comparison.
Headless: blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_markets.py -- [A B C] [shot-prefix ...] [--tris]
Writes assets/plaza_draft2/markets/<A|B|C>/<piece>_<shot>.jpg and prints every piece's tris and size.

Fixed (checked by check() for every piece): positions and facing, the counter where the prompt part stands, the floor
edge (x +-94, z +-110), nothing in the sky loop's ribbon or posts, every roof no higher than today's (the floating headers
stay where they are), the flat sign boards where the game writes its text (left blank here: no modelled text).
One building per service (4.24: no vendor stalls, no courtyard). Merchants are generic, original people.

RUBRIC (written before any geometry; each 0 to 10, a draft passes at 8 on all, judged on the renders only)
  1 Read from spawn   84 studs away at fov 70 the service is guessable without the header (silhouette plus goods).
  2 Distinct          the four buildings differ in silhouette, not only in colour; A and B differ as concepts.
  3 Merchant          a person is visible from the front, faces the player, reads as that trade, blocky house style.
  4 Detail close up   at 12 studs there is something to look at; nothing floats by accident, pokes through or z-fights.
  5 Fit               belongs beside the torii, terrace and (B) the rift; scale right beside a 5.5-stud player.
  6 Rules             header, sign, prompt and floor limits kept; no text, logo, real name or known character.
  7 Cost              at most 4,500 tris a building and 900 a merchant (proposed), few glow colours per piece.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "world2"))

import build_plaza as bp  # noqa: E402
import plaza_w2 as pw  # noqa: E402

OUT = os.path.join(bp.ROOT, "assets", "plaza_draft2", "markets")
R3 = lambda deg, ax: Matrix.Rotation(math.radians(deg), 3, ax)
TAU = math.tau

PAL = {
	"plaster": "#EFE6D2", "plaster2": "#DCCFB4", "iron": "#3A3C46", "copper": "#B8693A", "leather": "#7A4A2C", "herb": "#6E9A48",
	"herb2": "#93A852", "skin": "#F0C8A0", "skin2": "#C98F62", "skin3": "#E2B088", "white": "#F2F0EA", "ink": "#25212B",
	"hairb": "#3A2A24", "hairg": "#A9A7AE", "hairr": "#8A3A22", "hairv": "#54407C", "hairw": "#E9E6EE", "navy": "#28304E",
	"silk": "#6A35A6", "silk2": "#8E55C8", "cream": "#F3E3BC", "rose": "#B8456A", "olive": "#5F6B3A", "basalt": "#4A4F68",
	"basalt2": "#5C6280", "basalt3": "#383C52", "indigo": "#34407A", "indigo2": "#283260", "mist": "#A8B4D8", "geode": "#2E4F9E",
	"slate": "#59617A", "sun": "#E26A3C", "hill": "#8FA67C", "hill2": "#B9C49A", "dummy": "#4C8FD0", "dummy2": "#2F5F92", "ochre": "#C98A34", "stele": "#8E97BE", "stele2": "#A7B0D2",
}
GLOW = {
	"g_blue": ("#3C9BFF", 1.5), "g_mag": ("#FF4FB8", 1.5), "g_green": ("#46E08A", 1.4), "g_amber": ("#FFB040", 1.4),
	"g_violet": ("#9A63FF", 1.6), "g_cyan": ("#3CE6FF", 1.9),
}


# --- Kit -------------------------------------------------------------------------------------------------------------
class K(bp.M):
	def taper(self, a, b, wa, wb, material, sides=4, roll=None):
		"""A frustum from a to b, widths wa and wb; 4 sides give a square section."""
		a, b = Vector(a), Vector(b)
		d = (b - a).normalized()
		ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
		u = (ref - d * ref.dot(d)).normalized()
		v = d.cross(u)
		off = math.pi / sides if roll is None else roll
		k = math.sqrt(2) if sides == 4 else 1
		ring = lambda c, w: [c + (u * math.cos(i / sides * TAU + off) + v * math.sin(i / sides * TAU + off)) * w / 2 * k for i in range(sides)]
		ra, rb_ = ring(a, wa), ring(b, wb)
		for i in range(sides):
			j = (i + 1) % sides
			self.face([ra[i], ra[j], rb_[j], rb_[i]], material)
		self.face(ra[::-1], material)
		if wb > 0.01:
			self.face(rb_, material)

	def lathe(self, prof, c, material, n=8, mats=None):
		"""Revolve [(r, z), ...] about the vertical through c; mats gives a material per band."""
		cx, cy, cz = c
		for i in range(len(prof) - 1):
			(r0, z0), (r1, z1) = prof[i], prof[i + 1]
			mt = mats[i] if mats else material
			pt = lambda r, z, k: (cx + r * math.cos(k / n * TAU + TAU / 2 / n), cy + r * math.sin(k / n * TAU + TAU / 2 / n), cz + z)
			for k in range(n):
				if r0 < 0.01:
					self.face([pt(0, z0, 0), pt(r1, z1, k + 1), pt(r1, z1, k)], mt)
				elif r1 < 0.01:
					self.face([pt(r0, z0, k), pt(r0, z0, k + 1), pt(0, z1, 0)], mt)
				else:
					self.face([pt(r0, z0, k), pt(r0, z0, k + 1), pt(r1, z1, k + 1), pt(r1, z1, k)], mt)

	def gem(self, c, r, up, down, material, n=6):
		self.lathe([(0, -down), (r, 0), (0, up)], c, material, n)

	def crystal(self, a, d, r, ln, material, n=5):
		"""A shard standing on a along direction d."""
		a, d = Vector(a), Vector(d).normalized()
		self.taper(a, a + d * ln * 0.65, r * 1.5, r * 2, material, n)
		self.taper(a + d * ln * 0.65, a + d * ln, r * 2, 0, material, n)

	def ball(self, r, c, material):
		self.blob(r, c, material, squash=1, jitter=0)

	def ydisc(self, r, c, depth, material, n=16):
		self.taper((c[0], c[1] + depth / 2, c[2]), (c[0], c[1] - depth / 2, c[2]), r * 2, r * 2, material, n)

	def plate(self, pts, depth, material):
		"""An upright polygon [(x, z)] extruded in y from -depth/2 to depth/2 about y = self.py."""
		y0, y1 = self.py - depth / 2, self.py + depth / 2
		n = len(pts)
		self.face([(x, y0, z) for x, z in pts], material)
		self.face([(x, y1, z) for x, z in pts][::-1], material)
		for i in range(n):
			(xa, za), (xb, zb) = pts[i], pts[(i + 1) % n]
			self.face([(xa, y0, za), (xa, y1, za), (xb, y1, zb), (xb, y0, zb)], material)

	py = 0.0

	def strip(self, rows, material, alt=None):
		"""A two-sided cloth through rows of points [[p, p], ...]; alt alternates the columns' material."""
		for a, b in zip(rows, rows[1:]):
			for k in range(len(a) - 1):
				mt = alt if alt and k % 2 else material
				self.face([a[k], a[k + 1], b[k + 1], b[k]], mt)
				self.face([b[k], b[k + 1], a[k + 1], a[k]], mt)

	def gable(self, cx, cy, z, w, d, h, material, trim, lift=0.9, ribs=10, segx=6, segt=3, end="plaster"):
		"""A straight gable, ridge along x, concave slopes, upturned corners, tile ribs, filled gable ends."""
		def p(x, t, s, dz=0.0):
			e = (abs(x) / (w / 2)) ** 3
			return (cx + x, cy + s * d / 2 * t, z + h * (1 - t) ** 1.35 + lift * e * t * t + dz)
		xs = [-w / 2 + w * i / segx for i in range(segx + 1)]
		ts = [i / segt for i in range(segt + 1)]
		for s in (-1, 1):
			for i in range(segx):
				for j in range(segt):
					q = [p(xs[i], ts[j], s), p(xs[i + 1], ts[j], s), p(xs[i + 1], ts[j + 1], s), p(xs[i], ts[j + 1], s)]
					self.face(q, material)
					self.face([(a, b, c - 0.45) for a, b, c in q][::-1], "dark")
				a, b = p(xs[i], 1, s), p(xs[i + 1], 1, s)
				self.face([a, b, (b[0], b[1], b[2] - 0.45), (a[0], a[1], a[2] - 0.45)], trim)
			for k in range(ribs):
				x = -w / 2 + 0.7 + (w - 1.4) * k / (ribs - 1)
				for j in range(segt):
					a, b = p(x, ts[j], s, 0.02), p(x, ts[j + 1], s, 0.02)
					q = lambda o, q_: (q_[0] + o, q_[1], q_[2])
					ta, tb = (a[0], a[1], a[2] + 0.24), (b[0], b[1], b[2] + 0.24)
					self.face([q(-0.17, a), ta, tb, q(-0.17, b)], "tile2" if material != "tile2" else "tile")
					self.face([ta, q(0.17, a), q(0.17, b), tb], "tile2" if material != "tile2" else "tile")
			for sx in (-1, 1):  # bargeboards
				for j in range(segt):
					self.beam(p(sx * w / 2, ts[j], s, 0.05), p(sx * w / 2, ts[j + 1], s, 0.05), 0.7, trim)
		for sx in (-1, 1):
			x = sx * (w / 2 - 1.3)
			pts = [p(x, t, -1, -0.4) for t in ts[::-1]] + [p(x, t, 1, -0.4) for t in ts[1:]]
			low = min(q[2] for q in pts)
			self.face(pts if sx > 0 else pts[::-1], end)
			self.box((0.4, 0.5, h * 0.7), (cx + x + sx * 0.1, cy, z + h * 0.45), "dark")
		self.box((w + 0.4, 1.0, 0.7), (cx, cy, z + h + 0.1), trim)
		for sx in (-1, 1):
			self.box((0.8, 1.3, 1.1), (cx + sx * (w / 2 + 0.1), cy, z + h + 0.2), trim)

	def lantern(self, c, r=0.6, cloth="red", glow="lamp"):
		"""A hanging paper lantern, its top at c."""
		x, y, z = c
		self.box((0.08, 0.08, 0.6), (x, y, z + 0.2), "ink")
		self.lathe([(r * 0.5, 0), (r * 0.55, -0.18)], (x, y, z), "ink", 8)
		self.lathe([(r * 0.55, -0.18), (r, -0.6), (r, -1.2), (r * 0.55, -1.6)], (x, y, z), glow, 8, [cloth, glow, cloth])
		self.lathe([(r * 0.55, -1.6), (r * 0.4, -1.8), (0, -1.8)], (x, y, z), "ink", 8)

	def board(self, x, y, z, w, h, face="black", frame="gold"):
		"""A blank flat sign board: the game writes its text on it."""
		self.box((w, 0.4, h), (x, y, z), frame)
		self.box((w - 0.5, 0.56, h - 0.5), (x, y, z), face)

	def crate(self, c, s, body="plank", band="dark"):
		x, y, z = c
		self.box((s, s, s * 0.8), (x, y, z + s * 0.4), body)
		for k in (-1, 1):
			self.box((0.16, s + 0.1, s * 0.82), (x + k * s * 0.36, y, z + s * 0.41), band)

	def coins(self, c, r, count):
		"""A flat-topped stack of coins."""
		self.cyl(r * 1.15, 0.12 * count, c, "gold", n=6)

	def chest(self, c, w, body, glow=None, d=1.5, open_=False):
		x, y, z = c
		self.box((w, d, 0.9), (x, y, z + 0.45), body)
		for k in (-1, 1):
			self.box((0.2, d + 0.12, 1.0), (x + k * w * 0.36, y, z + 0.5), "gold")
		if open_:
			self.box((w - 0.3, d - 0.3, 0.2), (x, y, z + 0.9), "gold")
			self.box((w, 0.3, 1.2), (x, y + d / 2 + 0.2, z + 1.35), body, R3(-18, "X"))
			for i in range(5):
				self.coins((x - w * 0.3 + w * 0.15 * i, y + (0.2 if i % 2 else -0.15), z + 1.0), 0.26, 2 - i % 2)
		else:
			for i in range(3):  # a rounded lid in three facets
				a0, a1 = math.pi * i / 3, math.pi * (i + 1) / 3
				f = lambda a, xx: (xx, y - math.cos(a) * d / 2, z + 0.9 + math.sin(a) * 0.5)
				self.face([f(a0, x - w / 2), f(a0, x + w / 2), f(a1, x + w / 2), f(a1, x - w / 2)], body)
			for k in (-1, 1):
				self.face([(x + k * w / 2, y - math.cos(math.pi * i / 3) * d / 2, z + 0.9 + math.sin(math.pi * i / 3) * 0.5) for i in range(4)], body)
			self.box((0.4, 0.16, 0.5), (x, y - d / 2 - 0.05, z + 0.85), glow or "gold")

	def flask(self, c, s, glow, kind=0):
		prof = (
			[(0.2, 0), (0.6, 0.15), (0.62, 0.6), (0.22, 1.0), (0.2, 1.3)],
			[(0.45, 0), (0.45, 0.9), (0.2, 1.15), (0.2, 1.4)],
			[(0.65, 0), (0.2, 1.0), (0.2, 1.35)],
		)[kind % 3]
		prof = [(r * s, z * s) for r, z in prof]
		self.lathe([(0, 0)] + prof, c, glow, 7, [glow] * (len(prof) - 1) + ["white"])
		self.cyl(0.24 * s, 0.22 * s, (c[0], c[1], c[2] + prof[-1][1]), "wood", n=6)


# --- Merchants: generic, original people in the house style (chunky, blocky, head about a third of the height) --------
BROWS = {  # angle (positive: outer end down), height, thickness; "raised" lifts the right one
	"soft": (9, 0.5, 0.12), "flat": (0, 0.45, 0.16), "high": (4, 0.56, 0.1), "raised": (3, 0.46, 0.13), "bushy": (12, 0.46, 0.24), "firm": (-9, 0.42, 0.15),
}


def figure(m, at, s, yaw=0, height=5.5):
	"""s keys: skin, top, legs, trim, sash, boots, robe, hair, style, hat, l/r hand targets; face: brow, mouth, eyes; build:
	bulk (width), tall (body stretch, the head keeps its size), belly."""
	k = height / 5.5
	old = m.local
	base = old @ Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4)
	g = s.get
	tall = g("tall", 1.0)
	m.local = base @ Matrix.Diagonal((1, 1, tall, 1))
	skin, top, trim = s["skin"], s["top"], s["trim"]
	bulk = g("bulk", 1.0)
	if g("robe"):
		m.taper((0, 0, 0.12), (0, 0, 1.75), 2.3 * bulk, 1.75 * bulk, s["legs"])
		m.taper((0, 0, 0.1), (0, 0, 0.34), 2.36 * bulk, 2.32 * bulk, trim)
		m.box((0.3, 0.1, 1.5), (0, -1.02 * bulk, 0.95), trim, R3(-9, "X"))
		for x in (-0.45, 0.45):
			m.box((0.7, 0.9, 0.2), (x, -0.75, 0.1), s["boots"])
	else:
		for x in (-0.52, 0.52):
			m.taper((x * bulk, 0, 0.45), (x * bulk, 0, 1.75), 0.86, 0.96, s["legs"])
			m.box((0.9, 1.2, 0.5), (x * bulk, -0.12, 0.25), s["boots"])
			m.box((0.96, 1.0, 0.16), (x * bulk, 0, 0.55), trim)
	# torso: two stacked blocks, overlapping collar, sash and knot
	m.box((1.75 * bulk, 1.1 * bulk, 0.9), (0, 0, 2.1), top)
	m.box((2.0 * bulk, 1.16 * bulk, 1.1), (0, 0, 2.95), top)
	fy = -0.6 * bulk
	if g("belly"):
		m.box((1.6 * bulk, 0.5, 1.0), (0, fy - 0.05, 2.2), top)
		fy -= 0.16
	for sx in (-1, 1):
		m.box((0.26, 0.12, 1.45), (sx * 0.3, fy, 2.85), trim, R3(sx * 22, "Y"))
	m.box((0.5, 0.1, 0.4), (0, fy + 0.02, 3.32), skin)
	m.box((1.84 * bulk, 1.2 * bulk, 0.42), (0, 0, 1.82), s["sash"])
	if not g("apron"):
		m.box((0.5, 0.24, 0.5), (0.45, fy - 0.06, 1.82), s["sash"])
		m.box((0.26, 0.12, 0.75), (0.4, fy - 0.08, 1.4), s["sash"], R3(8, "Y"))
	else:
		m.box((1.35 * bulk, 0.1, 1.7), (0, fy - 0.2, 1.5), s["apron"])
		m.box((1.0 * bulk, 0.1, 0.9), (0, fy - 0.2, 2.7), s["apron"])
		m.box((0.7, 0.14, 0.45), (0, fy - 0.24, 1.5), trim)
	# arms: shoulder, elbow, hand; wide sleeves
	for sx, key in ((-1, "l"), (1, "r")):
		sh = Vector((sx * 1.2 * bulk, 0, 3.2))
		hand = Vector(g(key) or (sx * 1.45, -0.15, 1.75))
		mid = (sh + hand) / 2 + Vector((sx * 0.32, 0.22, -0.18))
		m.taper(sh + Vector((-sx * 0.1, 0, 0.22)), mid, 0.82, 0.72, top)
		wr = mid.lerp(hand, 0.72)
		m.taper(mid, wr, 0.74, 0.92, top)
		m.taper(mid.lerp(hand, 0.64), mid.lerp(hand, 0.76), 0.96, 0.98, trim)
		m.box((0.52, 0.52, 0.52), hand, skin)
	if g("prop"):
		g("prop")(m, s)
	# head: tapered to the chin, its size kept whatever the build
	m.local = base @ Matrix.Translation((0, 0, 3.6 * (tall - 1)))
	m.box((0.6, 0.6, 0.3), (0, 0, 3.58), skin)
	hz = 3.66
	jaw = g("jaw", 1.18)
	m.taper((0, 0, hz), (0, 0, hz + 0.45), jaw, 1.5, skin)
	m.box((1.5, 1.5, 0.95), (0, 0, hz + 0.92), skin)
	f, ey = -0.77, hz + 0.72
	ang, up, th = BROWS[g("brow", "flat")]
	for sx in (-1, 1):
		x = sx * 0.36
		eyes = g("eyes", "open")
		if eyes == "closed":  # two facets of a smiling closed eye
			for q in (-1, 1):
				m.box((0.22, 0.06, 0.09), (x + q * 0.09, f, ey + 0.02), "ink", R3(q * 22, "Y"))
		else:
			h = {"open": 0.4, "narrow": 0.24, "round": 0.46}[eyes]
			m.box((0.4, 0.04, h), (x, f, ey), "white")
			m.box((0.24, 0.05, h - 0.04), (x - sx * 0.03, f - 0.02, ey - 0.01), g("iris") or "hairb")
			m.box((0.1, 0.06, 0.12), (x - sx * 0.08, f - 0.04, ey + h * 0.25), "white")
			m.box((0.48, 0.07, 0.08), (x, f - 0.02, ey + h / 2 + 0.03), "ink", R3(sx * ang * 0.5, "Y"))
		lift = 0.14 if g("brow") == "raised" and sx > 0 else 0
		m.box((0.46, 0.08, th), (x, f - 0.03, ey + up + lift), g("browc") or s["hair"], R3(sx * ang, "Y"))
		if g("glasses"):
			for q in (-1, 1):  # square frames
				m.box((0.56, 0.06, 0.07), (x, f - 0.09, ey + q * 0.28), s["glasses"])
				m.box((0.07, 0.06, 0.56), (x + q * 0.27, f - 0.09, ey), s["glasses"])
		m.box((0.2, 0.4, 0.42), (sx * 0.82, 0.05, ey - 0.05), skin)
	nose = g("nose", 0.14)
	m.box((nose, 0.16, 0.18), (0, f - 0.03, ey - 0.24), skin)
	mz, mo = ey - 0.48, g("mouth", "smile")
	if mo == "smile":
		m.box((0.34, 0.05, 0.08), (0, f + 0.07, mz), "rose")
		for sx in (-1, 1):
			m.box((0.14, 0.05, 0.08), (sx * 0.22, f + 0.06, mz + 0.04), "rose", R3(sx * -35, "Y"))
	elif mo == "grin":
		m.box((0.6, 0.05, 0.2), (0, f + 0.05, mz + 0.02), "ink")
		m.box((0.52, 0.06, 0.09), (0, f + 0.04, mz + 0.06), "white")
	elif mo == "smirk":
		m.box((0.4, 0.05, 0.08), (0.06, f + 0.06, mz + 0.02), "rose", R3(-14, "Y"))
	elif mo == "small":
		m.box((0.2, 0.05, 0.09), (0, f + 0.07, mz), "rose")
	elif mo == "flat":
		m.box((0.36, 0.05, 0.07), (0, f + 0.07, mz), "ink")
	hairdo(m, s, hz)
	hat(m, s, hz)
	m.local = old


def hairdo(m, s, hz):
	h, st = s["hair"], s.get("style")
	tip = lambda a, b, w: m.taper(a, b, w, 0.02, h)
	topz = hz + 1.4
	if st in ("crop", "topknot", "lowbun", "bob"):
		m.box((1.66, 1.35, 0.45), (0, 0.16, topz), h)
		m.box((1.66, 0.5, 1.2), (0, 0.66, topz - 0.6), h)
		for sx in (-1, 1):
			m.box((0.2, 0.9, 0.75), (sx * 0.8, 0.3, topz - 0.3), h)
	if st == "crop":  # short and blocky, a straight edge
		m.box((1.5, 0.3, 0.26), (0, -0.62, topz + 0.06), h)
	if st == "topknot":
		m.taper((0, 0.35, topz + 0.2), (0, 0.5, topz + 0.5), 0.5, 0.4, h, 6)
		m.box((0.46, 0.46, 0.14), (0, 0.45, topz + 0.36), "ink")
	if st == "lowbun":  # parted in the middle, a round bun low at the back, a wooden comb
		for sx in (-1, 1):
			m.box((0.86, 0.24, 0.24), (sx * 0.4, -0.66, topz + 0.06), h, R3(sx * 14, "Y"))
		m.gem((0, 1.2, topz - 0.35), 0.62, 0.5, 0.5, h, 7)
		m.box((0.7, 0.12, 0.2), (0, 0.5, topz + 0.28), "copper")
	if st == "bob":  # a plain chin-length cut
		for sx in (-1, 1):
			m.box((0.3, 1.2, 1.5), (sx * 0.86, 0.3, topz - 0.8), h)
	if st == "braid":
		for sx in (-1, 1):
			tip((sx * 0.2, -0.72, topz - 0.02), (sx * 0.7, -0.84, topz - 0.42), 0.4)
		p = Vector((0.75, -0.2, hz + 0.5))
		for i in range(5):
			q = p + Vector((0.07, -0.16, -0.5))
			m.taper(p, q, 0.5 - 0.04 * i, 0.4 - 0.04 * i, h if i < 4 else s["trim"], 5)
			p = q
	if st == "fringe":  # under a hat: side locks only
		for sx in (-1, 1):
			m.box((0.22, 0.5, 1.0), (sx * 0.82, -0.3, topz - 0.6), h)
		m.box((1.5, 0.3, 1.0), (0, 0.74, topz - 0.6), h)
	if st == "chops":  # mutton chops
		for sx in (-1, 1):
			m.box((0.24, 0.7, 0.9), (sx * 0.76, -0.4, hz + 0.45), h)
	b = s.get("beard")
	if b == "moustache":
		for sx in (-1, 1):
			m.box((0.48, 0.16, 0.2), (sx * 0.22, -0.84, hz + 0.36), h, R3(sx * 14, "Y"))
	elif b:
		m.taper((0, -0.56, hz + 0.12), (0, -0.7, hz + 0.1 - b), 0.95, s.get("beardw", 0.3), h)
		for sx in (-1, 1):
			m.box((0.44, 0.14, 0.14), (sx * 0.22, -0.82, hz + 0.36), h, R3(sx * 20, "Y"))


def hat(m, s, hz):
	st, a, b = s.get("hat"), s.get("hat_a"), s.get("hat_b")
	z = hz + 1.25
	if st == "wrap":  # a tied headcloth
		m.box((1.72, 1.72, 0.3), (0, 0.04, z + 0.16), a)
		m.box((0.36, 0.3, 0.46), (0.5, 1.0, z + 0.16), a)
	if st == "cone":  # a straw rain hat
		m.lathe([(1.85, 0), (1.5, 0.28), (0, 1.05)], (0, 0, z + 0.06), a, 12)
		m.lathe([(0, 0.1), (1.85, 0)], (0, 0, z + 0.06), b, 12)
	if st == "kerchief":  # a folded cloth over the hair, knotted behind
		m.taper((0, 0.1, z - 0.02), (0, 0.2, z + 0.5), 1.78, 1.3, a)
		m.taper((0, 0.9, z + 0.1), (0, 1.5, z - 0.4), 0.5, 0.2, a)
	if st == "skullcap":  # a leather work cap with a stitched band
		m.taper((0, 0.04, z + 0.1), (0, 0.04, z + 0.46), 1.66, 1.5, a)
		m.box((1.2, 1.2, 0.2), (0, 0.04, z + 0.52), a)
		m.box((1.72, 1.72, 0.18), (0, 0.04, z + 0.16), b)
	if st == "cap":  # a soft scholar's cap
		m.box((1.7, 1.6, 0.34), (0, 0.06, z + 0.16), a)
		m.box((1.5, 0.9, 0.55), (0, 0.35, z + 0.55), a)
		m.box((1.74, 1.64, 0.14), (0, 0.06, z - 0.02), b)
	if st == "tallcap":  # a pleated cloth cap
		m.taper((0, 0.1, z), (0, 0.2, z + 0.55), 1.62, 1.3, a)
		m.box((1.68, 1.68, 0.16), (0, 0.04, z + 0.02), b)
	if st == "hood":
		m.taper((0, 0.16, hz + 1.2), (0, 0.5, hz + 2.2), 1.86, 0.5, a)
		m.box((1.84, 0.36, 1.5), (0, 0.8, hz + 0.6), a)
		for sx in (-1, 1):
			m.box((0.24, 1.7, 1.45), (sx * 0.94, 0.06, hz + 0.62), a)
			m.box((0.28, 0.16, 1.45), (sx * 0.92, -0.82, hz + 0.62), b)
		m.box((2.06, 0.2, 0.26), (0, -0.84, hz + 1.42), b)
	if st == "brim":  # a wide flat festival hat
		m.lathe([(0, 0), (1.75, 0), (1.75, 0.14), (0.8, 0.2), (0.7, 0.65), (0, 0.75)], (0, 0, z + 0.04), a, 10, [b, b, a, a, a])
		m.lathe([(0.82, 0.2), (0.8, 0.36)], (0, 0, z + 0.04), b, 10)


def p_purse(m, s):
	"""A tied coin purse on the palm."""
	m.lathe([(0.2, 0), (0.5, 0.2), (0.45, 0.6), (0.16, 0.8), (0.3, 1.0)], (0.75, -1.3, 2.5), "leather", 7)
	m.taper((0.75, -1.3, 3.26), (0.75, -1.3, 3.36), 0.44, 0.44, "gold", 7)


def p_shard(m, s):
	m.crystal((0.8, -1.3, 2.45), (0.05, 0, 1), 0.34, 1.4, "g_blue", 5)


def p_mortar(m, s):
	m.lathe([(0, 0), (0.45, 0), (0.6, 0.6), (0.5, 0.6), (0.3, 0.3)], (-0.35, -1.25, 2.15), "stone2", 8)
	m.beam((-0.3, -1.25, 2.5), (0.35, -1.15, 3.2), 0.18, "wood")


def p_flask(m, s):
	m.flask((1.25, -1.15, 2.75), 0.75, s.get("jewel", "g_mag"), 0)


def p_hoop(m, s):
	m.hoop(0.75, (1.6, -0.95, 3.7), 0.16, s.get("jewel", "g_amber"), n=12)


def p_book(m, s):
	for sx in (-1, 1):
		m.box((0.75, 1.0, 0.14), (sx * 0.37, -1.15, 2.35), "paper", R3(sx * -14, "Y"))
		m.box((0.8, 1.06, 0.1), (sx * 0.38, -1.15, 2.26), s.get("trim"), R3(sx * -14, "Y"))


def p_staff(m, s):
	m.beam((1.75, -0.45, 0.0), (1.75, -0.45, 4.6), 0.2, "wood", 6)
	m.box((0.3, 0.3, 0.4), (1.75, -0.45, 4.5), "gold")


def p_lampstaff(m, s):
	"""A walking pole with a square paper lamp hung from a short crossbar."""
	m.beam((1.75, -0.45, 0.0), (1.75, -0.45, 4.9), 0.2, "dark", 6)
	m.box((0.9, 0.16, 0.16), (2.0, -0.6, 4.75), "dark")
	m.box((0.06, 0.06, 0.3), (2.35, -0.6, 4.55), "ink")
	m.box((0.56, 0.56, 0.6), (2.35, -0.6, 4.1), "lamp")
	m.box((0.68, 0.68, 0.12), (2.35, -0.6, 4.44), "verm")
	m.box((0.62, 0.62, 0.1), (2.35, -0.6, 3.78), "verm")


FIG = {
	# A: the dojo market's people
	"A_Shop": dict(skin="skin2", top="ochre", legs="leather", trim="cream", sash="verm2", boots="dark", hair="hairb", style="crop", hat="wrap", hat_a="cream", apron="leather", bulk=1.26, belly=True, jaw=1.4, nose=0.24, tall=0.94, beard="moustache", brow="bushy", mouth="none", eyes="closed", l=(-1.3, -0.9, 1.9), r=(0.75, -1.25, 2.25), prop=p_purse),
	"A_Potions": dict(skin="skin", top="olive", legs="leather", trim="cream", sash="rose", boots="dark", robe=True, hair="hairr", style="braid", hat="cone", hat_a="rope", hat_b="wood", iris="herb", bulk=0.88, tall=1.0, brow="high", mouth="small", l=(-0.35, -1.2, 2.3), r=(0.5, -1.15, 3.0), prop=p_mortar),
	"A_Market": dict(skin="skin3", top="teal", legs="teal", trim="cream", sash="gold", boots="dark", robe=True, hair="hairb", style="lowbun", bulk=1.12, belly=True, jaw=1.32, tall=0.96, brow="high", mouth="smile", eyes="closed", l=(-1.55, -0.8, 2.4), r=(1.6, -0.85, 3.0), prop=p_hoop),
	"A_Index": dict(skin="skin", top="cream", legs="hill", trim="olive", sash="copper", boots="dark", robe=True, hair="hairb", style="bob", hat="kerchief", hat_a="olive", glasses="ink", iris="leather", bulk=0.86, tall=1.04, brow="raised", mouth="smirk", l=(-0.65, -1.05, 2.2), r=(0.65, -1.05, 2.2), prop=p_book),
	"A_Sensei": dict(skin="skin3", top="white", legs="navy", trim="navy", sash="leather", boots="dark", hair="hairg", style="topknot", beard=0.75, beardw=0.5, bulk=0.96, tall=1.14, brow="bushy", mouth="none", eyes="narrow", l=(-1.35, -0.4, 1.8), r=(1.75, -0.5, 2.6), prop=p_staff),
	# B: the rift shrine's keepers
	"B_Shop": dict(skin="skin3", top="copper", legs="indigo2", trim="cream", sash="leather", boots="iron", hair="hairg", style="chops", hat="skullcap", hat_a="leather", hat_b="copper", apron="leather", bulk=1.22, jaw=1.45, nose=0.26, tall=0.98, brow="flat", mouth="grin", eyes="narrow", l=(-1.3, -0.9, 1.9), r=(0.8, -1.25, 2.2), prop=p_shard),
	"B_Potions": dict(skin="skin2", top="rose", legs="indigo2", trim="mist", sash="gold", boots="ink", robe=True, hair="hairb", style="braid", hat="hood", hat_a="indigo2", hat_b="mist", jewel="g_mag", iris="leather", bulk=0.9, tall=1.02, brow="high", mouth="smile", l=(-0.8, -1.0, 2.3), r=(1.2, -1.0, 2.75), prop=p_flask),
	"B_Market": dict(skin="skin", top="teal", legs="silk", trim="gold", sash="silk2", boots="ink", robe=True, hair="hairr", style="fringe", hat="brim", hat_a="silk", hat_b="silk2", jewel="g_amber", iris="leather", bulk=0.94, tall=1.1, brow="raised", mouth="smirk", l=(-1.6, -0.8, 2.6), r=(1.55, -0.85, 3.0), prop=p_hoop),
	"B_Index": dict(skin="skin2", top="rose", legs="cream", trim="cream", sash="gold", boots="ink", robe=True, hair="hairg", style="lowbun", bulk=1.06, jaw=1.3, tall=0.92, brow="soft", mouth="small", eyes="round", iris="leather", l=(-0.65, -1.05, 2.2), r=(0.65, -1.05, 2.2), prop=p_book),
	"B_Sensei": dict(skin="skin2", top="ochre", legs="leather", trim="cream", sash="navy", boots="dark", robe=True, hair="hairg", style="fringe", hat="tallcap", hat_a="navy", hat_b="gold", beard="moustache", nose=0.2, bulk=1.0, tall=1.12, brow="bushy", mouth="flat", eyes="closed", l=(-1.35, -0.4, 1.8), r=(1.75, -0.5, 2.6), prop=p_lampstaff),
}


def merchant(name, pos, face, at, yaw=0, height=5.5, ped=0.0):
	m = K(name + "_Merchant", bp.place(pos[0], pos[1], bp.TOP, face))
	figure(m, at, FIG[name], yaw, height)
	return m


def player(name, matrix, at, yaw=0):
	"""The 5.5-stud scale figure (render context, not a piece)."""
	m = K("Ctx_" + name, matrix)
	m.local = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
	for s in (-1, 1):
		m.box((0.95, 0.95, 1.85), (s * 0.5, 0, 0.93), "dummy2")
		m.box((0.8, 0.9, 1.9), (s * 1.42, 0, 2.8), "skin")
	m.box((2.0, 1.0, 1.95), (0, 0, 2.8), "dummy")
	m.box((1.35, 1.35, 1.7), (0, 0, 4.65), "skin")
	m.box((1.5, 1.45, 0.5), (0, 0.06, 5.25), "hairb")
	return m


# --- A: dojo market --------------------------------------------------------------------------------------------------
def a_shop():
	"""Treasure storehouse (kura): thick white plaster walls on a diamond-tile base, heavy doors folded back."""
	m = K("A_Shop", bp.place(*bp.SHOP, bp.TOP, bp.SHOP_FACE))
	w, d = 15, 9.6
	m.box((w + 1, d + 1, 0.3), (0, 0, 0.15), "slab")
	m.box((w + 0.2, d + 0.2, 0.3), (0, 0, 0.4), "stone2")
	back = d / 2 - 0.5
	walls = [((w, 0.9), (0, back)), ((0.9, d - 1), (-w / 2 + 0.45, 0)), ((0.9, d - 1), (w / 2 - 0.45, 0))]
	wing = 2.5
	for sx in (-1, 1):
		walls.append(((wing, 0.9), (sx * (w / 2 - wing / 2), -d / 2 + 0.7)))
	for (sx_, sy_), (x, y) in walls:
		m.box((sx_ + 0.14, sy_ + 0.14, 2.9), (x, y, 2.0), "iron")
		m.box((sx_, sy_, 5.4), (x, y, 6.1), "plaster")
		m.box((sx_ + 0.24, sy_ + 0.24, 0.25), (x, y, 3.5), "plaster2")
		m.box((sx_ + 0.3, sy_ + 0.3, 0.5), (x, y, 8.7), "plaster2")
	# diamond lattice on the dark base: front wings and both sides
	for sx in (-1, 1):
		for i in range(2):
			for j in range(2):
				for a in (45, -45):
					m.box((1.6, 0.12, 0.16), (sx * (w / 2 - 0.65 - 1.2 * i), -d / 2 + 0.16, 1.35 + 1.3 * j), "white", R3(a, "Y"))
		for i in range(4):
			for j in range(2):
				for a in (45, -45):
					m.box((0.12, 1.7, 0.16), (sx * (w / 2 + 0.1), -3.0 + 2.0 * i, 1.35 + 1.3 * j), "white", R3(a, "X"))
	# folded-back vault doors with stepped edges, iron straps and ring handles
	for sx in (-1, 1):  # folded right back flat on the wings, clear of the opening
		c = Vector((sx * 6.35, -d / 2 - 0.02, 5.9))
		for k, (dw, dd, mt) in enumerate(((2.5, 0.3, "plaster2"), (2.2, 0.55, "plaster"), (1.9, 0.75, "plaster2"))):
			m.box((dw, dd, 5.0 - 0.3 * k), c, mt)
		for zz in (4.4, 5.9, 7.4):
			m.box((2.0, 0.85, 0.28), (c.x, c.y, zz), "iron")
		m.hoop(0.42, (c.x, c.y - 0.5, 5.2), 0.16, "gold", n=8)
	# counter: a strong bench with gold-edged drawers, glass-dark top and trays of gems
	cy = -2.9
	m.box((9, 2, 3.0), (0, cy, 1.9), "wood")
	m.box((9.5, 2.5, 0.35), (0, cy, 3.5), "dark")
	for i in range(4):
		m.box((1.9, 0.14, 1.0), (-3.3 + 2.2 * i, cy - 1.04, 2.5), "plank")
		m.box((1.9, 0.14, 0.9), (-3.3 + 2.2 * i, cy - 1.04, 1.3), "plank")
		for zz in (2.5, 1.3):
			m.box((0.5, 0.2, 0.18), (-3.3 + 2.2 * i, cy - 1.12, zz), "gold")
	m.box((9.1, 0.16, 0.3), (0, cy - 1.06, 3.2), "gold")
	for x, glow in ((-3.6, "g_blue"), (3.7, "g_violet")):
		m.box((1.7, 1.3, 0.3), (x, cy, 3.85), "verm2")
		for i in range(3):
			if i == 1:
				m.gem((x, cy + 0.1, 4.35), 0.4, 0.55, 0.35, glow)
			else:
				m.coins((x - 0.5 + 0.5 * i, cy - 0.15, 4.0), 0.27, 2 + i // 2)
	# back shelves of chests in the rarity colours
	for zz in (3.2, 5.6):
		m.box((11, 1.8, 0.25), (0, back - 1.3, zz), "dark")
	for i, mt in enumerate(("r_common", "r_rare", "r_epic", "r_leg")):
		m.chest((-4.1 + 2.75 * i, back - 1.4, 3.32), 2.0, mt)
	for i, mt in enumerate(("r_myth", "r_rare", "r_leg")):
		m.chest(((-4.3, -2.0, 3.6)[i], back - 1.4, 5.72), 2.1, mt)
	m.lantern((-4.3, -3.9, 8.9))
	m.lantern((4.3, -3.9, 8.9))
	for sx in (-1, 1):  # a barred window in each side wall
		m.box((0.2, 2.6, 2.2), (sx * (w / 2 + 0.02), 0.4, 6.2), "dark")
		for k in (-0.8, 0, 0.8):
			m.box((0.3, 0.2, 2.4), (sx * (w / 2 + 0.06), 0.4 + k, 6.2), "iron")
		m.box((0.4, 3.0, 0.3), (sx * (w / 2 + 0.06), 0.4, 7.4), "plaster2")
		m.box((0.4, 3.0, 0.3), (sx * (w / 2 + 0.06), 0.4, 5.0), "plaster2")
	# the landmark: a treasure chest as tall as a player, one great blue gem standing in it
	old = m.local
	m.local = Matrix.Translation((-10.6, -3.6, 0)) @ Matrix.Rotation(math.radians(16), 4, "Z") @ Matrix.Scale(2.0, 4)
	m.chest((0, 0, 0), 2.4, "verm2", "gold", d=1.6, open_=True)
	m.lathe([(0.1, 0.95), (0.85, 2.0), (0.6, 2.45), (0, 2.5)], (0, 0, 0), "g_blue", 6)
	m.local = old
	# goods at the sides, under the eaves
	m.crate((8.7, -1.6, 0), 1.9)
	m.crate((8.6, -1.5, 1.52), 1.5, "r_rare", "gold")
	m.crate((8.6, 1.1, 0), 1.7)
	for i, (x, z) in enumerate(((-8.6, 0.6), (-9.75, 0.6), (-9.17, 1.6))):  # straw rice bales
		y = 1.6
		m.taper((x, y - 1.3, z), (x, y + 1.3, z), 1.1, 1.1, "rope", 8)
		for k in (-0.7, 0.7):
			m.taper((x, y + k - 0.08, z), (x, y + k + 0.08, z), 1.2, 1.2, "leather", 8)
	m.gable(0, 0.2, 8.9, w + 3.6, d + 4.2, 3.7, "tileb", "black", lift=0.8, ribs=11)
	for sx in (-1, 1):  # roof gems in gold sockets
		m.lathe([(0.5, 0), (0.3, 0.35)], (sx * 5.6, 0.2, 12.95), "gold", 6)
	m.board(0, -5.6, 11.2, 7, 2)
	for sx in (-1, 1):
		m.box((0.35, 1.6, 0.35), (sx * 2.6, -4.8, 10.5), "dark", R3(-12, "X"))
		m.gem((sx * 4.6, -5.6, 11.1), 0.7, 0.95, 0.95, "g_blue", 6)
		m.box((1.0, 0.3, 0.3), (sx * 3.9, -5.6, 11.1), "gold")
	return m, merchant("A_Shop", bp.SHOP, bp.SHOP_FACE, (0, -0.7, 1.35))


def a_potions():
	"""Apothecary: a round moon gate in a plum wall, a medicine-drawer front, a copper still and drying herbs."""
	m = K("A_Potions", bp.place(*bp.POTIONS, bp.TOP, bp.POTIONS_FACE))
	w, d = 14, 9.6
	m.box((w + 0.8, d + 0.8, 0.35), (0, 0, 0.17), "slab")
	m.box((w, d, 0.2), (0, 0, 0.42), "plank")
	wy, cz, r, hw, top = -2.3, 5.0, 3.9, w / 2 - 0.4, 8.9
	n = 24
	inner = [(r * math.cos(k / n * TAU), cz + r * math.sin(k / n * TAU)) for k in range(n)]
	def out(k):
		a = k / n * TAU
		c, s = math.cos(a), math.sin(a)
		t = min(hw / abs(c) if abs(c) > 1e-6 else 1e9, ((top - cz) / s if s > 1e-6 else ((cz - 0.5) / -s if s < -1e-6 else 1e9)))
		return (t * c, cz + t * s)
	outer = [out(k) for k in range(n)]
	for k in range(n):
		a, b, c, e = inner[k], outer[k], outer[(k + 1) % n], inner[(k + 1) % n]
		for y, flip in ((wy - 0.25, False), (wy + 0.25, True)):
			q = [(p[0], y, p[1]) for p in (a, b, c, e)]
			m.face(q[::-1] if flip else q, "silk")
		m.face([(a[0], wy - 0.25, a[1]), (e[0], wy - 0.25, e[1]), (e[0], wy + 0.25, e[1]), (a[0], wy + 0.25, a[1])], "dark")
	for sx in (-1, 1):  # corner fill where the rays miss the rectangle's corners
		for zc in (0.5, top):
			m.box((1.2, 0.48, 1.6), (sx * (hw - 0.6), wy, zc + (0.8 if zc < 1 else -0.8)), "silk")
	m.hoop(r + 0.15, (0, wy, cz), 0.6, "dark", n=24)
	m.hoop(r + 0.6, (0, wy - 0.1, cz), 0.26, "gold", n=24)
	m.box((w - 1, 0.5, 8.4), (0, d / 2 - 0.5, 4.7), "plank")
	for sx in (-1, 1):
		m.box((0.5, d - 3, 8.4), (sx * (w / 2 - 0.5), 1.1, 4.7), "plaster")
		for y in (-4.2, wy, d / 2 - 0.5):
			m.box((0.8, 0.8, 8.9), (sx * (w / 2 - 0.45), y, 4.6), "dark")
		# medicine drawers flanking the gate
		x = sx * 5.55
		m.box((2.0, 0.9, 4.2), (x, wy - 0.6, 2.6), "wood")
		for i in range(2):
			for j in range(4):
				m.box((0.82, 0.14, 0.86), (x - 0.47 + 0.94 * i, wy - 1.06, 1.1 + 1.0 * j), "plank")
				m.box((0.22, 0.16, 0.16), (x - 0.47 + 0.94 * i, wy - 1.16, 1.1 + 1.0 * j), "gold")
		m.flask((x - 0.4, wy - 0.6, 4.7), 0.8, "g_green" if sx < 0 else "g_mag", 1)
		m.flask((x + 0.45, wy - 0.65, 4.7), 0.65, "g_mag" if sx < 0 else "g_green", 2)
	# counter through the gate
	cy = -3.5
	m.box((7.6, 2, 3.0), (0, cy, 1.9), "wood")
	m.box((8.0, 2.5, 0.35), (0, cy, 3.5), "plank")
	m.box((7.0, 0.14, 2.0), (0, cy - 1.04, 1.9), "silk")
	m.box((7.0, 0.16, 0.25), (0, cy - 1.05, 1.1), "gold")
	for x, s, glow, kd in ((-3.3, 1.15, "g_mag", 0), (-2.1, 0.8, "g_green", 2), (2.2, 0.85, "g_mag", 1), (3.3, 1.2, "g_green", 0)):
		m.flask((x, cy, 3.68), s, glow, kd)
	# shelves of jars behind
	for zz in (4.2, 6.4):
		m.box((9, 1.2, 0.2), (0, d / 2 - 1.2, zz), "dark")
		for i in range(6):
			m.lathe([(0, 0), (0.45, 0), (0.55, 0.7), (0.35, 1.1), (0, 1.1)], (-3.75 + 1.5 * i, d / 2 - 1.2, zz + 0.1), ("plaster2", "rose", "herb")[(i + int(zz)) % 3], 7)
	# herb bundles under the front eave
	m.beam((-6.4, -4.2, 8.3), (6.4, -4.2, 8.3), 0.22, "dark")
	for i, x in enumerate((-5.6, -4.5, -3.4, 3.4, 4.5, 5.6)):
		m.beam((x, -4.2, 8.3), (x, -4.2, 7.9), 0.1, "rope")
		m.taper((x, -4.2, 8.0), (x, -4.2, 6.5), 0.22, 0.95, ("herb", "herb2", "rose")[i % 3], 6)
	# the copper still at the left: brazier, pot-bellied boiler, swan neck to a receiver
	old = m.local
	m.local = Matrix.Translation((-10.4, -2.4, 0)) @ Matrix.Scale(1.45, 4)
	sx, sy = 0, 0
	m.cyl(1.7, 0.9, (sx, sy, 0), "stone2", n=8, r2=1.5)
	m.cyl(1.2, 0.3, (sx, sy, 0.8), "lamp", n=8)
	m.lathe([(0.9, 1.1), (1.7, 1.9), (1.75, 2.9), (1.0, 3.9), (0.55, 4.3), (0.55, 4.8), (0.9, 5.2), (0.5, 5.8), (0, 5.9)], (sx, sy, 0), "copper", 10, ["iron", "copper", "copper", "copper", "gold", "copper", "copper", "copper"])
	m.ydisc(0.6, (sx, sy - 1.72, 2.5), 0.2, "gold", 10)
	m.ydisc(0.45, (sx, sy - 1.84, 2.5), 0.1, "g_mag", 10)
	neck = [(sx, sy, 5.7), (sx + 0.5, sy - 0.5, 6.3), (sx + 1.2, sy - 1.2, 6.0), (sx + 1.5, sy - 1.7, 4.4), (sx + 1.5, sy - 1.7, 2.1)]
	for a, b in zip(neck, neck[1:]):
		m.beam(a, b, 0.36, "copper", 6)
	m.flask((sx + 1.5, sy - 1.7, 0.3), 1.3, "g_mag", 0)
	m.local = old
	# the landmark: a great round flask in a wooden cradle, a herb pot beside it
	m.cyl(2.3, 0.8, (10.4, -2.2, 0), "wood", n=8, r2=2.0)
	m.lathe([(1.1, 0.8), (2.5, 2.0), (2.8, 3.2), (2.5, 4.3)], (10.4, -2.2, 0), "g_mag", 10)
	m.lathe([(2.5, 4.3), (1.7, 5.3), (0.8, 5.9), (0.75, 7.2), (1.0, 7.5), (0, 7.5)], (10.4, -2.2, 0), "white", 10)
	m.cyl(0.85, 0.9, (10.4, -2.2, 7.4), "wood", n=8, r2=0.95)
	m.lathe([(2.86, 3.0), (2.86, 3.5)], (10.4, -2.2, 0), "gold", 10)
	for k in range(4):
		a = k / 4 * TAU + 0.78
		m.beam((10.4 + 2.2 * math.cos(a), -2.2 + 2.2 * math.sin(a), 0.4), (10.4 + 2.9 * math.cos(a), -2.2 + 2.9 * math.sin(a), 3.3), 0.4, "wood")
	m.lathe([(0.7, 0), (1.0, 1.1), (0.8, 1.1), (0, 1.0)], (8.6, 1.8, 0), "copper", 8)
	for k in range(6):
		a = k / 6 * TAU
		m.taper((8.6, 1.8, 1.0), (8.6 + 0.8 * math.cos(a), 1.8 + 0.8 * math.sin(a), 2.3 + 0.3 * (k % 2)), 0.7, 0.02, "herb")
	m.roof(0, 0, 9.0, w + 3.4, d + 4, 3.1, "tilet", ridge=0.3, lift=1.4, trim="black", hip_rings=3)
	m.board(0, -5.6, 11.2, 7, 2)
	for q in (-1, 1):
		m.box((0.35, 1.8, 0.35), (q * 2.6, -4.8, 10.4), "dark", R3(-12, "X"))
	return m, merchant("A_Potions", bp.POTIONS, bp.POTIONS_FACE, (0, -0.9, 1.3))


def karahafu(m, y, d, z, w, h, t, material, trim, n=12):
	"""A bow-shaped gable roof seen from the front: arch in the middle, flicking up at the ends."""
	f = lambda u: z + h * (math.cos(u * math.pi) * 0.5 + 0.5) ** 1.0 + 0.5 * abs(u) ** 4 * h
	xs = [(-1 + 2 * i / n) for i in range(n + 1)]
	for a, b in zip(xs, xs[1:]):
		xa, xb, za, zb = a * w / 2, b * w / 2, f(a), f(b)
		y0, y1 = y - d / 2, y + d / 2
		m.face([(xa, y0, za + t), (xb, y0, zb + t), (xb, y1, zb + t), (xa, y1, za + t)], material)
		m.face([(xa, y1, za), (xb, y1, zb), (xb, y0, zb), (xa, y0, za)], "dark")
		for yy, flip in ((y0, False), (y1, True)):
			q = [(xa, yy, za), (xb, yy, zb), (xb, yy, zb + t), (xa, yy, za + t)]
			m.face(q[::-1] if flip else q, trim)
	for s in (-1, 1):
		za = f(s)
		m.face([(s * w / 2, y - d / 2, za), (s * w / 2, y + d / 2, za), (s * w / 2, y + d / 2, za + t), (s * w / 2, y - d / 2, za + t)], trim)


def a_market():
	"""Silk house: two storeys, a bow gable over the MARKET board, a striped silk canopy, aura busts and a ribbon rack."""
	m = K("A_Market", bp.place(*bp.MARKET_STALL, bp.TOP, bp.MARKET_FACE))
	w, d = 20, 11
	f, b = -d / 2, d / 2
	m.box((w + 0.6, d + 0.6, 0.25), (0, 0, 0.12), "slab")
	m.box((w, d, 0.3), (0, 0, 0.38), "plank")
	for x in (-9.5, -6.6, 6.6, 9.5):
		m.box((0.9, 0.9, 8.6), (x, f + 0.6, 4.6), "verm2")
		m.box((1.2, 1.2, 0.6), (x, f + 0.6, 0.8), "stone2")
		m.box((1.1, 1.1, 0.4), (x, f + 0.6, 8.5), "gold")
	m.box((w - 1, 0.5, 8.6), (0, b - 0.6, 4.6), "plaster")
	m.box((w - 2, 0.2, 5.8), (0, b - 1.0, 5.2), "cream")
	for x in (-6.4, -3.2, 0, 3.2, 6.4):
		m.box((1.0, 0.24, 5.8), (x, b - 1.02, 5.2), "silk2" if x else "gold")
	for sx in (-1, 1):
		m.box((0.6, d - 1.2, 3.0), (sx * 9.5, 0.3, 2.0), "plank")
		m.box((0.3, 5, 5.2), (sx * 9.5, 2.3, 6.1), "paper")
		m.box((0.9, 0.9, 8.6), (sx * 9.5, b - 0.6, 4.6), "verm2")
	# counter
	cy = f + 1.7
	m.box((11.6, 2, 3.0), (0, cy, 2.0), "wood")
	m.box((12.2, 2.6, 0.35), (0, cy, 3.65), "plank")
	m.box((11.0, 0.12, 2.5), (0, cy - 1.05, 2.1), "verm2")
	for k in range(6):  # a scalloped gold hem
		x = -4.6 + 1.84 * k
		m.py = cy - 1.12
		m.plate([(x - 0.92, 1.5), (x, 0.95), (x + 0.92, 1.5), (x + 0.92, 1.75), (x - 0.92, 1.75)], 0.08, "gold")
	m.py = 0
	for x, r, glow in ((-4.6, 0.95, "lampw"), (-2.6, 0.7, "g_cyan"), (4.5, 0.85, "g_amber")):
		m.box((1.1, 0.9, 0.3), (x, cy, 3.95), "verm2")
		m.box((0.2, 0.3, 0.4), (x, cy, 4.2), "gold")
		m.hoop(r, (x, cy, 4.35 + r), 0.2, glow, n=12)
	# the landmark: two aura busts on plinths either side of the house
	for x, glow in ((-13.2, "g_amber"), (13.2, "g_cyan")):
		y, k = -3.4, 1.9
		m.cyl(2.2, 0.5, (x, y, 0), "slab", n=8)
		m.cyl(1.6, 1.8, (x, y, 0.5), "stone3", n=8, r2=1.35)
		# a wooden mannequin: shoulders in a collared coat, a neck, a head with hair, so it reads as a person
		m.taper((x, y, 2.3), (x, y, 4.5), 1.5, 2.6, "teal" if x < 0 else "verm2")
		for q in (-1, 1):
			m.box((0.28, 0.14, 1.5), (x + q * 0.4, y - 1.22, 3.9), "cream", R3(q * 22, "Y"))
		m.box((0.8, 0.8, 0.6), (x, y, 4.7), "plank")
		m.taper((x, y, 4.9), (x, y, 5.4), 1.4, 1.8, "plank")
		m.box((1.8, 1.8, 1.4), (x, y, 6.1), "plank")
		m.box((2.0, 1.9, 0.5), (x, y + 0.1, 6.95), "hairb")
		m.box((2.0, 0.6, 1.3), (x, y + 0.75, 6.3), "hairb")
		m.hoop(2.5, (x, y + 0.8, 6.3), 0.34, glow, n=18)
		for q in range(11):
			a = -0.35 + (math.pi + 0.7) * q / 10
			ln = 1.5 if q % 2 else 0.9
			ray = lambda r: (x + r * math.cos(a), y + 0.8, 6.3 + r * math.sin(a))
			m.taper(ray(2.75), ray(2.75 + ln), 0.5, 0.02, glow)
	for i, (mt, x) in enumerate((("g_amber", -8.6), ("g_cyan", -7.6), ("g_violet", 7.6), ("g_amber", 8.6))):
		rows = []
		for k in range(6):
			t = k / 5
			cx = x + 0.28 * math.sin(t * TAU + i)
			wd = 0.42 * (1 - 0.75 * t)
			rows.append([(cx - wd, f + 0.9 + 0.25 * math.sin(t * 5 + i), 8.4 - 5.6 * t), (cx + wd, f + 0.9 + 0.25 * math.sin(t * 5 + i), 8.4 - 5.6 * t)])
		m.strip(rows, mt)
	# silk canopy sweeping out over the customer
	cols = 12
	rows = []
	for k in range(3):
		t = k / 2
		rows.append([(-6.6 + 13.2 * c / cols, f + 0.2 - 2.9 * t, 8.45 - 0.5 * t - 0.35 * math.sin(math.pi * t) * (0.4 + 0.6 * math.sin(math.pi * c / cols))) for c in range(cols + 1)])
	m.strip(rows, "silk2", "cream")
	last = rows[-1]
	for c in range(cols):
		a, e = last[c], last[c + 1]
		m.strip([[a, e], [((a[0] + e[0]) / 2 - 0.35, a[1], a[2] - 0.6), ((a[0] + e[0]) / 2 + 0.35, a[1], a[2] - 0.6)]], "gold" if c % 2 else "verm2")
	for sx in (-1, 1):
		m.beam((sx * 6.6, f + 0.3, 5.6), (sx * 6.6, f - 2.6, 7.8), 0.34, "gold")
		m.lantern((sx * 10.6, f - 0.6, 8.2), 0.65, "silk")
	# lower roof, balcony storey, bow gable, upper roof
	m.roof(0, 0, 8.9, w + 3.4, d + 3.2, 2.6, "tile", ridge=0.72, lift=1.1, trim="gold", hip_rings=2)
	m.box((18, 6.4, 3.4), (0, 1.2, 11.5), "plaster")
	for x in (-9, -4.5, 4.5, 9):
		m.box((0.5, 6.6, 3.4), (x, 1.2, 11.5), "verm2")
	m.roof(0, 1.8, 12.6, 21.5, 8.0, 1.9, "tile", ridge=0.6, lift=0.9, trim="gold", hip_rings=2)
	for s in (-1, 1):
		m.box((0.5, 2.4, 0.5), (s * 5.5, -2.7, 11.6), "dark")
	m.board(0, -3.8, bp.MARKET_SIGN_Y, 16, 4.1, "silk")
	# the bow gable stands on the board and runs back into the upper roof, its face filled in
	karahafu(m, -2.7, 4.4, 13.85, 18.6, 1.25, 0.45, "tile", "gold")
	m.py = -3.7
	m.plate([(-7.6, 13.6), (7.6, 13.6), (6.4, 14.15), (3.2, 14.8), (0, 15.05), (-3.2, 14.8), (-6.4, 14.15)], 0.5, "cream")
	m.py = 0
	for q in (-1, 1):
		m.box((0.7, 3.6, 1.0), (q * 7.7, -2.6, 13.5), "verm2")
	return m, merchant("A_Market", bp.MARKET_STALL, bp.MARKET_FACE, (0.6, -1.5, 1.35), height=5.7)


def a_index():
	"""Great scroll library: a giant hanging scroll of runner cards between two pigeonhole towers."""
	m = K("A_Index", bp.place(*bp.INDEX, bp.TOP, bp.INDEX_FACE))
	m.box((25, 5.4, 0.4), (0, 0.3, 0.2), "slab")
	m.box((24, 4.6, 0.3), (0, 0.3, 0.55), "stone2")
	m.box((15, 0.5, 11), (0, 0.6, 6.2), "dark")
	# the scroll: hangs from the top roller, curls out at the foot
	prof = [(-0.4, 11.4), (-0.25, 9.0), (-0.15, 5.0), (-0.25, 2.9), (-0.8, 2.0), (-1.6, 1.5)]
	hw = 6.6
	m.strip([[(-hw - 0.6, y + 0.04, z), (hw + 0.6, y + 0.04, z)] for y, z in prof], "verm")
	m.strip([[(-hw, y - 0.06, z + 0.03), (hw, y - 0.06, z + 0.03)] for y, z in prof], "paper")
	for y, z in ((-0.4, 11.6), (-1.75, 1.35)):
		m.taper((-hw - 1, y, z), (hw + 1, y, z), 0.9, 0.9, "wood", 8)
		for sx in (-1, 1):
			m.taper((sx * (hw + 1), y, z), (sx * (hw + 1.6), y, z), 1.2, 0.9, "gold", 8)
	m.box((11, 0.2, 1.1), (0, -0.5, 10.4), "cream")  # header strip: the game writes its title here
	m.box((11.3, 0.1, 1.3), (0, -0.42, 10.4), "verm2")
	colours = ["r_common", "r_rare", "r_epic", "r_leg", "r_myth"]
	for i in range(6):
		for j in range(3):
			x, z = -5 + 2 * i, 4.2 + 2.1 * j
			m.box((1.6, 0.16, 1.8), (x, -0.36, z), "dark")
			m.box((1.4, 0.2, 1.6), (x, -0.38, z), colours[(i * 3 + j * 2) % 5])
			# a runner's bust silhouette: shoulders and head
			m.py = -0.5
			m.plate([(x - 0.5, z - 0.7), (x + 0.5, z - 0.7), (x + 0.35, z - 0.15), (x - 0.35, z - 0.15)], 0.06, "ink" if (i + j) % 4 == 0 else "cream")
			m.ydisc(0.3, (x, -0.5, z + 0.22), 0.06, "ink" if (i + j) % 4 == 0 else "cream", 6)
	m.py = 0
	# pigeonhole towers
	for sx in (-1, 1):
		x = sx * 10
		m.box((4.6, 0.3, 11), (x, 1.9, 6.2), "dark")
		for k in (-2.2, 0, 2.2):
			m.box((0.25, 3.0, 11), (x + k, 0.5, 6.2), "wood")
		for j in range(5):
			m.box((4.6, 3.0, 0.25), (x, 0.5, 1.6 + 2.45 * j), "wood")
		for c in range(2):
			for j in range(4):
				cx, cz = x - 1.1 + 2.2 * c, 1.75 + 2.45 * j
				for q, (ox, oz) in enumerate(((-0.5, 0.45), (0.5, 0.45), (0.0, 1.25))):
					if (c + j + q) % 5 == 4:
						continue
					mt = ("paper", "cream", "r_rare", "r_leg", "r_epic", "verm")[(c * 5 + j * 2 + q) % 6]
					m.taper((cx + ox, 1.6, cz + oz), (cx + ox, -1.0 - 0.2 * (q % 2), cz + oz), 0.85, 0.85, mt, 5 if sx > 0 else 6)
		m.cyl(0.8, 12.2, (sx * 12.4, 0.3, 0.4), "verm2", n=8)
		m.lantern((sx * 7.5, -1.5, 11.6), 0.55)
	# a ladder on the right tower
	for k in (-0.6, 0.6):
		m.beam((9.6 + k, -2.9, 0.5), (9.6 + k, -1.2, 9.8), 0.22, "plank")
	for j in range(7):
		t = (j + 0.6) / 7
		m.beam((9.0, -2.9 + 1.7 * t, 0.5 + 9.3 * t), (10.2, -2.9 + 1.7 * t, 0.5 + 9.3 * t), 0.18, "plank")
	# the keeper's desk, left of the board's middle
	m.box((2.6, 1.4, 2.6), (-8.2, -4.0, 1.3), "wood")
	m.box((3.0, 1.8, 0.25), (-8.2, -4.0, 2.7), "dark", R3(8, "X"))
	m.box((2.9, 0.1, 0.7), (-8.2, -4.86, 2.3), "olive")  # a cloth runner, two drawers with brass pulls, corner posts
	for q in (0, 1):
		m.box((2.1, 0.14, 0.62), (-8.2, -4.72, 0.7 + 0.8 * q), "plank")
		m.box((0.5, 0.2, 0.16), (-8.2, -4.8, 0.7 + 0.8 * q), "gold")
	for q in (-1, 1):
		m.box((0.24, 1.6, 2.6), (-8.2 + q * 1.25, -4.0, 1.3), "dark")
		m.beam((-9.1, -3.8 + 0.1 * q, 3.1 if q < 0 else 3.4), (-7.9, -3.8 + 0.1 * q, 3.1 if q < 0 else 3.4), 0.42, "paper" if q < 0 else "r_rare", 6)
	m.lathe([(0.25, 0), (0.3, 0.4), (0.15, 0.5)], (-7.2, -3.9, 2.85), "ink", 6)
	m.taper((-7.2, -3.9, 3.3), (-6.9, -3.7, 4.2), 0.08, 0.3, "white")
	m.gable(0, 0.3, 12.5, 27, 6.4, 2.8, "tile", "verm2", lift=0.8, ribs=14, segx=8, segt=2)
	return m, merchant("A_Index", bp.INDEX, bp.INDEX_FACE, (-5.2, -4.2, 0), yaw=-14, height=5.4)


def a_sensei():
	"""Training mat: tatami dais, a painted folding screen of the road, a wooden-sword rack and a tea tray."""
	m = K("A_Sensei", bp.place(*bp.SENSEI, bp.TOP, bp.SENSEI_FACE))
	m.cyl(4, 0.45, (0, 0, 0), "stone", n=8)
	m.cyl(3.6, 0.2, (0, 0, 0.42), "tatami", n=8)
	for k in (0.0,):
		m.box((0.16, 5.8, 0.06), (k, 0, 0.64), "olive")
	n = 5
	pts = [(-3.5 + 7 * i / n, 2.55 + (0.28 if i % 2 else 0) - 0.5 * (abs(i - n / 2) / (n / 2)) ** 2) for i in range(n + 1)]
	for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
		q = lambda z0, z1, dy: [(xa, ya + dy, z0), (xb, yb + dy, z0), (xb, yb + dy, z1), (xa, ya + dy, z1)]
		m.face(q(0.6, 6.1, 0), "cream")
		m.face(q(0.6, 6.1, 0.2)[::-1], "dark")
		m.face(q(0.6, 1.9, -0.03), "hill")
		mid = ((xa + xb) / 2, (ya + yb) / 2)
		m.face([(xa, ya - 0.02, 1.9), (xb, yb - 0.02, 1.9), (mid[0] + 0.1, mid[1] - 0.02, 3.5 + 0.5 * math.sin(xa * 2))], "hill2")
		for z in (0.65, 6.1):
			m.beam((xa, ya, z), (xb, yb, z), 0.2, "ink")
		m.beam((xa, ya, 0.6), (xa, ya, 6.15), 0.2, "ink")
	m.beam((pts[-1][0], pts[-1][1], 0.6), (pts[-1][0], pts[-1][1], 6.15), 0.2, "ink")
	m.beam((2.35, 2.3, 3.1), (2.1, 2.3, 4.7), 0.18, "bark", 5)  # a painted pine
	for q, (px, pz, pw) in enumerate(((2.2, 4.1, 1.5), (2.05, 4.65, 1.2), (2.15, 5.15, 0.8))):
		m.box((pw, 0.1, 0.34), (px, 2.28, pz), "pine" if q % 2 else "pine2")
	at = lambda t: (-3.1 + 6.2 * t, 2.3, 1.1 + 2.6 * t + 0.5 * math.sin(t * 9))
	for i in range(9):  # the road: ten stops on one line
		m.beam(at(i / 9), at((i + 1) / 9), 0.12, "verm")
	for i in range(10):
		m.gem(at(i / 9), 0.17, 0.17, 0.17, "gold" if i == 9 else "verm2", 6)
	for sx in (-1, 1):  # sword rack, left
		m.box((0.2, 0.9, 1.7), (-2.75 + sx * 0.75, 0.6, 1.45), "dark")
	for j in range(3):
		m.beam((-3.9, 0.35, 1.1 + 0.45 * j), (-1.7, 0.35, 1.25 + 0.45 * j), 0.16, "plank")
	m.box((1.3, 0.9, 0.5), (2.4, -0.3, 0.9), "wood")
	m.lathe([(0, 0), (0.32, 0.05), (0.36, 0.35), (0.1, 0.5)], (2.2, -0.3, 1.15), "iron", 8)
	m.cyl(0.14, 0.2, (2.75, -0.4, 1.15), "white", n=6)
	return m, merchant("A_Sensei", bp.SENSEI, bp.SENSEI_FACE, (0, -0.5, 0.62), height=4.95)


# --- B: rift-shrine market -------------------------------------------------------------------------------------------
def rift_base(m, rx, ry, seam="g_cyan", n=8, h=0.7):
	pt = lambda k, r, z: (rx * r * math.cos(k / n * TAU + TAU / 2 / n), ry * r * math.sin(k / n * TAU + TAU / 2 / n), z)
	for k in range(n):
		m.face([pt(k, 1.04, 0), pt(k + 1, 1.04, 0), pt(k + 1, 1, h * 0.55), pt(k, 1, h * 0.55)], "basalt3")
		m.face([pt(k, 0.985, h * 0.55), pt(k + 1, 0.985, h * 0.55), pt(k + 1, 0.985, h * 0.72), pt(k, 0.985, h * 0.72)], seam)
		m.face([pt(k, 1, h * 0.72), pt(k + 1, 1, h * 0.72), pt(k + 1, 0.97, h), pt(k, 0.97, h)], "basalt")
		m.face([pt(k, 0.97, h), pt(k + 1, 0.97, h), pt(k + 1, 0, h)], "basalt2" if k % 2 else "basalt")
		m.face([pt(k, 1, h * 0.55), pt(k + 1, 1, h * 0.55), pt(k + 1, 0.985, h * 0.55), pt(k, 0.985, h * 0.55)], "basalt3")


def b_shop():
	"""Geode vault: a cracked-open geode lined with blue crystal, caskets on ledges inside, the sign on two stone beams."""
	m = K("B_Shop", bp.place(*bp.SHOP, bp.TOP, bp.SHOP_FACE))
	rift_base(m, 10.2, 6.6)
	nu, nv = 14, 6
	rnd = bp.rng
	jit = [[rnd.uniform(0.92, 1.08) for _ in range(nu + 1)] for _ in range(nv + 1)]
	rag = [rnd.uniform(-0.26, 0.16) for _ in range(nv + 1)]  # how far the broken mouth runs round, per height
	def pt(u, v, rx, ry, rz, j=1.0):
		a = rag[v] + (math.pi - rag[v] * 2) * u / nu if u in (0, nu) else math.pi * u / nu
		e = (math.pi / 2) * (v / nv) ** 0.9
		c = max(math.cos(e), 0.34 * (v / nv))
		return (rx * j * math.cos(a) * c, 0.4 + ry * j * math.sin(a) * c, 0.4 + rz * math.sin(e))
	out = [[pt(u, v, 9.8, 5.4, 12.2, jit[v][u]) for u in range(nu + 1)] for v in range(nv + 1)]
	inn = [[pt(u, v, 7.9, 4.1, 10.8, 1 + (jit[v][u] - 1) * 0.5) for u in range(nu + 1)] for v in range(nv + 1)]
	tone = ("ink", "indigo2", "indigo", "geode", "geode", "r_rare")
	for v in range(nv):
		for u in range(nu):
			m.face([out[v][u], out[v][u + 1], out[v + 1][u + 1], out[v + 1][u]], ("basalt", "basalt2", "basalt3")[(u * 2 + v) % 3])
			m.face([inn[v][u + 1], inn[v][u], inn[v + 1][u], inn[v + 1][u + 1]], tone[v])
		for u, flip in ((0, False), (nu, True)):  # the broken edge
			q = [out[v][u], inn[v][u], inn[v + 1][u], out[v + 1][u]]
			m.face(q if flip else q[::-1], "mist")
	m.face(out[nv], "basalt2")
	m.face(inn[nv][::-1], "geode")
	for u in range(nu):
		m.face([out[nv][u], out[nv][u + 1], inn[nv][u + 1], inn[nv][u]], "mist")
	# crystals grow out of the shell: each foot is sunk in its wall, between the outer and inner skin
	mid = lambda v, u: (Vector(out[v][u]) + Vector(inn[v][u])) / 2
	def grow(foot, d, r, ln, mt):
		d = Vector(d).normalized()
		a = foot - d * 0.7
		if a.z < 0.5:
			a = Vector((foot.x, foot.y, 0.5))
		ln = min(ln + 0.7, (13.9 - a.z) / d.z)
		m.taper(a, a + d * ln * 0.6, r * 2.1, r * 1.7, mt, 5)
		m.taper(a + d * ln * 0.6, a + d * ln, r * 1.7, 0, mt, 5)
	for sx, u in ((1, 0), (-1, nu)):
		for v, r, ln, mt in ((0, 0.9, 3.6, "g_blue"), (1, 0.75, 2.6, "r_rare"), (2, 0.8, 2.6, "g_blue"), (3, 0.7, 2.2, "r_rare"), (4, 0.75, 2.4, "g_blue")):
			c = mid(v, u)
			grow(c, (sx * 0.45, -0.25, 1), r, ln, mt)
		for v, w_, r, ln, mt in ((3, 2, 1.05, 4.4, "g_blue"), (4, 3, 0.8, 3.0, "r_rare"), (2, 2, 0.8, 3.2, "r_rare")):
			uu = w_ if u == 0 else nu - w_
			grow(mid(v, uu), (sx * 0.7, -0.15, 1), r, ln, mt)
	for u in (3, 5, 9, 11):
		c = Vector(inn[4][u])
		d = (Vector((0, -1.0, 5)) - c).normalized()
		m.taper(c - d * 0.4, c + d * 1.5, 0.9, 0, "r_rare" if u % 3 else "g_blue", 5)
	# counter: a split stone altar slab with a glowing seam
	cy = -2.9
	m.box((9, 2, 2.9), (0, cy, 2.1), "basalt3")
	m.box((9.6, 2.6, 0.4), (0, cy, 3.6), "verm")
	m.box((9.06, 2.06, 0.18), (0, cy, 2.9), "g_cyan")
	for k in range(5):
		m.box((0.5, 0.2, 2.1), (-4 + 2 * k, cy - 1.02, 1.7), "basalt2")
	for x in (-3.6, 3.6):
		m.box((1.8, 1.4, 0.3), (x, cy, 3.95), "gold")
		m.crystal((x, cy, 4.05), (0.1, 0, 1), 0.4, 1.8, "g_blue")
		m.crystal((x - 0.5, cy + 0.1, 4.05), (-0.5, 0, 1), 0.28, 1.1, "r_rare")
		m.crystal((x + 0.5, cy - 0.1, 4.05), (0.6, -0.2, 1), 0.25, 1.0, "r_rare")
	# caskets on stone ledges that run back into the shell, clear of the keeper's head
	for x, z, mt in ((-4.5, 5.2, "r_epic"), (-2.7, 7.7, "r_leg"), (2.7, 7.7, "r_myth"), (4.5, 5.2, "r_rare")):
		m.box((2.3, 3.6, 0.4), (x, 2.2, z), "stele")
		m.chest((x, 1.3, z + 0.2), 1.9, mt, "gold")
	# the sign hangs on a rough stone beam that juts out of the shell
	for sx in (-1, 1):
		m.taper((sx * 2.8, 0.5, 11.6), (sx * 2.8, -5.5, 11.2), 1.2, 0.7, "basalt3", 5)
		m.lantern((sx * 4.4, -4.6, 10.2), 0.55, "indigo2", "g_cyan")
		m.beam((sx * 2.8, -5.2, 11.6), (sx * 4.5, -4.6, 10.3), 0.22, "iron")
	m.board(0, -5.6, 11.2, 7, 2, "basalt3")
	return m, merchant("B_Shop", bp.SHOP, bp.SHOP_FACE, (0, -0.7, 1.35))


def b_potions():
	"""Rift still: a round parasol roof, glass orbs on a vermilion arch, a curved back wall, two great orbs outside, feeding a stone basin counter."""
	m = K("B_Potions", bp.place(*bp.POTIONS, bp.TOP, bp.POTIONS_FACE))
	rift_base(m, 8.2, 6.4, n=10)
	# arch of beams, behind the keeper
	ar, az, ay = 5.6, 3.4, 1.2
	n = 14
	ap = lambda k: (ar * math.cos(math.pi * k / n), ay, az + ar * math.sin(math.pi * k / n))
	for k in range(n):
		m.beam(ap(k), ap(k + 1), 0.8, "verm")
	for sx in (-1, 1):
		m.beam((sx * ar, ay, 0.6), (sx * ar, ay, az), 0.8, "verm")
		m.box((1.5, 1.5, 0.9), (sx * ar, ay, 0.9), "black")
	# orbs with liquid: glow belly under a clear-looking cap, in a copper cradle
	for x, z, r, glow in ((-3.7, 5.6, 1.35, "g_mag"), (3.7, 5.6, 1.35, "g_green")):
		y = ay - 0.2
		m.lathe([(0, -r), (r * 0.7, -r * 0.7), (r, 0), (r * 0.96, r * 0.3)], (x, y, z), glow, 10)
		m.lathe([(r * 0.96, r * 0.3), (r * 0.7, r * 0.72), (r * 0.25, r)], (x, y, z), "mist", 10)
		m.lathe([(r * 1.04, 0.05), (r * 1.04, 0.3)], (x, y, z), "copper", 10)
		m.cyl(r * 0.28, 0.5, (x, y, z + r), "copper", n=7)
		m.beam((x, y, z + r + 0.3), (x, ay, min(8.9, az + math.sqrt(max(0, ar * ar - x * x)))), 0.22, "gold")
	for sx in (-1, 1):  # drip pipes down to the basin
		pp = [(sx * 3.7, ay - 0.2, 4.3), (sx * 3.9, 0.3, 4.0), (sx * 3.9, -0.5, 4.1), (sx * 3.9, -1.0, 3.5)]
		for a, b in zip(pp, pp[1:]):
			m.beam(a, b, 0.3, "copper", 6)
	# counter: an arc of stone with a liquid channel
	seg = 7
	R0, R1, cy0 = 4.4, 6.8, 2.4
	arc = lambda r, k, z: (r * math.sin(-0.72 + 1.44 * k / seg), cy0 - r * math.cos(-0.72 + 1.44 * k / seg), z)
	for k in range(seg):
		for r, flip, mt in ((R1 - 0.2, False, "basalt3"), (R0 + 0.2, True, "basalt3")):
			q = [arc(r, k, 0.6), arc(r, k + 1, 0.6), arc(r, k + 1, 3.3), arc(r, k, 3.3)]
			m.face(q[::-1] if flip else q, mt)
		q = [arc(R1 - 0.12, k, 2.3), arc(R1 - 0.12, k + 1, 2.3), arc(R1 - 0.12, k + 1, 2.55), arc(R1 - 0.12, k, 2.55)]
		m.face(q, "g_cyan")
		for z0, z1, mt in ((3.3, 3.65, "basalt2"),):
			m.face([arc(R1, k, z1), arc(R1, k + 1, z1), arc(R0, k + 1, z1), arc(R0, k, z1)], mt)
			m.face([arc(R1, k, z0), arc(R1, k + 1, z0), arc(R1, k + 1, z1), arc(R1, k, z1)], mt)
			m.face([arc(R0, k + 1, z0), arc(R0, k, z0), arc(R0, k, z1), arc(R0, k + 1, z1)], mt)
			m.face([arc(R1, k, z0), arc(R0, k, z0), arc(R0, k + 1, z0), arc(R1, k + 1, z0)], mt)
	for k in (0, seg):
		q = [arc(R1 - 0.2, k, 0.6), arc(R1 - 0.2, k, 3.3), arc(R0 + 0.2, k, 3.3), arc(R0 + 0.2, k, 0.6)]
		m.face(q, "basalt")
		m.face(q[::-1], "basalt")
	for a, s, glow, kd in ((-0.6, 1.1, "g_mag", 0), (-0.42, 0.8, "g_amber", 2), (0.28, 0.75, "g_green", 1), (0.44, 0.85, "g_mag", 2), (0.6, 1.15, "g_green", 0)):
		m.flask((5.6 * math.sin(a), cy0 - 5.6 * math.cos(a), 3.65), s, glow, kd)
	# shelf drums at the back
	for i, x in enumerate((-4.6, -2.6, 2.6, 4.6)):
		m.lathe([(0.8, 0), (1.0, 0.8), (0.8, 1.8), (0, 2.0)], (x, 3.0, 0.6), ("slate", "indigo")[i % 2], 8)
		m.lathe([(1.02, 0.7), (1.02, 0.9)], (x, 3.0, 0.6), ("g_mag", "g_green")[i % 2], 8)
	# a curved back wall of stone behind the keeper, with a lit shelf line and a row of vials
	bw = lambda k, z, r=6.6: (r * math.cos(math.pi * (0.12 + 0.76 * k / 7)), r * 0.75 * math.sin(math.pi * (0.12 + 0.76 * k / 7)), z)
	for k in range(7):
		for z0, z1, mt, r in ((0.6, 5.4, "slate", 6.6), (5.4, 5.7, "g_cyan", 6.58), (5.7, 9.0, "basalt2", 6.6)):
			q = [bw(k, z0, r), bw(k, z1, r), bw(k + 1, z1, r), bw(k + 1, z0, r)]
			m.face(q, mt)
			m.face([bw(k + 1, z0, r + 0.5), bw(k + 1, z1, r + 0.5), bw(k, z1, r + 0.5), bw(k, z0, r + 0.5)], "basalt" if mt != "g_cyan" else mt)
	for k in (0, 7):
		q = [bw(k, 0.6, 6.6), bw(k, 0.6, 7.1), bw(k, 9, 7.1), bw(k, 9, 6.6)]
		m.face(q, "basalt3")
		m.face(q[::-1], "basalt3")
	m.box((6.4, 1.0, 0.25), (0, 4.4, 4.2), "basalt3")
	for i, x in enumerate((-2.6, -1.3, 1.3, 2.6)):
		m.lathe([(0, 0), (0.42, 0.1), (0.45, 0.8), (0.2, 1.1), (0.2, 1.3)], (x, 4.3, 4.32), ("g_green", "g_amber", "g_mag", "g_green")[i], 6)
	# parasol roof on four posts
	for x, y in ((-6.0, -3.4), (6.0, -3.4), (-5.2, 4.0), (5.2, 4.0)):
		m.cyl(0.4, 8.4, (x, y, 0.5), "black", n=6)
	nr = 16
	m.lathe([(8.3, 9.2), (8.3, 8.8), (4.5, 9.5), (0.5, 9.9)], (0, 0, 0), "dark", nr, ["g_cyan", "dark", "dark"])
	m.lathe([(8.3, 9.2), (5.6, 10.3), (3.0, 11.9), (1.2, 13.2)], (0, 0, 0), "indigo", nr, ["indigo2", "indigo", "indigo2"])
	for k in range(0, nr, 2):
		a = k / nr * TAU + TAU / 2 / nr
		pr = [(8.35, 9.25), (5.6, 10.4), (3.0, 12.0), (1.2, 13.25)]
		for (r0, z0), (r1, z1) in zip(pr, pr[1:]):
			m.beam((r0 * math.cos(a), r0 * math.sin(a), z0), (r1 * math.cos(a), r1 * math.sin(a), z1), 0.3, "verm")
	m.gem((0, 0, 13.3), 0.7, 0.7, 0.6, "gold", 8)
	# the landmark: two great orbs hung out past the roof on vermilion arms, dripping into stone bowls
	for sx, glow in ((-1, "g_mag"), (1, "g_green")):
		x, y, z, r = sx * 10.6, -2.2, 5.4, 2.2
		arm = [(sx * 6.0, -2.6, 0.6), (sx * 8.0, -2.4, 4.0), (sx * 8.2, -2.3, 7.4), (sx * 9.2, -2.2, 9.0), (x, y, 9.2), (sx * 11.8, y, 8.6)]
		for p0, p1 in zip(arm, arm[1:]):
			m.beam(p0, p1, 0.6, "verm", 6)
		m.beam((x, y, 9.1), (x, y, z + r), 0.3, "gold")
		m.lathe([(0, -r), (r * 0.7, -r * 0.72), (r, 0), (r * 0.95, r * 0.35)], (x, y, z), glow, 10)
		m.lathe([(r * 0.95, r * 0.35), (r * 0.7, r * 0.75), (r * 0.3, r)], (x, y, z), "mist", 10)
		m.lathe([(r * 1.03, -0.05), (r * 1.03, 0.3)], (x, y, z), "copper", 10)
		m.cyl(r * 0.34, 0.5, (x, y, z + r - 0.05), "copper", n=8)
		m.taper((x, y, z - r), (x, y, z - r - 0.7), 0.4, 0.2, "copper", 6)
		m.taper((x, y, z - r - 0.6), (x, y, 1.2), 0.2, 0.2, glow, 5)
		m.lathe([(0.9, 0), (0.7, 0.4), (1.3, 1.3), (1.0, 1.3)], (x, y, 0), "basalt", 6)
		m.lathe([(1.02, 1.15), (0, 1.15)], (x, y, 0), glow, 6)
	for k in (0, 3):
		a = (-2.55, -1.95, -1.2, -0.6)[k]
		m.lantern((7.2 * math.cos(a), 7.2 * math.sin(a) * 0.95, 8.7), 0.4, "indigo2", "g_mag" if k % 2 else "g_green")
	m.board(0, -5.6, 11.2, 7, 2, "basalt3")
	for sx in (-1, 1):
		m.box((0.35, 1.4, 0.35), (sx * 2.6, -4.8, 10.9), "dark")
	return m, merchant("B_Potions", bp.POTIONS, bp.POTIONS_FACE, (0, -0.9, 1.4))


def b_market():
	"""Halo pavilion: a ring of auras behind the keeper, a rock island bedded on a pillared frame, trails from the frame."""
	m = K("B_Market", bp.place(*bp.MARKET_STALL, bp.TOP, bp.MARKET_FACE))
	w, d = 20, 11
	for k, (a, b, h, mt) in enumerate(((21, 11.8, 0.3, "basalt3"), (20.2, 11, 0.6, "basalt"))):
		m.box((a, b, h), (0, 0, h / 2), mt)
	m.box((20.4, 11.2, 0.14), (0, 0, 0.36), "g_cyan")
	f = -d / 2
	for x in (-9.5, -6.6, 6.6, 9.5):
		m.cyl(0.55, 8.2, (x, f + 0.7, 0.6), "verm", n=8)
		m.cyl(0.8, 0.9, (x, f + 0.7, 0.6), "black", n=8)
	for sx in (-1, 1):
		m.cyl(0.55, 8.2, (sx * 9.5, 4.6, 0.6), "verm", n=8)
		m.box((0.4, 8.6, 2.4), (sx * 9.5, 0.2, 1.8), "basalt3")
		m.box((0.46, 8.7, 0.16), (sx * 9.5, 0.2, 2.7), "g_cyan")
	m.box((18.4, 0.5, 8.0), (0, 4.8, 4.6), "indigo2")
	for x in (-7, 7):
		m.box((0.5, 0.7, 8.0), (x, 4.7, 4.6), "basalt3")
	# the aura rings: three concentric, with stones riding the outer one
	cz = 5.2
	for r, wd, glow, y in ((3.6, 0.5, "g_violet", 3.8), (2.75, 0.36, "g_cyan", 3.5), (2.0, 0.28, "lampw", 3.2)):
		m.hoop(r, (0, y, cz), wd, glow, n=24)
	m.box((3.0, 0.9, 1.4), (0, 3.9, 1.3), "basalt2")  # the cradle the rings stand in
	# counter
	cy = f + 1.7
	m.box((11.6, 2, 2.8), (0, cy, 2.0), "basalt3")
	m.box((12.4, 2.6, 0.4), (0, cy, 3.6), "verm")
	m.box((11.66, 2.06, 0.16), (0, cy, 2.95), "g_cyan")
	m.box((5, 0.14, 2.6), (0, cy - 1.06, 2.2), "silk")
	m.box((5, 0.16, 0.3), (0, cy - 1.07, 1.1), "gold")
	for x in (-4.4, 4.4):
		for k in (-0.9, 0, 0.9):
			m.box((0.4, 0.2, 2.0), (x + k, cy - 1.03, 1.7), "basalt2")
	for x, r, glow in ((-4.8, 0.95, "lampw"), (-2.9, 0.7, "g_amber"), (4.6, 0.95, "g_violet")):
		m.cyl(0.6, 0.3, (x, cy, 3.8), "black", n=8)
		m.box((0.3, 0.4, 0.4), (x, cy, 4.2), "gold")
		m.hoop(r, (x, cy, 4.35 + r), 0.2, glow, n=14)
	# trails streaming from the outer posts
	for sx in (-1, 1):
		for i, glow in enumerate(("g_amber", "g_violet", "g_cyan")):
			rows = []
			for k in range(10):
				t = k / 9
				x = sx * (6.9 + 0.75 * i + 0.35 * math.sin(t * 6 + i))
				wd = 0.36 * (1 - 0.8 * t)
				y = f + 0.3 - 0.5 * math.sin(t * 4 + i)
				rows.append([(x - wd, y, 8.7 - 5.0 * t), (x + wd, y, 8.7 - 5.0 * t)])
			m.strip(rows, glow)
		# display plinth in each outer bay
		x = sx * 8.1
		m.cyl(0.95, 1.5, (x, f + 1.6, 0.6), "basalt2", n=6, r2=0.8)
		m.gem((x, f + 1.6, 2.5), 0.6, 0.9, 0.5, "g_amber" if sx < 0 else "g_violet", 6)
	# the roof is a floating island (the Rift Shrine's own rocks): a hovering keel of stone, grass and blossom on top
	rnd = bp.rng
	nn = 16
	prof = [(0.0, 9.5), (0.74, 9.5), (0.95, 10.0), (1.0, 11.2), (1.0, 12.8), (0.95, 13.5)]
	jit = [[rnd.uniform(0.95, 1.04) for _ in range(nn)] for i in range(len(prof))]
	def ring(i, k):
		r, z = prof[i]
		a = k / nn * TAU
		c, q = math.cos(a), math.sin(a)  # a squared-off oval, so it covers the pillars' corners
		f_ = r * jit[i][k % nn]
		return (12.6 * f_ * math.copysign(abs(c) ** 0.7, c), 1.0 + (4.4 if q < 0 else 5.0) * f_ * math.copysign(abs(q) ** 0.7, q), z)
	for i in range(len(prof) - 1):
		for k in range(nn):
			mt = "grass" if i == 4 else ("basalt2", "slate", "basalt", "slate")[(k + i * 3) % 4]
			if i == 0:
				m.face([ring(0, k), ring(1, k + 1), ring(1, k)], mt)
			else:
				m.face([ring(i, k), ring(i, k + 1), ring(i + 1, k + 1), ring(i + 1, k)], mt)
	m.face([ring(5, k) for k in range(nn)], "grass")
	for x, y, r, mt in ((-9.4, 1.6, 1.5, "bloom"), (-7.6, 0.4, 1.1, "bloom2"), (-11.0, 0.6, 0.9, "bloom3"), (9.2, 1.2, 1.3, "bloom2"), (11.0, 0.8, 0.9, "bloom"), (-2.6, 1.8, 1.5, "bloom3"), (0.2, 1.2, 1.7, "bloom"), (2.8, 1.9, 1.4, "bloom2")):
		m.blob(r, (x, y, 15.55 - r * 0.95), mt, squash=0.8, jitter=0.12)
	for x in (-9.2, 9.4, 0):
		m.beam((x, 1.3, 13.2), (x, 1.3, 14.4), 0.5, "bark", 5)
	# what holds it: a stone frame on the six pillars, brackets out to the rock, and the rock bedded on it
	m.box((20.6, 0.9, 0.9), (0, f + 0.7, 9.1), "basalt3")
	m.box((20.6, 0.94, 0.14), (0, f + 0.7, 8.75), "g_cyan")
	m.box((20.6, 0.9, 0.9), (0, 4.6, 9.1), "basalt3")
	for x in (-9.5, -4.8, 0, 4.8, 9.5):
		m.box((0.8, 9.6, 0.8), (x, -0.1, 9.15), "basalt")
	for sx in (-1, 1):
		m.taper((sx * 9.5, 0, 8.2), (sx * 11.2, 0, 10.2), 0.9, 1.4, "basalt3")
		for x in (9.5, 6.6):
			m.box((1.4, 1.3, 0.4), (sx * x, f + 0.7, 8.5), "black")
		m.box((0.5, 3.0, 0.5), (sx * 5.5, -2.4, 11.6), "iron")
		# the landmark: a great aura ring each side, riding on a stone cradle with loose stones round it
		x, y, r, glow = sx * 14.2, -2.6, 3.2, ("g_amber" if sx < 0 else "g_violet")
		m.cyl(1.9, 0.6, (x, y, 0), "basalt3", n=6)
		m.cyl(1.2, 1.2, (x, y, 0.6), "basalt", n=6, r2=0.8)
		m.hoop(r, (x, y, 5.6), 0.55, glow, n=20)
		m.hoop(r - 0.75, (x, y - 0.1, 5.6), 0.22, "lampw", n=18)
		for q in (-1, 1):  # two claws of the cradle hold the ring
			m.taper((x + q * 0.9, y, 0.6), (x + q * 1.7, y, 3.4), 0.9, 0.6, "basalt2")
	m.board(0, -3.8, bp.MARKET_SIGN_Y, 16, 4.1, "indigo2")
	return m, merchant("B_Market", bp.MARKET_STALL, bp.MARKET_FACE, (0, -1.5, 1.35), height=5.7)


def b_index():
	"""Stele archive: five standing stones in a fan, lit card tiles, a lectern and stacked tomes."""
	m = K("B_Index", bp.place(*bp.INDEX, bp.TOP, bp.INDEX_FACE))
	rift_base(m, 13.2, 4.8, n=12)
	colours = ["r_common", "r_rare", "r_epic", "r_leg", "r_myth"]
	glows = ("g_cyan", "g_violet", "g_amber")
	def stele(x, y, w, h, yaw, cols, rows, seed, top_cut):
		old = m.local
		m.local = Matrix.Translation((x, y, 0.6)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
		m.plate([(-w / 2, 0), (w / 2, 0), (w / 2 * 0.96, h - top_cut), (w / 2 * 0.55, h), (-w / 2 * 0.7, h - top_cut * 0.5), (-w / 2 * 0.97, h - top_cut * 1.5)], 1.1, "stele")
		m.box((w + 0.5, 1.7, 0.9), (0, 0, 0.4), "slate")
		m.box((w + 0.54, 1.74, 0.14), (0, 0, 0.95), "g_cyan")
		for q in (-1, 1):
			m.box((0.14, 0.1, h * 0.72), (q * (w / 2 * 0.95 - 0.12), -0.58, h * 0.36 + 0.6), "g_cyan")
		cw, ch = (w - 0.9) / cols, 2.15
		for i in range(cols):
			for j in range(rows):
				cx, cz = -w / 2 + 0.45 + cw * (i + 0.5), 2.5 + ch * j
				m.box((cw - 0.3, 0.2, ch - 0.35), (cx, -0.58, cz), "gold" if (i + j + seed) % 5 == 0 else "white")
				m.box((cw - 0.5, 0.24, ch - 0.55), (cx, -0.6, cz), colours[(i * 3 + j * 2 + seed) % 5])
				m.py = -0.75
				ink = "ink" if (i + 2 * j + seed) % 3 == 0 else "white"
				m.plate([(cx - 0.45, cz - 0.75), (cx + 0.45, cz - 0.75), (cx + 0.3, cz - 0.2), (cx - 0.3, cz - 0.2)], 0.06, ink)
				m.ydisc(0.28, (cx, -0.75, cz + 0.15), 0.06, ink, 6)
				m.py = 0
		m.local = old
	stele(0, 0.9, 9.4, 13.2, 0, 5, 3, 0, 1.0)
	for sx in (-1, 1):
		stele(sx * 7.3, 0.5, 4.4, 10.6, sx * -14, 2, 3, 2 + sx, 0.9)
		stele(sx * 11.3, -0.9, 2.8, 7.6, sx * -30, 1, 2, 4 + sx, 0.7)
	m.box((8.2, 0.3, 1.3), (0, 0.3, 10.7), "black")  # header strip: the game writes its title here
	m.box((8.5, 0.2, 1.6), (0, 0.36, 10.7), "gold")
	m.hoop(1.15, (0, 0.9, 13.0), 0.34, "gold", n=14)
	m.gem((0, 0.9, 13.0), 0.5, 0.75, 0.75, "g_cyan", 6)
	# tomes stacked on the base, a reading stand on the right
	for i, (x, w_, mt) in enumerate(((5.4, 1.9, "verm"), (5.5, 1.7, "teal"), (5.35, 1.8, "silk"))):
		m.box((w_, 1.3, 0.36), (x, -2.9, 0.9 + 0.4 * i), mt, R3(8 * i - 8, "Z"))
		m.box((w_ - 0.1, 1.2, 0.22), (x, -2.96, 0.9 + 0.4 * i), "paper", R3(8 * i - 8, "Z"))
	# lectern
	m.cyl(0.9, 0.5, (-5.6, -4.2, 0.2), "stele", n=6)
	m.cyl(0.4, 2.3, (-5.6, -4.2, 0.6), "stele2", n=6)
	m.box((2.2, 1.5, 0.25), (-5.6, -4.2, 3.0), "verm", R3(18, "X"))
	for sx in (-1, 1):
		m.box((0.8, 1.0, 0.14), (-5.6 + sx * 0.4, -4.3, 3.25), "paper", R3(18, "X"))
	return m, merchant("B_Index", bp.INDEX, bp.INDEX_FACE, (-3.0, -4.0, 0.62), yaw=-10, height=5.4)


def b_sensei():
	"""Rift dais: a cracked stone disc with a lit road of ten square milestones rising round the elder's back."""
	m = K("B_Sensei", bp.place(*bp.SENSEI, bp.TOP, bp.SENSEI_FACE))
	rift_base(m, 4, 4, n=8, h=0.6)
	# ten square milestones standing on the dais, each taller than the last: the tracks in order
	for i in range(10):
		t = i / 9
		a = math.radians(200 - 220 * t)
		x, y, h = 3.2 * math.cos(a), 0.2 + 2.6 * max(math.sin(a), -0.2), 1.5 + 4.0 * t
		rot = R3(-math.degrees(math.atan2(x, y + 1.5)), "Z")
		m.box((0.8, 0.6, h), (x, y, 0.55 + h / 2), "slate" if i % 2 else "basalt2", rot)
		m.box((0.9, 0.7, 0.2), (x, y, 0.55 + h), "gold" if i == 9 else "basalt3", rot)
		m.box((0.2, 0.64, h * 0.5), (x, y, 0.75 + h * 0.6), "g_amber" if i == 9 else "g_cyan", rot)
	return m, merchant("B_Sensei", bp.SENSEI, bp.SENSEI_FACE, (0, -0.5, 0.62), height=5.0)


PIECES = {
	"Shop": (bp.SHOP, bp.SHOP_FACE, a_shop, b_shop, 15.05),
	"Potions": (bp.POTIONS, bp.POTIONS_FACE, a_potions, b_potions, 15.05),
	"Market": (bp.MARKET_STALL, bp.MARKET_FACE, a_market, b_market, 17.0),
	"Index": (bp.INDEX, bp.INDEX_FACE, a_index, b_index, 17.25),
	"Sensei": (bp.SENSEI, bp.SENSEI_FACE, a_sensei, b_sensei, 8.2),
}
HEADERS = {  # Client/PlazaWayfinding and SpawnArea: fixed header points, drawn as a plain coloured marker (no text)
	"Shop": ((-78.945, 18, -2.924), "blue"), "Potions": ((-53.755, 18, -57.891), "rose"), "Market": ((2.905, 20, -78.446), "silk"),
	"Index": ((61.555, 20, -57.158), "gold"), "Sensei": ((bp.SENSEI[0], 8.2, bp.SENSEI[1]), "orange"),
}


def size(m):
	xs, ys, zs = zip(*[(v.x, v.y, v.z) for v in m.v])
	return max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), max(zs)


def mtris(m):
	return sum(len(f) - 2 for f in m.f)


MAX_TRIS = {  # the first reviewed draft (7068e5a6): a revision may not cost more
	"A_Shop": 3582, "A_Potions": 3663, "A_Market": 2996, "A_Index": 3282, "A_Sensei": 711, "B_Shop": 2352, "B_Potions": 3153,
	"B_Market": 3852, "B_Index": 2605, "B_Sensei": 1120, "A_Shop_Merchant": 876, "A_Potions_Merchant": 712,
	"A_Market_Merchant": 699, "A_Index_Merchant": 800, "A_Sensei_Merchant": 634, "B_Shop_Merchant": 940,
	"B_Potions_Merchant": 763, "B_Market_Merchant": 768, "B_Index_Merchant": 740, "B_Sensei_Merchant": 684,
}


def check(m, key, top):
	"""The fixed limits: floor edge, header height, sky loop ribbon and posts."""
	bad = []
	if mtris(m) > MAX_TRIS[key]:
		bad.append(f"{mtris(m)} tris over {MAX_TRIS[key]}")
	if "Sensei" in key and max(v.z for v in m.v) > 6.2:
		bad.append(f"Sensei height {max(v.z for v in m.v):.2f} over 6.2")
	hi = max(v.z for v in m.v) + bp.TOP
	if hi > top + 0.001:
		bad.append(f"top y {hi:.2f} over today's {top}")
	posts = [(62 * math.cos(math.radians(a)), 62 * math.sin(math.radians(a))) for a in (45, 100, 200, 250, 315)]
	for v in m.v:
		p = m.matrix @ v
		x, z, y = p.x, -p.y, p.z
		if abs(x) > 94 or abs(z) > 110:
			bad.append(f"past the floor edge ({x:.1f}, {z:.1f})")
			break
		if y < bp.TOP + 0.0 - 0.01:
			bad.append(f"below the floor {y:.2f}")
			break
		if 59.4 < math.hypot(x, z) < 64.6 and y > 28:
			bad.append("in the sky loop")
			break
		if any(math.hypot(x - a, z - b) < 1.8 for a, b in posts):
			bad.append("in a sky loop post")
			break
	print(f"CHECK {key}: {'OK' if not bad else 'FAIL ' + '; '.join(bad)}")


def header_mark(col, key):
	(x, y, z), colour = HEADERS[key]
	m = K("Ctx_Header_" + key, bp.place(x, z, y, PIECES[key][1]))
	s = 0.9 if key != "Sensei" else 0.5
	m.gem((0, 0, 0), s, s * 1.2, s * 1.2, colour, 6)
	m.build(col)


def reset(key):
	v = dict(pw.VARIANTS["B"]) if key == "B" else {"pal": {}, "glow": {}}
	pw.reset(v)
	bp.PAL.update(PAL)
	bp.GLOW.update(GLOW)
	return v


def engine(scene):
	"""EEVEE as build_plaza.setup_world picked it (works headless on software GL); ENGINE=CYCLES for the CPU path tracer."""
	if os.environ.get("ENGINE") == "CYCLES":
		scene.render.engine = "CYCLES"
		scene.cycles.device = "CPU"
		scene.cycles.samples = int(os.environ.get("SAMPLES", "16"))
		scene.cycles.use_denoising = True
		scene.cycles.max_bounces = 3
		scene.render.use_persistent_data = True
	else:
		scene.eevee.taa_render_samples = int(os.environ.get("SAMPLES", "16"))
	scene.render.threads_mode = "FIXED"
	scene.render.threads = 2
	scene.render.resolution_x, scene.render.resolution_y = 1280, 720


def build(key, scene, v):
	world = bpy.data.collections.new("Plaza")
	ctx = bpy.data.collections.new("Context")
	for c in (world, ctx):
		scene.collection.children.link(c)
	bp.context(ctx)
	if key != "C":
		bpy.data.objects.remove(bpy.data.objects["Sensei_Dais"])  # the draft brings its own dais
	for m in [bp.floor(), bp.path(), bp.showpiece(), bp.hero_torii(), bp.sky_loop(), bp.sakura(*bp.GREAT_SAKURA, 20, 44, "GreatSakura"), pw.world_gate()]:
		m.build(ctx)
	for i, t in enumerate((87, 100)):
		for s in (-1, 1):
			bp.stone_lantern(*bp.along(t, s * 8.6), f"Lantern_{i}_{s}").build(ctx)
	bp.pedestal(bp.PEDESTAL[0], bp.PEDESTAL[1], bp.PEDESTAL[2], "so", bp.EXCLUSIVE_FACE).build(ctx)
	if key == "B":
		pw.sky(scene, v)
		for m in pw.accents() + [pw.rift(v)] + pw.islands():
			m.build(ctx)
	else:
		bp.petals(ctx)
	bp.rng.seed(11)
	print(f"TRIS {key} piece: tris, w x d x h studs, glow colours")
	for name, (pos, face, fa, fb, top) in PIECES.items():
		if key == "C":
			ms = {
				"Shop": lambda: [bp.stall(*pos, face, "SHOP", "blue", "crates")],
				"Potions": lambda: [bp.stall(*pos, face, "POTIONS", "purple", "bottles")],
				"Market": lambda: [bp.market_stall(), bp.market_sign()],
				"Index": lambda: [bp.index_board()],
				"Sensei": lambda: [pw.sensei_standin()],
			}[name]()
		else:
			ms = list((fa if key == "A" else fb)())
		for m in ms:
			m.build(world)
			w, d, h, _ = size(m)
			print(f"  {m.name}: {mtris(m)} tris, {w:.1f} x {d:.1f} x {h:.1f}, glow {[g for g in m.mats if g in bp.GLOW]}")
			if key != "C":
				check(m, m.name, top if "Merchant" not in m.name else 99)
		header_mark(ctx, name)
		player("Player_" + name, bp.place(*pos, bp.TOP, face), {"Index": (6.5, -8.5, 0), "Sensei": (6.4, 0.6, 0), "Market": (8.0, -9.5, 0)}.get(name, (5.6, -8.0, 0)), 200).build(ctx)
		p = Vector((face[0], face[1])) * 6  # a soft fill at each front, as the game's lanterns do
		pw.point(ctx, (pos[0] + p.x, bp.TOP + 7, pos[1] + p.y), "#FFC58A" if key != "B" else "#E8D8FF", 350 if key != "B" else 1800, 3)


def world_at(pos, face, side, fwd):
	"""Roblox (x, z) at side studs to the viewer's right and fwd studs out from the front."""
	return pos[0] + face[0] * fwd + face[1] * side, pos[1] + face[1] * fwd - face[0] * side


def shots(key):
	out = {}
	for name, (pos, face, *_r) in PIECES.items():
		small = name == "Sensei"
		wide = {"Market": 1.3, "Index": 1.3}.get(name, 1)
		f, t = (13, 3.6) if small else (25 * wide, 7)
		e = world_at(pos, face, {"Sensei": 5.0, "Index": 8.0}.get(name, 0), f)
		out[name + "_1front"] = ((e[0], bp.TOP + (4.5 if small else 6.5), e[1]), (pos[0], bp.TOP + t, pos[1]), 50)
		e = world_at(pos, face, 9 if small else -20 * wide, 9 if small else 19 * wide)
		out[name + "_2three_quarter"] = ((e[0], bp.TOP + (6.5 if small else 11), e[1]), (pos[0], bp.TOP + t - 0.5, pos[1]), 52)
		at = {"Index": (-5.0, 4.0), "Sensei": (0, 0.5)}.get(name, (0, 1.5))
		c = world_at(pos, face, *at)
		e = world_at(pos, face, at[0] + {"Index": 1.5, "Sensei": 3.0}.get(name, 2.2), at[1] + (8.5 if name != "Sensei" else 7.5))
		out[name + "_3close"] = ((e[0], bp.TOP + 5.6, e[1]), (c[0], bp.TOP + (4.6 if name not in ("Index", "Sensei") else 3.4), c[1]), 50)
		d = Vector(pos).normalized()
		sp = d * 4
		out[name + "_4from_spawn"] = ((sp.x, bp.SPAWN_TOP + 5.0, sp.y), (pos[0], bp.TOP + 6, pos[1]), 70)
	out["ring_full"] = ((14, 175, 70), (-8, 0, -8), 46)
	out["ring_court"] = ((25, 27, 55), (-12, 6, -48), 62)
	out["merchants"] = None
	return out


def lineup(key, cam, scene):
	"""All five merchants in a row beside the 5.5-stud player, on a plain ground far from the plaza."""
	col = bpy.data.collections.new("Lineup")
	scene.collection.children.link(col)
	base = bp.place(600, 600, 900, (0, 1))
	g = K("Ctx_Line", base)
	g.box((60, 30, 1), (0, 0, -0.5), "stone" if key == "A" else "basalt2")
	g.box((60, 1, 30), (0, 9, 10), "plaster2" if key == "A" else "basalt")
	g.build(col)
	player("Line_Player", base, (-10.5, 0, 0), 0).build(col)
	for i, n in enumerate(("Shop", "Potions", "Market", "Index", "Sensei")):
		m = K(f"Line_{n}", base)
		figure(m, (-6 + 4.2 * i, 0, 0), FIG[f"{key}_{n}"], -8, 5.5)
		m.build(col)
	pw.point(col, (596, 912, 620), "#FFF0E0", 5000 if key == "A" else 22000, 4)
	scene.render.film_transparent = False
	bp.shoot(cam, (600.2, 904.4, 622), (600.2, 902.8, 600), "merchants", 40)
	scene.collection.children.unlink(col)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	keys = [a for a in argv if a in ("A", "B", "C")] or ["A", "B", "C"]
	want = [a for a in argv if a not in ("A", "B", "C") and not a.startswith("--")]
	for key in keys:
		v = reset(key)
		scene = bpy.context.scene
		cam = bp.setup_world(scene)
		engine(scene)
		build(key, scene, v)
		if "--tris" in argv:
			continue
		bp.OUT = os.path.join(OUT, key)
		os.makedirs(bp.OUT, exist_ok=True)
		for name, s in shots(key).items():
			if want and not any(name.startswith(x) or name.endswith(x) for x in want):
				continue
			if s:
				bp.shoot(cam, s[0], s[1], name, s[2])
			elif key != "C":
				lineup(key, cam, scene)


if __name__ == "__main__":
	main()
