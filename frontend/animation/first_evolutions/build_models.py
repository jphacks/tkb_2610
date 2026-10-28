"""Compile rigid cutout puppets: separate PNGs, no mesh or skin deformation."""
import copy
import json
import math
from pathlib import Path
import xml.etree.ElementTree as X
from face_geometry import FaceRig
from character_specs import SPECS
from part_layouts import LAYOUTS, LEGS
from rig_writer import ROOT, n, key
from registered_rig import RegisteredRig

HERE = Path(__file__).resolve().parent
PARTS = json.loads((HERE/'parts_manifest.json').read_text())


class CutoutRig(FaceRig):
    def __init__(self,spec,index):
        spec=dict(spec)
        if spec['kind']=='self_care':
            spec['mouth']=(187,296,'cat')
        if spec['kind']=='gratitude':
            spec['eyes']=[(135,267,16,27),(221,280,18,28)]
            spec['mouth']=(168,305,'sheep')
        tempo=[150,96,108,108,180,192,108][index]
        super().__init__('stage1_'+spec['kind'],index,tempo,spec.get('floating',False))
        self.spec=spec
        self.parts=[]
        self.nodes={'Artwork':self.canvas}
        self.pivots={'Artwork':(0,0)}
        head=self.joint('Head',spec['head'],'Artwork')
        self.expressions(head)
        if spec['kind']=='self_care':
            self.joint('Seated pose',(0,0),'Artwork')
            self.joint('Standing pose',(0,0),'Artwork',opacity=0)
        for row in LAYOUTS[spec['kind']]:
            name,asset,rect,pivot,parent,*accent=row
            self.piece(name,asset,rect,pivot,parent)
            if accent:
                self.accents.append((name,*accent))
        if spec['kind'] in LEGS:
            prefix,positions=LEGS[spec['kind']]
            parent='Standing pose' if spec['kind']=='self_care' else 'Artwork'
            for i,(suffix,(rect,pivot)) in enumerate(zip(
                    ['front_near','front_far','rear_near','rear_far'],positions)):
                name='Leg '+suffix
                self.piece(name,prefix+'_'+suffix,rect,pivot,parent)
                self.legs.append((name,[0,math.pi,math.pi,0][i]))
        if spec['kind']=='honesty':
            leg=self.nodes['Leg front_near']
            self.canvas.remove(leg)
            self.canvas.insert(list(self.canvas).index(self.nodes['Shell']),leg)
        # A child flame/fluke covers the overlap end of the tail stem.
        for parent in ('Tail','Tail stem'):
            if parent in self.nodes:
                node=self.nodes[parent]
                images=node.findall('Image')
                for image in images:
                    node.remove(image)
                    node.append(image)

    def joint(self,name,pivot,parent,**attrs):
        px,py=self.pivots[parent]
        x,y=pivot
        node=self.group(self.nodes[parent],name,x-px,y-py,**attrs)
        self.nodes[name]=node
        self.pivots[name]=pivot
        return node

    def piece(self,name,asset,rect,pivot,parent):
        node=self.joint(name,pivot,parent)
        x0,y0,x1,y1=rect
        sw,sh=PARTS[asset]['size']
        # Register each anatomical piece against the approved rest silhouette.
        # These fixed drawing dimensions never change during animation.
        w,h=x1-x0,y1-y0
        x,y=x0,y0
        asset_id=key()
        n(ROOT,'ImageAsset',name+' asset',id=asset_id,file=f'parts/{asset}.png')
        self.add(node,'Image',name+' image',assetId=asset_id,originX=0,originY=0,
                 x=x-pivot[0],y=y-pivot[1],scaleX=w/sw,scaleY=h/sh)
        self.parts.append(dict(name=name,asset=asset,rect=[x,y,x+w,y+h],
                               pivot=list(pivot),parent=parent))

    def animations(self):
        super().animations()
        for animation in self.art.findall('LinearAnimation'):
            name=animation.get('name')
            duration=int(animation.get('duration'))
            def track(name,prop,values):
                for obj in animation.findall('KeyedObject'):
                    if obj.get('objectId')==self.ids[name]:
                        for old in list(obj.findall('KeyedProperty')):
                            if old.get('propertyKey')==str(prop):
                                obj.remove(old)
                obj=n(animation,'KeyedObject',objectId=self.ids[name])
                kp=n(obj,'KeyedProperty',propertyKey=prop)
                for frame,value in values:
                    kf=n(kp,'KeyFrameDouble',frame=round(frame),value=value,
                         interpolationType='cubic')
                    n(kf,'CubicEaseInterpolator')
            walking=name=='Walk'
            # Individual rigid feet alternate a planted stroke and a small
            # lifted return. No scale keys or skin weights touch a leg image.
            for leg,phase in self.legs:
                x,y,_=self.groups[leg]
                stride=3 if self.spec['kind']=='honesty' else 4
                lift=2 if self.spec['kind']=='honesty' else 3
                frames=[(i*duration/16,i*math.pi/4+phase) for i in range(17)]
                track(leg,13,[(f,x+stride*math.cos(a)) for f,a in frames] if walking else [(0,x)])
                track(leg,14,[(f,y-lift*max(0,-math.sin(a))) for f,a in frames] if walking else [(0,y)])
                track(leg,15,[(f,-.045*math.cos(a)) for f,a in frames] if walking else [(0,0)])
            if self.spec['kind']=='self_care':
                track('Seated pose',18,[(0,0 if walking else 1)])
                track('Standing pose',18,[(0,1 if walking else 0)])
                hx,hy,_=self.groups['Head']
                track('Head',13,[(0,hx-20 if walking else hx)])
                track('Head',14,[(0,hy-8 if walking else hy)])
                tx,ty,_=self.groups['Tail']
                track('Tail',13,[(0,tx+48 if walking else tx)])
                track('Tail',14,[(0,ty-67 if walking else ty)])
            if name in ('Tap','Happy'):
                tilt=[.025,-.06,-.05,.045,.035,-.035,.06][self.index]
                track('Head',15,[(0,0),(8,-tilt*.25),(24,tilt),(48,tilt*.7),(72,0),(120,0)])
                gesture={'environment':'Leg front_near','courage':'Leg front_near',
                         'self_care':'Paw right'}.get(self.spec['kind'])
                if gesture:
                    _,y,_=self.groups[gesture]
                    track(gesture,14,[(0,y),(10,y+1),(24,y-9),(45,y-7),(65,y),(120,y)])
                    track(gesture,15,[(0,0),(24,-.10),(43,.04),(62,0),(120,0)])
                if self.spec['kind']=='cooperation':
                    track('Fin near',15,[(0,0),(12,.10),(27,-.25),(43,.12),(60,-.18),(80,0),(120,0)])
            # Blink about each eye's own centre. Painted head textures contain
            # neither eyes nor mouth; no white eye highlights are added here.
            for obj in list(animation.findall('KeyedObject')):
                if obj.get('objectId')==self.ids['Eyes']:
                    for prop in list(obj.findall('KeyedProperty')):
                        if prop.get('propertyKey')=='17':
                            for i in range(len(self.spec['eyes'])):
                                target=n(animation,'KeyedObject',objectId=self.ids[f'Eye {i}'])
                                target.append(copy.deepcopy(prop))
                            obj.remove(prop)
                if obj.get('objectId')==self.ids['Face']:
                    for prop in obj.findall('KeyedProperty'):
                        if prop.get('propertyKey')=='13':
                            for frame in prop.findall('KeyFrameDouble'):
                                frame.set('value',str(self.groups['Face'][0]))


