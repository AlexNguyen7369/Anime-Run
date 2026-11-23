"""Writes assets/world2_draft/index.html, the owner's approval page for the World 2 drafts.

Per track: the look-only source references (build/world2/refs/<Biome>/, gitignored, never shipped, shown only when
present on this machine), a link to docs/world2_refs/<Biome>.md, then the 6 Blender shots.
Run: python3 tools/blender/world2/make_index.py
"""

import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "world2_draft")
REFS = os.path.join(ROOT, "build", "world2", "refs")
TRACKS = [
	(1, "DevilTokyo", "Devil Hunter Tokyo", "Saw Man", "Katanah Man"),
	(2, "DemonCastle", "Demon King's Castle", "Solo Levelup", "Barran"),
	(3, "RuinedCityZ", "Ruined City Zed", "One Punch", "Garoo"),
	(4, "HauntedTunnel", "Haunted Tunnel Road", "Dandadan", "Turbo Grammy"),
	(5, "KaijuBase", "Wrecked Tachikawa", "Kaiju No. 8", "Kaijo No. 9"),
	(6, "ElvenPlains", "Elven Ruin Plains", "Frieren", "Ora"),
	(7, "AntIsland", "Ant Island", "Solo Levelup", "Berru"),
	(8, "MonsterDen", "Monster Den", "One Punch", "Orochy"),
	(9, "GoldenCity", "Golden City", "Frieren", "Machto"),
	(10, "HellGate", "Hell's Gate", "Saw Man", "Makina"),
]
IMG = (".jpg", ".jpeg", ".png", ".webp", ".gif")


def page():
	css = (
		"body{font:14px system-ui;background:#111;color:#eee;margin:24px}h2{margin:28px 0 6px}"
		"img{width:32%;margin:.3%;border-radius:6px}p{color:#aaa;margin:2px 0 8px}a{color:#8cf}"
		".ref img{width:15.4%;height:150px;object-fit:cover;outline:2px solid #fc6}"
	)
	out = [
		'<!doctype html><meta charset="utf-8"><title>World 2 track drafts</title><style>%s</style>' % css,
		"<h1>World 2: Blender drafts for approval</h1><p>Design doc 4.47. Each track: source references (yellow outline, "
		"look-only, local, never shipped), then overview, four runner views (6/33/62/90% of the road), side view. "
		"Rendered in Blender (EEVEE) from tools/blender/world2. Reply per track: approve, or what to change.</p>",
		"<h2>Plaza gate (World 1 spawn)</h2>",
	]
	out += ['<img src="gate/%s">' % f for f in ("01_both_front.jpg", "02_locked_close.jpg", "03_three_quarter.jpg", "04_studio_locked.jpg")]
	for n, key, title, series, enemy in TRACKS:
		folder = "track%02d_%s" % (n, key)
		out.append(
			'<h2>Track %d: %s</h2><p>%s &middot; enemy %s &middot; biome key %s &middot; <a href="../../docs/world2_refs/%s.md">reference notes</a></p>'
			% (n, title, series, enemy, key, key)
		)
		ref_dir = os.path.join(REFS, key)
		refs = sorted(f for f in os.listdir(ref_dir) if f.lower().endswith(IMG)) if os.path.isdir(ref_dir) else []
		if refs:
			out.append('<div class="ref">' + "".join('<img src="../../build/world2/refs/%s/%s">' % (key, f) for f in refs) + "</div>")
		shots = sorted(f for f in os.listdir(os.path.join(OUT, folder)) if f.endswith(".jpg"))  # the 6 fixed shots plus any EXTRA_SHOTS
		out += ['<img src="%s/%s">' % (folder, s) for s in shots]
	return "\n".join(out) + "\n"


if __name__ == "__main__":
	open(os.path.join(OUT, "index.html"), "w").write(page())
	print("wrote", os.path.join(OUT, "index.html"))
