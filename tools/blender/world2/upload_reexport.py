#!/usr/bin/env python3
"""Uploads the World 2 colour re-export (reexport_props.py, docs/W2_REEXPORT_PLAN.md) in batches, with its own ledger
(tools/blender/world2/reexport_assets.json). The game's ledgers (World2/<Biome>.luau rows, uploaded_assets.tsv) keep the old ids until a
whole batch is uploaded, read in Studio, reviewed and checked; `apply` then writes it and `rollback` puts the old ids back.
  python3 tools/blender/world2/upload_reexport.py plan                        the batches
  ... dry <batch | key ...>                                                   what would be sent
  ... upload <batch | key ...>                                                sends (ROBLOX_OPEN_CLOUD_KEY, ROBLOX_CREATOR_ID)
  ... clear <key> <Model id | none>                                           after a lost reply: what a person found on the Creator dashboard
  ... mesh <key> <MeshId>                                                     the MeshId read in Studio from the uploaded Model
  ... compare-script <batch | key ...>   ... compare <file>                   the Studio vertex comparison and its results
  ... review <batch> "<date> <who>"     ... check <batch> "<date> <who>"      signed by the auditor / after the Studio look
  ... apply <batch>   ... rollback <batch>   ... recover (after a crash between their files)   ... --self-test (no network)
A send is written down before its POST: if the reply is lost, the key is not sent again until `clear`. Once the reply is in, its operation is
logged and a crash resumes it. One run at a time (lock). Everything a command needs is checked before it sends or writes anything.
"""

import datetime
import fcntl
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
MAX_DIFFERENCE = 0.001  # mesh-native units: the Studio comparison of old and new vertices
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


def put(path, text):
	"""Replaces a file whole: a crash leaves the old text or the new."""
	tmp = path + ".tmp"
	with open(tmp, "w") as f:
		f.write(text)
		f.flush()
		os.fsync(f.fileno())
	os.replace(tmp, path)


def save(ledger):
	put(LEDGER, json.dumps(ledger, indent=1, sort_keys=True))


def journal():
	return LEDGER + ".journal"


def lock():
	"""Held until the process ends (a crash frees it); a second run stops."""
	f = open(LEDGER + ".lock", "w")
	try:
		fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
	except OSError:
		raise SystemExit("another upload_reexport run holds the lock") from None
	return f


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


def needs_compare(a):
	"""A mesh whose re-made old file is not the uploaded one by hash (or has no hash recorded): its shape must be compared in Studio."""
	return a["OldHash"] != a["UploadedHash"]


def compared(a, row):
	c = row.get("Compared") or {}
	return c.get("Old") == a["OldMesh"] and c.get("New") == row.get("Mesh") and c.get("Max", 1) <= MAX_DIFFERENCE and c.get("TrisOld") == c.get("TrisNew") == a["Tris"]


def ready(m, ledger, keys):
	"""Why `keys` may not be applied yet: [] when they may."""
	out = []
	for k in keys:
		row = ledger.get(k, {})
		if row.get("Hash") != m[k]["Hash"]:
			out.append("%s: not uploaded as built" % k)
			continue
		out += ["%s: no %s" % (k, need) for need in ("Model", "Mesh", "Reviewed", "Checked") if not row.get(need)]
		if row.get("Applied"):
			out.append("%s: already applied" % k)
		if needs_compare(m[k]) and not compared(m[k], row):
			out.append("%s: no passing Studio comparison of its old and new vertices" % k)
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


def holds_old(m, keys):
	"""Raises when a key's theme row or tsv line does not hold its OldMesh."""
	tsv = open(TSV).read()
	for k in keys:
		set_row(open(theme_path(m[k]["Biome"])).read(), k, m[k]["OldMesh"], "0", "")
		set_tsv(tsv, k, m[k]["OldMesh"], [])


def send(m, ledger, key, path):
	"""One key's operation path and Model id ("" until polled). A send whose reply was lost stays "Sending" and is refused."""
	op, model = up.resumable(up.read_ops(), key, path)
	if op:
		ledger.get(key, {}).pop("Sending", None)
		return op, model
	if ledger.get(key, {}).get("Sending"):
		raise SystemExit("%s was being sent (%s) and its reply is lost: look on the Creator dashboard, then `clear`" % (key, ledger[key]["Sending"]["At"]))
	ledger.setdefault(key, {})["Sending"] = {"At": datetime.datetime.now().isoformat(timespec="seconds"), "Hash": m[key]["Hash"]}
	save(ledger)
	op = up.start(m[key]["Biome"], key, path)
	ledger[key].pop("Sending")
	save(ledger)
	return op, ""


