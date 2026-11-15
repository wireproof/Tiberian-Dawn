#!/usr/bin/env python3
"""Test real Apple singleton headers across separate Mach-O images, without UI."""
import os
from pathlib import Path
import platform
import shlex
import subprocess
import tempfile

if platform.system() != "Darwin":
    raise SystemExit("This regression requires macOS dyld.")
root = Path(__file__).resolve().parent.parent
compiler = shlex.split(os.environ.get("CXX", "c++"))
with tempfile.TemporaryDirectory(prefix="game-image-isolation-") as temporary:
    directory = Path(temporary)
    for optimization in ("-O0", "-O2"):
        common = compiler + ["-std=c++17", optimization, "-DMACOS_PORT", "-I", str(root),
                             str(root / "tests/game_image_isolation.cpp")]
        plugin = directory / (optimization + ".dylib")
        host = directory / (optimization + "-host")
        subprocess.run(common + ["-DPROBE_PLUGIN", "-dynamiclib", "-o", str(plugin)], check=True)
        subprocess.run(common + ["-o", str(host)], check=True)
        subprocess.run([str(host), str(plugin)], check=True)
        print(f"PASS {optimization}: seven laptop states, wrappers, cheat state/preferences/save callback isolated")
