# Big Raga's key poses for owner review (design doc 4.37, BOSS_EVENT_SPEC "Boss and attacks"). No in-betweens, no bake. Headless:
#   Blender -b --factory-startup --python tools/blender/boss_keyframes.py -- --blend <boss_raga.blend> [attack shout wheel_turn]
# Writes assets/characters_avatar/boss_raga/keyframes/<move>_slices.png, and keys.json for a later bake.
#
# MOVES is the pose data. Model axes: front faces -Y, +X is the character's left, Z up, one unit = 87.1 studs.
#   t      proposed time in seconds. Every move starts from the rest pose at 0 s and is back in it at the move's "end".
#   root   LowerTorso's offset from its joint, in model units.
#   tilt   LowerTorso's rotation, X, Y, Z degrees.
#   parts  rotation of a part about its own joint relative to its parent: Blender XYZ Euler degrees, replacing the rest value.
#          A part left out keeps its rest value: LeftUpperArm (0, -12, 0), RightUpperArm (0, 26, 0), others 0.
#          Signs on the arms and spine: X- swings an arm forward and up, leans the torso or head back; X+ leans forward.
#          Y+ moves the top of a part toward the character's left. Z+ turns the part toward the character's left.
#   spin   Wheel about its own local Y after its fixed 10 degree lean. Positive is clockwise from the front. One spoke = 45.
#   feet   ankle target per side, (x, y, yaw), foot flat on the floor. Default: (+-0.7, 0, 0). Legs are solved from root, tilt and feet;
#          keys.json holds the solved rotation of every part, so a bake reads only plain rotations.
import json
import math
import os
import sys

import blf
import bpy
import imbuf
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_avatar  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "characters_avatar", "boss_raga", "keyframes")
TMP = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "boss_keyframes")

