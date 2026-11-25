#!/usr/bin/env python3
"""Uploads the World 2 colour re-export (reexport_props.py, docs/W2_REEXPORT_PLAN.md) in batches, with its own ledger
(tools/blender/world2/reexport_assets.json). The game's ledgers (World2/<Biome>.luau rows, uploaded_assets.tsv) keep the old ids until a
whole batch is uploaded, read in Studio, reviewed and checked; `apply` then writes it and `rollback` puts the old ids back.
  python3 tools/blender/world2/upload_reexport.py plan                        the batches
  ... dry <batch | key ...>                                                   what would be sent
  ... upload <batch | key ...>                                                sends (ROBLOX_OPEN_CLOUD_KEY, ROBLOX_CREATOR_ID)
  ... mesh <key> <MeshId>                                                     the MeshId read in Studio from the uploaded Model
  ... review <batch> "<date> <who>"     ... check <batch> "<date> <who>"      signed by the auditor / after the Studio look
  ... apply <batch>   ... rollback <batch>   ... --self-test (no network)
A model is sent once per mesh hash; every operation is logged before polling, so a crash resumes it. Everything a command needs is checked
before it sends or writes anything.
"""

import json
import os
import re
import sys

import upload_props as up

HERE = up.HERE
FOLDER = os.path.join(up.ROOT, "build", "world2", "reexport")
LEDGER = os.path.join(HERE, "reexport_assets.json")
TSV = os.path.join(HERE, "uploaded_assets.tsv")
BATCH = 15
# left out of the batches: a mesh that keeps its file, and Track 5's reopened kaiju (its own export)
SKIP = {"W2_KaijuBase_GiantCorpse": "reopened (WORLD2_SPEC 2026-11-25): its rework exports it"}


def manifest(files=True):
	m = json.load(open(os.path.join(FOLDER, "manifest.json")))
	for key, a in m.items():
		path = os.path.join(FOLDER, key + ".glb")
		if files and (not os.path.exists(path) or up.sha256(path) != a["Sha256"]):
			raise SystemExit("%s: the GLB is missing or not the manifest's" % key)
	return m


def batches(m):
	"""[[key]]: the placed meshes by track, then the unplaced with an id; a track's keys stay together when they fit."""
	todo = [k for k in m if k not in SKIP and m[k]["OldMesh"] and m[k]["Hash"] != m[k]["OldHash"]]
	out, now = [], []
	for group in (True, False):
		for track in sorted({m[k]["Track"] for k in todo}):
			keys = sorted(k for k in todo if m[k]["Track"] == track and (m[k]["Placed"] > 0) == group)
			if now and len(now) + len(keys) > BATCH:
				out.append(now)
				now = []
			now = now + keys
		if now:
			out.append(now)
		now = []
	return out


def load():
	return json.load(open(LEDGER)) if os.path.exists(LEDGER) else {}


def save(ledger):
	tmp = LEDGER + ".tmp"
	with open(tmp, "w") as f:
		json.dump(ledger, f, indent=1, sort_keys=True)
	os.replace(tmp, LEDGER)


def select(m, names):
	"""The keys of `names`: one batch number, or keys."""
	if len(names) == 1 and names[0].isdigit():
		all_ = batches(m)
		if not 1 <= int(names[0]) <= len(all_):
			raise SystemExit("batch 1 to %d" % len(all_))
		return all_[int(names[0]) - 1]
	bad = [n for n in names if n not in m]
	if bad or not names:
		raise SystemExit("unknown or no key: %s" % " ".join(bad))
	held = [n for n in names if n in SKIP]
	if held:
		raise SystemExit("%s: %s" % (held[0], SKIP[held[0]]))
	return names


def unsent(m, ledger, keys):
	return [k for k in keys if not (ledger.get(k, {}).get("Hash") == m[k]["Hash"] and ledger[k].get("Model"))]


def theme_path(biome):
	return os.path.join(up.THEMES, biome + ".luau")


def set_row(src, key, old, new, reviewed):
	"""The ledger row's id from `old` to `new` (digits) and its Reviewed; raises when the row does not hold `old`."""
	row = re.compile(r'(\t\t%s = draftMesh\(\n\t\t\t\d+,\n\t\t\t)"rbxassetid://%s"(, -- Id[^\n]*\n\t\t\t)"[^"]*"' % (re.escape(key), old))
	out, n = row.subn(lambda x: '%s"rbxassetid://%s"%s"%s"' % (x.group(1), new, x.group(2), reviewed), src)
	if n != 1:
		raise SystemExit("%s: its ledger row does not hold %s" % (key, old))
	return out


