# Sidekick side_mage, The Elf Mage: the boss boss_mage downsized (docs/char_evidence/side_mage.md). The same painted R15 build
# with the fine detail dropped (no staff ribbon or gem ring, no mantle hem band, thicker earrings), since the follower scales the
# whole model to Sidekick size at runtime, as side_raga does. The staff and the twin tails stay separate parts; no golem.
# Built by build_boss_event.py (build side_mage), which renders and saves it like every Sidekick. Nothing here uploads.
ID = "side_mage"
NAME = "The Elf Mage"


class Downsized:
	def finish(self):
		import build_boss_mage

		root, _, tris = build_boss_mage.build(ID, small=True)
		return root, tris


def build(k):
	return Downsized()
