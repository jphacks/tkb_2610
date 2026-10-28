"""Separate the generated transparent sheets without repainting the artwork.

The user authorized programmatic crop/transparency processing earlier in this
project. Eye/mouth removal was performed by imagegen, not this script.
Requires Pillow and numpy; generation of scene.rml itself uses only Python stdlib.
"""
from collections import deque
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
GROUPS = [
    ('blank_faces_01.png', ['kindness', 'environment', 'gratitude', 'courage']),
    ('blank_faces_02.png', ['cooperation', 'honesty', 'self_care']),
]


def components(alpha):
    active = np.array(alpha) > 32
    height, width = active.shape
    labels = np.zeros(active.shape, dtype=np.int32)
    objects = []
    for y, x in np.argwhere(active):
        if not active[y, x]:
            continue
        label = len(objects) + 1
        stack = deque([(int(x), int(y))])
        active[y, x] = False
        count = 0
        left = right = int(x)
        top = bottom = int(y)
        while stack:
            px, py = stack.pop()
            labels[py, px] = label
            count += 1
            left, right = min(left, px), max(right, px)
            top, bottom = min(top, py), max(bottom, py)
            for nx, ny in [(px-1, py), (px+1, py), (px, py-1), (px, py+1)]:
                if 0 <= nx < width and 0 <= ny < height and active[ny, nx]:
                    active[ny, nx] = False
                    stack.append((nx, ny))
        objects.append((label, count, (left, top, right+1, bottom+1)))
    return labels, objects


def main():
    target = HERE / 'textures'
    target.mkdir(exist_ok=True)
    manifest = {}
    for filename, names in GROUPS:
        image = Image.open(HERE / 'source' / filename).convert('RGBA')
        labels, objects = components(image.getchannel('A'))
        subjects = sorted([o for o in objects if o[1] > 10000], key=lambda o: o[2][0])
        if len(subjects) != len(names):
            raise ValueError(f'{filename}: expected {len(names)} subjects, got {subjects}')
        rgba = np.array(image)
        for name, (label, _, bbox) in zip(names, subjects):
            # Retain the original antialiasing at the connected component's edge.
            mask = Image.fromarray((labels == label).astype('uint8')*255).filter(ImageFilter.MaxFilter(3))
            pixels = rgba.copy()
            pixels[:, :, 3] = np.minimum(pixels[:, :, 3], np.array(mask))
            crop = Image.fromarray(pixels).crop(bbox)
            ratio = min(420/crop.width, 410/crop.height)
            size = (round(crop.width*ratio), round(crop.height*ratio))
            scaled = crop.resize(size, Image.Resampling.LANCZOS)
            offset = ((500-size[0])//2, 480-size[1])
            canvas = Image.new('RGBA', (500, 500))
            canvas.alpha_composite(scaled, offset)
            canvas.save(target / f'stage1_{name}.png', optimize=True)
            manifest[f'stage1_{name}'] = dict(sheet=filename, sourceBox=bbox,
                                             scale=ratio, offset=offset, size=size)
    (HERE / 'texture_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
