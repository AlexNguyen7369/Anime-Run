# Shared drawing and modelling for the db_* painted characters: faceted hair shards, domes, lofts, the sharp eye, drawn
# muscle and the limb-face mirroring. Authored once; each char_db_*.py draws its own design with these.
import math
from contextlib import contextmanager

from atlas import INK, shade

# ---- modelling (kit = avatar_base; every point is in world coordinates, front faces -Y, character's left is +X)


def _mesh(kit, name, build, colour, parent, smooth=False):
	import bmesh
	import bpy

	bm = bmesh.new()
	build(bm)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for p in mesh.polygons:
		p.use_smooth = smooth
	return kit._obj(name, mesh, colour, parent)


def _bez(a, b, c, t):
	return tuple((1 - t) ** 2 * a[i] + 2 * (1 - t) * t * b[i] + t * t * c[i] for i in range(3))


def _norm(v):
	n = math.sqrt(sum(c * c for c in v)) or 1
	return tuple(c / n for c in v)


def _cross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def shard(kit, name, base, ctrl, tip, r, colour, parent, flatten=0.5, facing=None, rings=5, belly=0.22, power=0.8):
	"""One anime hair spike: a curved spine, a flat hexagon with a ridge down its middle, hard facets so one half catches
	the light. facing = the way its flat side looks; default straight out from the skull centre."""
	spine = [_bez(base, ctrl, tip, i / rings) for i in range(rings + 1)]

	def build(bm):
		prev = first = None
		for i in range(rings):
			t = i / rings
			d = _norm(tuple(spine[i + 1][k] - spine[i][k] for k in range(3)))
			out = facing or _norm((spine[i][0], spine[i][1] + 0.0, spine[i][2] - 4.75))
			side = _norm(_cross(d, out))
			up = _norm(_cross(side, d))
			rad = r * (1 - t) ** power * (1 + belly * math.sin(math.pi * min(1, t * 2.2)))
			ring = []
			for k in range(6):
				a = math.pi / 2 + k * math.pi / 3
				s, u = rad * math.cos(a), rad * flatten * math.sin(a)
				ring.append(bm.verts.new(tuple(spine[i][j] + side[j] * s + up[j] * u for j in range(3))))
			if prev:
				for k in range(6):
					bm.faces.new((prev[k], prev[(k + 1) % 6], ring[(k + 1) % 6], ring[k]))
			else:
				first = ring
			prev = ring
		end = bm.verts.new(spine[-1])
		for k in range(6):
			bm.faces.new((prev[k], prev[(k + 1) % 6], end))
		bm.faces.new(list(reversed(first)))

	o = _mesh(kit, name, build, colour, parent)
	o["lock"] = (list(base), list(tip))
	return o


def shards(kit, parts, colour, spec, prefix="Hair"):
	"""spec rows: (base, ctrl, tip, r) or (base, ctrl, tip, r, flatten)."""
	for i, row in enumerate(spec):
		shard(kit, f"Head_{prefix}{i}", row[0], row[1], row[2], row[3], colour, parts["Head"], flatten=row[4] if len(row) > 4 else 0.5)


def dome(kit, name, centre, radii, colour, parent, rot=(0, 0, 0), nu=12, nv=4, full=False):
	"""A smooth ellipsoid cap (or whole ellipsoid). rot: Euler XYZ radians about the centre, for domes on a front or side."""
	from mathutils import Euler, Vector

	m = Euler(rot, "XYZ").to_matrix()
	c = Vector(centre)

	def pt(u, v):
		a, b = 2 * math.pi * u / nu, (math.pi / 2) * v / nv
		return c + m @ Vector((radii[0] * math.cos(a) * math.cos(b), radii[1] * math.sin(a) * math.cos(b), radii[2] * math.sin(b)))

	def build(bm):
		rows = []
		lo = -nv if full else 0
		for v in range(lo, nv):
			rows.append([bm.verts.new(pt(u, v)) for u in range(nu)])
		top = bm.verts.new(pt(0, nv))
		for r0, r1 in zip(rows, rows[1:]):
			for u in range(nu):
				bm.faces.new((r0[u], r0[(u + 1) % nu], r1[(u + 1) % nu], r1[u]))
		for u in range(nu):
			bm.faces.new((rows[-1][u], rows[-1][(u + 1) % nu], top))
		if full:
			bot = bm.verts.new(pt(0, -nv))
			for u in range(nu):
				bm.faces.new((rows[0][(u + 1) % nu], rows[0][u], bot))
		else:
			bm.faces.new(list(reversed(rows[0])))

	return _mesh(kit, name, build, colour, parent, smooth=True)