def upload(m, ledger, keys):
	todo = unsent(m, ledger, keys)
	applied = [k for k in todo if ledger.get(k, {}).get("Applied")]
	if applied:
		raise SystemExit("%s: applied; roll its batch back first" % " ".join(applied))
	holds_old(m, todo)
	olds = {k: old_of(m, k) for k in todo}
	for name in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID"):
		if not os.environ.get(name):
			raise SystemExit(name + " is not set")
	up.OPS = LEDGER + ".ops.tsv"  # beside the ledger, not in build/: a lost build folder sends nothing twice
	save(ledger)  # the ledger can be written
	for k in todo:
		path = os.path.join(FOLDER, k + ".glb")
		op, model = send(m, ledger, k, path)
		if not model:
			model = up.poll(m[k]["Biome"], k, op)
			up.log_op(m[k]["Biome"], k, op, model, up.sha256(path))
		ledger[k] = {"Hash": m[k]["Hash"], "Model": str(model), "Old": ledger.get(k, {}).get("Old") or olds[k]}
		save(ledger)
		print("UPLOADED", k, model, flush=True)


def is_id(text):
	return re.fullmatch(r"[1-9][0-9]*", text) is not None


def taken(m, ledger, key):
	"""id -> whose it is: every old and original Model and MeshId, and the new ones but `key`'s own MeshId."""
	out = {}
	for k, a in m.items():
		out[a.get("OldMesh")], out[a.get("OldModel")] = k + "'s old MeshId", k + "'s old Model"
	for k, r in ledger.items():
		old = r.get("Old") or {}  # the originals: after an apply a rebuilt manifest no longer has them
		out[old.get("Mesh")], out[(old.get("Tsv") or [""] * 3)[2]] = k + "'s original MeshId", k + "'s original Model"
		out[r.get("Model")] = k + "'s Model"
		if k != key:
			out[r.get("Mesh")] = k + "'s MeshId"
	return out


def clear(m, ledger, key, found):
	"""A person looked after a lost reply: `found` is the Model id that did arrive, or "none". It is the mesh that was sent: refused
	when the build has changed since."""
	sending = ledger.get(key, {}).get("Sending")
	if not sending or not (found == "none" or is_id(found)):
		raise SystemExit("clear <a key being sent> <Model id | none>")
	if found == "none":
		ledger[key].pop("Sending")
		return save(ledger)
	if sending["Hash"] != m[key]["Hash"]:
		raise SystemExit("%s was sent as %s and is built as %s: `clear %s none`, the arrived Model is not this build" % (key, sending["Hash"][:12], m[key]["Hash"][:12], key))
	ids = taken(m, ledger, key)
	ids[ledger[key].get("Mesh")] = "its own MeshId"
	if found in ids:
		raise SystemExit("%s is %s" % (found, ids[found]))
	ledger[key] = {"Hash": sending["Hash"], "Model": found, "Old": ledger[key].get("Old") or old_of(m, key)}
	save(ledger)


def set_mesh(m, ledger, key, mesh):
	row = ledger.get(key, {})
	if not row.get("Model") or not is_id(mesh):
		raise SystemExit("mesh <uploaded key> <MeshId>")
	if row.get("Applied"):
		raise SystemExit("%s is applied; roll its batch back first" % key)
	ids = taken(m, ledger, key)
	if mesh in ids:
		raise SystemExit("%s is %s" % (mesh, ids[mesh]))
	row["Mesh"] = mesh
	for signed in ("Reviewed", "Checked", "Compared"):  # they were about another mesh
		row.pop(signed, None)
	save(ledger)


