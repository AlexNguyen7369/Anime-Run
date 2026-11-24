"""Export the owner-approved World 2 drafts for the game (docs/WORLD2_SPEC.md "Blender first", BIOME_ENVIRONMENT_SPEC 4).

Builds each approved track exactly as build_track.py does (render=False), then writes:
- build/world2/export/<Biome>/W2_<Biome>_<Prop>.glb: one upload-ready mesh per unique non-road prop (one primitive,
  material colours baked to vertex colours, glTF Y up = Roblox Y up, -Z toward the road, base centre at the origin),
  plus manifest.json (prop, tris, hero, size, placements);
- src/shared/BiomeThemes/World2/<Biome>Draft.luau: the generated data the game theme reads (props with their sizes and
  parts fallbacks, explicit placements in track-local studs, lamps, ground, sky and sun values).
Road pieces (Wall, Dash, Apron, WinPad, Road, Ground) belong to the game's track builder and are not exported.
Headless:  Blender -b --factory-startup --python tools/blender/world2/export_props.py -- <number ...|approved>
Import-safe: main() runs only as a script. The biome modules are read, never changed.
"""

import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

# Owner-approved and frozen 2026-11-23 (WORLD2_SPEC "Render set approvals"). Tracks 2 and 9 are not approved.
APPROVED = {1: "DevilTokyo", 3: "RuinedCityZ", 4: "HauntedTunnel", 5: "KaijuBase", 6: "ElvenPlains", 7: "AntIsland", 8: "MonsterDen", 10: "HellGate"}
ROAD = {"Wall", "Dash", "Apron", "WinPad", "Road", "Ground"}
# Game names for draft props whose draft name holds a real character, brand or place name (design doc 5): asset keys and
# shipped data use the right-hand name only. The draft modules are frozen, so the rename lives here.
RENAME = {"SaitamaApt": "BrickFlat", "SeikoHouse": "OldWoodHouse", "Hallasan": "IslandVolcano", "Choga": "ThatchHouse", "KaijuCorpse": "GiantCorpse"}
EXPORT = os.path.join(ROOT, "build", "world2", "export")
THEMES = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2")
CAPS = {"hero": 20000, "mid": 3000, "unique": 12}  # BIOME_ENVIRONMENT_SPEC 4.3 / 4.5
HERO_MAX = 4  # placeholder: spec 4.3 heroes are one model each, 2-4 per biome
FALLBACK_PARTS = {"hero": 24, "mid": 6}  # placeholder: largest parts kept as the parts fallback silhouette (spec 4.2)


def origins():
	"""Track number -> (origin xyz, yaw) of its start, as chain.build chains them (TrackBuilder.CHAIN_ORIGIN)."""
	import glob

	import chain

	specs = sorted((chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))), key=lambda s: s["Number"])
	origin, yaw, out = chain.ORIGIN, 0.0, {}
	for spec in specs:
		_, end, heading, _ = chain.layout(spec)
		out[spec["Number"]] = (origin, yaw)
		origin, yaw = chain.to_world(origin, yaw, end), yaw + heading
	return out


def to_local(origin, yaw, p):
	"""Inverse of chain.to_world: a Roblox world point in the track's start frame."""
	x, y, z = p[0] - origin[0], p[1] - origin[1], p[2] - origin[2]
	c, s = math.cos(yaw), math.sin(yaw)
	return (x * c - z * s, y, x * s + z * c)


def record():
	"""Wrap Kit so the build leaves its prop parts, ground, sky and lamps on the Kit (the biome modules stay untouched)."""
	import kit

	if getattr(kit.Kit, "_recording", False):
		return
	prop, sky, ground, light = kit.Kit.prop, kit.Kit.sky, kit.Kit.ground, kit.Kit.light

	def rec(self):
		if not hasattr(self, "rec"):
			self.rec = {"parts": {}, "sky": None, "ground": None, "lights": []}
		return self.rec

	def prop_(self, name, parts):
		rec(self)["parts"][name] = [tuple(p) for p in parts]
		return prop(self, name, parts)

	def sky_(self, stops, strength=1.0, sun=None, fog=None):
		rec(self)["sky"] = {"stops": stops, "strength": strength, "sun": sun, "fog": fog}
		return sky(self, stops, strength, sun, fog)

	def ground_(self, color, margin=400, rough=1.0, y=-1.0):
		rec(self)["ground"] = {"color": color, "y": y}
		return ground(self, color, margin, rough, y)

	def light_(self, pos, color, energy=2000, radius=4):
		rec(self)["lights"].append((tuple(pos), color, energy))
		return light(self, pos, color, energy, radius)

	kit.Kit.prop, kit.Kit.sky, kit.Kit.ground, kit.Kit.light = prop_, sky_, ground_, light_
	kit.Kit._recording = True