def loft(kit, name, rings, colour, parent, smooth=False, lock=None):
	"""Closed skin through point rings of equal length, capped at both ends."""

	def build(bm):
		vs = [[bm.verts.new(p) for p in ring] for ring in rings]
		n = len(rings[0])
		for r0, r1 in zip(vs, vs[1:]):
			for k in range(n):
				bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
		bm.faces.new(vs[0])
		bm.faces.new(list(reversed(vs[-1])))

	o = _mesh(kit, name, build, colour, parent, smooth)
	if lock:
		o["lock"] = lock
	return o


def sculpted_head(kit, parts, profile, neck, n=4.0, sides=24):
	"""Replaces the head block with a painted shell cut to this character's skull and jaw: same Head_* atlas faces, projected
	straight on. profile rows: (z, half width, front depth, back depth), low to high. The block shrinks out of sight."""
	import avatar_paint
	from atlas import FACES, SIZE

	head = parts["Head"]
	for v in head.data.vertices:
		v.co *= 0.05
	rings = []
	for z, hx, front, back in profile:
		ring = []
		for i in range(sides):
			a = 2 * math.pi * i / sides
			c, s = math.cos(a), math.sin(a)
			k = (abs(c) ** n + abs(s) ** n) ** (-1 / n)
			ring.append((hx * k * c, (front if s < 0 else back) * k * s, z - 4.65))
		rings.append(ring)
	o = loft(kit, "Head_Shell", rings, "#808080", head, smooth=True)
	o.location = (0, 0, 4.65)
	o["painted"] = True
	avatar_paint._map_uv(o, "Head", (1.3, 1.2, 1.3), FACES, SIZE)
	kit.rbox("Head_Neck", (0.74, 0.7, 0.4), (0, 0.06, 4.08), neck, head, bevel=0.05)
	return o


def tube(kit, name, spine, radii, colour, parent, sides=8, flatten=1.0):
	"""Round tube along a point list, one radius per point: tails, antennae, horns."""
	rings = []
	for i, p in enumerate(spine):
		a, b = spine[max(0, i - 1)], spine[min(len(spine) - 1, i + 1)]
		d = _norm(tuple(b[k] - a[k] for k in range(3)))
		ref = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
		s = _norm(_cross(d, ref))
		u = _norm(_cross(s, d))
		rings.append([tuple(p[j] + radii[i] * (math.cos(2 * math.pi * k / sides) * s[j] + flatten * math.sin(2 * math.pi * k / sides) * u[j]) for j in range(3)) for k in range(sides)])
	return loft(kit, name, rings, colour, parent, smooth=True)


def lit(o, z0, z1):
	"""Cel band from z0 (start of the lit part) to z1, so a prop stays out of the swatch's bottom shadow band."""
	o["lock"] = ((0, 0, z0), (0, 0, z1))
	return o


def cuff(kit, part, name, cx, z, h, colour, w=1.08, y=0.0, d=None, bevel=0.025):
	"""A band standing proud of a limb: wristband, boot top, trouser bloom."""
	return kit.rbox(name, (w, d or w, h), (cx, y, z), colour, part, bevel=bevel)


def toe(kit, part, name, cx, colour, tip, y0=-0.5, reach=0.3, z0=0.0, h=0.32, w=1.0):
	"""A rounded boot toe past the block's front, with an optional darker tip piece."""
	hw = w / 2
	rings = [
		[(cx - hw, y0 + 0.04, z0), (cx + hw, y0 + 0.04, z0), (cx + hw, y0 + 0.04, z0 + h), (cx - hw, y0 + 0.04, z0 + h)],
		[(cx - hw * 0.98, y0 - reach * 0.55, z0), (cx + hw * 0.98, y0 - reach * 0.55, z0), (cx + hw * 0.92, y0 - reach * 0.55, z0 + h * 0.78), (cx - hw * 0.92, y0 - reach * 0.55, z0 + h * 0.78)],
		[(cx - hw * 0.72, y0 - reach, z0), (cx + hw * 0.72, y0 - reach, z0), (cx + hw * 0.6, y0 - reach, z0 + h * 0.42), (cx - hw * 0.6, y0 - reach, z0 + h * 0.42)],
	]
	return loft(kit, name, rings, colour, part)


