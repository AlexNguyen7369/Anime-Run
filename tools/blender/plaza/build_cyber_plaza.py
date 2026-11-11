# Blender draft of the enclosed cyber dojo spawn (design doc 4.24 "Enclosed cyber dojo", owner 2026-11-10). Headless:
#   Blender -b --factory-startup --python tools/blender/plaza/build_cyber_plaza.py
# Blockout for owner review only: no game assets are exported. Positions are Layout C's (build_plaza.py, WORLD_REDESIGN_SPEC 4).
# 1 Blender unit = 1 stud; rb(x, y, z) maps Roblox world positions. Renders go to assets/plaza_draft/Cyber_*.png.
import math
import os
import random

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "plaza_draft")
rng = random.Random(11)

# Layout C, copied from build_plaza.py (fixed by the game or approved 2026-11-10)
SPAWN, PAD = (0, 0), (-84, 78)
PLOTS = {1: ((-42, -91), (0, 1)), 2: ((25, -107), (0, 1)), 3: ((86, -68), (-1, 0)), 4: ((110, 0), (-1, 0)),
	5: ((86, 68), (-1, 0)), 6: ((25, 107), (0, -1)), 7: ((-42, 91), (0, -1))}
TIER = {1: 1, 2: 4, 3: 7, 4: 10}  # plots shown owned at Dojo levels 1, 4, 7, 10; the rest are closed
TREE = (80, 118)  # the Great Sakura's spot: the hologram tree
AXIS_LEN = math.hypot(*PAD)
AXIS = (PAD[0] / AXIS_LEN, PAD[1] / AXIS_LEN)
PERP = (AXIS[1], -AXIS[0])
if PERP[0] * -42 + PERP[1] * 91 < 0:
	PERP = (-PERP[0], -PERP[1])
ECON, SUMMON = PERP, (-PERP[0], -PERP[1])


def along(t, off=0):
	return (AXIS[0] * t + PERP[0] * off, AXIS[1] * t + PERP[1] * off)


ECON_ROW = [("SHOP", along(-24, -46)), ("POTIONS", along(-2, -46)), ("MARKET", along(20, -46)), ("INDEX", along(42, -46))]
BEST_ROLL, ALTAR, PEDESTAL = along(-22, 40), along(8, 48), (-3.4, 53.7)
SENSEI = along(98, -12)

# The wall (proposed): a ring around the plaza, the wings and the Dojo ring; the door sits on the path axis.
WALL_C, WALL_R, WALL_H = (20, 0), 158, 60

CY, MA, GR, OR, GOLD = (0, 0.94, 1), (1, 0.17, 0.84), (0.65, 1, 0.23), (1, 0.48, 0.1), (1, 0.8, 0.2)


def rb(x, y, z):
	return Vector((x, -z, y))


def place(x, z, y=0.0, face=None):
	yaw = math.atan2(face[0], face[1]) if face else 0.0
	return Matrix.Translation(rb(x, y, z)) @ Matrix.Rotation(yaw, 4, "Z")


MATS = {}


