#!/usr/bin/env python3
"""Upload the exported World 2 draft meshes (build/world2/export/<Biome>/*.glb, export_props.py) as the owner's assets
(Open Cloud, BIOME_ENVIRONMENT_SPEC 4.1 Lane B step 4) and write each id into its ledger row in
src/shared/BiomeThemes/World2/<Biome>.luau (the `nil, -- Id` line).

DRY RUN BY DEFAULT: it only lists what would upload. A real upload needs --upload, ROBLOX_OPEN_CLOUD_KEY and
ROBLOX_CREATOR_ID (the key goes to curl through stdin config, never argv). Rows that already have an Id are skipped.
Display names use the in-game asset key only (W2_<Biome>_<Prop>), never a real name (design doc 5).
  python3 tools/blender/world2/upload_props.py [--upload] [<Biome> ...]
Import-safe: main() runs only as a script.
"""

import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EXPORT = os.path.join(ROOT, "build", "world2", "export")
THEMES = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2")
API = "https://apis.roblox.com/assets/v1/"
APPROVED = ("DevilTokyo", "RuinedCityZ", "HauntedTunnel", "KaijuBase", "ElvenPlains", "AntIsland", "MonsterDen", "HellGate")


def row_re(key):
	return re.compile(r"(\t\t%s = draftMesh\(\n\t\t\t\d+,\n\t\t\t)nil(, -- Id)" % re.escape(key))


def pending(biome):
	"""(key, glb path, tris) for each manifest mesh whose ledger row still has no Id."""
	manifest = json.load(open(os.path.join(EXPORT, biome, "manifest.json")))
	src = open(os.path.join(THEMES, biome + ".luau")).read()
	out = []
	for key, p in manifest["Props"].items():
		if row_re(key).search(src):
			out.append((key, os.path.join(EXPORT, biome, p["File"]), p["Tris"]))
		elif ("\t\t%s = draftMesh(" % key) not in src:
			raise SystemExit("%s: no ledger row in %s.luau" % (key, biome))
	return out


def curl(*args):
	cfg = 'header = "x-api-key: %s"\n' % os.environ["ROBLOX_OPEN_CLOUD_KEY"]  # stdin config, never argv
	r = subprocess.run(["curl", "-sS", "--max-time", "120", "-K", "-", *args], input=cfg, capture_output=True, text=True)
	if r.returncode != 0:
		raise RuntimeError(r.stderr.strip())
	return json.loads(r.stdout)


def upload(key, path):
	req = {
		"assetType": "Model",
		"displayName": key,
		"description": "Anime Run World 2 scenery",
		"creationContext": {"creator": {"userId": os.environ["ROBLOX_CREATOR_ID"]}},
	}
	op = curl("-X", "POST", API + "assets", "--form-string", "request=" + json.dumps(req), "-F", "fileContent=@%s;type=model/gltf-binary" % path)
	if "path" not in op:
		raise RuntimeError("%s: %s" % (key, op))
	for _ in range(60):
		time.sleep(3)
		st = curl(API + op["path"])
		if st.get("done"):
			if "response" not in st:
				raise RuntimeError("%s: %s" % (key, st))
			return st["response"]["assetId"]
	raise RuntimeError("%s: timed out %s" % (key, op["path"]))


def write_id(biome, key, asset_id):
	path = os.path.join(THEMES, biome + ".luau")
	src = open(path).read()
	new, n = row_re(key).subn(r'\1"rbxassetid://%s"\2' % asset_id, src)
	assert n == 1, (key, n)
	open(path, "w").write(new)


def main():
	argv = sys.argv[1:]
	real = "--upload" in argv
	biomes = [a for a in argv if not a.startswith("--")] or list(APPROVED)
	for b in biomes:
		if b not in APPROVED:
			raise SystemExit("%s is not an approved World 2 biome" % b)
	todo = [(b, *item) for b in biomes for item in pending(b)]
	if not real:
		for b, key, path, tris in todo:
			print("DRY upload %-40s %6d tris %8d bytes" % (key, tris, os.path.getsize(path)))
		print("DRY %d meshes, %d tris total, %d biomes; nothing uploaded (pass --upload)" % (len(todo), sum(t[3] for t in todo), len(biomes)))
		return
	for k in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID"):
		if not os.environ.get(k):
			raise SystemExit(k + " is not set")
	for b, key, path, _ in todo:
		asset_id = upload(key, path)
		write_id(b, key, asset_id)
		print("UPLOADED", key, asset_id, flush=True)


if __name__ == "__main__":
	main()
