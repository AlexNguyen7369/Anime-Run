# Target look (design doc section 5): big head, faceted meshes, no ink outline. Builds on the style2 kit.
from style2 import Kit  # noqa: F401

# about 1/3 of body height; the jaw narrows under a flat front. Face art keeps Head_F's z 4.0-5.3, so draw it large.
BIG_HEAD = [(0, 0, 3.98, 0.56, 0.6), (0, 0, 4.14, 0.82, 0.78), (0, 0, 4.42, 0.9, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]


def big_head(k, rows=BIG_HEAD):
	k.reshape("Head", "Head", rows, corner=0.12, nc=1, fit=True, flat_front=True)


def finish():
	"""Call last in model(): no ink shell, hard facets on everything."""
	import bpy

	for o in bpy.data.objects:
		if o.type == "MESH":
			o["flat"] = True
			for p in o.data.polygons:
				p.use_smooth = False
