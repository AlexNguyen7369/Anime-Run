"""Blender concept drafts of the World 2 spawn plaza (design doc 4.47, WORLD_REDESIGN_SPEC 4 and 4.1, WORLD2_SPEC "Gate").

Owner idea 2026-11-23: "Should it be the sakura dojo theme but altered?" World 1's plaza (tools/blender/plaza/build_plaza.py,
imported, never edited) keeps its exact layout and footprint: same buildings, ring slots, spawn, torii and lanterns. Only
palette, sky, lighting and a few props change. The open World 1 return gate stands at hub-local (194, -176) = plaza
world (76, -96) (SpawnArea.WORLD_GATE_POS, hub-local = world + (118, -80)). Drafts only: no export, no game data.
  A  Moonlit Dojo: night, indigo sky, pale moon, crimson-violet glowing blossoms, lit lanterns, violet/magenta accents.
  B  Rift Shrine: dusk, a generic swirling portal ring beyond the torii, floating rock islands, cyan accents.
  C  Ember Dojo: autumn dusk, the Great Sakura as a red maple, orange sky, floating embers, copper accents.
Headless: Blender -b --factory-startup --python tools/blender/world2/plaza_w2.py -- [A B C] [shot ...] [--small]
Renders to assets/world2_draft/plaza/<A|B|C>/.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "plaza"))
sys.path.insert(0, HERE)

import build_plaza as bp  # noqa: E402
import build_track  # noqa: E402  (bloom)

OUT = os.path.join(bp.ROOT, "assets", "world2_draft", "plaza")
GATE = (76, -96)  # plaza world (x, z) of hub-local (194, -176)
GATE_FACE = bp.to_spawn(*GATE)
GATE_R = 11  # SpawnArea RING_RADIUS
PAL0, GLOW0 = dict(bp.PAL), dict(bp.GLOW)

VARIANTS = {
	"A": {
		"name": "Moonlit Dojo",
		"pal": {"bloom": "#C8326E", "bloom2": "#9A2E9E", "bloom3": "#E070B8", "grass": "#3E5A3A", "grass2": "#36503A"},
		"glow": {
			"bloom": ("#C8326E", 0.35), "bloom2": ("#9A2E9E", 0.35), "bloom3": ("#E070B8", 0.35),
			"lamp": ("#FFB765", 4.0), "neonb": ("#A64BFF", 2.2), "neonw": ("#E8C8FF", 1.6), "neono": ("#FF3FA4", 2.2),
			"acc1": ("#A64BFF", 3.0), "acc2": ("#FF3FB4", 3.0), "moon": ("#EEF0FF", 6.0),
		},
		"sky": [(0.0, "#2B2C6E"), (0.12, "#1E1F55"), (0.45, "#0E1030"), (1.0, "#05061A")],
		"sky_strength": 0.9, "stars": True,
		"sun": (1.4, "#A9B8FF", 40, -150),  # moonlight
		"lamp_w": 900,
	},
	"B": {
		"name": "Rift Shrine",
		"pal": {},
		"glow": {
			"lamp": ("#FFB765", 2.4), "neonb": ("#3CE6FF", 2.0), "neonw": ("#C8F8FF", 1.5), "neono": ("#4A8CFF", 2.0),
			"acc1": ("#3CE6FF", 3.0), "acc2": ("#7A9CFF", 3.0), "rift1": ("#1E50FF", 1.6), "rift2": ("#7A2BFF", 1.6),
			"rift3": ("#9FE8FF", 2.5),
		},
		"sky": [(0.0, "#FF9E70"), (0.08, "#E07A8A"), (0.3, "#7A5AA8"), (1.0, "#1E2458")],
		"sky_strength": 1.0,
		"sun": (2.4, "#FFB08A", 10, 120),
		"lamp_w": 500,
	},
	"C": {
		"name": "Ember Dojo",
		"pal": {"bloom": "#C8321E", "bloom2": "#E0561E", "bloom3": "#F08A2A", "grass": "#8E8A45", "grass2": "#7E7A3E", "bush": "#8A6A30"},
		"glow": {
			"lamp": ("#FFB765", 2.4), "neonb": ("#E0783A", 2.0), "neonw": ("#FFD0A0", 1.5), "neono": ("#FF5A1E", 2.0),
			"acc1": ("#E0783A", 3.0), "acc2": ("#FFB060", 3.0), "ember": ("#FF7A1E", 6.0),
		},
		"sky": [(0.0, "#FFC060"), (0.1, "#FF9040"), (0.35, "#C85A48"), (1.0, "#4A2E5A")],
		"sky_strength": 1.0,
		"sun": (3.0, "#FF9A50", 12, 120),
		"lamp_w": 500,
	},
}


def reset(v):
	"""Fresh scene and module state, so every variant builds the same layout (same rng seed) with its own palette."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bp.PAL.clear()
	bp.PAL.update(PAL0, steel="#8A8E98", gstone="#9E988C", gblack="#221E1E", gring="#46404F", robe="#3B4356", skin="#F0C8A0")
	bp.PAL.update(v["pal"])
	bp.GLOW.clear()
	bp.GLOW.update(GLOW0, gswirl=("#46D2FF", 2.5))  # the open gate's swirl colour in World 2 (SpawnArea)
	bp.GLOW.update(v["glow"])
	for store in (bp._mats, bp.SHIP, bp.SIGNS, bp._chars):
		store.clear()
	bp.rng.seed(7)


