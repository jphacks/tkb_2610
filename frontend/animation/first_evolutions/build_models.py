"""Build seven image-mesh puppets from the approved first-evolution designs.

The textures preserve the approved artwork. Independent root/child bones bend
the head, limbs and characteristic appendages; native vectors supply expressions.
No scripts, hosted assets, account credentials or animation-time image generation.
"""
import base64
import copy
import json
import math
from pathlib import Path
import xml.etree.ElementTree as X
from rig_writer import Rig, ROOT, n, key

HERE = Path(__file__).resolve().parent
INK = 'FF624C52'
GRID = 32


def smooth(a, b, value):
    v = max(0, min(1, (value-a)/(b-a)))
    return v*v*(3-2*v)


def ellipse_mask(cx, cy, rx, ry, fade=.45):
    def sample(x, y):
        d = math.hypot((x-cx)/rx, (y-cy)/ry)
        return 1-smooth(1-fade, 1, d)
    return sample


def capsule_mask(start, end, width, start_fade=.2):
    ax, ay = start
    bx, by = end
    dx, dy = bx-ax, by-ay
    length = dx*dx+dy*dy
    def sample(x, y):
        t = max(0, min(1, ((x-ax)*dx+(y-ay)*dy)/length))
        distance = math.hypot(x-ax-t*dx, y-ay-t*dy)
        return (1-smooth(width*.45, width, distance))*smooth(0, start_fade, t)
    return sample


def head_mask(kind):
    def sample(x, y):
        if kind == 'kindness':
            return 1-smooth(310, 361, y)
        if kind == 'environment':
            return (1-smooth(283,342,y))*(1-smooth(230,280,y)*smooth(273,343,x))
        if kind == 'gratitude':
            return (1-smooth(323, 378, y))*(1-smooth(285, 368, x))
        if kind == 'courage':
            return (1-smooth(362, 429, y))*(1-smooth(297, 374, x))
        if kind == 'cooperation':
            return 1-smooth(245, 319, x)
        if kind == 'honesty':
            return (1-smooth(181, 237, x))*(1-smooth(389, 432, y))
        return (1-smooth(314,370,y))*(1-smooth(190,250,y)*smooth(326,359,x))
    return sample


# Eye and mouth positions were registered against the approved character sheets.
# Face centres are intentionally not forced into a symmetric generic template.
SPECS = [
    dict(kind='kindness', tempo=120, floating=True, head=(245,310),
         eyes=[(166,270,18,28),(266,284,19,29)], mouth=(209,299,'plain'),
         accents=[
             ('Tentacle left',(170,318),(.10,0),('cap',(170,321),(67,427),30)),
             ('Tentacle middle left',(218,328),(.10,1.4),('cap',(218,329),(173,452),26)),
             ('Tentacle middle right',(264,326),(.09,2.8),('cap',(264,329),(300,450),26)),
             ('Tentacle right',(310,322),(.10,4.2),('cap',(310,324),(422,420),34)),
         ]),
    dict(kind='environment', tempo=72, head=(221,299),
         eyes=[(168,253,18,24)], mouth=(126,283,'plain'),
         accents=[('Leaf tail',(351,334),(.07,-1),('cap',(348,336),(392,273),37))],
         legs=[('Leg front',(217,382),(193,458),19,0),
               ('Leg near front',(252,390),(233,460),19,math.pi),
               ('Leg far back',(330,386),(300,456),19,math.pi),
               ('Leg back',(363,387),(365,461),20,0)]),
    dict(kind='gratitude', tempo=78, head=(204,329),
         eyes=[(135,282,16,27),(221,295,18,28)], mouth=(168,320,'sheep'),
         accents=[('Horn left',(109,186),(.025,1),('oval',107,180,48,48)),
                  ('Horn right',(322,217),(.025,-1),('oval',322,213,54,52))],
         legs=[('Leg front',(176,410),(163,455),20,0),
               ('Leg near front',(233,415),(221,461),21,math.pi),
               ('Leg far back',(310,417),(300,455),18,math.pi),
               ('Leg back',(365,416),(364,462),22,0)]),
    dict(kind='courage', tempo=90, head=(205,362),
         eyes=[(113,274,16,26),(202,282,19,27)], mouth=(144,313,'cat'),
         accents=[('Tail',(365,342),(.065,-1),('cap',(362,346),(429,246),36)),
                  ('Tail flame',(429,246),(.09,-1.6),('oval',428,229,45,73))],
         legs=[('Leg front',(139,408),(114,461),25,0),
               ('Leg near front',(204,410),(208,463),26,math.pi),
               ('Leg far back',(300,413),(281,460),22,math.pi),
               ('Leg back',(370,418),(387,462),28,0)]),
    dict(kind='cooperation', tempo=150, floating=True, head=(192,343),
         eyes=[(206,347,18,25)], mouth=(174,369,'plain'),
         accents=[('Fin',(238,388),(.10,.8),('cap',(238,390),(322,458),48)),
                  ('Tail',(382,326),(.08,-1.2),('oval',410,275,88,95)),
                  ('Rear fin',(100,444),(.06,2),('oval',98,448,57,29))]),
    dict(kind='honesty', tempo=156, head=(196,373),
         eyes=[(64,323,14,23),(159,329,18,25)], mouth=(102,350,'plain'),
         accents=[('Crystal',(255,205),(.012,1),('oval',261,191,45,69))],
         legs=[('Leg front',(240,408),(241,464),31,0),
               ('Leg far front',(104,412),(85,458),22,math.pi),
               ('Leg far back',(320,425),(313,463),25,0),
               ('Leg back',(394,414),(411,458),27,math.pi)]),
    dict(kind='self_care', tempo=96, head=(211,327),
         eyes=[(138,262,18,29),(241,273,21,30)], mouth=(179,303,'cat'),
         accents=[('Ear left',(128,166),(.028,1),('oval',124,127,50,79)),
                  ('Ear right',(291,165),(.028,-1),('oval',297,133,61,75)),
                  ('Tail',(325,432),(.045,-1),('cap',(330,427),(414,277),72))],
         legs=[('Paw left',(185,410),(185,467),27,0),
               ('Paw right',(235,411),(235,469),27,math.pi)]),
]