def main():
    rigs=[]
    for i,spec in enumerate(SPECS):
        rig=CutoutRig(spec,i) if spec['kind']=='kindness' else RegisteredRig(spec,i)
        rig.animations()
        rigs.append(rig)
    vm=n(ROOT,'ViewModel','CompanionState',id='0:40',defaultInstanceId='0:41')
    n(vm,'ViewModelPropertyNumber','mode',id='0:45')
    n(vm,'ViewModelPropertyNumber','lookX',id='0:46')
    instance=n(vm,'ViewModelInstance','Default',id='0:41',exports='true')
    n(instance,'ViewModelInstanceNumber',propertyValue=0,viewModelPropertyId='0:45')
    n(instance,'ViewModelInstanceNumber',propertyValue=0,viewModelPropertyId='0:46')
    X.indent(ROOT,space='  ')
    (HERE/'scene.rml').write_text(X.tostring(ROOT,encoding='unicode')+'\n')
    (HERE/'rig_manifest.json').write_text(json.dumps({
        'architecture':'rigid-cutout','meshCount':0,
        'artboards':[dict(kind=r.kind,parts=r.parts,
            appendages=[name for name,_,_ in r.accents],legs=[name for name,_ in r.legs],
            contacts=getattr(r,'contacts',None),masters=getattr(r,'masters',[]),
            walkFrames=r.walk_duration) for r in rigs],
    },indent=2)+'\n')


if __name__=='__main__':
    main()