def mat(name, color, emit=0.0, rough=0.5, metal=0.0):
	if name in MATS:
		return MATS[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (*color, 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if emit:
		b.inputs["Emission Color"].default_value = (*color, 1)
		b.inputs["Emission Strength"].default_value = emit
	MATS[name] = m
	return m


# THEME=hybrid (env): dark wood and red lacquer wired with neon, dusk sky, holo sakura (the proposals' option H inside the wall)
HYB = os.environ.get("THEME") == "hybrid"
STEEL = (lambda: mat("Wood", (0.075, 0.04, 0.025), rough=0.75)) if HYB else (lambda: mat("Steel", (0.05, 0.055, 0.08), rough=0.35, metal=0.8))
GUN = (lambda: mat("Stone", (0.05, 0.05, 0.06), rough=0.9)) if HYB else (lambda: mat("Gunmetal", (0.02, 0.022, 0.035), rough=0.6, metal=0.5))
LACQUER = lambda: mat("Lacquer", (0.35, 0.04, 0.04), rough=0.35)
PAPER = (0.96, 0.72, 0.38)


def roof(name, base, w, d, z, h=6):
	"""A hip roof (4-sided cone) with a neon rim along its eaves."""
	bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=math.sqrt(2) / 2, radius2=0.08, depth=1)
	o = bpy.context.object
	o.name = name
	o.matrix_world = base @ Matrix.Translation((0, 0, z + h / 2)) @ Matrix.Diagonal((w, d, h, 1)) @ Matrix.Rotation(math.pi / 4, 4, "Z")
	o.data.materials.append(mat("RoofTile", (0.04, 0.035, 0.05), rough=0.5))
	box(name + "Rim", GLOW(CY, 8), (w + 0.3, d + 0.3, 0.35), local=(0, 0, z), base=base)
GLOW = lambda c, s=6: mat(f"Glow{c}{s}", c, emit=s)


def box(name, m, size, local=(0, 0, 0), base=Matrix()):
	bpy.ops.mesh.primitive_cube_add(size=1)
	o = bpy.context.object
	o.name = name
	o.scale = size
	o.matrix_world = base @ Matrix.Translation(Vector(local)) @ Matrix.Diagonal((*size, 1))
	o.data.materials.append(m)
	return o


def cyl(name, m, r, h, at, verts=24):
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=at)
	o = bpy.context.object
	o.name = name
	o.data.materials.append(m)
	return o


def torus(name, m, R, r, at, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=at, rotation=rot, major_segments=96)
	o = bpy.context.object
	o.name = name
	o.data.materials.append(m)
	return o


def text(body, at_matrix, size, m):
	bpy.ops.object.text_add()
	o = bpy.context.object
	o.data.body = body
	o.data.align_x = "CENTER"
	o.data.size = size
	o.data.extrude = 0.15
	o.data.materials.append(m)
	o.matrix_world = at_matrix @ Matrix.Rotation(math.pi / 2, 4, "X")
	return o


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	sc = bpy.context.scene
	for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			sc.render.engine = engine
			break
		except TypeError:
			pass
	sc.render.resolution_x, sc.render.resolution_y = 1600, 900
	sc.view_settings.view_transform = "Standard"  # neon keeps its saturation; AgX turns it pastel
	# Sky: magenta horizon to deep purple overhead (client-local Zone 0 lighting in the game)
	w = bpy.data.worlds.new("Night")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.0, (0.75, 0.32, 0.3, 1) if HYB else (0.55, 0.05, 0.42, 1)
	ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.35, (0.02, 0.03, 0.14, 1) if HYB else (0.03, 0.01, 0.09, 1)
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
	nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
	bg.inputs["Strength"].default_value = 1.0


