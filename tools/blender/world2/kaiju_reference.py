"""Reference renders of World 2 Track 5's reworked dead kaiju (owner 2026-11-25; docs/WORLD2_SPEC.md "Render set
approvals"). Never overwrites the approved shots: the build goes to a scratch folder and every image to
assets/world2_draft/track05_KaijuBase/reference/. --fit also asks export_props's planner functions which placements pass
the game's rules at which scale; it exports and writes nothing.
Headless:  Blender -b --factory-startup --python tools/blender/world2/kaiju_reference.py -- <scratch folder> [--fast] [--fit]
Import-safe: main() runs only as a script.
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import build_track  # noqa: E402
import kit  # noqa: E402

DRAFT = os.path.join(build_track.ROOT, "assets", "world2_draft", "track05_KaijuBase")
OUT = os.path.join(DRAFT, "reference")
# Close-ups of the model alone, Roblox local studs: name -> (eye, look, vertical field)
MODEL = {
	"front": ((0, 60, -330), (0, 38, 0), 45),
	"back": ((-120, 110, 290), (0, 35, 0), 45),
	"34": ((210, 95, -230), (10, 30, 0), 45),
	"head": ((175, 32, -125), (118, 18, -42), 40),
	"foot": ((112, 22, -100), (70, 6, -54), 40),
	"wreck_mid": ((-70, 30, -120), (-40, 8, -48), 48),
	"wreck_tail": ((-60, 34, -110), (-104, 12, -30), 48),
	"wreck_back": ((110, 60, 140), (80, 14, 44), 48),
	"eye": ((112, 34, -86), (116, 24, -34), 34),
	"crew": ((112, 10, -66), (101, 7, -52), 40),
	"crew_flank": ((30, 70, -80), (8, 60, -20), 45),
	"top": ((0, 460, -30), (0, 0, 0), 40),
}


def model_shots(k, cam):
	"""The corpse prop alone on ground of the track's own colour."""
	src = k.props["KaijuCorpse"]
	hidden = [o for o in bpy.context.scene.objects if o.type not in ("LIGHT", "CAMERA") and not o.hide_render]
	for o in hidden:
		o.hide_render = True
	ob = bpy.data.objects.new(src.name + "_ref", src.data)
	bpy.context.scene.collection.objects.link(ob)
	bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, 0))
	floor = bpy.context.object
	floor.data.materials.append(k.mat("8C877C", 1.0))
	for name, (eye, look, fov) in MODEL.items():
		build_track.shoot(cam, eye, look, os.path.join(OUT, name + ".jpg"), fov)
	bpy.data.objects.remove(ob)
	bpy.data.objects.remove(floor)
	for o in hidden:
		o.hide_render = False


def run_shot(k, cam, d, name, ahead=70, fov=70):
	"""The runner's-eye camera of build_track.shots at distance d."""
	p, right, t = k.at(d)
	lane = p + right * 10
	eye, look = lane - t * build_track.RUNNER_EYE[0], lane + t * ahead
	build_track.shoot(cam, (eye.x, p.y + build_track.RUNNER_EYE[1], eye.z), (look.x, p.y + 4, look.z), os.path.join(OUT, name + ".jpg"), fov)


def context_shots(k, cam, sites):
	run_shot(k, cam, k.length * 0.06, "run_06_same_camera")
	run_shot(k, cam, k.length * 0.33, "run_33_same_camera")
	for i, (d, off, *_) in enumerate(sites, 1):
		run_shot(k, cam, d - 260, "run_site%d_far" % i)
		run_shot(k, cam, d - 150, "run_site%d_near" % i)
		# the game's run camera turns a little to the sight: the same eye, looking at the body
		p, right, t = k.at(d - 150)
		eye = p + right * 10 - t * 14
		q, r2, _ = k.at(d - 60)
		look = q + r2 * off * 0.7
		build_track.shoot(cam, (eye.x, p.y + 8, eye.z), (look.x, 22, look.z), os.path.join(OUT, "look_site%d.jpg" % i), 60)
		# raised view of the whole site
		p, right, t = k.at(d)
		eye = p + right * 220 - t * 240
		look = p + right * off
		build_track.shoot(cam, (eye.x, 190, eye.z), (look.x, 20, look.z), os.path.join(OUT, "site%d.jpg" % i), 55)


def sheet(pairs, path, w=960, h=540):
	"""Old (left) beside new (right), one row per pair, from images on disk."""
	import numpy as np

	rows = []
	for pair in pairs:
		row = []
		for f in pair:
			img = bpy.data.images.load(f)
			img.scale(w, h)
			a = np.empty(w * h * 4, np.float32)
			img.pixels.foreach_get(a)
			row.append(a.reshape(h, w, 4))
		rows.append(np.concatenate([row[0], np.ones((h, 12, 4), np.float32), row[1]], 1))
		rows.append(np.ones((12, w * 2 + 12, 4), np.float32))
	full = np.concatenate(rows[:-1][::-1], 0)
	out = bpy.data.images.new("sheet", full.shape[1], full.shape[0])
	out.pixels.foreach_set(full.ravel())
	out.file_format = "JPEG"
	out.filepath_raw = path
	out.save()
	print("SHOT", path)


