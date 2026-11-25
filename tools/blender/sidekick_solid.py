# Helper for new Sidekick builds: winds every block outward. Blender's recalc can turn a wide thin block inside out, and the
# portrait pass hides back faces, so such a block vanishes from the drawing.
from mathutils import Vector


def outward(verts, faces):
	"""Faces of a convex solid, wound so each normal points away from the middle."""
	vs = [Vector(v) for v in verts]
	mid = sum(vs, Vector()) / len(vs)
	out = []
	for f in faces:
		pts = [vs[i] for i in f]
		n = sum((a.cross(b) for a, b in zip(pts, pts[1:] + pts[:1])), Vector())
		c = sum(pts, Vector()) / len(pts)
		out.append(list(f) if n.dot(c - mid) >= 0 else list(reversed(f)))
	return out


def solid_blocks(m):
	block, add, live = m.block, m.add, [False]

	def new_add(part, ramp, verts, faces, **kw):
		if live[0]:
			faces, kw["keep"] = outward(verts, faces), True
		add(part, ramp, verts, faces, **kw)

	def new_block(*args, **kw):
		live[0] = True
		block(*args, **kw)
		live[0] = False

	m.add, m.block = new_add, new_block
	return m