def set_tsv(text, key, old_mesh, row):
	"""uploaded_assets.tsv with `key`'s line replaced; raises when the line does not hold old_mesh."""
	lines = text.split("\n")
	at = [i for i, line in enumerate(lines) if line.split("\t")[1:2] == [key]]
	if len(at) != 1 or lines[at[0]].split("\t")[3] != old_mesh:
		raise SystemExit("%s: uploaded_assets.tsv does not hold %s" % (key, old_mesh))
	lines[at[0]] = "\t".join(row)
	return "\n".join(lines)


def ready(m, ledger, keys):
	"""Why `keys` may not be applied yet: [] when they may."""
	out = []
	for k in keys:
		row = ledger.get(k, {})
		if row.get("Hash") != m[k]["Hash"]:
			out.append("%s: not uploaded as built" % k)
			continue
		out += ["%s: no %s" % (k, need) for need in ("Model", "Mesh", "Reviewed", "Checked") if not row.get(need)]
	return out


def switch(m, ledger, keys, back):
	"""Every file's new text for an apply or rollback, all made before any is written. Returns {path: text}."""
	files = {TSV: open(TSV).read()}
	for k in keys:
		a, row = m[k], ledger[k]
		path = theme_path(a["Biome"])
		src = files.get(path) or open(path).read()
		if back:
			files[path] = set_row(src, k, row["Mesh"], row["Old"]["Mesh"], row["Old"]["Reviewed"])
			files[TSV] = set_tsv(files[TSV], k, row["Mesh"], row["Old"]["Tsv"])
		else:
			files[path] = set_row(src, k, row["Old"]["Mesh"], row["Mesh"], row["Reviewed"])
			files[TSV] = set_tsv(files[TSV], k, row["Old"]["Mesh"], [a["Biome"], k, row["Model"], row["Mesh"], row["Hash"]])
	return files


def old_of(m, key):
	for line in open(TSV):
		f = line.rstrip("\n").split("\t")
		if f[1:2] == [key]:
			return {"Mesh": m[key]["OldMesh"], "Reviewed": m[key]["OldReviewed"], "Tsv": f}
	raise SystemExit("%s: not in uploaded_assets.tsv" % key)


def upload(m, ledger, keys):
	todo = unsent(m, ledger, keys)
	olds = {k: old_of(m, k) for k in todo}
	for name in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID"):
		if not os.environ.get(name):
			raise SystemExit(name + " is not set")
	up.OPS = os.path.join(FOLDER, "ops.tsv")
	save(ledger)  # the ledger can be written
	for k in todo:
		path = os.path.join(FOLDER, k + ".glb")
		op, model = up.resumable(up.read_ops(), k, path)
		if not model:
			op = op or up.start(m[k]["Biome"], k, path)
			model = up.poll(m[k]["Biome"], k, op)
			up.log_op(m[k]["Biome"], k, op, model, up.sha256(path))
		ledger[k] = {"Hash": m[k]["Hash"], "Model": str(model), "Old": ledger.get(k, {}).get("Old") or olds[k]}
		save(ledger)
		print("UPLOADED", k, model, flush=True)