MOVES = {
	"attack": {
		"title": "Attack: forearm blade slam (proposed)",
		"end": 3.6,
		"keys": [
			{
				"t": 0.7,
				"desc": "Wind-up: turns from the hips, blade arm lifts out to the side",
				"root": (0, 0.05, -0.1),
				"tilt": (-3, 0, -5),
				"parts": {
					"UpperTorso": (-5, 0, -8),
					"Head": (0, 0, 14),
					"RightUpperArm": (-15, 82, 0),
					"RightLowerArm": (0, 32, 0),
					"LeftUpperArm": (-35, -45, 0),
					"LeftLowerArm": (-25, 0, 0),
				},
			},
			{
				"t": 1.4,
				"desc": "Anticipation: rises tall, leans back, blade held high to the side",
				"root": (0, 0.1, -0.1),
				"tilt": (-5, 4, -8),
				"parts": {
					"UpperTorso": (-9, 5, -10),
					"Head": (3, -4, 16),
					"RightUpperArm": (10, 92, 0),
					"RightLowerArm": (0, 50, 0),
					"Sword": (0, 0, -40),
					"LeftUpperArm": (-20, -55, 0),
					"LeftLowerArm": (-22, 0, 0),
				},
			},
			{
				"t": 1.75,
				"desc": "Strike: whole body drops and turns, straight arm brings the blade to the floor",
				"root": (0, 0.26, -0.28),
				"tilt": (13, -3, 6),
				"parts": {
					"UpperTorso": (10, -4, 16),
					"Head": (-8, 0, -14),
					"RightUpperArm": (-56, 32, 0),
					"RightLowerArm": (-6, 0, 0),
					"Sword": (0, 0, 30),
					"LeftUpperArm": (25, -42, 0),
					"LeftLowerArm": (-22, 0, 0),
				},
			},
			{
				"t": 2.05,
				"desc": "Follow-through: blade point bites the floor, weight over it, off arm flung back",
				"root": (0, 0.3, -0.33),
				"tilt": (16, -3, 7),
				"parts": {
					"UpperTorso": (11, -4, 18),
					"Head": (-12, 0, -16),
					"RightUpperArm": (-60, 30, 0),
					"RightLowerArm": (-4, 0, 0),
					"Sword": (0, 0, 30),
					"LeftUpperArm": (35, -50, 0),
					"LeftLowerArm": (-30, 0, 0),
				},
			},
			{
				"t": 2.9,
				"desc": "Recovery: pulls the blade out and straightens, arm low, then settles to rest",
				"root": (0, -0.1, -0.14),
				"tilt": (5, 0, 5),
				"parts": {
					"UpperTorso": (4, 0, 5),
					"Head": (-3, 0, -6),
					"RightUpperArm": (-22, 28, 0),
					"RightLowerArm": (-14, 0, 0),
					"LeftUpperArm": (6, -18, 0),
					"LeftLowerArm": (-10, 0, 0),
				},
			},
		],
	},
	"shout": {
		"title": "Shout (proposed)",
		"end": 3.4,
		"keys": [
			{
				"t": 0.45,
				"desc": "Gather: chin down, shoulders forward, arms pull in",
				"root": (0, -0.04, -0.14),
				"tilt": (5, 0, 0),
				"parts": {
					"UpperTorso": (9, 0, 0),
					"Head": (12, 0, 0),
					"RightUpperArm": (-34, 14, 0),
					"RightLowerArm": (-42, 0, 0),
					"LeftUpperArm": (-34, -14, 0),
					"LeftLowerArm": (-42, 0, 0),
				},
			},
			{
				"t": 1.0,
				"desc": "Head back: chest out, arms spread wide and low",
				"root": (0, 0.06, -0.03),
				"tilt": (-4, 0, 0),
				"parts": {
					"UpperTorso": (-9, 0, 0),
					"Head": (-20, 0, 0),
					"Tail": (-6, 0, 0),
					"RightUpperArm": (10, 62, 0),
					"RightLowerArm": (-10, 0, 0),
					"LeftUpperArm": (10, -62, 0),
					"LeftLowerArm": (-10, 0, 0),
				},
			},
			{
				"t": 1.35,
				"desc": "Roar peak: arms fully spread, head thrown back, wheel tipped with it",
				"root": (0, 0.1, -0.05),
				"tilt": (-6, 0, 0),
				"parts": {
					"UpperTorso": (-11, 0, 0),
					"Head": (-22, 0, 0),
					"Tail": (-9, 0, 0),
					"RightUpperArm": (-12, 88, 0),
					"RightLowerArm": (0, 22, 0),
					"LeftUpperArm": (-12, -84, 0),
					"LeftLowerArm": (0, -22, 0),
				},
			},
			{
				"t": 2.5,
				"desc": "Recover: head level, arms lower, weight settles, then back to rest",
				"root": (0, 0, -0.08),
				"tilt": (2, 0, 0),
				"parts": {
					"UpperTorso": (3, 0, 0),
					"Head": (2, 0, 0),
					"RightUpperArm": (0, 40, 0),
					"RightLowerArm": (-14, 0, 0),
					"LeftUpperArm": (0, -28, 0),
					"LeftLowerArm": (-14, 0, 0),
				},
			},
		],
	},
	"wheel_turn": {
		"title": "Wheel turn: adaptation, one spoke (proposed)",
		"end": 1.6,
		"keys": [
			{"t": 0.0, "desc": "Rest: wheel at its start", "spin": 0, "parts": {}},
			{
				"t": 0.3,
				"desc": "Brace: shoulders set, small head tilt, wheel draws back a little",
				"spin": -6,
				"root": (0, 0, -0.04),
				"parts": {
					"Head": (3, 0, 0),
					"RightLowerArm": (-6, 0, 0),
					"LeftLowerArm": (-6, 0, 0),
				},
			},
			{
				"t": 0.5,
				"desc": "Turning: wheel halfway through the spoke, body still",
				"spin": 22.5,
				"root": (0, 0, -0.04),
				"parts": {
					"Head": (3, 5, 0),
					"RightLowerArm": (-6, 0, 0),
					"LeftLowerArm": (-6, 0, 0),
				},
			},
			{
				"t": 0.7,
				"desc": "Click: wheel slams past the spoke, head tilted most",
				"spin": 50,
				"root": (0, 0, -0.04),
				"parts": {
					"Head": (3, 7, 0),
					"RightLowerArm": (-6, 0, 0),
					"LeftLowerArm": (-6, 0, 0),
				},
			},
			{
				"t": 1.0,
				"desc": "Settle: one spoke on, wheel looks as at the start but has turned; head returning",
				"spin": 45,
				"parts": {"Head": (0, 3, 0)},
			},
		],
	},
}