def fit(k):
	"""Which placements pass every planner rule (export_props.rules_ok), and the largest scale that still does."""
	import export_props as ep

	import clearance
	import numpy as np

	number = 5
	origin, yaw = ep.origins()[number]
	lo, hi = ep.bounds(k.props["KaijuCorpse"].data)
	centre = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
	local = ep.local_tris(k.props["KaijuCorpse"].data, centre)
	ctx = ep.hero_ctx(number, clearance.corridors(build_track.load_chain().values()))
	parts = ep.fallback(k.rec["parts"]["KaijuCorpse"], centre, len(k.rec["parts"]["KaijuCorpse"]))[: ep.FALLBACK_PARTS["hero"]]
	local = np.concatenate([local, ep.parts_tris(parts)])  # what the game builds while the mesh has no Id, as export() tests it
	lsize = [hi[j] - lo[j] for j in range(3)]
	base = lambda pos, rot, sc, f: tuple(pos[j] - sum(rot[j][m] * centre[m] * sc[m] * (1 - f) for m in range(3)) for j in range(3))  # noqa: E731
	for i, (name, pos, rot, sc) in enumerate(q for q in ep.placements(k, ["KaijuCorpse"], origin, yaw, {"KaijuCorpse": centre}) if q[0] == "KaijuCorpse"):
		e = ep.euler_yxz(rot)
		ok = lambda p, f, why=None: ep.rules_ok(local, origin, yaw, p, e, tuple(v * f for v in sc), ctx, False, why)  # noqa: E731
		why = {}
		as_drafted = ok(pos, 1.0, why)
		top = max([f for f in [0.8 + 0.01 * n for n in range(51)] if ok(base(pos, rot, sc, f), f)] or [0.0])
		n, big = ep.props_overlap(local, origin, yaw, pos, e, sc, ctx)
		dist = np.sqrt(((ctx["line"] - (pos[0], pos[2])) ** 2).sum(1)).min()
		c_, Rb, hb = ep.hero_box(local, origin, yaw, pos, e, sc)
		over = {}
		for bc, bR, bh, tn, pn in ctx["props"]:
			if ep.obb_overlap(c_, Rb, hb, bc, bR, bh):
				over["T%d %s" % (tn, pn)] = over.get("T%d %s" % (tn, pn), 0) + 1
		print("FIT overlaps", over)
		print("FIT site %d base centre (%.0f, %.0f) scale %.2f as drafted passes=%s %s size %s own road %.0f largest passing scale there %.2f other-track props %d (%s)" % (i + 1, pos[0], pos[2], sc[0], as_drafted, why, [round(lsize[j] * sc[j], 1) for j in range(3)], dist, top * sc[0], n, big), flush=True)
		if "--search" in sys.argv:  # local search: along the road, across it and a turn
			best = (0, 0)
			for turn in (-6, -3, 0, 3, 6):
				r2 = [[sum(rot[a][m] * ep.yaw_rot(math.radians(turn))[m][b] for m in range(3)) for b in range(3)] for a in range(3)]
				e2 = ep.euler_yxz(r2)
				for along in range(-40, 41, 8):
					for across in range(-6, 7, 3):
						p = [pos[j] + rot[j][0] * along + rot[j][2] * across for j in range(3)]
						f = max(best[0], 0.9) + 0.01
						while ep.rules_ok(local, origin, yaw, base(p, r2, sc, f), e2, tuple(v * f for v in sc), ctx, False):
							best = (f, (along, across, turn))
							f += 0.01
			print("SEARCH site %d best scale %.2f at (along local +X, across local +Z, turn) %s" % (i + 1, best[0] * sc[0], best[1]), flush=True)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	scratch = [a for a in argv if not a.startswith("--")][0]
	build_track.OUT, build_track.BUILD = os.path.join(scratch, "out"), os.path.join(scratch, "build")
	if os.path.abspath(scratch).startswith(os.path.abspath(DRAFT)):
		raise SystemExit("the scratch folder may not be the draft folder")
	if "--fit" in argv:
		import export_props

		export_props.record()
	k = build_track.run(5, fast="--fast" in argv, render=False)
	if "--fit" in argv:
		fit(k)
		return
	os.makedirs(OUT, exist_ok=True)
	cam = bpy.context.scene.camera
	from biomes import KaijuBase

	model_shots(k, cam)
	context_shots(k, cam, KaijuBase.SITES)
	old = lambda n: os.path.join(DRAFT, n + ".jpg")  # noqa: E731
	new = lambda n: os.path.join(OUT, n + ".jpg")  # noqa: E731
	sheet([(old("m_KaijuCorpse_front"), new("front")), (old("m_KaijuCorpse_34"), new("34")), (old("02_run_33"), new("run_site2_near")), (old("01_run_6"), new("look_site1"))], new("old_vs_new"))


if __name__ == "__main__":
	main()