def self_test():
	import tempfile

	global TSV, LEDGER, FOLDER
	row = {"Track": 1, "Biome": "B", "Placed": 1, "Hash": "n", "OldHash": "o", "OldMesh": "11", "OldReviewed": "then", "Tris": 1}
	m = {"W2_B_A": dict(row), "W2_B_C": dict(row, OldMesh="12"), "W2_B_U": dict(row, Placed=0, OldMesh="13"), "W2_B_Nil": dict(row, OldMesh=""), "W2_B_Same": dict(row, Hash="o")}
	m["W2_KaijuBase_GiantCorpse"] = dict(row, Track=5)
	assert batches(m) == [["W2_B_A", "W2_B_C"], ["W2_B_U"]], batches(m)  # no id, unchanged and held meshes stay out
	many = {"W2_T%d_%02d" % (t, i): dict(row, Track=t) for t in (1, 2, 3) for i in range(9)}
	assert [len(b) for b in batches(many)] == [9, 9, 9] and max(len(b) for b in batches(many)) <= BATCH

	def refused(f, *a):
		try:
			f(*a)
		except SystemExit:
			return True
		return False

	assert refused(select, m, ["nope"]) and refused(select, m, []) and refused(select, m, ["99"]) and refused(select, m, ["W2_KaijuBase_GiantCorpse"])
	assert select(m, ["2"]) == ["W2_B_U"]
	keys, good = ["W2_B_A", "W2_B_C"], {"Hash": "n", "Model": "21", "Mesh": "31", "Reviewed": "r", "Checked": "c"}
	old = lambda n: {"Mesh": n, "Reviewed": "then", "Tsv": ["B", "", "1", n, "o"]}  # noqa: E731
	led = {"W2_B_A": dict(good, Old=old("11")), "W2_B_C": dict(good, Mesh="32", Old=old("12"))}
	for k in keys:
		led[k]["Old"]["Tsv"][1] = k
	assert ready(m, led, keys) == []
	for gap in ("Model", "Mesh", "Reviewed", "Checked"):
		assert ready(m, {**led, "W2_B_C": {**led["W2_B_C"], gap: ""}}, keys), gap  # one gap holds the whole batch
	assert ready(m, {**led, "W2_B_C": {**led["W2_B_C"], "Hash": "older"}}, keys)
	assert unsent(m, led, keys) == [] and unsent(m, {}, keys) == keys
	with tempfile.TemporaryDirectory() as d:
		saved = TSV, up.THEMES, LEDGER
		TSV, up.THEMES, LEDGER = os.path.join(d, "t.tsv"), d, os.path.join(d, "l.json")
		theme = "".join('\t\t%s = draftMesh(\n\t\t\t1,\n\t\t\t"rbxassetid://%s", -- Id: x\n\t\t\t"then", -- R\n\t\t),\n' % (k, n) for k, n in (("W2_B_A", "11"), ("W2_B_C", "12")))
		tsv = "B\tW2_B_A\t1\t11\to\nB\tW2_B_C\t1\t12\to\n"
		open(theme_path("B"), "w").write(theme)
		open(TSV, "w").write(tsv)
		files = switch(m, led, keys, False)
		assert open(TSV).read() == tsv and open(theme_path("B")).read() == theme  # switch itself writes nothing
		assert "31" in files[theme_path("B")] and '"r", -- R' in files[theme_path("B")] and "rbxassetid://11" not in files[theme_path("B")]
		assert files[TSV].split("\n")[1] == "B\tW2_B_C\t21\t32\tn"
		wrong = {**led, "W2_B_C": {**led["W2_B_C"], "Old": old("99")}}
		assert refused(switch, m, wrong, keys, False)  # the row holds another id: nothing is written for the batch
		for path, text in files.items():
			open(path, "w").write(text)
		back = switch(m, led, keys, True)
		assert back[theme_path("B")] == theme and back[TSV] == tsv  # rollback is the old text to the byte
		TSV, up.THEMES, LEDGER = saved
	print("SELF-TEST ok")


def main():
	argv = sys.argv[1:]
	if argv == ["--self-test"]:
		return self_test()
	if not argv:
		raise SystemExit(__doc__)
	cmd, rest = argv[0], argv[1:]
	m, ledger = manifest(files=cmd in ("dry", "upload")), load()
	if cmd == "plan":
		for i, keys in enumerate(batches(m), start=1):
			print("BATCH %d: %d meshes, %d tris, %d KB, placed rows %d | %s" % (i, len(keys), sum(m[k]["Tris"] for k in keys), sum(m[k]["Bytes"] for k in keys) // 1024, sum(m[k]["Placed"] for k in keys), " ".join(keys)))
		left = [k for k in sorted(m) if not any(k in b for b in batches(m))]
		return print("LEFT OUT:", ", ".join("%s (%s)" % (k, SKIP.get(k) or ("no id, not in game" if not m[k]["OldMesh"] else "unchanged")) for k in left))
	if cmd in ("dry", "upload"):
		keys = select(m, rest)
		for k in unsent(m, ledger, keys):
			print("SEND", k, m[k]["Tris"], "tris", m[k]["Bytes"], "bytes")
		return upload(m, ledger, keys) if cmd == "upload" else None
	if cmd == "mesh":
		key, mesh = rest
		if key not in ledger or not mesh.isdigit() or mesh in (m[key]["OldMesh"], ledger[key]["Model"]):
			raise SystemExit("mesh <uploaded key> <its MeshId: not the Model id, not the old one>")
		ledger[key]["Mesh"] = mesh
		return save(ledger)
	keys = select(m, rest[:1])
	if cmd in ("review", "check"):
		if len(rest) != 2 or not re.match(r"\d{4}-\d\d-\d\d \S", rest[1]) or any(k not in ledger for k in keys):
			raise SystemExit('%s <uploaded batch> "<YYYY-MM-DD> <who>"' % cmd)
		for k in keys:
			ledger[k]["Reviewed" if cmd == "review" else "Checked"] = rest[1]
		return save(ledger)
	if cmd in ("apply", "rollback"):
		gaps = ready(m, ledger, keys) if cmd == "apply" else [k for k in keys if not ledger.get(k, {}).get("Applied")]
		if gaps:
			raise SystemExit("not yet:\n" + "\n".join(gaps))
		for path, text in switch(m, ledger, keys, cmd == "rollback").items():
			with open(path, "w") as f:
				f.write(text)
		for k in keys:
			ledger[k]["Applied"] = cmd == "apply"
		return save(ledger)
	raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
	main()
