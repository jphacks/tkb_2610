"""Rigid appendages cut at native coordinates from a complete character."""
import copy,json,math
from pathlib import Path
from face_geometry import FaceRig
from rig_writer import n,key,ROOT

HERE=Path(__file__).resolve().parent
ASSEMBLIES=json.loads((HERE/'registered_manifest.json').read_text())


class RegisteredRig(FaceRig):
    def __init__(self,spec,index):
        super().__init__('stage1_'+spec['kind'],index,
            [150,108,120,120,180,192,120][index],spec.get('floating',False))
        self.spec=spec
        self.parts=[];self.contacts=[];self.masters=[]
        self.nodes={'Artwork':self.canvas};self.pivots={'Artwork':(0,0)}
        head=self.joint('Head',spec['head'],'Artwork')
        self.expressions(head)
        for assembly in ASSEMBLIES:
            if assembly['kind']!=spec['kind']:continue
            self.masters.append(assembly['master'])
            pose=assembly['pose']
            parent='Head'
            if pose in ('seated','standing'):
                parent='Seated pose' if pose=='seated' else 'Standing pose'
                self.joint(parent,(0,0),'Head',opacity=0 if pose=='standing' else 1)
            core=assembly['parts'][0]['name']
            # The complete painted body covers appendage roots. A child flame
            # or fluke draws above its tail stem, preserving original overlaps.
            rows=assembly['parts']
            for part in rows:
                name=part['name'];self.piece(part,parent)
                if part['accent']:
                    self.accents.append((name,*part['accent']))
                if part['leg']:
                    i=['front_near','front_far','rear_near','rear_far'].index(name[4:])
                    self.legs.append((name,[0,math.pi,math.pi,0][i]))
                if name!=core:
                    targets=[core]
                    if name=='Tail flukes':targets=['Tail stem']
                    if name=='Tail flame':targets=['Tail']
                    modes=[1] if pose=='standing' else [0,2,3,4,5] if pose=='seated' else list(range(6))
                    self.contacts.append(dict(child=name,parents=targets,modes=modes))

    def joint(self,name,pivot,parent,**attrs):
        x,y=pivot;px,py=self.pivots[parent]
        node=self.group(self.nodes[parent],name,x-px,y-py,**attrs)
        self.nodes[name]=node;self.pivots[name]=pivot
        return node

    def piece(self,part,parent):
        name=part['name'];rect=part['rect'];pivot=part['pivot']
        # A separately articulated flame/fluke inherits its stem's movement.
        parent={'Tail flukes':'Tail stem','Tail flame':'Tail'}.get(name,parent)
        node=self.joint(name,pivot,parent)
        asset_id=key()
        n(ROOT,'ImageAsset',name+' asset',id=asset_id,file='registered/'+part['asset']+'.png')
        self.add(node,'Image',name+' image',assetId=asset_id,originX=0,originY=0,
                 x=rect[0]-pivot[0],y=rect[1]-pivot[1],scaleX=1,scaleY=1)
        self.parts.append(dict(part,folder='registered',parent=parent))

    def animations(self):
        super().animations()
        for animation in self.art.findall('LinearAnimation'):
            mode=['Idle','Walk','Tap','Happy','Low energy','Sleep'].index(animation.get('name'))
            duration=int(animation.get('duration'))
            def track(name,prop,values):
                for obj in animation.findall('KeyedObject'):
                    if obj.get('objectId')==self.ids[name]:
                        for old in list(obj.findall('KeyedProperty')):
                            if old.get('propertyKey')==str(prop):obj.remove(old)
                obj=n(animation,'KeyedObject',objectId=self.ids[name])
                kp=n(obj,'KeyedProperty',propertyKey=prop)
                for frame,value in values:
                    kf=n(kp,'KeyFrameDouble',frame=round(frame),value=value,interpolationType='cubic')
                    n(kf,'CubicEaseInterpolator')
            for leg,phase in self.legs:
                x,y,_=self.groups[leg]
                slow=self.spec['kind'] in ('honesty','gratitude')
                stride,lift=(1.5,1) if slow else (2.5,1.5)
                frames=[(i*duration/16,i*math.pi/4+phase) for i in range(17)]
                track(leg,13,[(f,x+stride*math.cos(a)) for f,a in frames] if mode==1 else [(0,x)])
                track(leg,14,[(f,y-lift*max(0,-math.sin(a))) for f,a in frames] if mode==1 else [(0,y)])
                track(leg,15,[(f,-.035*math.cos(a)) for f,a in frames] if mode==1 else [(0,0)])
            if mode in (2,3):
                gesture={'environment':'Leg front_near','courage':'Leg front_near','self_care':'Paw right'}.get(self.spec['kind'])
                if gesture:
                    _,y,_=self.groups[gesture]
                    track(gesture,14,[(0,y),(12,y),(25,y-4),(45,y-3),(65,y),(120,y)])
                    track(gesture,15,[(0,0),(25,-.05),(45,.02),(65,0),(120,0)])
            fx,fy,_=self.groups['Face']
            track('Face',13,[(0,fx)]);track('Face',14,[(0,fy)])
            if self.spec['kind']=='self_care':
                walk=mode==1
                track('Seated pose',18,[(0,0 if walk else 1)])
                track('Standing pose',18,[(0,1 if walk else 0)])
                hx,hy=self.spec['head']
                track('Face',13,[(0,148-hx if walk else fx)])
                track('Face',14,[(0,272-hy if walk else fy)])
                track('Face',16,[(0,.85 if walk else 1)])
                track('Face',17,[(0,.85 if walk else 1)])
            for obj in list(animation.findall('KeyedObject')):
                if obj.get('objectId')==self.ids['Eyes']:
                    for prop in list(obj.findall('KeyedProperty')):
                        if prop.get('propertyKey')=='17':
                            for i in range(len(self.spec['eyes'])):
                                n(animation,'KeyedObject',objectId=self.ids[f'Eye {i}']).append(copy.deepcopy(prop))
                            obj.remove(prop)