# ---- painting helpers


@contextmanager
def mirrored(f, on=True):
	"""Draw in a flipped copy of the face: limbs are authored once, outer side on the right."""
	if on:
		f.out.append(f'<g transform="translate({f.w} 0) scale(-1 1)">')
	yield f
	if on:
		f.out.append("</g>")


def limb_faces(a, limb):
	"""Yields (side, key, face, mirror) so an author sees: F and B with the outer side on the right, O and I with the
	front on the left."""
	for side in ("Left", "Right"):
		for key in "FBOI":
			mir = {"F": side == "Right", "B": side == "Left", "O": side == "Right", "I": side == "Left"}[key]
			yield side, key, a[f"{side}{limb}_{key}"], mir


def head_faces(a, kind="Head"):
	yield a[f"{kind}_L"], False
	yield a[f"{kind}_R"], True


def clipped(f, clip_d, draw):
	"""Runs draw() with everything clipped to a path, so a pupil can't leave its eye."""
	cid = f"cl{f.name}{len(f.out)}"
	f.out.append(f'<clipPath id="{cid}"><path d="{clip_d}"/></clipPath><g clip-path="url(#{cid})">')
	draw()
	f.out.append("</g>")


def circle(cx, cy, rx, ry=None):
	ry = ry or rx
	return f"M{cx - rx} {cy}a{rx} {ry} 0 1 0 {2 * rx} 0a{rx} {ry} 0 1 0 {-2 * rx} 0Z"


def sharp_eye(f, cx, cy, sgn, w=25, h=10, slant=5, pupil=3.6, iris=None, look=0.0, lid=3.0, sclera="#fbf8f2", lash=INK, top_arc=1.0, lower=True, shine=True):
	"""A hard anime eye: a blade of white under a heavy upper lid, low at the nose and high at the temple, a small pupil
	pinned under the lid. sgn +1 = viewer's right. iris adds a coloured ring round the pupil. look moves it (+ = to the
	viewer's right)."""
	ix, ox = cx - sgn * w / 2, cx + sgn * w / 2
	iy, oy = cy + slant / 2, cy - slant / 2
	mx = (ix + ox) / 2
	shape = f"M{ix} {iy}Q{mx} {(iy + oy) / 2 - top_arc} {ox} {oy}Q{cx + sgn * w * 0.36} {cy + h * 0.72} {mx - sgn * w * 0.05} {cy + h * 0.62}Q{cx - sgn * w * 0.3} {cy + h * 0.55} {ix} {iy}Z"

	def inside():
		f.path(shape, sclera)
		py = cy + h * 0.02
		px = cx + look
		if iris:
			r = pupil * 1.55
			f.path(circle(px, py, r, r * 1.08), iris)
			f.path(f"M{px - r} {py - 1}a{r} {r} 0 0 1 {2 * r} 0Z", shade(iris, 0.5))
		f.path(circle(px, py, pupil, pupil * 1.08), "#0a080e")
		if shine:
			f.path(circle(px - pupil * 0.35, py - pupil * 0.45, pupil * 0.3), "#ffffff")
		# the lid's cast shadow on the white
		f.path(f"M{ix} {iy}Q{mx} {(iy + oy) / 2 - top_arc} {ox} {oy}V{oy + h * 0.28}Q{mx} {(iy + oy) / 2 + h * 0.18} {ix} {iy + h * 0.1}Z", "#4a3a58", opacity=0.22)

	clipped(f, shape, inside)
	f.path(f"M{ix - sgn * 1.2} {iy + 0.6}Q{mx} {(iy + oy) / 2 - top_arc - lid * 0.6} {ox + sgn * 2.4} {oy - 0.9}L{ox - sgn * 0.3} {oy + lid * 0.9}Q{mx} {(iy + oy) / 2 - top_arc + lid * 0.55} {ix - sgn * 1.2} {iy + 0.6}Z", lash)
	if lower:
		f.ink(f"M{ox - sgn * 1} {oy + 1.4}Q{cx + sgn * w * 0.36} {cy + h * 0.72} {mx - sgn * w * 0.05} {cy + h * 0.62}", 0.9, lash)


