"""Cut parts from one complete master, retaining native scale and position.

Only cropping/alpha masks are used, as authorized by the user. No generated
anatomical part is repositioned or stretched to fit a different character.
"""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np
from registered_cuts import CUTS,WALK_CUTS

HERE=Path(__file__).resolve().parent
OUT=HERE/'registered'


def mask(points):
    im=Image.new('1',(500,500))
    ImageDraw.Draw(im).polygon(points,fill=1)
    return np.array(im,dtype=bool)


def prepare(kind,pose,source,rows):
    master=Image.open(HERE/source).convert('RGBA')
    rgba=np.array(master)
    # The generated masters use alpha=254 for most solid interior paint.
    # Treating that as an antialiased edge would remove every hidden root
    # from the lower layer. Normalize only near-opaque paint; retain genuine
    # antialiasing around the outer silhouette.
    rgba[:,:,3]=np.where(rgba[:,:,3]>=250,255,rgba[:,:,3])
    master_path=f'masters/{kind}_{pose}.png'
    Image.fromarray(rgba).save(HERE/master_path)
    masks={name:mask(full) for name,full,_,_,_ in rows}
    distal={name:mask(cut)&masks[name] for name,_,cut,_,_ in rows}
    core=np.ones((500,500),dtype=bool)
    for cut in distal.values():core &= ~cut
    # The tail's own image keeps the fluke/flame root, but never duplicates
    # the child's distal silhouette when the child rotates independently.
    links={'Tail flukes':'Tail stem','Tail flame':'Tail'}
    for child,parent in links.items():
        if child in masks and parent in masks:
            masks[parent] &= ~distal[child]
    core_name='Seated torso' if pose=='seated' else 'Standing torso' if pose=='standing' else 'Torso'
    ordered=[(core_name,core)]+[(r[0],masks[r[0]]) for r in rows]
    # Each semitransparent silhouette pixel belongs to exactly one layer.
    # Opaque interior paint can overlap without changing the master at rest.
    seen=np.zeros((500,500),dtype=bool)
    for _,m in ordered:
        partial=(rgba[:,:,3]>0)&(rgba[:,:,3]<255)
        m[partial&seen]=False
        seen |= m
    parts=[]
    composed=Image.new('RGBA',(500,500))
    saved=[]
    for name,m in ordered:
        weights=m.astype('float64')
        children=list(distal) if name==core_name else [c for c,p in links.items() if p==name and c in distal]
        if children:
            blurred=np.zeros((500,500),dtype='float64')
            supported=np.zeros((500,500),dtype=bool)
            for child in children:
                im=Image.fromarray(distal[child].astype('uint8')*255).filter(ImageFilter.GaussianBlur(3))
                blurred=np.maximum(blurred,np.array(im)/255)
                supported |= masks[child]
            blend=np.clip(1-blurred,0,1)
            blend[blend<.04]=0;blend[blend>.96]=1
            # Underlying opaque paint is identical at rest. Feather only the
            # hidden interior seam; never soften the character's silhouette.
            where=supported&(rgba[:,:,3]==255)
            weights[where]=blend[where]
        pixels=rgba.copy();pixels[:,:,3]=np.rint(weights*rgba[:,:,3]).astype('uint8')
        layer=Image.fromarray(pixels)
        box=layer.getbbox()
        if box is None:raise ValueError(f'{kind}/{pose}/{name}: empty part')
        asset=f'{kind}_{pose}_{name.lower().replace(" ","_")}'
        crop=layer.crop(box);crop.save(OUT/f'{asset}.png',optimize=True)
        row=next((r for r in rows if r[0]==name),None)
        parts.append(dict(name=name,asset=asset,rect=list(box),
            pivot=list(row[3] if row else (250,400)),
            accent=list(row[4]) if row and row[4] else None,
            leg=name.startswith('Leg '),source=source,pose=pose))
        saved.append(layer)
    # Rive's first sibling draws on top, like a layers panel.
    for layer in reversed(saved):composed.alpha_composite(layer)
    check=np.array(composed)
    visible=rgba[:,:,3]>0
    assert np.array_equal(check[visible],rgba[visible]),f'{kind}/{pose}: master changed at rest'
    assert np.array_equal(check[:,:,3],rgba[:,:,3]),f'{kind}/{pose}: silhouette changed at rest'
    composed.save(OUT/f'{kind}_{pose}_assembled.png')
    return dict(kind=kind,pose=pose,master=master_path,source=source,
                restMatchesMaster=True,parts=parts)


def main():
    OUT.mkdir(exist_ok=True)
    boards=[]
    for kind,rows in CUTS.items():
        pose='seated' if kind=='self_care' else 'default'
        boards.append(prepare(kind,pose,f'textures/stage1_{kind}.png',rows))
    boards.append(prepare('self_care','standing','masters/cat_standing.png',WALK_CUTS))
    (HERE/'registered_manifest.json').write_text(json.dumps(boards,indent=2)+'\n')
    print('All 7 assemblies match their complete masters pixel-for-pixel at rest')


if __name__=='__main__':main()