def sky(scene, v):
	world = bpy.data.worlds.new("W2Sky")
	world.use_nodes = True
	nt = world.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
	cr = ramp.color_ramp
	stops = v["sky"]
	cr.elements[0].position, cr.elements[0].color = stops[0][0], bp.rgb(stops[0][1])
	cr.elements[1].position, cr.elements[1].color = stops[-1][0], bp.rgb(stops[-1][1])
	for pos, col in stops[1:-1]:
		cr.elements.new(pos).color = bp.rgb(col)
	colour = ramp.outputs[0]
	if v.get("stars"):
		noise = nt.nodes.new("ShaderNodeTexVoronoi")
		noise.inputs["Scale"].default_value = 260
		nt.links.new(tc.outputs["Generated"], noise.inputs["Vector"])
		sr = nt.nodes.new("ShaderNodeValToRGB")
		nt.links.new(noise.outputs["Distance"], sr.inputs["Fac"])
		sr.color_ramp.elements[0].position, sr.color_ramp.elements[0].color = 0.0, (1.6, 1.6, 1.8, 1)
		sr.color_ramp.elements[1].position, sr.color_ramp.elements[1].color = 0.06, (0, 0, 0, 1)
		up = nt.nodes.new("ShaderNodeMath")  # no stars near the horizon
		up.operation = "GREATER_THAN"
		up.inputs[1].default_value = 0.12
		nt.links.new(sep.outputs["Z"], up.inputs[0])
		mask = nt.nodes.new("ShaderNodeMix")
		mask.data_type = "RGBA"
		mask.blend_type = "MULTIPLY"
		nt.links.new(up.outputs[0], mask.inputs["Factor"])
		nt.links.new(sr.outputs[0], mask.inputs["A"])
		mask.inputs["B"].default_value = (1, 1, 1, 1)
		add = nt.nodes.new("ShaderNodeMix")
		add.data_type = "RGBA"
		add.blend_type = "ADD"
		add.inputs["Factor"].default_value = 1.0
		nt.links.new(colour, add.inputs["A"])
		nt.links.new(sr.outputs[0], add.inputs["B"])
		gate = nt.nodes.new("ShaderNodeMix")
		gate.data_type = "RGBA"
		nt.links.new(up.outputs[0], gate.inputs["Factor"])
		nt.links.new(colour, gate.inputs["A"])
		nt.links.new(add.outputs[2], gate.inputs["B"])
		colour = gate.outputs[2]
	nt.links.new(colour, bg.inputs["Color"])
	bg.inputs["Strength"].default_value = v["sky_strength"]
	scene.world = world
	sun = scene.objects["Sun"]
	energy, col, elev, azim = v["sun"]
	sun.data.energy = energy
	sun.data.color = bp.rgb(col)[:3]
	sun.rotation_euler = (math.radians(90 - elev), 0, math.radians(azim))


def point(col, pos, colour, energy, radius=1.5):
	ob = bpy.data.objects.new("Lamp", bpy.data.lights.new("Lamp", "POINT"))
	ob.data.energy = energy
	ob.data.color = bp.rgb(colour)[:3]
	ob.data.shadow_soft_size = radius
	ob.location = bp.rb(*pos)
	col.objects.link(ob)


def lantern_spots():
	return [bp.along(t, s * 8.6) for t in (87, 100) for s in (-1, 1)]


def accents():
	"""WORLD_REDESIGN_SPEC 4.1 cyber accents in the variant's colour: torii neon lines, the RACE START scanning ring, and
	4 drones over the gate lanterns. Stall eave lines and wall screens are left out of the draft (too small to read)."""
	ms = []
	m = bp.M("W2_ToriiAccents", bp.place(bp.PAD[0], bp.PAD[1], bp.TOP, (-bp.AXIS[0], -bp.AXIS[1])))
	for y in (-0.95, 0.95):
		m.box((26, 0.2, 0.35), (0, y, 27), "acc1")
	for s in (-1, 1):
		m.box((0.35, 0.35, 22), (s * 10.1, 0, 14), "acc2")
	for k in range(14):  # 14 bars round a vertical ring, a quarter of each step clear
		a0, a1 = k / 14 * math.tau, (k + 0.75) / 14 * math.tau
		p = lambda a: (7 * math.cos(a), 0, 8.5 + 7 * math.sin(a))
		m.beam(p(a0), p(a1), 0.45, "acc1")
	ms.append(m)
	d = bp.M("W2_Drones", bp.place(0, 0, 0))
	for i, (x, z) in enumerate(lantern_spots()):
		c = bp.rb(x, bp.TOP + 15 + i, z)
		d.cyl(2.0, 0.5, (c.x, c.y, c.z), "steel", n=10)
		d.cyl(2.15, 0.25, (c.x, c.y, c.z + 0.12), "acc2" if i == 0 else "acc1", n=10)
		d.cyl(0.6, 0.5, (c.x, c.y, c.z - 0.5), "lamp", n=6)
	ms.append(d)
	return ms