def slab_brow(f, cx, cy, sgn, colour, w=28, thick=7, angry=8):
	"""A wedge brow: thick at the nose, sharp at the temple, inner end pushed down by angry."""
	ix, ox = cx - sgn * w / 2, cx + sgn * w / 2
	f.path(f"M{ix} {cy + angry / 2}L{ix + sgn * 2} {cy + angry / 2 - thick}Q{cx} {cy - angry * 0.15 - thick * 0.9} {ox} {cy - angry / 2 - 1}Q{cx + sgn * 2} {cy - angry * 0.05} {ix} {cy + angry / 2}Z", colour)


def bare_arm(f, key, skin, top=0, wrist=166, d=None, line=None):
	"""Drawn arm muscle with hard cel shadow. F/B: outer side on the right. O/I: front on the left. Fills top..wrist."""
	d = d or shade(skin, 0.7)
	dd = shade(d, 0.72)
	l = shade(skin, 1.12)
	line = line or shade(skin, 0.32)
	h = wrist - top
	Y = lambda t: top + h * t
	f.path(f"M-5 {top - 5}H105V{wrist + 2}H-5Z", skin)
	if key == "F":
		# biceps belly, the crease at the elbow, forearm flexor
		f.path(f"M16 {Y(0.14)}Q50 {Y(0.06)} 84 {Y(0.14)}Q92 {Y(0.34)} 78 {Y(0.52)}Q50 {Y(0.6)} 22 {Y(0.52)}Q10 {Y(0.34)} 16 {Y(0.14)}Z", l, opacity=0.65)
		f.path(f"M84 {Y(0.12)}Q94 {Y(0.34)} 78 {Y(0.54)}L105 {Y(0.6)}V{Y(0.08)}Z", d, opacity=0.9)
		f.taper(16, Y(0.14), 8, Y(0.34), 22, Y(0.54), 1.5, line)
		f.taper(84, Y(0.12), 93, Y(0.34), 78, Y(0.54), 1.8, line)
		f.taper(22, Y(0.55), 50, Y(0.63), 78, Y(0.55), 1.6, line)
		f.taper(36, Y(0.7), 44, Y(0.84), 40, Y(0.99), 1.2, line)
		f.path(f"M68 {Y(0.64)}Q80 {Y(0.8)} 72 {Y(1)}H105V{Y(0.62)}Z", d, opacity=0.85)
		f.taper(66, Y(0.63), 80, Y(0.8), 70, Y(0.99), 1.5, line)
	elif key == "O":
		# deltoid cap, triceps split, long forearm muscle
		f.path(f"M-5 {Y(0.02)}H105V{Y(0.2)}Q70 {Y(0.34)} 52 {Y(0.42)}Q28 {Y(0.32)} -5 {Y(0.2)}Z", l, opacity=0.5)
		f.taper(-2, Y(0.2), 28, Y(0.34), 52, Y(0.43), 1.6, line)
		f.taper(102, Y(0.2), 74, Y(0.34), 52, Y(0.43), 1.6, line)
		f.path(f"M56 {Y(0.44)}Q84 {Y(0.5)} 96 {Y(0.6)}L105 {Y(0.6)}V{Y(0.18)}Q76 {Y(0.34)} 56 {Y(0.44)}Z", d, opacity=0.8)
		f.taper(52, Y(0.43), 56, Y(0.56), 44, Y(0.62), 1.3, line)
		f.taper(14, Y(0.66), 40, Y(0.74), 58, Y(0.99), 1.5, line)
		f.path(f"M60 {Y(0.66)}Q76 {Y(0.82)} 66 {Y(1)}H105V{Y(0.64)}Z", d, opacity=0.75)
		f.taper(84, Y(0.62), 92, Y(0.66), 96, Y(0.72), 1, line)
	elif key == "B":
		# triceps horseshoe, elbow, forearm extensor
		f.path(f"M18 {Y(0.14)}Q50 {Y(0.05)} 82 {Y(0.14)}L74 {Y(0.44)}Q50 {Y(0.34)} 26 {Y(0.44)}Z", l, opacity=0.5)
		f.taper(18, Y(0.14), 12, Y(0.34), 26, Y(0.46), 1.6, line)
		f.taper(82, Y(0.14), 88, Y(0.34), 74, Y(0.46), 1.6, line)
		f.taper(26, Y(0.46), 50, Y(0.33), 74, Y(0.46), 1.6, line)
		f.path(f"M78 {Y(0.14)}Q94 {Y(0.34)} 76 {Y(0.5)}L105 {Y(0.52)}V{Y(0.1)}Z", d, opacity=0.85)
		f.taper(40, Y(0.56), 50, Y(0.6), 60, Y(0.56), 1.2, line)
		f.taper(34, Y(0.66), 42, Y(0.82), 40, Y(0.99), 1.2, line)
		f.path(f"M64 {Y(0.64)}Q76 {Y(0.82)} 68 {Y(1)}H105V{Y(0.62)}Z", d, opacity=0.8)
	else:
		# inner arm: pit shadow, soft flexor line
		f.path(f"M-5 -5H105V{Y(0.16)}Q50 {Y(0.3)} -5 {Y(0.16)}Z", dd, opacity=0.75)
		f.taper(10, Y(0.34), 50, Y(0.48), 92, Y(0.34), 1.2, line)
		f.taper(38, Y(0.58), 50, Y(0.64), 62, Y(0.58), 1.1, line)
		f.taper(34, Y(0.72), 44, Y(0.86), 42, Y(0.99), 1.1, line)
		f.path(f"M-5 {Y(0.5)}Q14 {Y(0.75)} 6 {Y(1)}H-5Z", d, opacity=0.8)
		f.path(f"M105 {Y(0.5)}Q86 {Y(0.75)} 94 {Y(1)}H105Z", d, opacity=0.8)


