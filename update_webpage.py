#!/usr.bin/env python3
import subprocess
import os
if os.path.exists("./index.html"):
    print("Deleting old index.html.")
    os.unlink("./index.html")
    if os.path.exists("./index.html"):
        raise RuntimeError("Failed to delete existing index.html")
print("Exporting index.html with pico8.")
subprocess.run(["pico8", "-export", "./index.html", "./loop.p8"])
if os.path.exists("./index.html"):
    print("Success!")
else:
    raise RuntimeError("Failed to export index.html. Make sure pico8 is in your path!")