def world_gate():
	"""SpawnArea.WorldGate, open (World 2 leads back to World 1): dais, two leaning monoliths, 16 ring segments with a neon
	lip, the portal disc. Local -Y faces the spawn."""
	m = bp.M("W2_WorldGate", bp.place(GATE[0], GATE[1], bp.TOP, GATE_FACE))
	r = GATE_R
	cy = r + 3
	for a in range(4):
		m.box((30, 30 * math.tan(math.pi / 8), 1.2), (0, 0, 0.6), "gstone", Matrix.Rotation(math.radians(a * 45), 3, "Z"))
	for s in (-1, 1):
		m.box((3.4, 4, r * 2 + 8), (s * (r + 3.5), 0, r + 4), "gblack", Matrix.Rotation(math.radians(-s * 6), 3, "Y"))
	seg = 16
	ln = 2 * math.pi * r / seg + 0.6
	for i in range(seg):
		a = i / seg * math.tau
		radial = Vector((-math.sin(a), 0, math.cos(a)))
		c = Vector((0, 0, cy)) + radial * r
		rot = Matrix.Rotation(-a, 3, "Y")
		m.box((ln, 3, 2.4), tuple(c), "gring", rot)
		m.box((ln, 3.2, 0.4), tuple(c - radial * 1.3), "gswirl", rot)
	disc = r - 0.75
	pts = [(disc * math.cos(k / 32 * math.tau), 0, cy + disc * math.sin(k / 32 * math.tau)) for k in range(32)]
	m.face(pts, "gswirl")
	m.face(pts[::-1], "gswirl")
	return m


def sensei_standin():
	"""A plain blocky figure where the game puts the Sensei rig (its model is not in this worktree)."""
	m = bp.M("Ctx_SenseiStandin", bp.place(bp.SENSEI[0], bp.SENSEI[1], bp.TOP + 0.6, bp.SENSEI_FACE))
	for s in (-1, 1):
		m.box((0.9, 0.9, 2.0), (s * 0.5, 0, 1.0), "robe")
		m.box((0.8, 0.8, 1.9), (s * 1.45, 0, 3.0), "robe")
	m.box((2.0, 1.0, 2.0), (0, 0, 3.0), "robe")
	m.box((1.2, 1.2, 1.2), (0, 0, 4.6), "skin")
	return m


def rift(v):
	"""B: a generic dimensional rift beyond the torii on its view axis: a ring of rough floating stones round a swirling
	blue-violet disc. Original shape: no show's gate design."""
	t = bp.AXIS_LEN + 95
	x, z = bp.along(t)
	m = bp.M("W2_Rift", bp.place(x, z, 88, (-bp.AXIS[0], -bp.AXIS[1])))
	R = 32
	for k in range(22):
		a = k / 22 * math.tau
		rr = R + bp.rng.uniform(-1, 2)
		m.blob(bp.rng.uniform(2.2, 3.6), (rr * math.cos(a), bp.rng.uniform(-1.5, 1.5), rr * math.sin(a)), "rock", squash=1.0, jitter=0.35)
	m.hoop(R - 3.5, (0, 0, 0), 1.6, "rift3", n=48)
	rings, n = 9, 40
	for i in range(rings):
		r0, r1 = (R - 4.5) * i / rings, (R - 4.5) * (i + 1) / rings
		for k in range(n):
			a0, a1 = k / n * math.tau, (k + 1) / n * math.tau
			colour = "rift1" if ((k + i * 2.2) % 8) < 4 else "rift2"
			if i == 0:
				colour = "rift3"
			q = [(r0 * math.cos(a0), 0, r0 * math.sin(a0)), (r1 * math.cos(a0), 0, r1 * math.sin(a0)), (r1 * math.cos(a1), 0, r1 * math.sin(a1)), (r0 * math.cos(a1), 0, r0 * math.sin(a1))]
			m.face(q, colour)
			m.face(q[::-1], colour)
	return m