def sign(m, ledger, keys, field, text):
	if not text.isprintable() or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2} [^\s\"\\][^\"\\\x00-\x1f\x7f]*", text):  # it goes into a Luau string
		raise SystemExit('sign as "<YYYY-MM-DD> <who>", without quotes, backslashes or line breaks')
	applied = [k for k in keys if ledger.get(k, {}).get("Applied")]
	if applied:
		raise SystemExit("applied; roll back first: " + " ".join(applied))
	gaps = [k for k in keys if not ledger.get(k, {}).get("Mesh") or ledger[k].get("Hash") != m[k]["Hash"]]
	if gaps:
		raise SystemExit("no MeshId yet: " + " ".join(gaps))
	for k in keys:
		ledger[k][field] = text
	save(ledger)


def compare_script(m, ledger, keys):
	todo = [k for k in keys if ledger.get(k, {}).get("Mesh") and needs_compare(m[k])]
	rows = "".join('\n\t{ "%s", "%s", "%s" },' % (k, m[k]["OldMesh"], ledger[k]["Mesh"]) for k in todo)
	src = open(os.path.join(HERE, "reexport_compare.luau")).read()
	assert src.count("local ROWS = {} --ROWS") == 1
	return src.replace("local ROWS = {} --ROWS", "local ROWS = {%s\n}" % rows)


def take_compare(m, ledger, text):
	"""Stores the REEXPORT_COMPARE lines of a Studio output; raises on one that is about other meshes or none at all."""
	got = [json.loads(x) for x in re.findall(r"REEXPORT_COMPARE (\{[^}]*\})", text)]
	if not got:
		raise SystemExit("no REEXPORT_COMPARE line")
	for c in got:
		row = ledger.get(c.get("Key"), {})
		if not row.get("Mesh") or c["Old"] != m[c["Key"]]["OldMesh"] or c["New"] != row["Mesh"]:
			raise SystemExit("%s: compared %s with %s, not its old and new mesh" % (c.get("Key"), c.get("Old"), c.get("New")))
	for c in got:
		ledger[c["Key"]]["Compared"] = dict(c, At=datetime.date.today().isoformat())
		print("%-40s max %.6f tris %d / %d %s" % (c["Key"], c["Max"], c["TrisOld"], c["TrisNew"], "ok" if compared(m[c["Key"]], ledger[c["Key"]]) else "FAILS"))
	save(ledger)


def commit(files, ledger, keys, applied):
	"""Writes an apply or rollback: first the whole of it into the journal, then each file, then the ledger. A crash anywhere after the
	journal is finished by recover()."""
	for path in files:
		if not os.access(path, os.W_OK) or not os.access(os.path.dirname(path), os.W_OK):
			raise SystemExit("cannot write " + path)
	put(journal(), json.dumps({"Files": {p: {"Old": open(p).read(), "New": t} for p, t in files.items()}, "Keys": keys, "Applied": applied}))
	recover(ledger)


def recover(ledger):
	j = json.load(open(journal()))
	for path, t in j["Files"].items():
		if open(path).read() not in (t["Old"], t["New"]):
			raise SystemExit("%s was edited since: neither the old text nor the new; nothing written" % path)
	for path, t in j["Files"].items():
		put(path, t["New"])
	for k in j["Keys"]:
		ledger[k]["Applied"] = j["Applied"]
	save(ledger)
	os.remove(journal())