def varuints(values):
    raw = bytearray()
    for value in values:
        while value >= 128:
            raw.append((value & 127) | 128)
            value >>= 7
        raw.append(value)
    return base64.b64encode(raw).decode('ascii')


class MeshRig(Rig):
    def __init__(self, spec, index):
        super().__init__('stage1_'+spec['kind'], index, spec['tempo'], spec.get('floating',False))
        self.spec = spec
        self.bones = []
        self.validation_weights = []
        self.bone('Torso bone',(0,0),lambda x,y: 0)
        head = self.bone('Head',spec['head'],head_mask(spec['kind']))
        self.expressions(head)
        for name, pivot, (amplitude, phase), mask_spec in spec.get('accents',[]):
            if mask_spec[0] == 'oval':
                mask = ellipse_mask(*mask_spec[1:])
            else:
                mask = capsule_mask(*mask_spec[1:])
            if name.startswith('Tentacle'):
                # Keep the whole painted ribbon attached to its joint. A
                # narrow influence pins its outline while moving its centre.
                mask=capsule_mask(mask_spec[1],mask_spec[2],72)
            if spec['kind']=='self_care' and name=='Tail':
                wide_tail=mask
                mask=lambda x,y,fn=wide_tail: fn(x,y)*smooth(330,370,x)
            # Head accessories inherit the head pose; the other appendages have
            # their own pivots so the head never drags a tail along with it.
            parent = head if name.startswith(('Horn','Ear')) else None
            self.bone(name,pivot,mask,parent)
            self.accents.append((name,amplitude,phase))
        for name, start, end, width, phase in spec.get('legs',[]):
            self.bone(name,start,capsule_mask(start,end,width*2,.5))
            self.legs.append((name,phase))
        self.image_mesh()

    def bone(self, name, pivot, mask, parent=None):
        # Store world-space bind positions; child bone translations are local.
        x,y=pivot
        px,py=self.spec['head'] if parent is not None else (0,0)
        obj=self.add(parent if parent is not None else self.canvas,'RootBone',name,
                     x=x-px,y=y-py,length=0)
        self.groups[name]=(x-px,y-py,0)
        self.bones.append((name,pivot,mask))
        return obj

    def expressions(self, head):
        spec=self.spec
        cx=sum(e[0] for e in spec['eyes'])/len(spec['eyes'])
        cy=sum(e[1] for e in spec['eyes'])/len(spec['eyes'])
        hx,hy=spec['head']
        face=self.group(head,'Face',cx-hx,cy-hy)
        joy=self.group(face,'Joy face',opacity=0)
        sleep=self.group(face,'Sleep face',opacity=0)
        eyes=self.group(face,'Eyes')
        wander=self.group(eyes,'Wander gaze')
        def look(parent,name):
            group=self.group(parent,name)
            n(group,'DataBindContext',sourcePathIds='0:40-0:46',propertyKey=13)
            return group
        neutral_look=look(wander,'Look direction')
        joy_look=look(joy,'Joy gaze')
        sleep_look=look(sleep,'Sleep gaze')
        for i,(ex,ey,w,h) in enumerate(spec['eyes']):
            x,y=ex-cx,ey-cy
            self.ellipse(neutral_look,f'Eye {i}',x,y,w,h,INK)
            self.path(joy_look,f'Joy eye {i}',(x-w*.43,y+1),[
                ((x-w*.25,y-h*.38),(x+w*.25,y-h*.38),(x+w*.43,y+1)),
            ],stroke=INK,closed=False,width=3.4)
            self.path(sleep_look,f'Sleep eye {i}',(x-w*.43,y),[
                ((x-w*.18,y+4),(x+w*.18,y+4),(x+w*.43,y)),
            ],stroke=INK,closed=False,width=2.8)
        mx,my,mouth_style=spec['mouth']
        mx,my=mx-cx,my-cy
        self.path(joy,'Joy mouth',(mx-7,my-3),[
            ((mx-5,my+10),(mx+5,my+10),(mx+7,my-3)),
            ((mx+3,my-1),(mx-3,my-1),(mx-7,my-3)),
        ],INK)
        self.ellipse(sleep,'Sleep mouth',mx,my,4,3,INK)
        smile=self.group(face,'Smile')
        if mouth_style in ('cat','sheep'):
            if mouth_style=='sheep':
                self.path(smile,'Sheep nose',(mx-5,my-12),[
                    ((mx-5,my-17),(mx+5,my-17),(mx+5,my-12)),
                    ((mx+2,my-8),(mx-2,my-8),(mx-5,my-12)),
                ],'FFAD8073')
            self.path(smile,'Mouth stem',(mx,my-8),[
                ((mx,my-5),(mx,my-3),(mx,my-2)),
            ],stroke=INK,closed=False,width=2.3)
            self.path(smile,'Small W smile',(mx-8,my),[
                ((mx-4,my+4),(mx,my+1),(mx,my-3)),
                ((mx,my+1),(mx+4,my+4),(mx+8,my)),
            ],stroke=INK,closed=False,width=2.5)
        else:
            self.path(smile,'Smile curve',(mx-6,my-2),[
                ((mx-3,my+3),(mx+3,my+3),(mx+6,my-2)),
            ],stroke=INK,closed=False,width=2.8)

    def weights(self,x,y):
        head = self.bones[1][2](x,y)
        extra=[(i,fn(x,y)) for i,(_,_,fn) in enumerate(self.bones) if i>1]
        # A child head accessory already carries the head's full transform.
        extras=[(i,v) for i,v in extra if v>.001]
        strongest=max((v for _,v in extras),default=0)
        head *= (1-strongest)
        influences=[(0,max(0,1-head-strongest)),(1,head)]+extras
        influences=sorted([(i,v) for i,v in influences if v>.001],
                          key=lambda t:t[1],reverse=True)[:4]
        total=sum(v for _,v in influences)
        quant=[round(v/total*255) for _,v in influences]
        quant[0]+=255-sum(quant)
        assert sum(quant)==255 and all(0<=v<=255 for v in quant)
        indices=sum((i+1)<<(slot*8) for slot,(i,_) in enumerate(influences))
        values=sum(v<<(slot*8) for slot,v in enumerate(quant))
        return indices,values

    def image_mesh(self):
        asset_id=key()
        n(ROOT,'ImageAsset',self.kind+' texture',id=asset_id,
          file=f'textures/{self.kind}.png')
        image=self.add(self.canvas,'Image','Artwork texture',assetId=asset_id,
                       x=0,y=0,originX=0,originY=0)
        # Boundary vertices first, clockwise. Interior vertices follow, matching
        # the editor's contour convention while preserving a regular UV grid.
        perimeter=[(x,0) for x in range(GRID+1)]
        perimeter += [(GRID,y) for y in range(1,GRID+1)]
        perimeter += [(x,GRID) for x in range(GRID-1,-1,-1)]
        perimeter += [(0,y) for y in range(GRID-1,0,-1)]
        points=perimeter+[(x,y) for y in range(1,GRID) for x in range(1,GRID)]
        lookup={p:i for i,p in enumerate(points)}
        triangles=[]
        for y in range(GRID):
            for x in range(GRID):
                a,b,c,d=(lookup[p] for p in [(x,y),(x+1,y),(x+1,y+1),(x,y+1)])
                triangles.extend([a,b,c,a,c,d])
        assert max(triangles)<len(points)
        mesh=self.add(image,'Mesh','Puppet mesh',triangleIndexBytes=varuints(triangles))
        for i,(gx,gy) in enumerate(points):
            x,y=gx*500/GRID,gy*500/GRID
            vertex=n(mesh,'ContourMeshVertex' if i<len(perimeter) else 'MeshVertex',
                     x=x,y=y,u=gx/GRID,v=gy/GRID)
            indices,values=self.weights(x,y)
            n(vertex,'Weight',indices=indices,values=values)
            self.validation_weights.append([indices,values])
        skin=self.add(mesh,'Skin','Puppet skin',tx=0,ty=0)
        for name,(x,y),_ in self.bones:
            n(skin,'Tendon',name+' bind',boneId=self.ids[name],tx=x,ty=y)

    def animations(self):
        super().animations()
        # RootBone's translation properties differ from a Node's. Blink each
        # eye around its own centre, preserving the tilted three-quarter face.
        for animation in self.art.findall('LinearAnimation'):
            def replace_track(name,prop,values):
                for obj in list(animation.findall('KeyedObject')):
                    if obj.get('objectId')==self.ids[name]:
                        for old in list(obj.findall('KeyedProperty')):
                            if (old.get('propertyKey')==str(prop) or
                                    (name=='Head' and prop==91 and old.get('propertyKey')=='14')):
                                obj.remove(old)
                obj=n(animation,'KeyedObject',objectId=self.ids[name])
                keyed=n(obj,'KeyedProperty',propertyKey=prop)
                for frame,value in values:
                    kf=n(keyed,'KeyFrameDouble',frame=round(frame),value=value,
                         interpolationType='cubic')
                    n(kf,'CubicEaseInterpolator')

            name=animation.get('name')
            if self.spec['kind']=='kindness':
                duration=int(animation.get('duration'))
                amplitude={'Idle':.030,'Walk':.075,'Tap':.090,'Happy':.090,
                           'Low energy':.012,'Sleep':.004}[name]
                cycles=2 if name in ('Walk','Tap','Happy') else 3 if name=='Idle' else 1
                for tentacle,_,phase in self.accents:
                    replace_track(tentacle,15,[(round(i*duration/(cycles*4)),
                        amplitude*math.sin(i*math.pi/2+phase)) for i in range(cycles*4+1)])
            if name=='Walk':
                # A foot moves front-to-back on the ground, then lifts on the
                # return stroke. Opposite legs use opposite phases. Translation
                # is keyed on the root bone as well as rotation, so walking is
                # a gait rather than a whole-picture wobble.
                duration=self.spec['tempo']
                stride=6 if self.spec['kind']!='honesty' else 3.5
                lift=5 if self.spec['kind']!='honesty' else 2.5
                for leg,phase in self.legs:
                    x,y,_=self.groups[leg]
                    frames=[(round(i*duration/16),i*math.pi/4+phase) for i in range(17)]
                    replace_track(leg,90,[(f,x+stride*math.cos(a)) for f,a in frames])
                    replace_track(leg,91,[(f,y-lift*max(0,-math.sin(a))) for f,a in frames])
                    replace_track(leg,15,[(f,-.06*math.cos(a)) for f,a in frames])
            else:
                for leg,_ in self.legs:
                    x,y,_=self.groups[leg]
                    replace_track(leg,90,[(0,x)])
                    replace_track(leg,91,[(0,y)])

            # Different greeting poses, with anticipation and a soft return.
            # These use the skinned bones, keeping the face attached to the head.
            if name in ('Tap','Happy'):
                kind=self.spec['kind']
                tilt={'kindness':.025,'environment':-.075,'gratitude':-.065,
                      'courage':.055,'cooperation':.035,'honesty':-.045,
                      'self_care':.08}[kind]
                replace_track('Head',15,[(0,0),(8,-tilt*.25),(24,tilt),
                              (48,tilt*.7),(72,0),(120,0)])
                gesture={'environment':'Leg near front','courage':'Leg front',
                         'self_care':'Paw right'}.get(kind)
                if gesture:
                    x,y,_=self.groups[gesture]
                    height=9 if kind=='self_care' else 13
                    angle=.07 if kind=='self_care' else .13
                    replace_track(gesture,91,[(0,y),(8,y+1),(24,y-height),
                                  (45,y-height*.85),(65,y),(120,y)])
                    replace_track(gesture,15,[(0,0),(24,-angle),(43,angle*.46),
                                  (62,0),(120,0)])
                if kind=='gratitude':
                    y=self.groups['Head'][1]
                    replace_track('Head',91,[(0,y),(20,y+7),(40,y+3),(64,y),(120,y)])
                if kind=='honesty':
                    x,y,_=self.groups['Head']
                    replace_track('Head',90,[(0,x),(22,x-6),(45,x-3),(70,x),(120,x)])
                if kind=='cooperation':
                    replace_track('Fin',15,[(0,0),(12,.08),(27,-.18),
                                  (43,.10),(60,-.12),(80,0),(120,0)])
            elif self.spec['kind']=='honesty':
                replace_track('Head',90,[(0,self.groups['Head'][0])])
            gaze_object=n(animation,'KeyedObject',objectId=self.ids['Wander gaze'])
            gaze_property=n(gaze_object,'KeyedProperty',propertyKey=13)
            for frame,value in ([(0,0),(160,0),(190,3),(245,3),(275,-2),
                                  (325,-2),(355,0),(480,0)]
                                if animation.get('name')=='Idle' else [(0,0)]):
                kf=n(gaze_property,'KeyFrameDouble',frame=frame,value=value,
                     interpolationType='cubic')
                n(kf,'CubicEaseInterpolator')
            for obj in list(animation.findall('KeyedObject')):
                if obj.get('objectId')==self.ids['Head']:
                    for prop in obj.findall('KeyedProperty'):
                        if prop.get('propertyKey')=='14':
                            prop.set('propertyKey','91')
                if obj.get('objectId')==self.ids['Eyes']:
                    for prop in list(obj.findall('KeyedProperty')):
                        if prop.get('propertyKey')=='17':
                            for i in range(len(self.spec['eyes'])):
                                target=n(animation,'KeyedObject',objectId=self.ids[f'Eye {i}'])
                                target.append(copy.deepcopy(prop))
                            obj.remove(prop)
            # Mouths remain registered with noses painted in the texture. Only
            # the eyes look around; the mouth never slides off a retained nose.
            for obj in animation.findall('KeyedObject'):
                if obj.get('objectId')==self.ids['Face']:
                    for prop in obj.findall('KeyedProperty'):
                        if prop.get('propertyKey')=='13':
                            frames=prop.findall('KeyFrameDouble')
                            for frame in frames:
                                frame.set('value',str(self.groups['Face'][0]))


