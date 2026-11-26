"""The World 2 colour re-export (docs/W2_REEXPORT_PLAN.md): bakes every mesh of the ledgers (World2/<Biome>.luau draftMesh rows, the
unplaced ones too) with the corrected vertex colours into build/world2/reexport/<key>.glb and writes manifest.json there: hashes, sizes,
tris, the old ids, and how it compares with the uploaded mesh. Writes nothing else: no Draft, ledger, pin or hero_moves.
Old = the same mesh baked as the uploaded ones were (bake_glb linear): when its hash is uploaded_assets.tsv's, the file re-made is the
uploaded one, so only the colours changed.
Headless: blender -b --factory-startup --python tools/blender/world2/reexport_props.py -- [track ...] [--manifest]
(--manifest with tracks: also join every track's json; without tracks all ten run and are joined)
"""

import hashlib
import json
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import export_props as ep  # noqa: E402

OUT = os.path.join(ep.ROOT, "build", "world2", "reexport")
ROW = re.compile(r'\t\t(W2_\w+) = draftMesh\(\n\t\t\t(\d+),\n\t\t\t("[^"]*"|nil),[^\n]*\n\t\t\t("[^"]*"|nil)')


def without_colours(path):
	"""geometry_info's hash of the GLB less its vertex colours."""
	data = open(path, "rb").read()
	n = struct.unpack_from("<I", data, 12)[0]
	gl = json.loads(data[20 : 20 + n])
	for mesh in gl["meshes"]:
		for prim in mesh["primitives"]:
			for a in [a for a in prim["attributes"] if a.startswith("COLOR")]:
				del prim["attributes"][a]
	j = json.dumps(gl).encode()
	j += b" " * (-len(j) % 4)
	return ep.geometry_info(b"glTF" + struct.pack("<III", 2, 0, len(j)) + b"JSON" + j + data[20 + n :])[0]


def placed_scales(draft):
	"""game prop -> the scales of its Placed rows (a cut prop's pieces as their whole)."""
	out = {}
	for m in re.finditer(r'\{\s*"(\w+)",([^{}]*?)\}', draft[draft.index("\tPlaced = {") : draft.index("\tHeroes = ")]):
		raw = re.sub(r"Whole = v\([^)]*\)|Group = \d+", "", m.group(2))
		st = re.search(r"v\(([^)]*)\)", raw)
		nums = [float(x) for x in re.sub(r"v\([^)]*\)", "", raw).split(",") if x.strip()]
		out.setdefault(re.sub(r"_p\d+$", "", m.group(1)), []).append([float(x) for x in st.group(1).split(",")] if st else [nums[4]] * 3)
	return out


def track(number):
	import bpy
	import build_track

	k = build_track.run(number, render=False, fast=True)
	biome = k.biome
	theme = open(os.path.join(ep.THEMES, biome + ".luau")).read()
	scales = placed_scales(open(os.path.join(ep.THEMES, biome + "Draft.luau")).read())
	uploaded = {}
	for line in open(ep.UPLOADED):
		f = line.rstrip("\n").split("\t") + [""] * 2
		uploaded[f[1]] = f
	real = {v: n for n, v in ep.RENAME.items()}
	props, out = {}, {}
	rows = {m.group(1): m for m in ROW.finditer(theme)}
	for key in rows:
		name = key[len("W2_%s_" % biome) :]
		piece = re.match(r"^(.*)_p(\d+)$", name)
		props.setdefault(piece.group(1) if piece else name, []).append((key, int(piece.group(2)) if piece else None))
	for game, keys in props.items():
		ob = k.props[real.get(game, game)]
		lo, hi = ep.bounds(ob.data)
		whole = (ob, ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2), [hi[i] - lo[i] for i in range(3)])
		made = []
		if any(q for _, q in keys):
			big = [max(s[i] for s in scales.get(game, [[1.0] * 3])) for i in range(3)]
			for _, me in ep.split(ob, lo, hi, ep.cells(whole[2], big)):
				plo, phi = ep.bounds(me)
				o = bpy.data.objects.new(me.name, me)
				bpy.context.scene.collection.objects.link(o)
				made.append((o, ((plo[0] + phi[0]) / 2, plo[1], (plo[2] + phi[2]) / 2), [phi[i] - plo[i] for i in range(3)]))
			assert len(made) == len(keys), (game, "cut in %d pieces, the ledger has %d" % (len(made), len(keys)))
		for key, q in keys:
			o, centre, size = made[q - 1] if q else whole
			path, old = os.path.join(OUT, key + ".glb"), os.path.join(OUT, key + "_old.glb")
			ep.bake_glb(o, centre, path)
			ep.bake_glb(o, centre, old, linear=True)
			new_hash, tris, verts, _, _ = ep.geometry_info(path)
			old_hash, up = ep.geometry_info(old)[0], uploaded.get(key, [""] * 5)
			same = without_colours(path) == without_colours(old)
			os.remove(old)
			assert same and tris == int(rows[key].group(2)), (key, same, tris, rows[key].group(2))
			out[key] = {
				"Track": number,
				"Biome": biome,
				"Placed": len(scales.get(game, ())),
				"Hash": new_hash,
				"OldHash": old_hash,
				"UploadedHash": up[4],
				"OldModel": up[2],
				"OldMesh": re.sub(r"\D", "", rows[key].group(3)),
				"OldReviewed": rows[key].group(4).strip('"'),
				"Tris": tris,
				"Verts": verts,
				"Size": [round(v, 1) for v in size],
				"Bytes": os.path.getsize(path),
				"Sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
			}
	print("REEXPORT", number, biome, len(out), "of", len(rows), flush=True)
	return out


def main():
	argv = [int(a) for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if a.isdigit()]
	os.makedirs(OUT, exist_ok=True)
	for n in argv or sorted(ep.APPROVED):
		rows = track(n)
		with open(os.path.join(OUT, "track%02d.json" % n), "w") as f:
			json.dump(rows, f, indent=1, sort_keys=True)
	paths = [os.path.join(OUT, "track%02d.json" % n) for n in sorted(ep.APPROVED)]
	if argv and "--manifest" not in sys.argv:  # tracks may run side by side: the last step joins them
		return
	whole = {}
	for p in paths:
		whole.update(json.load(open(p)))
	with open(os.path.join(OUT, "manifest.json"), "w") as f:
		json.dump(whole, f, indent=1, sort_keys=True)
	print("MANIFEST", len(whole))


if __name__ == "__main__":
	main()
