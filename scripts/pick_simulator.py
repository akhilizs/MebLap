"""Reads `xcrun simctl list devices available -j` on stdin and prints the UDID of the newest iPhone."""
import json, re, sys

data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        name = d["name"]
        if not name.startswith("iPhone"):
            continue
        score = (version, "Pro" in name and "Max" not in name, name)
        if best is None or score > best[0]:
            best = (score, d["udid"], name)
if not best:
    sys.exit("No iPhone simulator found")
print(f"Using {best[2]} {best[0][0]}", file=sys.stderr)
print(best[1])
