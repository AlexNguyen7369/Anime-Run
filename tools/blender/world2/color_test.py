"""The exported vertex colours are the prop's own colours (docs/BUGS.md w2-dark-props): bakes a one-box prop per kit colour
with export_props.bake_glb and reads COLOR_0 back as bytes. The Studio pictures show Roblox reads those numbers as sRGB, so
each must be the hex colour the draft was approved with. Writes only to a temporary folder.
Headless: blender -b --factory-startup --python tools/blender/world2/color_test.py   (exit code 1 on a wrong colour)
"""

import json
import os
import struct
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import export_props as ep  # noqa: E402
import kit  # noqa: E402

COLOURS = ["2E4A26", "243F2E", "3A2A20", "74482C", "E6AE3E", "E8EEF8", "000000", "FFFFFF", "808080"]
TOL = 2  # bytes: the layer is 8 bit


def colours(path):
	data = open(path, "rb").read()
	n = struct.unpack_from("<I", data, 12)[0]
	gl, binc = json.loads(data[20 : 20 + n]), data[28 + n :]
	a = gl["accessors"][gl["meshes"][0]["primitives"][0]["attributes"]["COLOR_0"]]
	v = gl["bufferViews"][a["bufferView"]]
	fmt, b, div = {5121: ("B", 1, 255), 5123: ("H", 2, 65535), 5126: ("f", 4, 1)}[a["componentType"]]
	w = {"VEC3": 3, "VEC4": 4}[a["type"]]
	base, stride = v.get("byteOffset", 0) + a.get("byteOffset", 0), v.get("byteStride", b * w)
	return {tuple(round(x / div * 255) for x in struct.unpack_from("<3" + fmt, binc, base + i * stride)) for i in range(a["count"])}


def main():
	bad = 0
	with tempfile.TemporaryDirectory() as folder:
		for h in COLOURS:
			mesh = bpy.data.meshes.new(h)
			mesh.from_pydata([(0, 0, 0), (1, 0, 0), (0, 1, 0)], [], [(0, 1, 2)])
			m = bpy.data.materials.new(h)
			m.use_nodes = True
			next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = kit.hexcol(h)
			mesh.materials.append(m)
			path = os.path.join(folder, h + ".glb")
			ep.bake_glb(bpy.data.objects.new(h, mesh), (0, 0, 0), path)
			want, got = tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)), colours(path)
			ok = all(abs(a - b) <= TOL for c in got for a, b in zip(c, want))
			bad += not ok
			print("COLOR %s %s got %s" % ("ok  " if ok else "FAIL", h, " ".join("%02X%02X%02X" % c for c in sorted(got))))
	print("COLOR pass %d fail %d" % (len(COLOURS) - bad, bad))
	sys.stdout.flush()
	os._exit(1 if bad else 0)


main()
