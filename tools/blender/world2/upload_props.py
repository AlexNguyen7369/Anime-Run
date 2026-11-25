#!/usr/bin/env python3
"""Upload the exported World 2 draft meshes (build/world2/export/<Biome>/*.glb, export_props.py) as the owner's assets
(Open Cloud, BIOME_ENVIRONMENT_SPEC 4.1 Lane B step 4).

The ledger Id (src/shared/BiomeThemes/World2/<Biome>.luau, the `nil, -- Id` line) is the MeshPart's MeshId, which
Server/BiomeAssets loads with CreateMeshPartAsync. An Open Cloud upload of a .glb makes a Model asset holding that
MeshPart; the Model id is NOT the MeshId and this script cannot read the MeshId (Open Cloud does not return it). So an
upload never writes the ledger: it logs the Model id to build/world2/export/ops.tsv and leaves the ledger Id empty.
Read the MeshId in Studio, as was done for the 91 meshes (handoff.md): InsertService:LoadAsset(<model id>), take the
MeshPart's MeshId, then `upload_props.write_id(biome, key, mesh_id)` and add `biome key model mesh` to uploaded.tsv.

DRY RUN BY DEFAULT: it only lists what would upload. A real upload needs --upload, ROBLOX_OPEN_CLOUD_KEY and
ROBLOX_CREATOR_ID (the key goes to curl through stdin config, never argv). Only rows with no Id whose Reviewed is set
(the rules audit signed them) upload; --allow-unreviewed lifts that. Each operation id is appended to ops.tsv before
polling, with the GLB's sha256, so a timeout or crash resumes that operation on the next run instead of uploading the
mesh again; an operation is resumed only for the same GLB bytes (a re-exported mesh uploads afresh), and a failed one is
cleared (an empty row) so the next run starts a new upload. Self-check (no network): python3 upload_props.py --self-test
Display names use the in-game asset key only (W2_<Biome>_<Prop>), never a real name (design doc 5).
  python3 tools/blender/world2/upload_props.py [--upload] [--allow-unreviewed] [<Biome> ...]
Import-safe: main() runs only as a script.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EXPORT = os.path.join(ROOT, "build", "world2", "export")
OPS = os.path.join(EXPORT, "ops.tsv")  # biome, key, operation path, Model asset id (empty while pending), GLB sha256
THEMES = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2")
API = "https://apis.roblox.com/assets/v1/"
APPROVED = ("DevilTokyo", "DemonCastle", "RuinedCityZ", "HauntedTunnel", "KaijuBase", "ElvenPlains", "AntIsland", "MonsterDen", "GoldenCity", "HellGate")


def row_re(key):
	"""A ledger row with no Id; group 3 is its Reviewed value (`nil` or a quoted string)."""
	return re.compile(r"(\t\t%s = draftMesh\(\n\t\t\t\d+,\n\t\t\t)nil(, -- Id[^\n]*\n\t\t\t)(nil|\"[^\"]*\")" % re.escape(key))


def pending(biome, require_reviewed=True):
	"""(key, glb path, tris) for each manifest mesh whose ledger row has no Id (and, by default, is Reviewed)."""
	manifest = json.load(open(os.path.join(EXPORT, biome, "manifest.json")))
	src = open(os.path.join(THEMES, biome + ".luau")).read()
	out = []
	for key, p in manifest["Props"].items():
		m = row_re(key).search(src)
		if m:
			if require_reviewed and m.group(3) == "nil":
				print("SKIP %s: not Reviewed by the rules audit (--allow-unreviewed to upload anyway)" % key)
				continue
			out.append((key, os.path.join(EXPORT, biome, p["File"]), p["Tris"]))
		elif ("\t\t%s = draftMesh(" % key) not in src:
			raise SystemExit("%s: no ledger row in %s.luau" % (key, biome))
	return out


def sha256(path):
	return hashlib.sha256(open(path, "rb").read()).hexdigest()


def read_ops():
	"""key -> (operation path, Model id or '', GLB sha256 or ''), the last line per key. Rows from before the hash
	column have no sha, so they never match a GLB and are not resumed."""
	ops = {}
	if os.path.exists(OPS):
		for line in open(OPS):
			f = line.rstrip("\n").split("\t")
			if len(f) >= 3:
				ops[f[1]] = (f[2], f[3] if len(f) > 3 else "", f[4] if len(f) > 4 else "")
	return ops


def resumable(ops, key, path):
	"""(operation path, Model id) to resume for this GLB: only when its last op was for the same bytes, else ("", "")."""
	op_path, model_id, sha = ops.get(key, ("", "", ""))
	return (op_path, model_id) if op_path and sha == sha256(path) else ("", "")


def log_op(biome, key, op_path, model_id="", sha=""):
	"""Appends one op row; an empty op_path clears the key (a failed operation is not resumed)."""
	with open(OPS, "a") as f:
		f.write("%s\t%s\t%s\t%s\t%s\n" % (biome, key, op_path, model_id, sha))
		f.flush()
		os.fsync(f.fileno())


def curl(*args):
	cfg = 'header = "x-api-key: %s"\n' % os.environ["ROBLOX_OPEN_CLOUD_KEY"]  # stdin config, never argv
	r = subprocess.run(["curl", "-sS", "--max-time", "120", "-K", "-", *args], input=cfg, capture_output=True, text=True)
	if r.returncode != 0:
		raise RuntimeError(r.stderr.strip())
	return json.loads(r.stdout)


def start(biome, key, path):
	"""POSTs the upload and logs its operation path before polling. Returns the path."""
	req = {
		"assetType": "Model",
		"displayName": key,
		"description": "Anime Run World 2 scenery",
		"creationContext": {"creator": {"userId": os.environ["ROBLOX_CREATOR_ID"]}},
	}
	op = curl("-X", "POST", API + "assets", "--form-string", "request=" + json.dumps(req), "-F", "fileContent=@%s;type=model/gltf-binary" % path)
	if "path" not in op:
		raise RuntimeError("%s: %s" % (key, op))
	log_op(biome, key, op["path"], "", sha256(path))
	return op["path"]


def poll(biome, key, op_path):
	"""The uploaded Model's asset id (not the MeshId). A failed operation is cleared in ops.tsv before raising."""
	for _ in range(60):
		time.sleep(3)
		st = curl(API + op_path)
		if st.get("done"):
			if "response" not in st:
				log_op(biome, key, "")
				raise RuntimeError("%s: %s (cleared in ops.tsv; the next run uploads afresh)" % (key, st))
			return st["response"]["assetId"]
	raise RuntimeError("%s: timed out %s (logged in ops.tsv; the next run resumes it)" % (key, op_path))


