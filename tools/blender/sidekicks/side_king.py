# Sidekick side_king, The Golden King: the boss boss_king downsized (docs/char_evidence/side_king.md). The same painted R15 build
# with the fine detail dropped (one Ea cylinder, no red lines, the key as one plate, no side skirt plates, thicker earrings), since
# the follower scales the whole model to Sidekick size at runtime, as side_raga does. Ea and Key stay separate parts.
# Built by build_boss_event.py (build side_king), which renders and saves it like every Sidekick. Nothing here uploads.
ID = "side_king"
NAME = "The Golden King"


class Downsized:
	def finish(self):
		import build_boss_king

		root, _, tris = build_boss_king.build(ID, small=True)
		return root, tris


def build(k):
	return Downsized()
