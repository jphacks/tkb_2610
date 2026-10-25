"""Resize the supplied artwork into platform launcher icons (requires Pillow)."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/app_icon/yoinoko.png").convert("RGBA")
assert source.width == source.height, "The source icon must be square"
art = Image.new("RGB", source.size, "white")
art.paste(source, mask=source.getchannel("A"))
outputs = {}

for platform in ("ios", "macos"):
    folder = ROOT / platform / "Runner/Assets.xcassets/AppIcon.appiconset"
    for entry in json.loads((folder / "Contents.json").read_text())["images"]:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
        outputs[folder / entry["filename"]] = size

for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    outputs[ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"] = size

for entry in json.loads((ROOT / "web/manifest.json").read_text())["icons"]:
    outputs[ROOT / "web" / entry["src"]] = int(entry["sizes"].split("x")[0])
outputs[ROOT / "web/favicon.png"] = 32

for path, size in outputs.items():
    art.resize((size, size), Image.Resampling.LANCZOS).save(path)
    with Image.open(path) as result:
        assert result.size == (size, size) and result.mode == "RGB", path

art.resize((256, 256), Image.Resampling.LANCZOS).save(
    ROOT / "windows/runner/resources/app_icon.ico",
    sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)],
)
print(f"Updated and verified {len(outputs)} PNG icons and Windows ICO")