def write_id(biome, key, mesh_id):
	"""Writes a MeshId (read in Studio from the uploaded Model's MeshPart) into the row's empty Id. Never a Model id."""
	path = os.path.join(THEMES, biome + ".luau")
	src = open(path).read()
	new, n = row_re(key).subn(lambda m: '%s"rbxassetid://%s"%s%s' % (m.group(1), mesh_id, m.group(2), m.group(3)), src)
	assert n == 1, (key, n)
	open(path, "w").write(new)


def self_test():
	"""Op resume rules on a temp ops.tsv, no network: raises on a wrong answer."""
	import tempfile

	global OPS
	saved = OPS
	with tempfile.TemporaryDirectory() as d:
		OPS = os.path.join(d, "ops.tsv")
		glb = os.path.join(d, "a.glb")
		open(glb, "wb").write(b"old mesh")
		old = sha256(glb)
		assert resumable(read_ops(), "K", glb) == ("", "")  # nothing logged
		log_op("B", "K", "operations/1", "", old)
		assert resumable(read_ops(), "K", glb) == ("operations/1", "")  # same bytes: resume
		open(glb, "wb").write(b"new mesh")
		assert resumable(read_ops(), "K", glb) == ("", "")  # re-exported: never the old op
		log_op("B", "K", "operations/2", "", sha256(glb))
		log_op("B", "K", "")  # that op failed: cleared
		assert resumable(read_ops(), "K", glb) == ("", "")
		with open(OPS, "a") as f:
			f.write("B\tL\toperations/3\t99\n")  # a row from before the hash column
		assert resumable(read_ops(), "L", glb) == ("", "")
	OPS = saved
	print("SELF-TEST ok")


def main():
	argv = sys.argv[1:]
	if "--self-test" in argv:
		return self_test()
	real = "--upload" in argv
	biomes = [a for a in argv if not a.startswith("--")] or list(APPROVED)
	for b in biomes:
		if b not in APPROVED:
			raise SystemExit("%s is not an approved World 2 biome" % b)
	todo = [(b, *item) for b in biomes for item in pending(b, "--allow-unreviewed" not in argv)]
	ops = read_ops()
	if not real:
		for b, key, path, tris in todo:
			op_path, model_id = resumable(ops, key, path)
			note = " (Model %s, needs its MeshId)" % model_id if model_id else (" (resumes %s)" % op_path if op_path else "")
			print("DRY upload %-40s %6d tris %8d bytes%s" % (key, tris, os.path.getsize(path), note))
		print("DRY %d meshes, %d tris total, %d biomes; nothing uploaded (pass --upload)" % (len(todo), sum(t[3] for t in todo), len(biomes)))
		return
	for k in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID"):
		if not os.environ.get(k):
			raise SystemExit(k + " is not set")
	for b, key, path, _ in todo:
		op_path, model_id = resumable(ops, key, path)
		if not model_id:
			op_path = op_path or start(b, key, path)
			model_id = poll(b, key, op_path)
			log_op(b, key, op_path, model_id, sha256(path))
		print(
			"UPLOADED %s Model %s; ledger Id left empty: in Studio read the MeshPart MeshId of InsertService:LoadAsset(%s), "
			"then write_id(%r, %r, <MeshId>)" % (key, model_id, model_id, b, key),
			flush=True,
		)


if __name__ == "__main__":
	main()
