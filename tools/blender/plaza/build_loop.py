"""The sky loop with its posts at the fuller layout's places (build_plaza.LOOP_POSTS): SkyLoop.
Headless: blender -b --factory-startup --python tools/blender/plaza/build_loop.py -- [--check]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as bp  # noqa: E402
import piece_export  # noqa: E402

if __name__ == "__main__":
	piece_export.run("loop", [("SkyLoop", bp.sky_loop(bp.LOOP_POSTS))])