def build():
	# Floor, grid and path
	cyl("Floor", GUN(), WALL_R + 2, 1, rb(WALL_C[0], -0.5, WALL_C[1]), verts=96)
	bpy.ops.mesh.primitive_grid_add(x_subdivisions=64, y_subdivisions=64, size=2 * WALL_R, location=rb(WALL_C[0], 0.05, WALL_C[1]))
	g = bpy.context.object
	g.name = "Grid"
	import bmesh  # keep the grid inside the wall

	bm = bmesh.new()
	bm.from_mesh(g.data)
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.length > WALL_R - 3], context="VERTS")
	bm.to_mesh(g.data)
	bm.free()
	cyl("CityGround", mat("CityGround", (0.015, 0.012, 0.03), rough=0.9), 900, 1, rb(WALL_C[0], -0.7, WALL_C[1]), verts=64)
	wf = g.modifiers.new("wf", "WIREFRAME")
	wf.thickness = 0.12
	g.data.materials.append(mat("GridGlow", CY, emit=0.5))
	door_t = None
	for t in range(0, 400):  # the path axis meets the wall here
		x, z = along(t)
		if math.hypot(x - WALL_C[0], z - WALL_C[1]) >= WALL_R:
			door_t = t
			break
	mid = along(door_t / 2)
	axis_face = AXIS
	path = place(mid[0], mid[1], 0.12, axis_face)
	box("Path", mat("PathSteel", (0.03, 0.035, 0.06), rough=0.3, metal=0.6), (18, door_t, 0.2), base=path)
	for side in (-1, 1):
		box(f"PathEdge{side}", GLOW(CY, 8), (0.5, door_t, 0.3), local=(side * 9, 0, 0.05), base=path)

	# Wall ring with the blast door gap
	door_ang = math.atan2(along(door_t)[1] - WALL_C[1], along(door_t)[0] - WALL_C[0])
	n = 96
	for i in range(n):
		a = 2 * math.pi * i / n
		d = (a - door_ang + math.pi) % (2 * math.pi) - math.pi
		if abs(d) < 0.12:
			continue
		x, z = WALL_C[0] + WALL_R * math.cos(a), WALL_C[1] + WALL_R * math.sin(a)
		face = (-math.cos(a), -math.sin(a))  # inner face toward the plaza
		base = place(x, z, 0, face)
		seg = 2 * math.pi * WALL_R / n + 0.4
		box(f"Wall{i}", STEEL(), (seg, 4, WALL_H), local=(0, 0, WALL_H / 2), base=base)
		if i % 2 == 0:
			box(f"WallStrip{i}", GLOW(CY if i % 4 == 0 else MA, 5), (0.6, 0.3, WALL_H * 0.8), local=(0, -2.1, WALL_H * 0.45), base=base)
		if i % 6 == 0:
			box(f"WallPanel{i}", GLOW((0.05, 0.02, 0.18), 2), (seg * 0.8, 0.3, 10), local=(0, -2.15, 22), base=base)
	torus("WallRim", GLOW(CY, 10), WALL_R - 2, 0.7, rb(WALL_C[0], WALL_H, WALL_C[1]))

	# Blast door (closed) and its frame
	dx, dz = along(door_t)
	door = place(dx, dz, 0, (-AXIS[0], -AXIS[1]))
	for side in (-1, 1):
		box(f"DoorFrame{side}", STEEL(), (8, 8, WALL_H + 6), local=(side * 22, 0, (WALL_H + 6) / 2), base=door)
		box(f"DoorFrameGlow{side}", GLOW(MA, 8), (0.6, 0.4, WALL_H), local=(side * 18, -4.2, WALL_H / 2), base=door)
		box(f"DoorLeaf{side}", LACQUER() if HYB else mat("DoorSteel", (0.22, 0.24, 0.3), rough=0.6, metal=0.4), (18, 3, 44), local=(side * 9, 0, 22), base=door)
	box("DoorHeader", STEEL(), (52, 8, 10), local=(0, 0, 49), base=door)
	box("DoorSeam", GLOW(MA, 12), (0.5, 0.4, 44), local=(0, -1.8, 22), base=door)
	for k in range(6):  # hazard chevrons across both leaves
		box(f"DoorChevron{k}", GLOW(GOLD, 5), (34, 0.4, 1.0), local=(0, -1.8, 6 + k * 6), base=door)
	text("RACE START", door @ Matrix.Translation((0, -4.5, 47)), 4.5, GLOW(CY, 8))

	# RACE START holo arch at the gate pad, scanning ring, drones in place of lanterns
	px, pz = PAD
	arch = place(px, pz, 0, (-AXIS[0], -AXIS[1]))
	if HYB:  # the torii kept, lacquer with neon edges
		for side in (-1, 1):
			box(f"ToriiPost{side}", LACQUER(), (2.4, 2.4, 22), local=(side * 11, 0, 11), base=arch)
			box(f"ToriiEdge{side}", GLOW(CY, 8), (0.3, 2.6, 22), local=(side * 12.3, 0, 11), base=arch)
		box("ToriiKasagi", mat("RoofTile", (0.04, 0.035, 0.05)), (32, 3.5, 2), local=(0, 0, 23), base=arch)
		box("ToriiKasagiGlow", GLOW(CY, 8), (32.4, 3.7, 0.3), local=(0, 0, 22), base=arch)
		box("ToriiNuki", LACQUER(), (27, 1.6, 1.4), local=(0, 0, 18.5), base=arch)
	else:
		a = torus("HoloArch", GLOW(CY, 9), 15, 1.0, (0, 0, 0))
		a.matrix_world = arch @ Matrix.Rotation(math.pi / 2, 4, "X")
	r = torus("ScanRing", GLOW(MA, 7), 8, 0.4, (0, 0, 0))
	r.matrix_world = arch @ Matrix.Translation((0, 0, 9)) @ Matrix.Rotation(math.pi / 2, 4, "X")
	text("RACE START", arch @ Matrix.Translation((0, 0.5, 18)), 5, GLOW((1, 1, 1), 4))
	for i, (t, off) in enumerate([(-14, -14), (-14, 14), (-30, -14), (-30, 14)]):
		x, z = along(AXIS_LEN + t, off)
		if HYB:  # light pillars in place of the stone lanterns
			cyl(f"PillarBase{i}", GUN(), 1.6, 1.5, rb(x, 0.75, z), verts=8)
			cyl(f"Pillar{i}", GLOW(CY, 6), 0.6, 10, rb(x, 6.5, z), verts=8)
			cyl(f"PillarCap{i}", GLOW(PAPER, 6), 1.3, 1.6, rb(x, 12, z), verts=8)
		else:
			cyl(f"Drone{i}", STEEL(), 2.2, 0.8, rb(x, 16, z), verts=16)
			cyl(f"DroneLight{i}", GLOW(GR, 12), 0.6, 0.4, rb(x, 15.4, z), verts=12)

	# Economy wing: steel and glass with wall screens; floating headers
	screen_cols = [CY, GR, MA, GOLD]
	for i, (name, (x, z)) in enumerate(ECON_ROW):
		b = place(x, z, 0, ECON)
		box(f"{name}_Body", STEEL(), (16, 12, 13), local=(0, 0, 6.5), base=b)
		box(f"{name}_Glass", mat("Glass", (0.1, 0.25, 0.4), rough=0.05, metal=0.2), (14, 0.4, 5), local=(0, -6.1, 3), base=b)
		box(f"{name}_Screen", GLOW(PAPER if HYB else screen_cols[i], 3 if HYB else 5), (12, 0.3, 4.5), local=(0, -6.2, 9.2), base=b)
		if HYB:
			roof(f"{name}_Roof", b, 20, 16, 13, 6)
		else:
			box(f"{name}_Roof", GLOW(CY, 8), (17, 13, 0.5), local=(0, 0, 13.2), base=b)
		text(name, b @ Matrix.Translation((0, -1, 18)), 3.2, GLOW((1, 1, 1), 5))

	# Summon wing: Best Roll pedestal, Sidekick altar with its halo, the exclusive pedestal
	x, z = BEST_ROLL
	cyl("BestRollBase", STEEL(), 4, 4, rb(x, 2, z))
	bpy.ops.mesh.primitive_uv_sphere_add(radius=2.2, location=rb(x, 7, z))
	bpy.context.object.data.materials.append(GLOW(GR, 6))
	x, z = ALTAR
	for k, (rr, hh) in enumerate([(12, 2), (9, 2), (6, 2)]):
		cyl(f"AltarTier{k}", STEEL(), rr, hh, rb(x, 1 + 2 * k, z), verts=8)
		torus(f"AltarTrim{k}", GLOW(MA, 6), rr, 0.25, rb(x, 2 + 2 * k, z))
	h = torus("AltarHalo", GLOW(CY, 9), 6, 0.5, (0, 0, 0))
	h.matrix_world = place(x, z, 15, SUMMON) @ Matrix.Rotation(math.pi / 2, 4, "X")
	text("SIDEKICKS", place(x, z, 26, SUMMON), 3.2, GLOW((1, 1, 1), 5))
	x, z = PEDESTAL
	cyl("ExclusivePedestal", STEEL(), 3.5, 3, rb(x, 1.5, z), verts=8)
	torus("ExclusiveTrim", GLOW(GOLD, 8), 3.5, 0.3, rb(x, 3, z))
	cyl("ExclusiveFigure", mat("Figure", (0.15, 0.15, 0.2)), 1.2, 6, rb(x, 6, z))

	# Sensei beside the gate: a figure with a visor
	x, z = SENSEI
	cyl("SenseiBody", mat("Figure", (0.15, 0.15, 0.2)), 1.3, 6, rb(x, 3, z))
	box("SenseiVisor", GLOW(CY, 10), (2, 0.4, 0.6), local=(0, -1.3, 5.2), base=place(x, z, 0, SUMMON))

	# Hologram tree on a solid pedestal (replaces the Great Sakura)
	x, z = TREE
	cyl("TreePedestal", STEEL(), 8, 3, rb(x, 1.5, z), verts=8)
	if HYB:  # holo sakura: solid trunk, glowing pink canopy
		cyl("TreeTrunk", STEEL(), 2.2, 30, rb(x, 15, z), verts=10)
		for k in range(16):
			bpy.ops.mesh.primitive_uv_sphere_add(radius=rng.uniform(6, 10), location=rb(x + rng.uniform(-14, 14), rng.uniform(28, 40), z + rng.uniform(-14, 14)))
			bpy.context.object.data.materials.append(GLOW((1, 0.37, 0.72), 1.6))
	else:
		cyl("TreeTrunk", GLOW(CY, 4), 0.7, 30, rb(x, 18, z), verts=8)
	for k in range(0 if HYB else 8):
		rr = 22 - k * 2.4
		torus(f"TreeRing{k}", GLOW(MA if k % 2 else CY, 5), rr, 0.25, rb(x, 24 + k * 2.2, z))

	# Sky loop at its height (LOOP_H 30), drawn as a thin ring
	torus("SkyLoop", GLOW(GR, 6), 92, 0.4, rb(0, 30, 10))

	# Dojo ring: owned at four tiers in steel with stat-coloured rim lights (orange here); the rest closed
	for p, ((x, z), front) in PLOTS.items():
		b = place(x, z, 0, front)
		lv = TIER.get(p)
		if not lv:
			box(f"Plot{p}_Closed", STEEL(), (22, 18, 9), local=(0, 0, 4.5), base=b)
			box(f"Plot{p}_Shutter", mat("Shutter", (0.12, 0.12, 0.16), metal=0.7), (14, 0.3, 7), local=(0, -9.1, 3.5), base=b)
			box(f"Plot{p}_Sign", GLOW((1, 0.15, 0.15), 3), (6, 0.3, 1.2), local=(0, -9.2, 8), base=b)
			continue
		k = [1, 4, 7, 10].index(lv)
		box(f"Plot{p}_Base", STEEL(), (24, 20, 10), local=(0, 0, 5), base=b)
		box(f"Plot{p}_Screen", GLOW(OR, 4 + k), (16, 0.3, 5), local=(0, -10.2, 6), base=b)
		for s in range(k):
			w = 22 - s * 4
			box(f"Plot{p}_Tier{s}", STEEL(), (w, 18 - s * 3, 6), local=(0, 0, 13 + s * 6), base=b)
			box(f"Plot{p}_Rim{s}", GLOW(OR, 8), (w + 0.4, 18.4 - s * 3, 0.5), local=(0, 0, 10.2 + s * 6), base=b)
		if k >= 2:
			for side in (-1, 1):
				cyl(f"Plot{p}_Drone{side}", GLOW(OR, 10), 0.9, 0.5, (b @ Matrix.Translation((side * 16, -6, 14))).to_translation(), verts=12)
		if HYB:
			roof(f"Plot{p}_Roof", b, 26 - k * 4, 22 - k * 3, 10 + k * 6, 7)
		if k == 3:
			c = torus(f"Plot{p}_Crest", GLOW(CY, 10), 3, 0.4, (0, 0, 0))
			c.matrix_world = b @ Matrix.Translation((0, 0, 36)) @ Matrix.Rotation(math.pi / 2, 4, "X")
		text(f"LV {lv}", b @ Matrix.Translation((0, -10.5, 1.5)), 2.2, GLOW((1, 1, 1), 4))

	# City skyline beyond the wall
	for i in range(140):
		a = rng.uniform(0, 2 * math.pi)
		d = rng.uniform(WALL_R + 140, WALL_R + 520)
		x, z = WALL_C[0] + d * math.cos(a), WALL_C[1] + d * math.sin(a)
		w, h = rng.uniform(20, 55), rng.uniform(60, 220)
		b = place(x, z, 0, (math.cos(a), math.sin(a)))
		if HYB:  # mountains and a few lit pagoda towers instead of the city
			if i % 5:
				bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=w * 3, depth=h * 0.9, location=rb(x, h * 0.45, z))
				bpy.context.object.data.materials.append(mat("Mountain", (0.025, 0.03, 0.08), rough=0.9))
				continue
			h = h * 0.6
		box(f"City{i}", mat("City", (0.025, 0.02, 0.05), rough=0.8), (w, w, h), local=(0, 0, h / 2), base=b)
		for j in range(rng.randint(1, 4)):
			box(f"CityBand{i}_{j}", GLOW(rng.choice([CY, MA, (0.4, 0.2, 1)]), 2.5), (w + 0.4, w + 0.4, 0.8), local=(0, 0, rng.uniform(10, h - 4)), base=b)

	# Light: dim cool key and a few coloured fills so the steel reads
	bpy.ops.object.light_add(type="SUN", rotation=(math.radians(55), 0, math.radians(30)))
	bpy.context.object.data.energy = 0.6
	bpy.context.object.data.color = (0.6, 0.6, 1)
	fills = [(-30, -20, PAPER), (30, 30, CY), (-70, 60, PAPER), (60, -40, CY), (0, 0, (0.7, 0.7, 1))] if HYB else [(-30, -20, CY), (30, 30, MA), (-70, 60, CY), (60, -40, MA), (0, 0, (0.7, 0.6, 1))]
	for i, (x, z, c) in enumerate(fills):
		bpy.ops.object.light_add(type="POINT", location=rb(x, 25, z))
		bpy.context.object.data.energy = 60000
		bpy.context.object.data.color = c