def solve_legs(key, pivots):
	"""Two-bone legs from root, tilt and feet, foot flat on the floor. Returns the rotation in degrees of each leg part."""

	def frame(along, forward):
		z = (-along).normalized()
		y = -(forward - z * forward.dot(z)).normalized()
		x = y.cross(z)
		return Matrix((x, y, z)).transposed()

	root3 = Euler([math.radians(d) for d in key.get("tilt", (0, 0, 0))]).to_matrix()
	pelvis = Vector(pivots["LowerTorso"]) + Vector(key.get("root", (0, 0, 0)))
	out = {}
	for side, s in (("Left", 1), ("Right", -1)):
		hip_rest, knee_rest, ankle_rest = (Vector(pivots[side + p]) for p in ("UpperLeg", "LowerLeg", "Foot"))
		l1, l2 = (hip_rest - knee_rest).length, (knee_rest - ankle_rest).length
		fx, fy, yaw = key.get("feet", {}).get(side, (s * 0.7, 0, 0))
		ankle = Vector((fx, fy, ankle_rest.z + key.get("lift", {}).get(side, 0)))  # lift: in-betweens only, no approved key has one
		hip = pelvis + root3 @ (hip_rest - Vector(pivots["LowerTorso"]))
		to = ankle - hip
		assert to.length <= l1 + l2 + 1e-4, f"{side} leg cannot reach: {to.length:.3f} > {l1 + l2:.3f}, lower the root"
		d = min(to.length, l1 + l2 - 1e-5)
		a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
		h = math.sqrt(max(0.0, l1 * l1 - a * a))
		turn = Euler((0, 0, math.radians(yaw))).to_matrix()
		forward = turn @ Vector((0, -1, 0))
		pole = forward + turn @ Vector((s * 0.2, 0, 0))  # knees track out over the toes
		along = to / d
		knee = hip + along * a + (pole - along * pole.dot(along)).normalized() * h
		thigh, shin = frame(knee - hip, forward), frame(ankle - knee, forward)
		for part, m in ((side + "UpperLeg", root3.inverted() @ thigh), (side + "LowerLeg", thigh.inverted() @ shin), (side + "Foot", shin.inverted() @ turn)):
			out[part] = tuple(math.degrees(v) for v in m.to_euler("XYZ"))
	return out


def full_key(key, pivots, rest):
	"""Every part's plain rotation at a key: the record a bake reads."""
	rot = dict(rest)
	rot.update(key.get("parts", {}))
	rot.update(solve_legs(key, pivots))
	lean = Quaternion((1, 0, 0), math.radians(rest["Wheel"][0]))
	spin = Quaternion((0, 1, 0), math.radians(key.get("spin", 0)))
	rot["Wheel"] = tuple(math.degrees(v) for v in (lean @ spin).to_euler("XYZ"))
	rot["LowerTorso"] = tuple(key.get("tilt", (0, 0, 0)))
	return rot


def apply_key(objs, rest_loc, key, rot):
	for name, o in objs.items():
		o.rotation_euler = [math.radians(d) for d in rot[name]]
	objs["LowerTorso"].location = rest_loc + Vector(key.get("root", (0, 0, 0)))
	bpy.context.view_layer.update()


