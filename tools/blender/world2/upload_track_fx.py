#!/usr/bin/env python3
"""Upload the World 2 track effect assets (docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)") as the
owner's assets with Open Cloud (BIOME_ENVIRONMENT_SPEC 4.1 Lane B step 4). Approved by the lead on the owner's word
(change log 2026-11-26, f2446967: "You can go ahead and approve the assets that you draft up"); IP review OK for all 8.

- 4 textures (assets/world2_draft/track_fx/textures) go up as Decals; each Decal is resolved to its image id through
  the asset delivery API (the Decal XML's Texture url), as tools/blender/portrait/upload_portraits.py does.
- 4 meshes (assets/world2_draft/track_fx/meshes) go up as Models; each Model is downloaded through the asset delivery
  API to <dir>/<key>.rbxm, and its MeshPart's MeshId is read offline (tools/lune/trackfx_meshids.luau).
- Every result and its moderation state go in the ledger assets/world2_draft/track_fx/assets.json (key -> Hash, Kind,
  Decal / Model, Image, Moderation); a rerun spends no upload for a file whose hash is already there.

DRY RUN BY DEFAULT. A real run needs --upload, ROBLOX_OPEN_CLOUD_KEY and ROBLOX_CREATOR_ID; the key goes to curl
through stdin config, never argv, and is never printed. Display names are the asset keys only (design doc 5).
	python3 upload_track_fx.py [--upload] [--dir <folder holding the 8 files>] [--ledger <assets.json>]
Runs on python 3.9 (the Mac's). Import-safe: main() runs only as a script.
"""
import gzip
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
FX = os.path.abspath(os.path.join(HERE, "..", "..", "..", "assets", "world2_draft", "track_fx"))
API = "https://apis.roblox.com/assets/v1/"
DELIVERY = "https://apis.roblox.com/asset-delivery-api/v1/assetId/"
TEXTURE = re.compile(rb'name="Texture"[^>]*>\s*<url>[^<]*?(\d+)\s*</url>')
ASSETS = (  # key, kind, file under track_fx/, content type
	("TrackFx_SmokePuff", "Decal", "textures/TrackFx_SmokePuff.flipbook.png", "image/png"),
	("TrackFx_Wisp", "Decal", "textures/TrackFx_Wisp.flipbook.png", "image/png"),
	("TrackFx_Haze", "Decal", "textures/TrackFx_Haze.png", "image/png"),
	("TrackFx_Ember", "Decal", "textures/TrackFx_Ember.png", "image/png"),
	("TrackFx_DrakeBody", "Model", "meshes/TrackFx_DrakeBody.glb", "model/gltf-binary"),
	("TrackFx_DrakeWing", "Model", "meshes/TrackFx_DrakeWing.glb", "model/gltf-binary"),
	("TrackFx_EelHead", "Model", "meshes/TrackFx_EelHead.glb", "model/gltf-binary"),
	("TrackFx_EelSegment", "Model", "meshes/TrackFx_EelSegment.glb", "model/gltf-binary"),
)


def curl(*args):
	cfg = 'header = "x-api-key: %s"\n' % os.environ["ROBLOX_OPEN_CLOUD_KEY"]  # stdin config, never argv
	r = subprocess.run(["curl", "-sS", "--max-time", "120", "-K", "-"] + list(args), input=cfg, capture_output=True, text=True)
	if r.returncode != 0:
		raise RuntimeError(r.stderr.strip())
	return json.loads(r.stdout)


def sha256(path):
	return hashlib.sha256(open(path, "rb").read()).hexdigest()


def upload(key, kind, path, ctype):
	req = {
		"assetType": kind,
		"displayName": key,
		"description": "Anime Run World 2 track effect",
		"creationContext": {"creator": {"userId": os.environ["ROBLOX_CREATOR_ID"]}},
	}
	op = curl("-X", "POST", API + "assets", "--form-string", "request=" + json.dumps(req), "-F", "fileContent=@%s;type=%s" % (path, ctype))
	if "path" not in op:
		raise RuntimeError("%s: %s" % (key, op))
	return op["path"]