def main():
    rigs=[]
    for i,spec in enumerate(SPECS):
        rig=MeshRig(spec,i)
        rig.animations()
        rigs.append(rig)
    vm=n(ROOT,'ViewModel','CompanionState',id='0:40',defaultInstanceId='0:41')
    n(vm,'ViewModelPropertyNumber','mode',id='0:45')
    n(vm,'ViewModelPropertyNumber','lookX',id='0:46')
    instance=n(vm,'ViewModelInstance','Default',id='0:41',exports='true')
    n(instance,'ViewModelInstanceNumber',propertyValue=0,viewModelPropertyId='0:45')
    n(instance,'ViewModelInstanceNumber',propertyValue=0,viewModelPropertyId='0:46')
    X.indent(ROOT,space='  ')
    (HERE/'scene.rml').write_text(X.tostring(ROOT,encoding='unicode')+'\n',encoding='utf-8')
    (HERE/'rig_manifest.json').write_text(json.dumps({
        'meshGrid':GRID, 'vertexCount':(GRID+1)**2,
        'triangleCount':GRID*GRID*2,
        'artboards':[dict(kind=r.kind,
            bones=[dict(name=name,bind=list(pivot)) for name,pivot,_ in r.bones],
            weights=r.validation_weights,
            walkFrames=r.spec['tempo']) for r in rigs],
    },indent=2)+'\n')


if __name__=='__main__':
    main()
