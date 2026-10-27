"""Crop separately generated puppet pieces; never repaint or stretch the art.

Connected-component masks retain edge antialiasing and exclude neighbouring
pieces, including when a generated atlas does not obey its requested grid.
Programmatic cropping/transparency was explicitly authorized by the user.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from prepare_textures import components

HERE = Path(__file__).resolve().parent


def prepare(filename, names):
    image = Image.open(HERE / 'source' / filename).convert('RGBA')
    labels, objects = components(image.getchannel('A'))
    subjects = [o for o in objects if o[1] > 1500]
    if len(subjects) != len(names):
        raise ValueError(f'{filename}: expected {len(names)} parts, got {subjects}')
    rgba = np.array(image)
    result = {}
    for name, (label, _, bbox) in zip(names, subjects):
        mask = Image.fromarray((labels == label).astype('uint8')*255)
        mask = mask.filter(ImageFilter.MaxFilter(3))
        pixels = rgba.copy()
        pixels[:, :, 3] = np.minimum(pixels[:, :, 3], np.array(mask))
        crop = Image.fromarray(pixels).crop(bbox)
        if name == 'cat_head':
            # The generated head includes an extra neck tab. The torso has
            # its own neck; crop that redundant tab below the chin.
            crop = crop.crop((0,0,crop.width,330))
        path = HERE / 'parts' / f'{name}.png'
        path.parent.mkdir(exist_ok=True)
        crop.save(path, optimize=True)
        result[name] = dict(source=filename, box=bbox, size=list(crop.size))
    return result


SHEETS = {
    'parts_environment.png': ['deer_head', 'deer_front_near', 'deer_front_far',
        'deer_body', 'deer_rear_far', 'deer_rear_near', 'deer_tail',
        'deer_near_ear', 'deer_far_antler', 'deer_near_antler', 'deer_far_ear'],
    'parts_gratitude.png': ['sheep_head', 'sheep_body', 'sheep_front_near',
        'sheep_front_far', 'sheep_rear_near', 'sheep_rear_far',
        'sheep_far_ear', 'sheep_near_ear', 'sheep_far_horn', 'sheep_near_horn'],
    'parts_courage.png': ['lion_mane', 'lion_front_near', 'lion_body',
        'lion_head', 'lion_rear_near', 'lion_front_far', 'lion_rear_far',
        'lion_tail', 'lion_flame', 'lion_far_ear', 'lion_near_ear'],
    'parts_honesty.png': ['turtle_shell', 'turtle_head', 'turtle_crystal',
        'turtle_body', 'turtle_front_near', 'turtle_rear_near',
        'turtle_front_far', 'turtle_rear_far', 'turtle_tail'],
    'parts_kindness.png': ['jelly_cap', 'jelly_far_left', 'jelly_inner_left',
        'jelly_inner_right', 'jelly_centre', 'jelly_far_right', 'jelly_reference'],
    'parts_cooperation.png': ['whale_body', 'whale_near_fin', 'whale_far_fin',
        'whale_tail_stem', 'whale_flukes', 'whale_reference'],
    'parts_cat_idle.png': ['cat_head', 'cat_seated_body', 'cat_left_ear',
        'cat_seated_right_leg', 'cat_seated_left_leg', 'cat_right_ear',
        'cat_tail', 'cat_near_hind_paw', 'cat_far_hind_paw'],
    'parts_cat_walk.png': ['cat_walk_reference', 'cat_walk_front_near',
        'cat_walk_body', 'cat_walk_rear_near', 'cat_walk_front_far',
        'cat_walk_rear_far'],
}


if __name__ == '__main__':
    manifest = {}
    for filename, names in SHEETS.items():
        if (HERE / 'source' / filename).exists():
            manifest.update(prepare(filename, names))
    (HERE / 'parts_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'Prepared {len(manifest)} independent parts')
