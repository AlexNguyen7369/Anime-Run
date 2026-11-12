# Drawn UI portraits for The Golden King (goal boss-king k5, owner approval drafts): boss_king by the character pipeline, side_king
# and side_mage by the Sidekick path, all from the in-memory builds (no .blend, no review render touched). Ea is left out of
# both king portraits (the owner is reworking it; design doc 4.37). Drafts go to assets/ui/boss_king/, never to
# assets/characters_avatar/<id>/ (that is the approved pipeline's place: copy them there on approval). Nothing here uploads.
#   Blender -b --factory-startup --python tools/blender/portrait/king_portraits.py
import os
import shutil
import sys
import tempfile

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402
import build_boss_king  # noqa: E402
import build_boss_mage  # noqa: E402
import render_portrait as rp  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "ui", "boss_king"))
WITHOUT_EA = ("Head", "Torso", "LeftArm", "RightArm")


def boss_king():
	"""portrait.png and head.png as the mage's, Ea dropped before the merge (it would merge into the right arm and cross the cut)."""
	merge = avatar_merge.merge

	def merge_without_ea(cid, keep=()):
		for o in [o for o in bpy.data.objects if o.name.startswith(build_boss_king.LOOSE["Ea"][0])]:
			bpy.data.objects.remove(o)
		return merge(cid, keep)

	avatar_merge.merge = merge_without_ea
	try:
		rp.render("boss_king", "boss_king", build_avatar.load_data()["boss_king"], False)
	finally:
		avatar_merge.merge = merge
	for name in ("portrait.png", "head.png"):
		shutil.copy(os.path.join(rp.AVATARS, "boss_king", name), os.path.join(OUT, name))


def sidekick(cid, build, show=None):
	"""The downsized build drawn by render_sidekick's path, framed by tools/blender/sidekicks/<cid>.views.json."""
	rp.PALETTE = rp.SIDEKICK_PALETTE
	avatar_merge.BANDS = ((1.0, 1.0, 0.0),)
	_, objs, _ = build(cid, small=True)
	for name, o in objs.items():
		if name in avatar_merge.GROUPS:
			rp.strip_ink(o)
	image = next(n for n in objs["Head"].data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image
	mat, sources, emit = rp.data_material(image)
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	for i, o in enumerate(meshes):
		o.data.materials[0] = mat
		o.pass_index = i + 1
	view = rp.SIDEKICK_VIEWS[cid]
	portrait_view = dict(view["portrait"], show=show) if show else view["portrait"]
	portrait, lut, side = rp.sidekick_shot(meshes, portrait_view, mat, sources, emit, False)
	head, _, _ = rp.sidekick_shot(meshes, view["head"], mat, sources, emit, True, lut, side)
	for name, rgba, size, max_bytes in ((cid + "_portrait.png", portrait, rp.SIZE, rp.MAX_BYTES), (cid + "_head.png", head, rp.HEAD_SIZE, rp.HEAD_MAX_BYTES)):
		path = os.path.join(OUT, name)
		rp.write_png(path, rgba)
		try:
			rp.check(path, rgba, size, max_bytes)
		except AssertionError as e:
			print("CHECK", e, flush=True)  # a draft: kept for the owner's eye, reported
		print(f"SIDEKICK {path} {os.path.getsize(path)} bytes", flush=True)


def main():
	os.makedirs(OUT, exist_ok=True)
	with tempfile.TemporaryDirectory() as tmp:
		rp.AVATARS = tmp
		boss_king()
	sidekick("side_king", build_boss_king.build, WITHOUT_EA)
	sidekick("side_mage", build_boss_mage.build)


if __name__ == "__main__":
	main()