def poll(key, op_path):
	for _ in range(80):
		time.sleep(3)
		st = curl(API + op_path)
		if st.get("done"):
			if "response" not in st:
				raise RuntimeError("%s: %s" % (key, st))
			return st["response"]["assetId"]
	raise RuntimeError("%s: timed out %s" % (key, op_path))


def moderation(asset_id):
	try:
		st = curl(API + "assets/%s?readMask=moderationResult" % asset_id)
	except (RuntimeError, ValueError) as e:
		return "Unread (%s)" % str(e)[:80]
	return (st.get("moderationResult") or {}).get("moderationState", "Unknown: %s" % str(st)[:120])


def download(key, asset_id):
	"""The asset's bytes through the delivery API (key needs legacy-asset:manage); the signed url is never logged."""
	last = None
	for _ in range(10):
		st = curl(DELIVERY + str(asset_id))
		location = st.get("location")
		if location:
			if urlparse(location).scheme != "https":
				raise RuntimeError("%s: refusing a non-https location" % key)
			r = subprocess.run(["curl", "-sS", "--fail", "-L", "--max-time", "120", location], capture_output=True)
			if r.returncode != 0:
				raise RuntimeError("%s: download failed, curl exit %d" % (key, r.returncode))
			body = r.stdout
			return gzip.decompress(body) if body.startswith(b"\x1f\x8b") else body
		last = st
		time.sleep(3)
	raise RuntimeError("%s: no delivery location for %s (a 403 means the key lacks legacy-asset:manage): %s" % (key, asset_id, last))


def image_id_in(body):
	found = TEXTURE.search(body)
	if found:
		return found.group(1).decode()
	raise RuntimeError("no Texture url in %d bytes starting %r" % (len(body), body[:40]))


def main():
	argv = sys.argv[1:]
	real = "--upload" in argv
	base = argv[argv.index("--dir") + 1] if "--dir" in argv else FX
	ledger_path = argv[argv.index("--ledger") + 1] if "--ledger" in argv else os.path.join(FX, "assets.json")
	ledger = json.load(open(ledger_path)) if os.path.exists(ledger_path) else {}

	def save():
		with open(ledger_path, "w") as f:
			json.dump(ledger, f, indent=1, sort_keys=True)
			f.write("\n")

	for key, kind, rel, ctype in ASSETS:
		path = os.path.join(base, rel) if os.path.exists(os.path.join(base, rel)) else os.path.join(base, os.path.basename(rel))
		digest = sha256(path)
		row = ledger.get(key, {})
		if row.get("Hash") != digest:
			row = {"Hash": digest, "Kind": kind}
		if not real:
			state = "done" if (row.get("Image") or row.get("Model")) else "would upload"
			print("DRY %-20s %-5s %8d bytes  %s" % (key, kind, os.path.getsize(path), state))
			continue
		if not row.get(kind):
			row["Op"] = row.get("Op") or upload(key, kind, path, ctype)
			ledger[key] = row
			save()  # the operation is kept before polling, so a crash resumes it
			row[kind] = poll(key, row["Op"])
			ledger[key] = row
			save()
		if kind == "Decal" and not row.get("Image"):
			row["Image"] = image_id_in(download(key, row["Decal"]))
		if kind == "Model":
			out = os.path.join(os.path.dirname(ledger_path), key + ".rbxm")
			if not os.path.exists(out):
				with open(out, "wb") as f:
					f.write(download(key, row["Model"]))
		row["Moderation"] = moderation(row[kind])
		if kind == "Decal":
			row["ImageModeration"] = moderation(row["Image"])
		ledger[key] = row
		save()
		print("UPLOADED %s %s %s image %s moderation %s" % (key, kind, row[kind], row.get("Image", "-"), row["Moderation"]), flush=True)
	if not real:
		print("DRY: nothing uploaded (pass --upload)")


if __name__ == "__main__":
	main()