def self_test():
	import tempfile

	global TSV, LEDGER, FOLDER, put
	row = {"Track": 1, "Biome": "B", "Placed": 1, "Hash": "n", "OldHash": "o", "UploadedHash": "o", "OldMesh": "11", "OldReviewed": "then", "Tris": 1}
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
		# apply is whole or recoverable: a crash after any number of file writes
		real = put
		for crash_at in range(1, 6):
			open(theme_path("B"), "w").write(theme)
			open(TSV, "w").write(tsv)
			l2 = json.loads(json.dumps(led))
			save(l2)

			def crashing(path, text):
				writes[0] += 1
				if writes[0] == crash_at:
					raise KeyboardInterrupt
				real(path, text)

			writes = [0]
			put = crashing
			try:
				commit(switch(m, l2, keys, False), l2, keys, True)
				crashed = False
			except KeyboardInterrupt:
				crashed = True
			put = real
			if os.path.exists(journal()):
				recover(load())
			now = open(theme_path("B")).read(), open(TSV).read(), [bool(load()[k].get("Applied")) for k in keys]
			old_state = (theme, tsv, [False, False])
			new_state = (files[theme_path("B")], files[TSV], [True, True])
			assert now == (old_state if crash_at == 1 else new_state), (crash_at, now[2])  # before the journal: nothing; after: all
			assert crashed == (crash_at <= 4) and not os.path.exists(journal())
		# an applied key: no mesh, no upload, no second apply; rollback frees it
		l2 = load()
		assert ready(m, l2, keys) and refused(set_mesh, m, l2, "W2_B_A", "77") and refused(upload, {**m, "W2_B_A": dict(m["W2_B_A"], Hash="n2")}, l2, ["W2_B_A"])
		commit(switch(m, l2, keys, True), l2, keys, False)
		assert open(theme_path("B")).read() == theme and open(TSV).read() == tsv and ready(m, load(), keys) == []
		put(journal(), json.dumps({"Files": {TSV: {"Old": "x", "New": "y"}}, "Keys": [], "Applied": True}))
		assert refused(recover, load()) and open(TSV).read() == tsv  # someone edited the file in between
		os.remove(journal())
		# mesh: clears what was signed, and takes no id that is another's
		l2 = json.loads(json.dumps(led))
		for bad in ("12", "32", "21", "x", "11"):
			assert refused(set_mesh, m, l2, "W2_B_A", bad), bad
		l2["W2_B_A"]["Compared"] = {"Max": 0}
		set_mesh(m, l2, "W2_B_A", "888")
		assert not any(f in l2["W2_B_A"] for f in ("Reviewed", "Checked", "Compared")) and ready(m, l2, keys)
		assert refused(set_mesh, m, {}, "W2_B_A", "5")
		for field in ("Reviewed", "Checked"):
			l3 = {"W2_B_A": {"Hash": "n", "Model": "1"}}
			assert refused(sign, m, l3, ["W2_B_A"], field, "2026-11-25 me") and field not in l3["W2_B_A"]
			l3["W2_B_A"]["Mesh"] = "5"
			assert refused(sign, m, l3, ["W2_B_A"], field, "me")
			sign(m, l3, ["W2_B_A"], field, "2026-11-25 me")
			assert l3["W2_B_A"][field]
			for bad in ('2026-11-25 me"', "2026-11-25 me\\", "2026-11-25 me\nx", "2026-11-25 me\n", "2026-11-25 \r", "2026-11-25 m\udce9", "2026-11-25 m\u2028x"):
				assert refused(sign, m, l3, ["W2_B_A"], field, bad), repr(bad)
			l3["W2_B_A"]["Applied"] = True
			assert refused(sign, m, l3, ["W2_B_A"], field, "2026-11-25 you") and l3["W2_B_A"][field] == "2026-11-25 me"
		for bad in ("0777", "0", "\u0667\u0667", "7 ", "7\n", "-7", "1", "14"):  # 1: an OldModel of the manifest
			m3 = {**m, "W2_B_C": dict(m["W2_B_C"], OldModel="14")}
			l3 = json.loads(json.dumps(led))
			assert refused(set_mesh, {**m3, "W2_B_A": dict(m["W2_B_A"], OldModel="1")}, l3, "W2_B_A", bad), repr(bad)
		# the Studio comparison: needed where the old file is not proved, and about these two meshes
		for up_hash in ("other", ""):
			m2 = {**m, "W2_B_A": dict(m["W2_B_A"], UploadedHash=up_hash)}
			l3 = json.loads(json.dumps(led))
			assert len(ready(m2, l3, keys)) == 1
			line = 'x REEXPORT_COMPARE {"Key": "W2_B_A", "Old": "%s", "New": "%s", "Max": %s, "TrisOld": %d, "TrisNew": %d}\n'
			assert refused(take_compare, m2, l3, "nothing") and refused(take_compare, m2, l3, line % ("11", "99", "0", 1, 1)) and refused(take_compare, m2, l3, line % ("9", "31", "0", 1, 1))
			for bad in (("11", "31", "0.0011", 1, 1), ("11", "31", "0", 1, 2), ("11", "31", "0", 2, 2)):
				take_compare(m2, l3, line % bad)
				assert ready(m2, l3, keys), bad
			take_compare(m2, l3, line % ("11", "31", "0.0009", 1, 1))
			assert ready(m2, l3, keys) == []
			assert '{ "W2_B_A", "11", "31" }' in compare_script(m2, l3, keys) and "W2_B_C" not in compare_script(m2, l3, keys)
		# sending: a lost reply is never sent twice; a logged operation resumes
		FOLDER_WAS, OPS_WAS, start_was, poll_was = FOLDER, up.OPS, up.start, up.poll
		FOLDER = d
		posts = []
		for k in keys:
			open(os.path.join(d, k + ".glb"), "wb").write(b"mesh " + k.encode())
		env = {n: os.environ.get(n) for n in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID")}
		os.environ.update(ROBLOX_OPEN_CLOUD_KEY="k", ROBLOX_CREATOR_ID="1")

		def lost(biome, key, path):
			posts.append(key)
			raise RuntimeError("reply lost")

		def sent(biome, key, path):
			posts.append(key)
			up.log_op(biome, key, "operations/" + key, "", up.sha256(path))
			return "operations/" + key

		def stuck(biome, key, op):
			raise RuntimeError("timed out")

		up.start = lost
		save({})
		for _ in range(2):
			try:
				upload(m, load(), keys)
			except (RuntimeError, SystemExit):
				pass
		assert posts == ["W2_B_A"] and load()["W2_B_A"]["Sending"]["Hash"] == "n", posts
		later = {**m, "W2_B_A": dict(m["W2_B_A"], Hash="n2", OldModel="61"), "W2_B_C": dict(m["W2_B_C"], OldModel="62")}
		assert refused(clear, later, load(), "W2_B_A", "555")  # what arrived was the hash that was sent, not today's build
		l3 = {"W2_B_A": {"Hash": "older", "Model": "81", "Mesh": "82", "Old": old("11"), "Sending": {"At": "t", "Hash": "n"}}}
		for bad in ("81", "82"):  # its own earlier new ids
			assert refused(clear, m, l3, "W2_B_A", bad), bad
		# after an apply the rebuilt manifest's old ids are the new ones: the originals live in the ledger's Old
		kept = {"W2_B_C": dict(good, Model="22", Mesh="32", Old=dict(old("12"), Tsv=["B", "W2_B_C", "91", "12", "o"]))}
		rebuilt = {**m, "W2_B_C": dict(m["W2_B_C"], OldMesh="32", OldModel="22")}
		for bad in ("12", "91"):
			l3 = {**kept, "W2_B_A": {"Hash": "n", "Model": "21", "Sending": {"At": "t", "Hash": "n"}}}
			assert refused(set_mesh, rebuilt, l3, "W2_B_A", bad) and refused(clear, rebuilt, l3, "W2_B_A", bad), bad
		both = {**later, "W2_B_A": dict(m["W2_B_A"], OldModel="61")}
		l3 = load()
		l3["W2_B_C"] = {"Hash": "n", "Model": "444", "Mesh": "445"}
		for bad in ("61", "62", "444", "445", "11", "12", "0555", "\u0665", "maybe"):  # an old or another key's id
			assert refused(clear, both, l3, "W2_B_A", bad), repr(bad)
		assert refused(clear, m, load(), "W2_B_C", "none") and refused(clear, m, load(), "W2_B_A", "maybe")
		clear(m, load(), "W2_B_A", "none")
		up.start, up.poll = sent, stuck
		for _ in range(2):  # the poll dies: the same operation is resumed, not sent again
			try:
				upload(m, load(), keys)
			except RuntimeError:
				pass
		assert posts == ["W2_B_A", "W2_B_A"] and not load()["W2_B_A"].get("Sending")
		up.poll = lambda biome, key, op: "9" + str(len(key))
		upload(m, load(), keys)
		assert posts == ["W2_B_A", "W2_B_A", "W2_B_C"] and all(load()[k]["Model"] for k in keys)
		upload(m, load(), keys)
		assert len(posts) == 3  # sent once per mesh
		# killed after the operation is logged, before the ledger is: still not sent again
		l3 = load()
		l3["W2_B_C"] = {"Sending": {"At": "t", "Hash": "n"}}
		save(l3)
		upload(m, load(), keys)
		assert len(posts) == 3 and load()["W2_B_C"]["Model"]
		l3 = load()
		l3["W2_B_C"] = {"Sending": {"At": "t", "Hash": "n"}}
		clear(m, l3, "W2_B_C", "555")
		assert load()["W2_B_C"]["Hash"] == "n" and load()["W2_B_C"]["Model"] == "555" and load()["W2_B_C"]["Old"]["Mesh"] == "12"
		l3 = load()
		l3["W2_B_A"]["Applied"] = True  # its files hold the old id again, by hand: the ledger alone refuses
		n_posts = len(posts)
		os.environ.pop("ROBLOX_OPEN_CLOUD_KEY")
		try:
			upload({**m, "W2_B_A": dict(m["W2_B_A"], Hash="n2")}, l3, ["W2_B_A"])
			raise AssertionError("an applied key was sent")
		except SystemExit as e:
			assert "applied" in str(e), e
		os.environ["ROBLOX_OPEN_CLOUD_KEY"] = "k"
		assert len(posts) == n_posts
		# the first upload looks at the game's files
		save({})
		open(theme_path("B"), "w").write(theme.replace("rbxassetid://12", "rbxassetid://99"))
		assert refused(upload, m, load(), keys) and len(posts) == 3
		open(theme_path("B"), "w").write(theme)
		open(TSV, "w").write(tsv.replace("\t11\t", "\t98\t"))
		assert refused(upload, m, load(), keys) and len(posts) == 3
		first = lock()
		assert refused(lock)  # a second run
		first.close()
		lock().close()
		FOLDER, up.OPS, up.start, up.poll = FOLDER_WAS, OPS_WAS, start_was, poll_was
		for n, v in env.items():
			os.environ.pop(n)
			if v is not None:
				os.environ[n] = v
		TSV, up.THEMES, LEDGER = saved
	print("SELF-TEST ok")


def main():
	argv = sys.argv[1:]
	if argv == ["--self-test"]:
		return self_test()
	if not argv:
		raise SystemExit(__doc__)
	cmd, rest = argv[0], argv[1:]
	held = None if cmd in ("plan", "dry", "compare-script") else lock()  # noqa: F841 (until the process ends)
	m, ledger = manifest(files=cmd in ("dry", "upload")), load()
	if cmd == "plan":
		for i, keys in enumerate(batches(m), start=1):
			print("BATCH %d: %d meshes, %d tris, %d KB, placed rows %d | %s" % (i, len(keys), sum(m[k]["Tris"] for k in keys), sum(m[k]["Bytes"] for k in keys) // 1024, sum(m[k]["Placed"] for k in keys), " ".join(keys)))
		left = [k for k in sorted(m) if not any(k in b for b in batches(m))]
		return print("LEFT OUT:", ", ".join("%s (%s)" % (k, SKIP.get(k) or ("no id, not in game" if not m[k]["OldMesh"] else "unchanged")) for k in left))
	if cmd == "dry":
		for k in unsent(m, ledger, select(m, rest)):
			print("SEND", k, m[k]["Tris"], "tris", m[k]["Bytes"], "bytes", "(SENDING, reply lost)" if ledger.get(k, {}).get("Sending") else "")
		return None
	if cmd == "compare-script":
		return print(compare_script(m, ledger, select(m, rest)))
	if cmd == "recover":
		return recover(ledger) if os.path.exists(journal()) else print("nothing to recover")
	if os.path.exists(journal()):
		raise SystemExit("an apply or rollback was cut off: run `recover` first")
	if cmd == "upload":
		return upload(m, ledger, select(m, rest))
	if cmd == "compare":
		return take_compare(m, ledger, open(rest[0]).read())
	if cmd in ("mesh", "clear"):
		if len(rest) != 2 or rest[0] not in m:
			raise SystemExit("%s <key> <id>" % cmd)
		return (set_mesh if cmd == "mesh" else clear)(m, ledger, *rest)
	keys = select(m, rest[:1])
	if cmd in ("review", "check"):
		return sign(m, ledger, keys, "Reviewed" if cmd == "review" else "Checked", rest[1] if len(rest) == 2 else "")
	if cmd in ("apply", "rollback"):
		gaps = ready(m, ledger, keys) if cmd == "apply" else [k + ": not applied" for k in keys if not ledger.get(k, {}).get("Applied")]
		if gaps:
			raise SystemExit("not yet:\n" + "\n".join(gaps))
		return commit(switch(m, ledger, keys, cmd == "rollback"), ledger, keys, cmd == "apply")
	raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
	main()