def verts(o):
	co = np.empty(len(o.data.vertices) * 3)
	o.data.vertices.foreach_get("co", co)
	mw = np.array(o.matrix_world)
	return co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]


def fit(cam, pts, d, aspect, margin=0.92):
	"""Same framing for every key of a move: fits all its poses at once."""
	d = Vector(d).normalized()
	c = Vector(((pts.min(axis=0) + pts.max(axis=0)) / 2).tolist())
	span = float(np.linalg.norm(pts.max(axis=0) - pts.min(axis=0)))
	cam.location = c + d * span * 3
	build_avatar.aim(cam, c)
	bpy.context.view_layer.update()
	mw = np.array(cam.matrix_world)
	x, y = pts @ mw[:3, 0], pts @ mw[:3, 1]
	cam.location = cam.location + Vector((mw[:3, 0] * (x.min() + x.max() - 2 * np.dot(mw[:3, 3], mw[:3, 0])) / 2 + mw[:3, 1] * (y.min() + y.max() - 2 * np.dot(mw[:3, 3], mw[:3, 1])) / 2).tolist())
	cam.data.type = "ORTHO"
	# ortho_scale spans the longer image side
	cam.data.ortho_scale = max(float(x.max() - x.min()) / min(aspect, 1), float(y.max() - y.min()) * max(aspect, 1)) / margin
	cam.data.clip_end = span * 60
	return cam.location.copy(), cam.rotation_euler.copy(), cam.data.ortho_scale


def matte(name, rgb):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (*rgb, 1)
	bsdf.inputs["Roughness"].default_value = 1
	return mat


def dot(name, parent, local, r, mat):
	"""A render-only marker. Never part of the model or of keys.json."""
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(0, 0, 0))
	o = bpy.context.object
	o.name = name
	o.data.materials.append(mat)
	o.parent = parent
	o.location = local
	return o


def load_px(path):
	img = bpy.data.images.load(path)
	w, h = img.size
	a = np.empty(w * h * 4, dtype=np.float32)
	img.pixels.foreach_get(a)
	bpy.data.images.remove(img)
	return a.reshape(h, w, 4)[::-1].copy()  # row 0 on top


def render(scene, cam, view, size, path):
	scene.render.resolution_x, scene.render.resolution_y = size
	cam.location, cam.rotation_euler, cam.data.ortho_scale = view
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	return load_px(path)


def text_px(lines, w, h, bg):
	"""Text as pixels: lines = (text, size, y from top, x, rgb)."""
	ib = imbuf.new((w, h))
	path = os.path.join(TMP, "text.png")
	font = 0
	with blf.bind_imbuf(font, ib):
		for s, size, y, x, rgb in lines:
			blf.size(font, size)
			blf.color(font, *rgb, 1)
			blf.position(font, x, h - y, 0)
			blf.draw_buffer(font, s)
	imbuf.write(ib, filepath=path)
	px = load_px(path)
	alpha = px[:, :, 3:]
	return np.concatenate([px[:, :, :3] * alpha + np.array(bg) * (1 - alpha), np.ones((h, w, 1))], axis=2)


def save_px(px, path):
	h, w = px.shape[:2]
	img = bpy.data.images.new("sheet", w, h, alpha=False)
	img.pixels.foreach_set(px[::-1].astype(np.float32).ravel())
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	bpy.data.images.remove(img)


def paste(sheet, px, x, y):
	sheet[y : y + px.shape[0], x : x + px.shape[1]] = px


def small_view(sheet, px, x, y, label):
	"""A smaller view in the cell's side column, with its name above."""
	paste(sheet, text_px([(label, 22, 24, 8, DIM)], px.shape[1], 32, BG), x, y)
	paste(sheet, px, x, y + 32)