def islands():
	"""B: floating rock islands above the plaza edge (outside the floor, clear of the ring and the sky loop)."""
	ms = []
	for i, (x, z, y, r) in enumerate(((-124, -34, 50, 15), (120, 46, 62, 12), (26, 140, 56, 17), (-46, -136, 66, 13), (-150, 30, 78, 10))):
		m = bp.M(f"W2_Island_{i}", bp.place(x, z, y))
		m.cyl(r * 0.25, r * 1.5, (0, 0, -r * 1.5), "rock", n=7, r2=r)
		m.cyl(r, 0.4, (0, 0, 0), "slab", n=7, r2=r * 0.98)
		m.cyl(r * 0.96, 0.9, (0, 0, 0.4), "grass", n=7, r2=r * 0.9)
		m.blob(r * 0.3, (r * 0.2, -r * 0.1, 1.4), "bloom", squash=0.9)
		if i % 2 == 0:
			bp.lantern_geo(m, -r * 0.45, r * 0.3, 1.3, 0.5)
		ms.append(m)
	return ms


def embers(col, n=700):
	m = bp.M("Ctx_Embers")
	for _ in range(n):
		p = Vector(bp.rb(bp.rng.uniform(-110, 110), bp.rng.uniform(2, 50), bp.rng.uniform(-120, 130)))
		s = bp.rng.uniform(0.12, 0.28)
		m.face([p + Vector((s, 0, 0)), p + Vector((0, s, s)), p + Vector((-s, 0, 0)), p + Vector((0, -s, -s))], "ember")
		m.face([p + Vector((0, -s, -s)), p + Vector((-s, 0, 0)), p + Vector((0, s, s)), p + Vector((s, 0, 0))], "ember")
	m.build(col)


def moon(col):
	d = bp.along(2400)
	c = bp.rb(d[0], 820, d[1])
	ob = bpy.data.objects.new("Moon", bpy.data.meshes.new("Moon"))
	import bmesh

	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=150)
	bm.to_mesh(ob.data)
	bm.free()
	ob.data.materials.append(bp.mat("moon"))
	ob.location = c
	col.objects.link(ob)


def build_variant(key, small, only=()):
	v = VARIANTS[key]
	reset(v)
	scene = bpy.context.scene
	cam = bp.setup_world(scene)
	if small:
		scene.render.resolution_x, scene.render.resolution_y = 800, 450
	try:
		scene.eevee.taa_render_samples = 32
	except AttributeError:
		pass
	build_track.bloom(scene)
	sky(scene, v)
	bp.build(scene)
	w2 = bpy.data.collections.new("World2")
	scene.collection.children.link(w2)
	extra = accents() + [world_gate(), sensei_standin()]
	if key == "B":
		extra += [rift(v)] + islands()
	for m in extra:
		m.build(w2)
	bp.add_text(w2, "WORLD 1", bp.place(GATE[0], GATE[1], bp.TOP, GATE_FACE) @ Matrix.Translation((0, -3, 2 * GATE_R + 9)), 3.2, "paper", "Sign_World1")
	lw = v["lamp_w"]
	for x, z in lantern_spots():
		point(w2, (x, bp.TOP + 5, z), "#FFB765", lw)
	for k in range(8):
		a = k / 8 * math.tau
		point(w2, (13 * math.cos(a), bp.SPAWN_TOP + 3, -13 * math.sin(a)), "#FFB765", lw * 0.3, 0.5)
	point(w2, (GATE[0] + GATE_FACE[0] * 6, bp.TOP + GATE_R + 3, GATE[1] + GATE_FACE[1] * 6), "#46D2FF", 6000, 4)
	if key == "A":
		moon(w2)
	if key == "B":
		rx, rz = bp.along(bp.AXIS_LEN + 80)
		point(w2, (rx, 70, rz), "#7A7CFF", 80000, 20)
	if key == "C":
		embers(w2)
	bp.OUT = os.path.join(OUT, key)
	os.makedirs(bp.OUT, exist_ok=True)
	back = bp.along(-12)
	shots = {
		"01_overview": ((118, 150, -150), (-4, 0, 14), 60),
		"02_arrival": ((back[0], bp.SPAWN_TOP + 7.5, back[1]), (bp.PAD[0], bp.TOP + 14, bp.PAD[1]), 70),
		"03_return_gate": ((38, bp.TOP + 9, -78), (GATE[0], bp.TOP + 12, GATE[1]), 60),
	}
	for name, (eye, look, fov) in shots.items():
		if not only or name in only:
			bp.shoot(cam, eye, look, name, fov)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	small = "--small" in argv
	keys = [a for a in argv if a in VARIANTS] or list(VARIANTS)
	only = [a for a in argv if a[:1].isdigit()]  # shot names, e.g. 03_return_gate
	for key in keys:
		build_variant(key, small, only)


if __name__ == "__main__":
	main()
