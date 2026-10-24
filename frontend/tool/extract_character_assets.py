"""User-authorized crop/transparent extraction. Requires Pillow + numpy.
Run with --source <provided character directory>. Never changes source files.
"""
from pathlib import Path
import argparse, json
import numpy as np
from PIL import Image, ImageDraw
from collections import deque

CATEGORIES = ['kindness','environment','gratitude','courage','cooperation','honesty','self_care']
SHEETS = {
 'kindness': ('codex-clipboard-7c9c45d4-cdbd-4a79-9433-ce2276306de1.png', [(0,130,438,525),(415,82,746,525),(744,130,1156,528),(1160,80,1536,525),(0,542,483,1005),(515,574,1029,1005),(1125,530,1536,1018)]),
 'environment': ('codex-clipboard-26d1f733-907d-4f58-8bd4-079d5850e782.png', [(0,74,388,549),(306,120,775,557),(777,90,1130,568),(1140,147,1536,557),(0,601,592,985),(591,600,1098,993),(1096,532,1536,1010)]),
 'gratitude': ('codex-clipboard-b7b5cd58-1551-499f-8af5-e8f05670c3bf.png', [(45,127,340,556),(306,224,774,558),(737,126,1186,555),(1183,102,1536,572),(0,631,624,987),(617,600,1114,997),(1113,595,1536,1018)]),
 'courage': ('codex-clipboard-5d84d4c8-351f-44b4-98ee-d0d2e60cfbe0.png', [(8,92,353,545),(343,184,754,545),(771,136,1237,546),(1230,85,1536,550),(0,618,574,991),(529,652,1113,992),(1143,550,1536,1018)]),
 'cooperation': ('codex-clipboard-639537c4-e5c4-45b2-ba78-12d2a7121aab.png', [(0,80,377,370),(390,83,762,370),(778,67,1138,368),(1162,65,1536,370),(3,577,579,811),(612,601,1077,812),(1116,569,1536,816)]),
 'honesty': ('exec-25482763-b670-467f-a34a-7b517b2b98f9.png', [(0,132,401,558),(391,197,782,558),(777,125,1194,551),(1206,78,1536,552),(0,612,610,978),(564,653,1125,987),(1157,548,1536,1016)]),
 'self_care': ('codex-clipboard-596e0d90-62da-4ec5-9c78-6f8b78026c8c.png', [(17,120,343,538),(374,137,768,538),(774,97,1169,540),(1182,117,1536,543),(17,580,580,983),(601,630,1059,973),(1076,571,1536,997)]),
}
FIRST = ('exec-5852de66-0be5-4966-9f00-2957be1e76b4.png', [(16,196,367,488),(387,157,741,487),(770,106,1097,488),(1127,141,1536,488),(8,543,387,919),(386,606,817,919),(812,576,1166,919),(1171,558,1536,919)])

def cut(source, rect, image_id):
    rgb = np.asarray(source.crop(rect).convert('RGB'))
    # Flood only pale near-neutral background connected to the crop edges.
    # Enclosed white/cream markings remain opaque.
    lo = rgb.min(axis=2).astype(float); hi = rgb.max(axis=2).astype(float)
    pale = (lo > 205) & ((hi - lo) < 32)
    flood=Image.fromarray(np.pad(pale.astype(np.uint8)*255,1,constant_values=255)).copy()
    ImageDraw.floodfill(flood,(0,0),128)
    bg=np.asarray(flood)[1:-1,1:-1]==128
    mask=~bg
    h,w=mask.shape;seen=np.zeros(mask.shape,bool)
    # Separate connected pieces. The main body is the largest component;
    # preserve local floating decorations, discard captions and edge fragments.
    components=[]
    for yy,xx in zip(*np.where(mask)):
        if seen[yy,xx]:continue
        q=deque([(yy,xx)]);seen[yy,xx]=True;component=[]
        while q:
            y,x=q.popleft();component.append((y,x))
            for ny,nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
                if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;q.append((ny,nx))
        components.append(component)
    components.sort(key=len,reverse=True)
    cleaned=np.zeros(mask.shape,bool)
    caption_bottom=170 if rect[1]<540 else 645
    for i,component in enumerate(components):
        ys=np.array([v[0] for v in component]);xs=np.array([v[1] for v in component])
        edge=xs.min()==0 or ys.min()==0 or xs.max()==w-1 or ys.max()==h-1
        full_y=ys.min()+rect[1]
        # The starter's pearl is deliberately detached. Floating sun crown is also retained.
        pearl=image_id=='base_01' and i==1
        crown=image_id=='stage2_kindness_kindness' and 190<xs.mean()+rect[0]<230 and 125<ys.mean()+rect[1]<180
        if i==0 or pearl or crown or (len(component)>=35 and not edge and full_y>caption_bottom):
            cleaned[ys,xs]=True
    mask=cleaned
    rgba=np.dstack([rgb,mask.astype(np.uint8)*255])
    im=Image.fromarray(rgba,'RGBA'); bbox=im.getbbox()
    if not bbox: raise ValueError('Empty crop')
    im=im.crop(bbox)
    im.thumbnail((464,464),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(512,512))
    canvas.alpha_composite(im,((512-im.width)//2,488-im.height))
    return canvas

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);args=ap.parse_args()
    root=Path(__file__).resolve().parents[1]; out=root/'assets/characters/evolution';out.mkdir(parents=True,exist_ok=True)
    manifest=[]
    def emit(image_id,file,rect):
        img=cut(Image.open(args.source/file),rect,image_id);img.save(out/(image_id+'.png'),optimize=True)
        manifest.append({'imageId':image_id,'source':file,'crop':rect})
    file,rects=FIRST
    emit('base_01',file,rects[0])
    for c,r in zip(CATEGORIES,rects[1:]):emit('stage1_'+c,file,r)
    for first,(file,rects) in SHEETS.items():
        for second,r in zip(CATEGORIES,rects):emit('stage2_'+first+'_'+second,file,r)
    # The moon-deer is the single approved generated facial correction.
    override=root/'assets/characters/overrides/stage2_environment_self_care.png'
    if override.exists():
        im=Image.open(override).convert('RGBA');im=im.crop(im.getbbox());im.thumbnail((464,464),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512));canvas.alpha_composite(im,((512-im.width)//2,488-im.height));canvas.save(out/'stage2_environment_self_care.png')
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    # Review-only board, never referenced by the app.
    board=Image.new('RGB',(8*180,8*205),'#E8F5FD');d=ImageDraw.Draw(board)
    ids=['base_01']+['stage1_'+c for c in CATEGORIES]
    for first in CATEGORIES: ids += ['stage2_'+first+'_'+c for c in CATEGORIES]+[None]
    for i,id in enumerate(ids):
        if id is None:continue
        im=Image.open(out/(id+'.png'));im.thumbnail((170,170))
        x=i%8*180;y=i//8*205;board.paste(im,(x,y),im);d.text((x+2,y+173),id.replace('stage2_','').replace('stage1_','1_'),fill='#25324A')
    qa=root/'build/qa';qa.mkdir(parents=True,exist_ok=True);board.save(qa/'evolution-catalog.png')
if __name__=='__main__':main()