MAIN_W, CELL_H, SIDE_W, STRIP_H, COLS = 860, 960, 300, 104, 3
CELL_W = MAIN_W + SIDE_W
INSET = (SIDE_W, 330)
BG, INK, DIM = (0.93, 0.93, 0.94), (0.08, 0.08, 0.1), (0.3, 0.3, 0.34)


def run_move(name, move, objs, pivots, rest, cam, scene, wheel_markers):
	rest_loc = objs["LowerTorso"].location.copy()
	keys = move["keys"]
	records, report = [], []
	all_pts = []
	for key in keys:
		rot = full_key(key, pivots, rest)
		apply_key(objs, rest_loc, key, rot)
		pts = {n: verts(o) for n, o in objs.items()}
		all_pts.append(np.vstack(list(pts.values())))
		records.append({"t": key["t"], "desc": key["desc"], "root_offset": list(key.get("root", (0, 0, 0))), "wheel_spin": key.get("spin", 0), "rotations": {k: [round(v, 3) for v in r] for k, r in rot.items()}})
		near = lambda a, b: round(float(np.sqrt(((pts[a][:, None, :] - pts[b][None, :, :]) ** 2).sum(axis=2).min())), 2)
		clear = {"wheel_tail": near("Wheel", "Tail"), "wheel_head": near("Wheel", "Head"), "lhand_tail": near("LeftHand", "Tail"), "larm_tail": near("LeftLowerArm", "Tail")}
		foot = {s: float(pts[s + "Foot"][:, 2].min()) for s in ("Left", "Right")}
		joints = {}
		for n, r in rot.items():
			if n.endswith("LowerLeg") or n.endswith("LowerArm") or n == "UpperTorso":
				joints[n] = round(math.degrees(Euler([math.radians(d) for d in r]).to_matrix().to_quaternion().angle))
		report.append({"t": key["t"], "foot_min_z": {s: round(v, 3) for s, v in foot.items()}, "lowest": min((round(float(p[:, 2].min()), 3), n) for n, p in pts.items() if n != "Sword"), "blade_tip_z": round(float(pts["Sword"][:, 2].min()), 3), "clear": clear, "bends": joints})
		assert all(abs(v) < 0.02 for v in foot.values()), f"{name} {key['t']}: foot off the floor {foot}"
	union = np.vstack(all_pts + [np.array([[0, -2, 0], [0, 2, 0]])])
	cells = {}
	three = fit(cam, union, build_avatar.VIEWS["three_quarter"], MAIN_W / CELL_H)
	front = fit(cam, union, (0, -1, 0.1), INSET[0] / INSET[1])
	hub_pts = verts(objs["Wheel"])
	wheel_view = None
	if wheel_markers:
		sp = max(np.ptp(hub_pts, axis=0))
		c = Vector(hub_pts.mean(axis=0).tolist())
		cam.location = c + Vector((0, -1, 0)) * 40
		build_avatar.aim(cam, c)
		wheel_view = (cam.location.copy(), cam.rotation_euler.copy(), float(sp) * 1.5)
	for i, key in enumerate(keys):
		apply_key(objs, rest_loc, key, full_key(key, pivots, rest))
		cells[i] = {
			"three": render(scene, cam, three, (MAIN_W, CELL_H), os.path.join(TMP, f"{name}_{i}_3q.png")),
			"front": render(scene, cam, front, INSET, os.path.join(TMP, f"{name}_{i}_front.png")),
		}
		if wheel_markers:
			cells[i]["wheel"] = render(scene, cam, wheel_view, INSET, os.path.join(TMP, f"{name}_{i}_wheel.png"))
	apply_key(objs, rest_loc, {}, full_key({}, pivots, rest))
	rows = math.ceil(len(keys) / COLS)
	head_h = 96
	sheet = np.ones((head_h + rows * (CELL_H + STRIP_H) + 8, COLS * CELL_W, 4), dtype=np.float32)
	sheet[:, :, :3] = BG
	note = f"Rest at 0 s, back in rest at {move['end']} s. Times proposed. For owner review: not approved."
	if wheel_markers:
		note += " Red dot on a spoke, white dot at that spoke's start: render marks only, not on the model."
	paste(sheet, text_px([(move["title"], 40, 46, 24, INK), (note, 24, 84, 24, DIM)], COLS * CELL_W, head_h, BG), 0, 0)
	for i, key in enumerate(keys):
		row, col = divmod(i, COLS)
		x, y = col * CELL_W, head_h + row * (CELL_H + STRIP_H)
		paste(sheet, cells[i]["three"], x, y)
		small_view(sheet, cells[i]["front"], x + MAIN_W, y, "front")
		if wheel_markers:
			small_view(sheet, cells[i]["wheel"], x + MAIN_W, y + 32 + INSET[1] + 10, "wheel from the front")
		head = f"{name}  key {i + 1} of {len(keys)}  {key['t']:.2f} s"
		if wheel_markers:
			head += f"  spoke mark {key.get('spin', 0):+g} deg of 45"
		paste(sheet, text_px([(head, 32, 40, 18, INK), (key["desc"], 25, 80, 18, DIM)], CELL_W, STRIP_H, BG), x, y + CELL_H)
		sheet[y : y + CELL_H + STRIP_H, x : x + 2] = (0.5, 0.5, 0.52, 1)
	path = os.path.join(OUT, name + "_slices.png")
	save_px(sheet, path)
	print("SHEET", path)
	for row in report:
		print("KEY", json.dumps(row))
	return records


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	blend = argv[argv.index("--blend") + 1]
	wanted = [a for a in argv if a in MOVES] or list(MOVES)
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(TMP, exist_ok=True)
	bpy.ops.wm.open_mainfile(filepath=blend)
	scene = bpy.context.scene
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	rest = {n: tuple(math.degrees(v) for v in o.rotation_euler) for n, o in objs.items()}
	for o in objs.values():
		o.rotation_mode = "XYZ"
	bpy.context.view_layer.update()
	# pivots with no rotation: the model's stored joint offsets added down the parent chain
	pivots = {}
	for n, o in objs.items():
		p, q = o.location.copy(), o.parent
		while q is not None and q.name in objs:
			p += q.location
			q = q.parent
		pivots[n] = tuple(p)
	cam = build_avatar.setup_render(scene)
	scene.render.film_transparent = False
	bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
	floor = bpy.context.object
	floor.data.materials.append(matte("floor", (0.62, 0.63, 0.66)))
	rad = math.radians(22.5)
	tip = (1.34 * math.cos(rad), -0.12, 1.34 * math.sin(rad))
	red = dot("SpokeMark", objs["Wheel"], tip, 0.17, matte("red", (0.9, 0.04, 0.03)))
	# the start position sits on the Head, so it stays put while the wheel turns
	lean = Euler((math.radians(rest["Wheel"][0]), 0, 0)).to_matrix()
	white = dot("SpokeStart", objs["Head"], objs["Wheel"].location + lean @ Vector((tip[0], -0.2, tip[2])), 0.11, matte("white", (0.97, 0.97, 0.97)))
	path = os.path.join(OUT, "keys.json")
	data = json.load(open(path)) if os.path.exists(path) else {"units": "XYZ Euler degrees about each part's joint, relative to its parent; root_offset in model units", "pivots": {}, "moves": {}}
	data["pivots"] = {k: [round(v, 3) for v in p] for k, p in pivots.items()}
	for name in wanted:
		on = name == "wheel_turn"
		red.hide_render = white.hide_render = not on
		data["moves"][name] = {"end": MOVES[name]["end"], "keys": run_move(name, MOVES[name], objs, pivots, rest, cam, scene, on)}
	with open(path, "w") as f:
		json.dump(data, f, indent=1)


if __name__ == "__main__":  # bake_boss_raga.py imports the pose data and the leg solver
	main()