def fist(f, key, skin, y=168, line=None, nails=None):
	"""A closed fist below the wrist. Same side rules as bare_arm. Fingers on the inner face, knuckles on the outer."""
	h = 208
	line = line or shade(skin, 0.36)
	d = shade(skin, 0.68)
	f.path(f"M-5 {y}H105V{h}H-5Z", skin)
	f.path(f"M-5 {h - 6}Q50 {h - 16} 105 {h - 6}V{h + 5}H-5Z", d, opacity=0.9)
	if key == "O":  # back of the hand, tendons to the knuckles
		f.path(f"M12 {y + 4}L24 {h - 12}M36 {y + 4}L40 {h - 12}M62 {y + 4}L60 {h - 12}M86 {y + 4}L78 {h - 12}", stroke=line, sw=0.9, opacity=0.65)
		f.taper(6, h - 12, 50, h - 8, 94, h - 12, 1.3, line)
	elif key == "I":  # the curled fingers
		for x in (22, 42, 62, 82):
			f.path(f"M{x - 16} {y + 16}H{x + 3}V{h - 4}H{x - 16}Z", shade(skin, 1.05), stroke=line, sw=1.3)
			if nails:
				f.path(f"M{x - 12} {h - 10}H{x}V{h - 3}H{x - 12}Z", nails)
		f.ink(f"M4 {y + 15}H98", 1.4, line)
	elif key == "F":  # thumb across the fingers
		f.path(f"M30 {y + 3}Q18 {y + 18} 34 {h - 6}Q62 {h - 2} 74 {h - 18}Q58 {y + 24} 56 {y + 4}Z", shade(skin, 1.06), stroke=line, sw=1.5)
		f.taper(38, y + 26, 54, y + 32, 70, h - 16, 0.9, line)
		if nails:
			f.path(f"M60 {h - 18}L74 {h - 18}L70 {h - 8}L58 {h - 9}Z", nails)
	else:  # heel of the hand
		f.taper(20, y + 12, 50, y + 22, 80, y + 12, 1.1, line)
		f.taper(40, y + 26, 50, h - 12, 60, y + 26, 0.8, line)