def shot(name, eye, target, lens=24):
	sc = bpy.context.scene
	cam = bpy.data.objects.get("Cam")
	if not cam:
		cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
		sc.collection.objects.link(cam)
		sc.camera = cam
	cam.data.lens = lens
	cam.data.clip_end = 3000
	e, t = rb(*eye), rb(*target)
	cam.location = e
	cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
	os.makedirs(OUT, exist_ok=True)
	sc.render.filepath = os.path.join(OUT, f"{'Hybrid' if HYB else 'Cyber'}_{name}.png")
	bpy.ops.render.render(write_still=True)
	print("render", sc.render.filepath)


reset()
build()
gx, gz = PAD
sx, sz = along(-75)
shot("1_Spawn", (sx, 16, sz), (gx, 14, gz), lens=17)
shot("2_Overhead", (60, 330, -150), (10, 0, 10), lens=18)
shot("3_Door", (gx * 0.55, 8, gz * 0.55), (gx * 1.35, 25, gz * 1.35), lens=20)
shot("4_Dojos", (-10, 14, 10), (90, 10, -60), lens=20)
shot("5_SummonWing", (-40, 10, -10), (30, 10, 50), lens=22)
shot("6_Loading", (20, 95, 0), (20 + 700, 60, 250), lens=24)
