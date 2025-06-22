#!/usr.bin/env python3
import subprocess
import os
files = ("index.html", "index.js")
for file in files:
    path = f"./{file}"
    if os.path.exists(path):
        print(f"Deleting existing {file}.")
        os.unlink(path)
        if os.path.exists(path):
            raise RuntimeError(f"Failed to delete existing {file}")
print("Exporting with pico8...")
subprocess.run(["pico8", "-export", "./index.html", "./loop.p8"])
if all(os.path.exists(f"./{file}") for file in files):
    print("Success!")
else:
    raise RuntimeError("Failed to export. Make sure pico8 is in your path!")