# Blender (x, y, z) = Roblox (x, -z, y); the map is a proper rotation, so angles keep their sign per axis
def rb_of(v):
	return (v[0], v[2], -v[1])


def rb_matrix(m3):
	"""Blender 3x3 rotation -> Roblox 3x3 rows (P^T M P with P the Roblox -> Blender axis map)."""
	P = ((1, 0, 0), (0, 0, -1), (0, 1, 0))
	pm = [[sum(m3[i][k] * P[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
	return [[sum(P[k][i] * pm[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def bounds(mesh):
	pts = [rb_of(v.co) for v in mesh.vertices]
	lo = [min(p[i] for p in pts) for i in range(3)]
	hi = [max(p[i] for p in pts) for i in range(3)]
	return lo, hi


def material_of(color, o):
	if o.get("emit", 0) > 0:
		return "Neon"
	if o.get("alpha", 1) < 1:
		return "Glass"
	if o.get("metal", 0) >= 0.5:
		return "Metal"
	return "SmoothPlastic"


def fallback(parts, centre, keep):
	"""The `keep` largest parts (by volume) of a kit.prop parts list as Kit.part fields, re-centred on the prop's base
	centre. Shapes: box -> Block, ball -> Ball, wedge -> Wedge, cyl / cone -> an upright Cylinder (a cone at its mean
	width). Rot is Roblox Y, X, Z degrees (kit.prop's order)."""
	out = []
	for shape, size, pos, color, *rest in parts:
		o = rest[0] if rest else {}
		sx, sy, sz = size
		if shape == "cone" or (shape == "cyl" and o.get("taper", 1.0) != 1.0):
			k = (1 + o.get("taper", 0.0 if shape == "cone" else 1.0)) / 2
			sx, sz = sx * k, sz * k
		out.append(
			{
				"Shape": {"box": "Block", "ball": "Ball", "wedge": "Wedge", "cyl": "Cylinder", "cone": "Cylinder"}[shape],
				"Size": (sx, sy, sz),
				"Pos": (pos[0] - centre[0], pos[1] - centre[1], pos[2] - centre[2]),
				"Rot": tuple(o.get("rot", (0, 0, 0))),
				"Color": color,
				"Material": material_of(color, o),
				"Volume": abs(sx * sy * sz),
			}
		)
	out.sort(key=lambda p: -p["Volume"])
	return out[:keep]


def bake_glb(src, centre, path):
	"""One mesh, re-centred, with material base colours baked to a vertex colour layer, written as GLB."""
	import bpy

	me = src.data.copy()
	me.name = src.name + "_export"
	offset = (centre[0], -centre[2], centre[1])  # Roblox -> Blender
	for v in me.vertices:
		v.co.x -= offset[0]
		v.co.y -= offset[1]
		v.co.z -= offset[2]
	attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	cols = []
	for m in me.materials:
		b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
		cols.append(tuple(b.inputs["Base Color"].default_value) if b else (0.5, 0.5, 0.5, 1.0))
	for poly in me.polygons:
		c = cols[poly.material_index] if cols else (0.5, 0.5, 0.5, 1.0)
		for li in poly.loop_indices:
			attr.data[li].color = c
	me.materials.clear()
	ob = bpy.data.objects.new(src.name, me)
	bpy.context.scene.collection.objects.link(ob)
	for o in bpy.context.scene.objects:
		o.select_set(o == ob)
	bpy.context.view_layer.objects.active = ob
	kw = dict(filepath=path, use_selection=True, export_format="GLB", export_yup=True, export_apply=True, export_materials="NONE")
	try:
		bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
	except TypeError:  # older exporters name it differently
		bpy.ops.export_scene.gltf(export_colors=True, **kw)
	bpy.data.objects.remove(ob)
	bpy.data.meshes.remove(me)


def placements(k, names, origin, yaw, centres):
	"""Every placed instance of a prop: (name, local pos of its base centre, local rotation rows, Roblox-axis scale)."""
	import bpy

	bpy.context.view_layer.update()
	by_mesh = {k.props[n].data.name: n for n in names}
	lib = set(k.lib.objects)
	out = []
	c, s = math.cos(yaw), math.sin(yaw)
	inv_yaw = ((c, 0, -s), (0, 1, 0), (s, 0, c))  # CFrame.Angles(0, yaw, 0) transposed
	for ob in bpy.context.scene.objects:
		if ob.type != "MESH" or ob in lib or ob.data.name not in by_mesh or ob.hide_render:
			continue
		name = by_mesh[ob.data.name]
		mw = ob.matrix_world
		m3 = [[mw[i][j] for j in range(3)] for i in range(3)]
		scl = [math.sqrt(sum(m3[i][j] ** 2 for i in range(3))) for j in range(3)]
		rot = rb_matrix([[m3[i][j] / scl[j] for j in range(3)] for i in range(3)])
		sc = (scl[0], scl[2], scl[1])  # Blender local x, z, y = Roblox local X, Y, Z
		ctr = centres[name]
		off = [sum(rot[i][j] * ctr[j] * sc[j] for j in range(3)) for i in range(3)]
		world = rb_of(mw.translation)
		base = to_local(origin, yaw, (world[0] + off[0], world[1] + off[1], world[2] + off[2]))
		lrot = [[sum(inv_yaw[i][kk] * rot[kk][j] for kk in range(3)) for j in range(3)] for i in range(3)]
		out.append((name, base, lrot, sc))
	return out


def euler_yxz(r):
	"""(rx, ry, rz) radians with r = Ry(ry) Rx(rx) Rz(rz), as CFrame.fromEulerAnglesYXZ(rx, ry, rz)."""
	rx = math.asin(max(-1.0, min(1.0, -r[1][2])))
	if abs(r[1][2]) < 0.99999:
		return rx, math.atan2(r[0][2], r[2][2]), math.atan2(r[1][0], r[1][1])
	return rx, math.atan2(-r[2][0], r[0][0]), 0.0  # gimbal lock: fold Z into Y


def from_euler_yxz(rx, ry, rz):
	def mul(a, b):
		return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

	cy, sy, cx, sx, cz, sz = math.cos(ry), math.sin(ry), math.cos(rx), math.sin(rx), math.cos(rz), math.sin(rz)
	Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
	Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
	Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
	return mul(mul(Ry, Rx), Rz)


def lua_num(x):
	return ("%.3f" % x).rstrip("0").rstrip(".") if abs(x) > 5e-4 else "0"


def lua_vec(t):
	return "v(%s)" % ", ".join(lua_num(x) for x in t)


def write_luau(biome, number, props, placed, lights, rec, path):
	L = [
		"--!nonstrict",
		"-- GENERATED by tools/blender/world2/export_props.py from the owner-approved Blender draft (Track %d). Do not edit:" % number,
		"-- re-run the exporter. Track-local studs (TrackBuilder origin of this track, Y up, -Z toward the road at heading 0).",
		"-- Props: Size = the mesh's box; Parts = its largest kit parts, the parts fallback (BIOME_ENVIRONMENT_SPEC 4.2).",
		"-- PartsOnly: a prop of 1-2 kit boxes is built from them exactly and is no mesh asset.",
		"-- Placed: { Prop, X, Y, Z, Yaw, Scale } for each prop's base centre (radians, CFrame.fromEulerAnglesYXZ), or",
		"-- { Prop, X, Y, Z, Yaw, 1, RX, RZ, v(SX, SY, SZ) } for a tilted or stretched one. Biggest props first.",
		"-- Lights: { X, Y, Z, Color, Energy (Blender W) }, brightest first.",
		"local v, hex = Vector3.new, Color3.fromHex",
		"local M, P = Enum.Material, Enum.PartType",
		"",
		"return {",
		"\tProps = {",
	]
	for name, p in props.items():
		L.append("\t\t%s = {" % name)
		L.append("\t\t\tSize = %s," % lua_vec(p["size"]))
		L.append("\t\t\tTris = %d," % p["tris"])
		if p["hero"]:
			L.append("\t\t\tHero = true,")
		if p["partsOnly"]:
			L.append("\t\t\tPartsOnly = true,")
		L.append("\t\t\tParts = {")
		for q in p["parts"]:
			L.append(
				'\t\t\t\t{ %s, %s, hex("%s"), M.%s, P.%s, %s },'
				% (lua_vec(q["Size"]), lua_vec(q["Pos"]), q["Color"], q["Material"], q["Shape"], lua_vec(q["Rot"]))
			)
		L.append("\t\t\t},")
		L.append("\t\t},")
	L.append("\t},")
	L.append("\tPlaced = {")
	for name, pos, (rx, ry, rz), sc in placed:
		head = '"%s", %s, %s, %s, %s' % (name, lua_num(pos[0]), lua_num(pos[1]), lua_num(pos[2]), lua_num(ry))
		uniform = max(sc) - min(sc) <= 1e-3 * max(sc)
		if uniform and abs(rx) < 1e-4 and abs(rz) < 1e-4:
			L.append("\t\t{ %s, %s }," % (head, lua_num(sc[0])))
		else:
			L.append("\t\t{ %s, 1, %s, %s, %s }," % (head, lua_num(rx), lua_num(rz), lua_vec(sc)))
	L.append("\t},")
	L.append("\tLights = {")
	for pos, col, energy in lights:
		L.append('\t\t{ %s, %s, %s, hex("%s"), %g },' % (lua_num(pos[0]), lua_num(pos[1]), lua_num(pos[2]), col, energy))
	L.append("\t},")
	g = rec["ground"] or {"color": "777777", "y": -1.0}
	L.append('\tGround = { Color = hex("%s"), Y = %s },' % (g["color"], lua_num(g["y"])))
	sky = rec["sky"]
	if sky:
		stops = ", ".join('{ %s, hex("%s") }' % (lua_num(a), b) for a, b in sky["stops"])
		L.append("\tSky = { Stops = { %s }, Strength = %s }," % (stops, lua_num(sky["strength"])))
		if sky["sun"]:
			e, col, elev, azim = sky["sun"]
			L.append('\tSun = { Energy = %s, Color = hex("%s"), Elevation = %s, Azimuth = %s },' % (lua_num(e), col, lua_num(elev), lua_num(azim)))
		if sky["fog"]:
			d, col = sky["fog"]
			L.append('\tFog = { Density = %s, Color = hex("%s") },' % (lua_num(d), col))
	L.append("}")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as f:
		f.write("\n".join(L) + "\n")


def export(number, glb=True):
	import bpy

	import build_track

	if number not in APPROVED:
		raise SystemExit("track %d is not owner-approved (approved: %s)" % (number, sorted(APPROVED)))
	record()
	k = build_track.run(number, render=False)
	biome = k.biome
	assert biome == APPROVED[number], (number, biome)
	module = importlib.import_module("biomes." + biome)
	heroes = set(getattr(module, "MODEL_SHOTS", ()))
	rec = getattr(k, "rec", {"parts": {}, "sky": None, "ground": None, "lights": []})
	names = [n for n in k.props if n not in ROAD]
	game = {n: RENAME.get(n, n) for n in names}
	origin, yaw = origins()[number]
	folder = os.path.join(EXPORT, biome)
	os.makedirs(folder, exist_ok=True)
	props, centres = {}, {}
	for n in names:
		me = k.props[n].data
		me.calc_loop_triangles()
		lo, hi = bounds(me)
		centres[n] = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
		props[n] = {
			"partsOnly": 0 < len(rec["parts"].get(n, [])) <= 2 and all(q[0] == "box" for q in rec["parts"][n]),
			"tris": len(me.loop_triangles),
			"size": tuple(hi[i] - lo[i] for i in range(3)),
			"count": 0,
		}
	warns, placed = [], []
	mirrored = {}
	for name, pos, rot, sc in placements(k, names, origin, yaw, centres):
		det = sum(rot[0][i] * (rot[1][(i + 1) % 3] * rot[2][(i + 2) % 3] - rot[1][(i + 2) % 3] * rot[2][(i + 1) % 3]) for i in range(3))
		if det < 0:  # a mirrored instance: Roblox parts cannot mirror, so it stands unmirrored (same box)
			rot = [[-r[0], r[1], r[2]] for r in rot]
			mirrored[name] = mirrored.get(name, 0) + 1
		e = euler_yxz(rot)
		back = from_euler_yxz(*e)
		assert all(abs(back[i][j] - rot[i][j]) < 1e-4 for i in range(3) for j in range(3)), (name, rot)
		placed.append((name, pos, e, sc))
		props[name]["count"] += 1
	for n, p in props.items():
		# a hero landmark (spec 4.3) is a close-up model (MODEL_SHOTS) placed at most HERO_MAX times; a repeated close-up
		# model is a mid prop
		p["hero"] = n in heroes and p["count"] <= HERO_MAX
		parts = rec["parts"].get(n, [])
		p["parts"] = fallback(parts, centres[n], len(parts) if p["partsOnly"] else FALLBACK_PARTS["hero" if p["hero"] else "mid"])
	for name, n in mirrored.items():
		warns.append("%s: %d mirrored instances placed unmirrored" % (game[name], n))
	# biggest first, so the game's part budget trims the small props
	placed.sort(key=lambda p: -(props[p[0]]["size"][0] * props[p[0]]["size"][2] * p[3][0] * p[3][2]))
	lights = sorted(((to_local(origin, yaw, p), col, e) for p, col, e in rec["lights"]), key=lambda x: -x[2])
	meshes = [n for n in names if not props[n]["partsOnly"]]
	for n in meshes:
		if glb:
			bake_glb(k.props[n], centres[n], os.path.join(folder, "W2_%s_%s.glb" % (biome, game[n])))
	breaches = []
	if len(meshes) > CAPS["unique"]:
		breaches.append("unique meshes %d > %d" % (len(meshes), CAPS["unique"]))
	for n, p in props.items():
		if p["partsOnly"]:
			continue
		cap = CAPS["hero" if p["hero"] else "mid"]
		if p["tris"] > cap:
			breaches.append("%s %s tris %d > %d" % (game[n], "hero" if p["hero"] else "mid", p["tris"], cap))
		if p["count"] == 0:
			warns.append("%s: never placed" % game[n])
		if p["hero"] and max(p["size"][0], p["size"][2]) > 60:
			warns.append("%s: hero footprint %.0f x %.0f > 60 x 60 (placeholder, spec 4.3)" % (game[n], p["size"][0], p["size"][2]))
	manifest = {
		"Track": number,
		"Biome": biome,
		"Props": {
			"W2_%s_%s" % (biome, game[n]): {"Prop": game[n], "Tris": p["tris"], "Hero": p["hero"], "Size": [round(x, 2) for x in p["size"]], "Placements": p["count"], "File": "W2_%s_%s.glb" % (biome, game[n]) if glb else None}
			for n, p in props.items()
			if not p["partsOnly"]
		},
		"PartsOnly": {game[n]: p["count"] for n, p in props.items() if p["partsOnly"]},
		"Lights": len(lights),
		"Breaches": breaches,
		"Warnings": warns[:20] + (["... %d more" % (len(warns) - 20)] if len(warns) > 20 else []),
	}
	with open(os.path.join(folder, "manifest.json"), "w") as f:
		json.dump(manifest, f, indent=1)
	props = {game[n]: p for n, p in props.items()}
	placed = [(game[n], pos, e, sc) for n, pos, e, sc in placed]
	write_luau(biome, number, props, placed, lights, rec, os.path.join(THEMES, biome + "Draft.luau"))
	print("EXPORT", json.dumps(manifest))
	return manifest


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	nums = [a for a in argv if not a.startswith("--")]
	numbers = sorted(APPROVED) if nums in ([], ["approved"]) else [int(a) for a in nums]
	for n in numbers:
		export(n, glb="--no-glb" not in argv)


if __name__ == "__main__":
	main()
