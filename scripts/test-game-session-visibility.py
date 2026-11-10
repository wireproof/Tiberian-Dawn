#!/usr/bin/env python3
"""Compile the actual visibility helper against lightweight TD/RA focus models.

This checks event ordering without SDL/UIKit or a full application build.
Device testing is still required for actual UIKit lifecycle delivery.
"""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / "common/video_sdl2.cpp").read_text()
start = source.index("void Video_Set_Game_Window_Visible(bool visible)")
end = source.index("\n#endif", start)
with tempfile.TemporaryDirectory(prefix="game-session-visibility-") as temporary:
    directory = Path(temporary)
    (directory / "game_session_visibility_under_test.h").write_text(source[start:end])
    binary = directory / "test"
    compiler = shlex.split(os.environ.get("CXX", "c++"))
    subprocess.run(compiler + ["-std=c++17", "-I", str(directory),
                   str(root / "tests/game_session_visibility.cpp"), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print("PASS: TD/RA hide-show ordering, stale events, 10 cycles each, null window")
